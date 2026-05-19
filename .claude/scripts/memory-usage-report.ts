#!/usr/bin/env tsx
/**
 * Memory Usage Report Script
 *
 * Generates comprehensive usage analytics:
 * - Vector counts per namespace
 * - Confidence score distribution
 * - Importance distribution
 * - Human-validated percentage
 * - Growth trends (if historical data available)
 *
 * Usage:
 *   npx tsx .claude/scripts/memory-usage-report.ts [--json] [--namespace=NS]
 *
 * Options:
 *   --json          Output JSON only
 *   --namespace=NS  Report on specific namespace only
 */

import { Pinecone } from '@pinecone-database/pinecone';
import * as fs from 'fs/promises';
import * as path from 'path';

interface ConfidenceBucket {
  range: string;
  count: number;
  percentage: number;
}

interface ImportanceBucket {
  level: string;
  count: number;
  percentage: number;
}

interface NamespaceUsage {
  name: string;
  vectorCount: number;
  percentage: number;
  confidenceDistribution: ConfidenceBucket[];
  importanceDistribution: ImportanceBucket[];
  validatedCount: number;
  validatedPercentage: number;
  avgConfidence?: number;
}

interface UsageReport {
  timestamp: string;
  totalVectors: number;
  totalNamespaces: number;
  namespaces: NamespaceUsage[];
  globalStats: {
    avgConfidence: number;
    validatedPercentage: number;
    confidenceBuckets: ConfidenceBucket[];
    importanceBuckets: ImportanceBucket[];
  };
  growthTrends?: {
    weeklyGrowthRate?: number; // vectors/week
    monthlyGrowthRate?: number; // vectors/month
  };
}

function categorizeConfidence(confidence: number): string {
  if (confidence < 0.5) return '<0.5 (Low)';
  if (confidence < 0.7) return '0.5-0.7 (Medium-Low)';
  if (confidence < 0.85) return '0.7-0.85 (Medium-High)';
  return '>=0.85 (High)';
}

function categorizeImportance(importance: string | undefined): string {
  return importance || 'medium';
}

async function generateUsageReport(options: {
  namespace?: string;
}): Promise<UsageReport> {
  const apiKey = process.env.PINECONE_API_KEY;

  if (!apiKey) {
    throw new Error('PINECONE_API_KEY environment variable not set');
  }

  const pc = new Pinecone({ apiKey });
  const indexName = 'orryx-dev-intelligence';
  const index = pc.index(indexName);

  // Get index stats
  const stats = await index.describeIndexStats();

  const namespacesToAnalyze = options.namespace
    ? [options.namespace]
    : Object.keys(stats.namespaces || {});

  const namespaceUsages: NamespaceUsage[] = [];
  let totalVectors = 0;

  // Global aggregators
  const globalConfidenceBuckets: Map<string, number> = new Map();
  const globalImportanceBuckets: Map<string, number> = new Map();
  let globalValidatedCount = 0;
  let globalConfidenceSum = 0;
  let globalConfidenceCount = 0;

  for (const ns of namespacesToAnalyze) {
    const nsVectorCount = stats.namespaces?.[ns]?.vectorCount || 0;
    totalVectors += nsVectorCount;

    if (nsVectorCount === 0) {
      // Empty namespace - add with zeros
      namespaceUsages.push({
        name: ns,
        vectorCount: 0,
        percentage: 0,
        confidenceDistribution: [],
        importanceDistribution: [],
        validatedCount: 0,
        validatedPercentage: 0,
      });
      continue;
    }

    // Query vectors in namespace to get metadata
    // Note: This uses dummy vector approach - in production, implement proper pagination
    const dummyVector = new Array(1536).fill(0);

    try {
      const queryResponse = await index.namespace(ns).query({
        vector: dummyVector,
        topK: Math.min(nsVectorCount, 10000),
        includeMetadata: true,
      });

      // Analyze metadata
      const confidenceBuckets: Map<string, number> = new Map();
      const importanceBuckets: Map<string, number> = new Map();
      let validatedCount = 0;
      let confidenceSum = 0;
      let confidenceCount = 0;

      for (const match of queryResponse.matches) {
        const metadata = match.metadata || {};
        const confidence = (metadata.confidence as number) || 0.8;
        const importance = (metadata.importance as string) || 'medium';
        const validated = (metadata.validated as boolean) || false;

        // Confidence buckets
        const confBucket = categorizeConfidence(confidence);
        confidenceBuckets.set(confBucket, (confidenceBuckets.get(confBucket) || 0) + 1);
        globalConfidenceBuckets.set(confBucket, (globalConfidenceBuckets.get(confBucket) || 0) + 1);
        confidenceSum += confidence;
        confidenceCount++;
        globalConfidenceSum += confidence;
        globalConfidenceCount++;

        // Importance buckets
        importanceBuckets.set(importance, (importanceBuckets.get(importance) || 0) + 1);
        globalImportanceBuckets.set(importance, (globalImportanceBuckets.get(importance) || 0) + 1);

        // Validated count
        if (validated) {
          validatedCount++;
          globalValidatedCount++;
        }
      }

      const totalRetrieved = queryResponse.matches.length;

      namespaceUsages.push({
        name: ns,
        vectorCount: nsVectorCount,
        percentage: 0, // Calculate after totals known
        confidenceDistribution: Array.from(confidenceBuckets.entries()).map(([range, count]) => ({
          range,
          count,
          percentage: (count / totalRetrieved) * 100,
        })),
        importanceDistribution: Array.from(importanceBuckets.entries()).map(([level, count]) => ({
          level,
          count,
          percentage: (count / totalRetrieved) * 100,
        })),
        validatedCount,
        validatedPercentage: (validatedCount / totalRetrieved) * 100,
        avgConfidence: confidenceCount > 0 ? confidenceSum / confidenceCount : undefined,
      });
    } catch (error) {
      console.error(`Error analyzing namespace ${ns}:`, error);
      namespaceUsages.push({
        name: ns,
        vectorCount: nsVectorCount,
        percentage: 0,
        confidenceDistribution: [],
        importanceDistribution: [],
        validatedCount: 0,
        validatedPercentage: 0,
      });
    }
  }

  // Calculate percentages
  namespaceUsages.forEach(ns => {
    ns.percentage = totalVectors > 0 ? (ns.vectorCount / totalVectors) * 100 : 0;
  });

  const report: UsageReport = {
    timestamp: new Date().toISOString(),
    totalVectors,
    totalNamespaces: namespacesToAnalyze.length,
    namespaces: namespaceUsages.sort((a, b) => b.vectorCount - a.vectorCount),
    globalStats: {
      avgConfidence: globalConfidenceCount > 0 ? globalConfidenceSum / globalConfidenceCount : 0,
      validatedPercentage: totalVectors > 0 ? (globalValidatedCount / totalVectors) * 100 : 0,
      confidenceBuckets: Array.from(globalConfidenceBuckets.entries()).map(([range, count]) => ({
        range,
        count,
        percentage: totalVectors > 0 ? (count / totalVectors) * 100 : 0,
      })),
      importanceBuckets: Array.from(globalImportanceBuckets.entries()).map(([level, count]) => ({
        level,
        count,
        percentage: totalVectors > 0 ? (count / totalVectors) * 100 : 0,
      })),
    },
  };

  // TODO: Load historical data for growth trends
  // For now, growth trends are omitted until we have historical snapshots

  return report;
}

