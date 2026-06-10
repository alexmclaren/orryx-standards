#!/usr/bin/env tsx
/**
 * Pinecone Memory Query Interface
 *
 * Retrieves relevant memories from Pinecone based on query and context
 * Used by hooks and can be invoked manually
 *
 * Usage:
 *   npx tsx .claude/scripts/pinecone-memory-query.ts "authentication patterns" --namespace=pillarworks.patterns
 *   npx tsx .claude/scripts/pinecone-memory-query.ts "NoneType error" --repo=pillarworks --domain=debugging
 */

import { Pinecone } from '@pinecone-database/pinecone';
import { OpenAI } from 'openai';

const INDEX_NAME = 'orryx-dev-intelligence';

interface QueryOptions {
  query: string;
  namespaces?: string[];
  repo?: string;
  domain?: string;
  topK?: number;
  minConfidence?: number;
  minImportance?: 'low' | 'medium' | 'high' | 'critical';
  recencyBias?: number;
  prioritizeValidated?: boolean;
  includeSuperseded?: boolean;
}

interface MemoryMatch {
  id: string;
  score: number;
  content?: string;
  metadata?: Record<string, any>;
}

interface QueryResult {
  query: string;
  matches: MemoryMatch[];
  namespaces_searched: string[];
  total_matches: number;
}

async function generateEmbedding(text: string): Promise<number[]> {
  const openaiKey = process.env.OPENAI_API_KEY;
  if (!openaiKey) {
    throw new Error('OPENAI_API_KEY environment variable not set');
  }

  const openai = new OpenAI({ apiKey: openaiKey });
  const response = await openai.embeddings.create({
    model: 'text-embedding-ada-002',
    input: text,
  });

  return response.data[0].embedding;
}

function determineNamespaces(options: QueryOptions): string[] {
  // Explicit namespaces provided
  if (options.namespaces && options.namespaces.length > 0) {
    return options.namespaces;
  }

  // Build namespaces from repo + domain
  const namespaces: string[] = [];

  if (options.repo && options.domain) {
    namespaces.push(`${options.repo}.${options.domain}`);
  } else if (options.repo) {
    // Search all domains in repo
    namespaces.push(
      `${options.repo}.sessions`,
      `${options.repo}.architecture`,
      `${options.repo}.patterns`,
      `${options.repo}.debugging`
    );
  } else if (options.domain) {
    // Search domain across common repos
    namespaces.push(
      `pillarworks.${options.domain}`,
      `orryx-brain.${options.domain}`,
      `clinical-trials.${options.domain}`
    );
  } else {
    // Default: search cross-repo namespaces
    namespaces.push(
      'standards.global',
      'architecture.cross-repo',
      'patterns.common'
    );
  }

  return namespaces;
}

function buildMetadataFilter(options: QueryOptions): Record<string, any> {
  const filter: Record<string, any> = {};

  // Confidence threshold
  if (options.minConfidence !== undefined) {
    filter.confidence = { $gte: options.minConfidence };
  }

  // Importance threshold
  if (options.minImportance) {
    const importanceLevels = ['low', 'medium', 'high', 'critical'];
    const minIndex = importanceLevels.indexOf(options.minImportance);
    filter.importance = { $in: importanceLevels.slice(minIndex) };
  }

  // Validated only
  if (options.prioritizeValidated) {
    filter.validated = true;
  }

  // Exclude superseded unless explicitly requested
  if (!options.includeSuperseded) {
    filter.superseded_by = { $exists: false };
  }

  return Object.keys(filter).length > 0 ? filter : undefined;
}

