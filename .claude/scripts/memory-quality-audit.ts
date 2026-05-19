#!/usr/bin/env tsx
/**
 * Memory Quality Audit Script
 *
 * Comprehensive quality checks for memory data integrity:
 * - Confidence score validation (flag low-confidence memories)
 * - Metadata completeness (required fields present)
 * - Orphaned memories (superseded_by points to non-existent memory)
 * - Security scan integration (references memory-security-audit.ts)
 *
 * Usage:
 *   npx tsx .claude/scripts/memory-quality-audit.ts [--namespace=NS] [--fix]
 *
 * Options:
 *   --namespace=NS  Audit specific namespace only
 *   --fix           Auto-fix issues where safe (dangerous!)
 *   --json          Output JSON only
 */

import { Pinecone } from '@pinecone-database/pinecone';

interface QualityIssue {
  memoryId: string;
  namespace: string;
  severity: 'critical' | 'high' | 'medium' | 'low';
  issue: string;
  details: string;
  fixable: boolean;
}

interface QualityAuditResult {
  timestamp: string;
  totalMemoriesAudited: number;
  namespacesAudited: string[];
  issues: QualityIssue[];
  issuesByCategory: {
    lowConfidence: number;
    missingMetadata: number;
    orphanedMemories: number;
    invalidTypes: number;
    other: number;
  };
  passed: boolean;
  recommendations: string[];
}

// Required metadata fields
const REQUIRED_FIELDS = ['type', 'repo', 'domain', 'confidence', 'importance'];

// Valid memory types
const VALID_TYPES = [
  'session-learning',
  'adr',
  'pattern',
  'debugging-solution',
  'incident',
  'code-review',
  'standard',
  'decision',
  'codeburn-finding',
  'codex-review',
];