function formatMarkdownReport(report: UsageReport): string {
  let md = `# Memory Usage Report\n\n`;
  md += `**Generated:** ${new Date(report.timestamp).toLocaleString()}\n\n`;
  md += `---\n\n`;

  // Summary
  md += `## Summary\n\n`;
  md += `- **Total Vectors:** ${report.totalVectors.toLocaleString()}\n`;
  md += `- **Namespaces:** ${report.totalNamespaces}\n`;
  md += `- **Avg Confidence:** ${report.globalStats.avgConfidence.toFixed(2)}\n`;
  md += `- **Validated:** ${report.globalStats.validatedPercentage.toFixed(1)}%\n\n`;

  // Namespace breakdown
  md += `## Namespace Breakdown\n\n`;
  md += `| Namespace | Vectors | % of Total | Avg Confidence | Validated % |\n`;
  md += `|-----------|---------|------------|----------------|-------------|\n`;

  for (const ns of report.namespaces) {
    md += `| ${ns.name} | ${ns.vectorCount.toLocaleString()} | ${ns.percentage.toFixed(1)}% | ${ns.avgConfidence?.toFixed(2) || 'N/A'} | ${ns.validatedPercentage.toFixed(1)}% |\n`;
  }

  // Global confidence distribution
  md += `\n## Confidence Score Distribution\n\n`;
  md += `| Range | Count | Percentage |\n`;
  md += `|-------|-------|------------|\n`;

  for (const bucket of report.globalStats.confidenceBuckets.sort((a, b) => {
    const order = ['<0.5 (Low)', '0.5-0.7 (Medium-Low)', '0.7-0.85 (Medium-High)', '>=0.85 (High)'];
    return order.indexOf(a.range) - order.indexOf(b.range);
  })) {
    md += `| ${bucket.range} | ${bucket.count.toLocaleString()} | ${bucket.percentage.toFixed(1)}% |\n`;
  }

  // Global importance distribution
  md += `\n## Importance Distribution\n\n`;
  md += `| Level | Count | Percentage |\n`;
  md += `|-------|-------|------------|\n`;

  const importanceOrder = ['critical', 'high', 'medium', 'low'];
  const sortedImportance = report.globalStats.importanceBuckets.sort((a, b) => {
    return importanceOrder.indexOf(a.level) - importanceOrder.indexOf(b.level);
  });

  for (const bucket of sortedImportance) {
    md += `| ${bucket.level} | ${bucket.count.toLocaleString()} | ${bucket.percentage.toFixed(1)}% |\n`;
  }

  md += `\n---\n\n`;
  md += `*Note: Statistics based on queryable vectors. Index stats may lag actual data.*\n`;

  return md;
}

async function main() {
  const args = process.argv.slice(2);
  const jsonOnly = args.includes('--json');
  const namespace = args.find(a => a.startsWith('--namespace='))?.split('=')[1];

  try {
    const report = await generateUsageReport({ namespace });

    if (!jsonOnly) {
      const markdown = formatMarkdownReport(report);
      console.error(markdown);
    }

    // JSON output
    console.log(JSON.stringify(report, null, 2));

    process.exit(0);
  } catch (error) {
    console.error('❌ Usage report failed:', error);
    if (error instanceof Error) {
      console.error(`   Error: ${error.message}`);
    }
    process.exit(1);
  }
}

// Export for testing
export { generateUsageReport, UsageReport, NamespaceUsage };

// Run CLI
const hasCliArgs = process.argv.slice(2).length >= 0;
main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
