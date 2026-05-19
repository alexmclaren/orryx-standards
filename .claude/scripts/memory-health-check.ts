#!/usr/bin/env tsx
/**
 * Memory Health Check Script
 *
 * Checks Pinecone index health and connectivity
 * Returns: Index stats, namespace health, warnings
 *
 * Usage:
 *   npx tsx .claude/scripts/memory-health-check.ts [--json]
 *
 * Options:
 *   --json    Output JSON only (for CI/automation)
 */

import { Pinecone } from '@pinecone-database/pinecone';

interface NamespaceHealth {
  name: string;
  vectorCount: number;
  empty: boolean;
  growthRate?: number; // Vectors/day if historical data available
}

interface HealthCheckResult {
  healthy: boolean;
  timestamp: string;
  index: {
    name: string;
    dimension: number;
    metric: string;
    totalVectors: number;
  };
  namespaces: NamespaceHealth[];
  warnings: string[];
  connectivity: {
    pinecone: boolean;
    latency: number; // ms
  };
}

async function checkHealth(): Promise<HealthCheckResult> {
  const apiKey = process.env.PINECONE_API_KEY;

  if (!apiKey) {
    throw new Error('PINECONE_API_KEY environment variable not set');
  }

  const pc = new Pinecone({ apiKey });
  const indexName = 'orryx-dev-intelligence';
  const index = pc.index(indexName);

  // Measure connectivity latency
  const startTime = Date.now();
  const stats = await index.describeIndexStats();
  const latency = Date.now() - startTime;

  // Parse namespaces
  const namespaces: NamespaceHealth[] = Object.entries(stats.namespaces || {}).map(
    ([name, data]) => ({
      name,
      vectorCount: data.vectorCount || 0,
      empty: (data.vectorCount || 0) === 0,
    })
  );

  // Identify warnings
  const warnings: string[] = [];

  // Warning: Empty namespaces
  const emptyNamespaces = namespaces.filter(ns => ns.empty);
  if (emptyNamespaces.length > 0) {
    warnings.push(
      `${emptyNamespaces.length} empty namespace(s): ${emptyNamespaces.map(ns => ns.name).join(', ')}`
    );
  }

  // Warning: High latency
  if (latency > 1000) {
    warnings.push(`High latency: ${latency}ms (target: <500ms)`);
  }

  // Warning: Low total vector count (might indicate seeding issue)
  if (stats.totalVectorCount === 0) {
    warnings.push('No vectors in index - seeding may have failed');
  }

  // Determine overall health
  const healthy = warnings.length === 0 || warnings.every(w => w.includes('empty namespace'));

  const result: HealthCheckResult = {
    healthy,
    timestamp: new Date().toISOString(),
    index: {
      name: indexName,
      dimension: stats.dimension || 1536,
      metric: 'cosine', // Default for text-embedding-ada-002
      totalVectors: stats.totalVectorCount || 0,
    },
    namespaces,
    warnings,
    connectivity: {
      pinecone: true,
      latency,
    },
  };

  return result;
}

async function main() {
  const args = process.argv.slice(2);
  const jsonOnly = args.includes('--json');

  try {
    const result = await checkHealth();

    if (!jsonOnly) {
      // Human-readable output to stderr
      console.error('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.error('🏥 Memory Health Check');
      console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      console.error(`📊 Index: ${result.index.name}`);
      console.error(`   Dimension: ${result.index.dimension}`);
      console.error(`   Total Vectors: ${result.index.totalVectors.toLocaleString()}`);
      console.error(`   Namespaces: ${result.namespaces.length}\n`);

      console.error(`🔗 Connectivity:`);
      console.error(`   Pinecone: ${result.connectivity.pinecone ? '✅ Connected' : '❌ Disconnected'}`);
      console.error(`   Latency: ${result.connectivity.latency}ms${result.connectivity.latency < 500 ? ' ✅' : ' ⚠️'}\n`);

      console.error(`📁 Namespaces:`);
      result.namespaces
        .sort((a, b) => b.vectorCount - a.vectorCount)
        .forEach(ns => {
          const status = ns.empty ? '⚠️  Empty' : '✅ Active';
          console.error(`   ${status} ${ns.name.padEnd(35)} ${ns.vectorCount.toLocaleString()} vectors`);
        });

      if (result.warnings.length > 0) {
        console.error(`\n⚠️  Warnings:`);
        result.warnings.forEach(w => console.error(`   - ${w}`));
      }

      console.error(`\n${result.healthy ? '✅ HEALTHY' : '⚠️  WARNINGS PRESENT'}`);
      console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    }

    // JSON output to stdout (for automation)
    console.log(JSON.stringify(result, null, 2));

    process.exit(result.healthy ? 0 : 1);
  } catch (error) {
    console.error('❌ Health check failed:', error);
    if (error instanceof Error) {
      console.error(`   Error: ${error.message}`);
    }
    process.exit(1);
  }
}

// Export for testing
export { checkHealth, HealthCheckResult, NamespaceHealth };

// Run CLI
const hasCliArgs = process.argv.slice(2).length >= 0; // Always run when invoked
main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