async function queryMemory(options: QueryOptions): Promise<QueryResult> {
  const apiKey = process.env.PINECONE_API_KEY;
  if (!apiKey) {
    throw new Error('PINECONE_API_KEY environment variable not set');
  }

  // Initialize clients
  const pinecone = new Pinecone({ apiKey });
  const index = pinecone.index(INDEX_NAME);

  // Determine search strategy
  const namespaces = determineNamespaces(options);
  const topK = options.topK || 5;
  const filter = buildMetadataFilter(options);

  // Generate query embedding
  console.error(`🔍 Generating embedding for: "${options.query}"`);
  const queryVector = await generateEmbedding(options.query);

  // Query across namespaces
  console.error(`📊 Searching ${namespaces.length} namespace(s)...`);
  const allMatches: MemoryMatch[] = [];

  for (const namespace of namespaces) {
    try {
      const results = await index.namespace(namespace).query({
        vector: queryVector,
        topK,
        includeMetadata: true,
        filter,
      });

      if (results.matches) {
        allMatches.push(
          ...results.matches.map((match) => ({
            id: match.id,
            score: match.score || 0,
            metadata: match.metadata as Record<string, any>,
            namespace,
          }))
        );
      }
    } catch (error) {
      console.error(`⚠️  Namespace "${namespace}" query failed:`, error);
    }
  }

  // Sort by score (with optional recency bias)
  allMatches.sort((a, b) => {
    let scoreA = a.score;
    let scoreB = b.score;

    // Apply recency bias if requested
    if (options.recencyBias && a.metadata?.created_at && b.metadata?.created_at) {
      const ageA = Date.now() - new Date(a.metadata.created_at).getTime();
      const ageB = Date.now() - new Date(b.metadata.created_at).getTime();
      const maxAge = 365 * 24 * 60 * 60 * 1000; // 1 year in ms

      scoreA += options.recencyBias * (1 - ageA / maxAge);
      scoreB += options.recencyBias * (1 - ageB / maxAge);
    }

    return scoreB - scoreA;
  });

  // Take top K across all namespaces
  const topMatches = allMatches.slice(0, topK);

  return {
    query: options.query,
    matches: topMatches,
    namespaces_searched: namespaces,
    total_matches: allMatches.length,
  };
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log(`
Pinecone Memory Query Interface

Usage:
  npx tsx .claude/scripts/pinecone-memory-query.ts QUERY [OPTIONS]

Arguments:
  QUERY              Search query string (required)

Options:
  --namespace=NS     Specific namespace(s) to search (comma-separated)
  --repo=REPO        Repository name (pillarworks, orryx-brain, etc.)
  --domain=DOMAIN    Domain name (architecture, debugging, patterns, etc.)
  --top-k=N          Number of results to return (default: 5)
  --min-confidence=N Minimum confidence score 0-1 (default: 0.6)
  --min-importance=I Minimum importance (low, medium, high, critical)
  --recency-bias=N   Weight recent memories higher 0-1 (default: 0)
  --validated-only   Only return human-validated memories
  --include-superseded Include superseded memories

Examples:
  # Search for JWT authentication patterns in Pillarworks
  npx tsx .claude/scripts/pinecone-memory-query.ts "JWT authentication" --repo=pillarworks --domain=patterns

  # Search for NoneType errors across all repos
  npx tsx .claude/scripts/pinecone-memory-query.ts "NoneType error" --domain=debugging

  # Search specific namespace with high confidence only
  npx tsx .claude/scripts/pinecone-memory-query.ts "incident response" --namespace=incidents.postmortems --min-confidence=0.8
`);
    process.exit(0);
  }

  // Parse arguments
  const query = args[0];
  const options: QueryOptions = { query };

  for (const arg of args.slice(1)) {
    if (arg.startsWith('--namespace=')) {
      options.namespaces = arg.split('=')[1].split(',');
    } else if (arg.startsWith('--repo=')) {
      options.repo = arg.split('=')[1];
    } else if (arg.startsWith('--domain=')) {
      options.domain = arg.split('=')[1];
    } else if (arg.startsWith('--top-k=')) {
      options.topK = parseInt(arg.split('=')[1], 10);
    } else if (arg.startsWith('--min-confidence=')) {
      options.minConfidence = parseFloat(arg.split('=')[1]);
    } else if (arg.startsWith('--min-importance=')) {
      options.minImportance = arg.split('=')[1] as any;
    } else if (arg.startsWith('--recency-bias=')) {
      options.recencyBias = parseFloat(arg.split('=')[1]);
    } else if (arg === '--validated-only') {
      options.prioritizeValidated = true;
    } else if (arg === '--include-superseded') {
      options.includeSuperseded = true;
    }
  }

  try {
    const result = await queryMemory(options);

    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`📝 Query: "${result.query}"`);
    console.log(`📊 Found ${result.total_matches} matches across ${result.namespaces_searched.length} namespace(s)`);
    console.log(`🎯 Showing top ${result.matches.length} results`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    result.matches.forEach((match, index) => {
      console.log(`${index + 1}. [Score: ${match.score.toFixed(4)}] ${match.id}`);
      console.log(`   Namespace: ${match.metadata?.namespace || 'unknown'}`);
      console.log(`   Type: ${match.metadata?.type || 'unknown'}`);
      console.log(`   Confidence: ${match.metadata?.confidence || 'N/A'}`);
      console.log(`   Importance: ${match.metadata?.importance || 'N/A'}`);
      console.log(`   Tags: ${match.metadata?.tags?.join(', ') || 'none'}`);
      console.log(`   Created: ${match.metadata?.created_at || 'unknown'}`);
      if (match.metadata?.validated) {
        console.log(`   ✅ Human-validated`);
      }
      console.log();
    });

    // Output JSON for programmatic consumption
    if (process.env.OUTPUT_JSON === 'true') {
      console.log(JSON.stringify(result, null, 2));
    }

  } catch (error) {
    console.error('❌ Query failed:', error);
    if (error instanceof Error) {
      console.error(`   Error: ${error.message}`);
    }
    process.exit(1);
  }
}

// Export for use in hooks
export { queryMemory, QueryOptions, QueryResult, MemoryMatch };

// Run CLI only if CLI-style arguments provided (not when imported as module)
const hasCliArgs = process.argv.slice(2).some(arg => arg.startsWith('--') || arg === '-h' || arg === '--help') ||
                   (process.argv.length > 2 && !process.argv[2].startsWith('{'));
if (hasCliArgs) {
  main().catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}