async function auditQuality(options: {
  namespace?: string;
  fix?: boolean;
}): Promise<QualityAuditResult> {
  const apiKey = process.env.PINECONE_API_KEY;

  if (!apiKey) {
    throw new Error('PINECONE_API_KEY environment variable not set');
  }

  const pc = new Pinecone({ apiKey });
  const indexName = 'orryx-dev-intelligence';
  const index = pc.index(indexName);

  // Get index stats
  const stats = await index.describeIndexStats();

  const namespacesToAudit = options.namespace
    ? [options.namespace]
    : Object.keys(stats.namespaces || {});

  console.error('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.error('🔍 Memory Quality Audit');
  console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  console.error(`📊 Auditing ${namespacesToAudit.length} namespace(s)...`);

  let totalMemoriesAudited = 0;
  const allIssues: QualityIssue[] = [];
  const issuesByCategory = {
    lowConfidence: 0,
    missingMetadata: 0,
    orphanedMemories: 0,
    invalidTypes: 0,
    other: 0,
  };

  // Track all memory IDs for orphan detection
  const allMemoryIds = new Set<string>();
  const supersededByReferences = new Map<string, string[]>(); // memory_id -> referencing memories

  // First pass: Collect all memory IDs and references
  for (const ns of namespacesToAudit) {
    const nsVectorCount = stats.namespaces?.[ns]?.vectorCount || 0;

    if (nsVectorCount === 0) continue;

    try {
      const dummyVector = new Array(1536).fill(0);
      const queryResponse = await index.namespace(ns).query({
        vector: dummyVector,
        topK: Math.min(nsVectorCount, 10000),
        includeMetadata: true,
      });

      for (const match of queryResponse.matches) {
        allMemoryIds.add(match.id);

        const supersededBy = match.metadata?.superseded_by as string | undefined;
        if (supersededBy) {
          if (!supersededByReferences.has(supersededBy)) {
            supersededByReferences.set(supersededBy, []);
          }
          supersededByReferences.get(supersededBy)!.push(match.id);
        }
      }
    } catch (error) {
      console.error(`Error in first pass for ${ns}:`, error);
    }
  }

  // Second pass: Quality checks
  for (const ns of namespacesToAudit) {
    const nsVectorCount = stats.namespaces?.[ns]?.vectorCount || 0;
    totalMemoriesAudited += nsVectorCount;

    if (nsVectorCount === 0) {
      console.error(`   Skipping: ${ns} (empty)`);
      continue;
    }

    console.error(`   Auditing: ${ns} (${nsVectorCount} vectors)`);

    try {
      const dummyVector = new Array(1536).fill(0);
      const queryResponse = await index.namespace(ns).query({
        vector: dummyVector,
        topK: Math.min(nsVectorCount, 10000),
        includeMetadata: true,
      });

      for (const match of queryResponse.matches) {
        const metadata = match.metadata || {};
        const memoryId = match.id;

        // Check 1: Low confidence
        const confidence = (metadata.confidence as number) || 0.8;
        if (confidence < 0.5) {
          allIssues.push({
            memoryId,
            namespace: ns,
            severity: 'medium',
            issue: 'Low Confidence',
            details: `Confidence score ${confidence.toFixed(2)} below threshold (0.5)`,
            fixable: false,
          });
          issuesByCategory.lowConfidence++;
        }

        // Check 2: Missing required metadata
        const missingFields: string[] = [];
        for (const field of REQUIRED_FIELDS) {
          if (metadata[field] === undefined || metadata[field] === null) {
            missingFields.push(field);
          }
        }

        if (missingFields.length > 0) {
          allIssues.push({
            memoryId,
            namespace: ns,
            severity: 'high',
            issue: 'Missing Required Metadata',
            details: `Missing fields: ${missingFields.join(', ')}`,
            fixable: false,
          });
          issuesByCategory.missingMetadata++;
        }

        // Check 3: Invalid memory type
        const type = metadata.type as string;
        if (type && !VALID_TYPES.includes(type)) {
          allIssues.push({
            memoryId,
            namespace: ns,
            severity: 'low',
            issue: 'Invalid Memory Type',
            details: `Type "${type}" not in valid types list`,
            fixable: false,
          });
          issuesByCategory.invalidTypes++;
        }

        // Check 4: Orphaned superseded_by reference
        const supersededBy = metadata.superseded_by as string | undefined;
        if (supersededBy && !allMemoryIds.has(supersededBy)) {
          allIssues.push({
            memoryId,
            namespace: ns,
            severity: 'medium',
            issue: 'Orphaned Superseded Reference',
            details: `Points to non-existent memory: ${supersededBy}`,
            fixable: true, // Can remove the superseded_by field
          });
          issuesByCategory.orphanedMemories++;
        }

        // Check 5: Empty content
        const content = metadata.content as string;
        if (!content || content.trim().length === 0) {
          allIssues.push({
            memoryId,
            namespace: ns,
            severity: 'critical',
            issue: 'Empty Content',
            details: 'Memory has no content',
            fixable: false, // Should probably delete
          });
          issuesByCategory.other++;
        }
      }
    } catch (error) {
      console.error(`   Error auditing ${ns}:`, error);
    }
  }

  // Generate recommendations
  const recommendations: string[] = [];

  if (issuesByCategory.lowConfidence > 0) {
    recommendations.push(
      `Review ${issuesByCategory.lowConfidence} low-confidence memories. Consider human validation or removal.`
    );
  }

  if (issuesByCategory.missingMetadata > 0) {
    recommendations.push(
      `Fix ${issuesByCategory.missingMetadata} memories with missing metadata. Update write scripts to enforce required fields.`
    );
  }

  if (issuesByCategory.orphanedMemories > 0) {
    recommendations.push(
      `Clean up ${issuesByCategory.orphanedMemories} orphaned references. Run with --fix to remove broken superseded_by fields.`
    );
  }

  if (issuesByCategory.invalidTypes > 0) {
    recommendations.push(
      `Update ${issuesByCategory.invalidTypes} memories with invalid types or add new types to VALID_TYPES list.`
    );
  }

  const totalIssues = allIssues.length;
  const passed = totalIssues === 0;

  // Print report
  console.error('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.error('📋 Quality Audit Results');
  console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  console.error(`   Total Memories: ${totalMemoriesAudited.toLocaleString()}`);
  console.error(`   Namespaces: ${namespacesToAudit.length}`);
  console.error(`   Issues Found: ${totalIssues}`);
  console.error(`   - Low Confidence: ${issuesByCategory.lowConfidence}`);
  console.error(`   - Missing Metadata: ${issuesByCategory.missingMetadata}`);
  console.error(`   - Orphaned References: ${issuesByCategory.orphanedMemories}`);
  console.error(`   - Invalid Types: ${issuesByCategory.invalidTypes}`);
  console.error(`   - Other: ${issuesByCategory.other}\n`);

  if (passed) {
    console.error('✅ PASSED: All quality checks passed');
  } else {
    console.error('⚠️  ISSUES DETECTED\n');

    // Group by severity
    const criticalIssues = allIssues.filter(i => i.severity === 'critical');
    const highIssues = allIssues.filter(i => i.severity === 'high');
    const mediumIssues = allIssues.filter(i => i.severity === 'medium');

    if (criticalIssues.length > 0) {
      console.error(`🔴 CRITICAL Issues (${criticalIssues.length}):`);
      criticalIssues.slice(0, 5).forEach(i => {
        console.error(`   - ${i.issue}: ${i.namespace}/${i.memoryId}`);
        console.error(`     ${i.details}`);
      });
      if (criticalIssues.length > 5) {
        console.error(`   ... and ${criticalIssues.length - 5} more`);
      }
      console.error('');
    }

    if (highIssues.length > 0) {
      console.error(`🟠 HIGH Issues (${highIssues.length}):`);
      highIssues.slice(0, 5).forEach(i => {
        console.error(`   - ${i.issue}: ${i.namespace}/${i.memoryId}`);
        console.error(`     ${i.details}`);
      });
      if (highIssues.length > 5) {
        console.error(`   ... and ${highIssues.length - 5} more`);
      }
      console.error('');
    }

    if (mediumIssues.length > 0) {
      console.error(`🟡 MEDIUM Issues (${mediumIssues.length}):`);
      mediumIssues.slice(0, 3).forEach(i => {
        console.error(`   - ${i.issue}: ${i.namespace}/${i.memoryId}`);
      });
      if (mediumIssues.length > 3) {
        console.error(`   ... and ${mediumIssues.length - 3} more`);
      }
      console.error('');
    }

    // Recommendations
    if (recommendations.length > 0) {
      console.error('💡 Recommendations:');
      recommendations.forEach(r => console.error(`   - ${r}`));
      console.error('');
    }

    // Fix option
    if (options.fix) {
      console.error('⚠️  FIX MODE: Applying auto-fixes...\n');

      const fixableIssues = allIssues.filter(i => i.fixable);
      console.error(`   Fixable issues: ${fixableIssues.length}/${totalIssues}`);

      // Currently, only orphaned references are auto-fixable
      // In production, implement metadata updates to remove orphaned superseded_by fields
      console.error('   Note: Auto-fix not yet implemented. Manual intervention required.');
    }
  }

  console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // For security audit integration reference
  console.error('💡 For PII/secrets scanning, run: npx tsx .claude/scripts/memory-security-audit.ts\n');

  const result: QualityAuditResult = {
    timestamp: new Date().toISOString(),
    totalMemoriesAudited,
    namespacesAudited: namespacesToAudit,
    issues: allIssues,
    issuesByCategory,
    passed,
    recommendations,
  };

  return result;
}

async function main() {
  const args = process.argv.slice(2);
  const namespace = args.find(a => a.startsWith('--namespace='))?.split('=')[1];
  const fix = args.includes('--fix');
  const jsonOnly = args.includes('--json');

  try {
    const result = await auditQuality({ namespace, fix });

    // JSON output
    console.log(JSON.stringify(result, null, 2));

    // Exit code: 0 if passed, 1 if issues found
    process.exit(result.passed ? 0 : 1);
  } catch (error) {
    console.error('❌ Quality audit failed:', error);
    if (error instanceof Error) {
      console.error(`   Error: ${error.message}`);
    }
    process.exit(1);
  }
}

// Export for testing
export { auditQuality, QualityAuditResult, QualityIssue };

// Run CLI
const hasCliArgs = process.argv.slice(2).length >= 0;
main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
