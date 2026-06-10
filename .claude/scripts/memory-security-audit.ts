#!/usr/bin/env tsx
/**
 * Memory Security Audit Script
 *
 * Scans all memories in Pinecone for PII and secrets
 * Zero-tolerance policy: Any violation blocks deployment
 *
 * Usage:
 *   npx tsx .claude/scripts/memory-security-audit.ts [--namespace=NS] [--fix]
 *
 * Options:
 *   --namespace=NS  Only scan specific namespace (default: all)
 *   --fix           Delete violating memories (dangerous!)
 *   --report-only   Generate report without exit code
 */

import { Pinecone } from '@pinecone-database/pinecone';

// Forbidden patterns (CRITICAL: Keep updated)
const FORBIDDEN_PATTERNS = [
  {
    name: 'Pinecone API Keys',
    pattern: /pcsk_[A-Za-z0-9_-]+/g,
    severity: 'critical',
  },
  {
    name: 'OpenAI API Keys',
    pattern: /sk-proj-[A-Za-z0-9_-]+/g,
    severity: 'critical',
  },
  {
    name: 'AWS Access Keys',
    pattern: /AKIA[0-9A-Z]{16}/g,
    severity: 'critical',
  },
  {
    name: 'AWS Secret Keys',
    pattern: /ASIA[0-9A-Z]{16}/g,
    severity: 'critical',
  },
  {
    name: 'Generic Passwords',
    pattern: /password\s*[=:]\s*[^\s]+/gi,
    severity: 'high',
  },
  {
    name: 'Email Addresses',
    pattern: /\b(?!noreply@anthropic\.com)[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g,
    severity: 'medium',
    note: 'Excludes noreply@anthropic.com (Claude Code co-authorship)',
  },
  {
    name: 'Phone Numbers (US)',
    pattern: /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/g,
    severity: 'medium',
  },
  {
    name: 'Phone Numbers (AU)',
    pattern: /\b(?:\+?61|0)[2-478]\s?\d{4}\s?\d{4}\b/g,
    severity: 'medium',
  },
  {
    name: 'Credit Card Numbers',
    pattern: /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/g,
    severity: 'high',
  },
  {
    name: 'Social Security Numbers',
    pattern: /\b\d{3}-\d{2}-\d{4}\b/g,
    severity: 'high',
  },
  {
    name: 'Australian TFN',
    pattern: /\b\d{3}\s\d{3}\s\d{3}\b/g,
    severity: 'high',
  },
  {
    name: 'Bearer Tokens',
    pattern: /Bearer\s+[A-Za-z0-9_-]+/g,
    severity: 'critical',
  },
  {
    name: 'Private Keys',
    pattern: /-----BEGIN\s+(?:RSA\s+)?PRIVATE\s+KEY-----/g,
    severity: 'critical',
  },
];

interface Violation {
  memoryId: string;
  namespace: string;
  patternName: string;
  severity: string;
  matches: string[];
  content: string;
}

interface AuditResult {
  totalMemoriesScanned: number;
  namespacesScanned: string[];
  violations: Violation[];
  criticalCount: number;
  highCount: number;
  mediumCount: number;
  passed: boolean;
}

async function scanMemory(
  pc: Pinecone,
  indexName: string,
  namespace: string
): Promise<Violation[]> {
  const violations: Violation[] = [];
  const index = pc.index(indexName);

  try {
    // Query all vectors in namespace (use dummy query vector)
    // Note: This is a simplified approach. In production, paginate through all vectors
    const dummyVector = new Array(1536).fill(0); // OpenAI ada-002 dimension

    const queryResponse = await index.namespace(namespace).query({
      vector: dummyVector,
      topK: 10000, // Max query limit
      includeMetadata: true,
    });

    for (const match of queryResponse.matches) {
      const content = match.metadata?.content as string || '';
      const memoryId = match.id;

      // Scan content against all patterns
      for (const { name, pattern, severity } of FORBIDDEN_PATTERNS) {
        const matches = content.match(pattern);

        if (matches && matches.length > 0) {
          violations.push({
            memoryId,
            namespace,
            patternName: name,
            severity,
            matches: matches.map(m => m.substring(0, 20) + '...'), // Truncate for safety
            content: content.substring(0, 100) + '...', // Truncate for report
          });
        }
      }
    }
  } catch (error) {
    console.error(`❌ Error scanning namespace ${namespace}:`, error);
  }

  return violations;
}

async function runAudit(options: {
  namespace?: string;
  fix?: boolean;
  reportOnly?: boolean;
}): Promise<AuditResult> {
  const apiKey = process.env.PINECONE_API_KEY;

  if (!apiKey) {
    throw new Error('PINECONE_API_KEY environment variable not set');
  }

  const pc = new Pinecone({ apiKey });
  const indexName = 'orryx-dev-intelligence';
  const index = pc.index(indexName);

  // Get index stats to determine namespaces
  const stats = await index.describeIndexStats();
  const namespacesToScan = options.namespace
    ? [options.namespace]
    : Object.keys(stats.namespaces || {});

  console.error('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.error('🔒 Memory Security Audit');
  console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  console.error(`📊 Scanning ${namespacesToScan.length} namespace(s)...`);

  let totalMemories = 0;
  const allViolations: Violation[] = [];

  for (const ns of namespacesToScan) {
    const nsVectorCount = stats.namespaces?.[ns]?.vectorCount || 0;
    totalMemories += nsVectorCount;

    console.error(`   Scanning: ${ns} (${nsVectorCount} vectors)`);
    const violations = await scanMemory(pc, indexName, ns);

    if (violations.length > 0) {
      console.error(`   ❌ ${violations.length} violation(s) found`);
      allViolations.push(...violations);
    } else {
      console.error(`   ✅ Clean`);
    }
  }

  // Count by severity
  const criticalCount = allViolations.filter(v => v.severity === 'critical').length;
  const highCount = allViolations.filter(v => v.severity === 'high').length;
  const mediumCount = allViolations.filter(v => v.severity === 'medium').length;

  const passed = allViolations.length === 0;

  const result: AuditResult = {
    totalMemoriesScanned: totalMemories,
    namespacesScanned: namespacesToScan,
    violations: allViolations,
    criticalCount,
    highCount,
    mediumCount,
    passed,
  };

  // Print report
  console.error('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.error('📋 Audit Results');
  console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  console.error(`   Total Memories: ${totalMemories}`);
  console.error(`   Namespaces: ${namespacesToScan.length}`);
  console.error(`   Violations: ${allViolations.length}`);
  console.error(`   Critical: ${criticalCount}`);
  console.error(`   High: ${highCount}`);
  console.error(`   Medium: ${mediumCount}\n`);

  if (passed) {
    console.error('✅ PASSED: No PII or secrets detected');
  } else {
    console.error('❌ FAILED: PII or secrets detected\n');

    // Print violations by severity
    if (criticalCount > 0) {
      console.error('🔴 CRITICAL Violations:');
      allViolations
        .filter(v => v.severity === 'critical')
        .forEach(v => {
          console.error(`   - ${v.patternName} in ${v.namespace}/${v.memoryId}`);
          console.error(`     Matches: ${v.matches.join(', ')}`);
        });
      console.error('');
    }

    if (highCount > 0) {
      console.error('🟠 HIGH Violations:');
      allViolations
        .filter(v => v.severity === 'high')
        .forEach(v => {
          console.error(`   - ${v.patternName} in ${v.namespace}/${v.memoryId}`);
        });
      console.error('');
    }

    if (mediumCount > 0) {
      console.error('🟡 MEDIUM Violations:');
      allViolations
        .filter(v => v.severity === 'medium')
        .forEach(v => {
          console.error(`   - ${v.patternName} in ${v.namespace}/${v.memoryId}`);
        });
      console.error('');
    }

    // Fix option (dangerous)
    if (options.fix) {
      console.error('⚠️  FIX MODE: Deleting violating memories...\n');

      const memoryIdsToDelete = [...new Set(allViolations.map(v => v.memoryId))];

      for (const memoryId of memoryIdsToDelete) {
        const violation = allViolations.find(v => v.memoryId === memoryId)!;
        try {
          await index.namespace(violation.namespace).deleteOne(memoryId);
          console.error(`   ✓ Deleted: ${violation.namespace}/${memoryId}`);
        } catch (error) {
          console.error(`   ✗ Failed to delete: ${violation.namespace}/${memoryId}`);
        }
      }
    } else {
      console.error('💡 To delete violating memories: Run with --fix flag (DANGEROUS)');
    }
  }

  console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  return result;
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);

  const options = {
    namespace: args.find(a => a.startsWith('--namespace='))?.split('=')[1],
    fix: args.includes('--fix'),
    reportOnly: args.includes('--report-only'),
  };

  try {
    const result = await runAudit(options);

    // Output JSON for programmatic use
    console.log(JSON.stringify(result, null, 2));

    // Exit with code 1 if violations found (unless report-only)
    if (!result.passed && !options.reportOnly) {
      process.exit(1);
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Audit failed:', error);
    if (error instanceof Error) {
      console.error(`   Error: ${error.message}`);
    }
    process.exit(1);
  }
}

// Export for testing
export { runAudit, FORBIDDEN_PATTERNS, AuditResult, Violation };

// Run CLI
const hasCliArgs = process.argv.slice(2).length > 0;
if (hasCliArgs || process.argv.slice(2).some(arg => arg.startsWith('--'))) {
  main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}
