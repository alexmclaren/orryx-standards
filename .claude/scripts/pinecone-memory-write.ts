#!/usr/bin/env tsx
/**
 * Pinecone Memory Write Interface
 *
 * Writes memories (learnings, patterns, solutions) to Pinecone
 * Used by hooks and can be invoked manually
 *
 * Usage:
 *   npx tsx .claude/scripts/pinecone-memory-write.ts \
 *     --content="Use refresh tokens with JWT" \
 *     --type=pattern \
 *     --repo=pillarworks \
 *     --domain=architecture \
 *     --tags=authentication,security,JWT
 */

import { Pinecone } from '@pinecone-database/pinecone';
import { OpenAI } from 'openai';
import { v4 as uuidv4 } from 'uuid';

const INDEX_NAME = 'orryx-dev-intelligence';

type MemoryType =
  | 'session-learning'
  | 'adr'
  | 'pattern'
  | 'debugging-solution'
  | 'incident'
  | 'code-review'
  | 'standard'
  | 'decision'
  | 'codeburn-finding'
  | 'codex-review';

type Importance = 'critical' | 'high' | 'medium' | 'low';

interface MemoryMetadata {
  // Core Identity
  id: string;
  type: MemoryType;

  // Context
  repo: string;
  domain: string;
  namespace: string;

  // Temporal
  created_at: string;
  updated_at: string;
  expires_at?: string;

  // Provenance
  author: string;
  author_type: 'human' | 'agent';
  session_id?: string;

  // Content Classification
  tags: string[];
  confidence: number;
  importance: Importance;

  // Relationships
  related_files: string[];
  related_issues: string[];
  related_prs: string[];
  related_memories: string[];
  supersedes?: string;
  superseded_by?: string;

  // Retrieval Hints
  retrieval_triggers: string[];
  relevant_to: string[];

  // Quality Metadata
  validated: boolean;
  validation_timestamp?: string;
  usage_count: number;
  effectiveness_score?: number;
}

interface WriteMemoryOptions {
  content: string;
  type: MemoryType;
  repo: string;
  domain: string;
  tags?: string[];
  confidence?: number;
  importance?: Importance;
  author?: string;
  author_type?: 'human' | 'agent';
  session_id?: string;
  related_files?: string[];
  related_issues?: string[];
  related_prs?: string[];
  related_memories?: string[];
  supersedes?: string;
  retrieval_triggers?: string[];
  relevant_to?: string[];
  validated?: boolean;
  expires_in_days?: number;
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

function extractKeywords(text: string): string[] {
  // Simple keyword extraction (can be enhanced with NLP)
  const words = text
    .toLowerCase()
    .replace(/[^\w\s]/g, ' ')
    .split(/\s+/)
    .filter((word) => word.length > 3);

  // Remove common words
  const stopWords = new Set([
    'this',
    'that',
    'with',
    'from',
    'have',
    'been',
    'were',
    'they',
    'there',
    'their',
    'about',
    'would',
    'could',
    'should',
  ]);

  return Array.from(new Set(words.filter((word) => !stopWords.has(word))));
}

function chunkContent(content: string, maxTokens: number = 500): string[] {
  // Simple chunking by paragraph or sentence
  const paragraphs = content.split(/\n\n+/);
  const chunks: string[] = [];
  let currentChunk = '';

  for (const paragraph of paragraphs) {
    const estimatedTokens = (currentChunk + paragraph).split(/\s+/).length;

    if (estimatedTokens > maxTokens && currentChunk.length > 0) {
      chunks.push(currentChunk.trim());
      currentChunk = paragraph;
    } else {
      currentChunk += (currentChunk ? '\n\n' : '') + paragraph;
    }
  }

  if (currentChunk.trim()) {
    chunks.push(currentChunk.trim());
  }

  return chunks.length > 0 ? chunks : [content];
}

async function writeMemory(options: WriteMemoryOptions): Promise<string[]> {
  const apiKey = process.env.PINECONE_API_KEY;
  if (!apiKey) {
    throw new Error('PINECONE_API_KEY environment variable not set');
  }

  // Initialize Pinecone
  const pinecone = new Pinecone({ apiKey });
  const index = pinecone.index(INDEX_NAME);

  // Build namespace
  const namespace = `${options.repo}.${options.domain}`;

  // Chunk content if necessary
  const chunks = chunkContent(options.content);
  const isChunked = chunks.length > 1;

  console.error(
    `📝 Writing ${isChunked ? chunks.length + ' chunks' : '1 memory'} to namespace: ${namespace}`
  );

  const memoryIds: string[] = [];

  for (let i = 0; i < chunks.length; i++) {
    const chunk = chunks[i];
    const memoryId = uuidv4();

    // Generate embedding
    console.error(`🔄 Generating embedding for chunk ${i + 1}/${chunks.length}...`);
    const embedding = await generateEmbedding(chunk);

    // Build metadata
    const now = new Date().toISOString();
    const expiresAt = options.expires_in_days
      ? new Date(Date.now() + options.expires_in_days * 24 * 60 * 60 * 1000).toISOString()
      : undefined;

    const metadata: Partial<MemoryMetadata> = {
      id: memoryId,
      type: options.type,
      repo: options.repo,
      domain: options.domain,
      namespace,
      created_at: now,
      updated_at: now,
      expires_at: expiresAt,
      author: options.author || 'Claude Sonnet 4.5',
      author_type: options.author_type || 'agent',
      session_id: options.session_id,
      tags: options.tags || [],
      confidence: options.confidence ?? 0.8,
      importance: options.importance || 'medium',
      related_files: options.related_files || [],
      related_issues: options.related_issues || [],
      related_prs: options.related_prs || [],
      related_memories: options.related_memories || [],
      supersedes: options.supersedes,
      retrieval_triggers: options.retrieval_triggers || extractKeywords(chunk),
      relevant_to: options.relevant_to || [options.type],
      validated: options.validated ?? false,
      usage_count: 0,
    };

    // Add chunk info if multi-chunk
    if (isChunked) {
      metadata.chunk_index = i;
      metadata.total_chunks = chunks.length;
      metadata.chunk_of = memoryIds[0] || memoryId; // First chunk ID
    }

    // Upsert to Pinecone
    await index.namespace(namespace).upsert([
      {
        id: memoryId,
        values: embedding,
        metadata: metadata as Record<string, any>,
      },
    ]);

    memoryIds.push(memoryId);
    console.error(`✅ Chunk ${i + 1}/${chunks.length} written: ${memoryId}`);
  }

  // If superseding old memory, mark it
  if (options.supersedes) {
    console.error(`🔄 Marking superseded memory: ${options.supersedes}`);
    try {
      await index.namespace(namespace).update({
        id: options.supersedes,
        metadata: {
          superseded_by: memoryIds[0],
          superseded_at: new Date().toISOString(),
        },
      });
      console.error(`✅ Superseded memory updated`);
    } catch (error) {
      console.error(`⚠️  Failed to mark superseded memory:`, error);
    }
  }

  return memoryIds;
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log(`
Pinecone Memory Write Interface

Usage:
  npx tsx .claude/scripts/pinecone-memory-write.ts [OPTIONS]

Required Options:
  --content=TEXT     Memory content (required)
  --type=TYPE        Memory type (required)
  --repo=REPO        Repository name (required)
  --domain=DOMAIN    Domain name (required)

Optional:
  --tags=TAG1,TAG2   Comma-separated tags
  --confidence=N     Confidence score 0-1 (default: 0.8)
  --importance=I     Importance level (critical|high|medium|low, default: medium)
  --author=NAME      Author name (default: Claude Sonnet 4.5)
  --author-type=T    Author type (human|agent, default: agent)
  --session-id=ID    Session ID
  --related-files=F  Comma-separated file paths
  --related-issues=I Comma-separated issue IDs
  --related-prs=P    Comma-separated PR IDs
  --supersedes=ID    ID of memory this replaces
  --validated        Mark as human-validated
  --expires-in-days=N Memory expiration in days

Memory Types:
  session-learning, adr, pattern, debugging-solution, incident,
  code-review, standard, decision, codeburn-finding, codex-review

Examples:
  # Write an authentication pattern
  npx tsx .claude/scripts/pinecone-memory-write.ts \\
    --content="Use refresh tokens with JWT for better security. Store refresh tokens in httpOnly cookies." \\
    --type=pattern \\
    --repo=pillarworks \\
    --domain=architecture \\
    --tags=authentication,security,JWT \\
    --importance=high

  # Write a debugging solution
  npx tsx .claude/scripts/pinecone-memory-write.ts \\
    --content="NoneType error in login: User model missing email validation. Added required field and migration." \\
    --type=debugging-solution \\
    --repo=pillarworks \\
    --domain=debugging \\
    --tags=NoneType,email,authentication \\
    --related-files=backend/auth/login.py,backend/models/user.py \\
    --validated
`);
    process.exit(0);
  }

  // Parse arguments
  const options: Partial<WriteMemoryOptions> = {};

  for (const arg of args) {
    if (arg.startsWith('--content=')) {
      options.content = arg.split('=').slice(1).join('=');
    } else if (arg.startsWith('--type=')) {
      options.type = arg.split('=')[1] as MemoryType;
    } else if (arg.startsWith('--repo=')) {
      options.repo = arg.split('=')[1];
    } else if (arg.startsWith('--domain=')) {
      options.domain = arg.split('=')[1];
    } else if (arg.startsWith('--tags=')) {
      options.tags = arg.split('=')[1].split(',').map((t) => t.trim());
    } else if (arg.startsWith('--confidence=')) {
      options.confidence = parseFloat(arg.split('=')[1]);
    } else if (arg.startsWith('--importance=')) {
      options.importance = arg.split('=')[1] as Importance;
    } else if (arg.startsWith('--author=')) {
      options.author = arg.split('=')[1];
    } else if (arg.startsWith('--author-type=')) {
      options.author_type = arg.split('=')[1] as 'human' | 'agent';
    } else if (arg.startsWith('--session-id=')) {
      options.session_id = arg.split('=')[1];
    } else if (arg.startsWith('--related-files=')) {
      options.related_files = arg.split('=')[1].split(',').map((f) => f.trim());
    } else if (arg.startsWith('--related-issues=')) {
      options.related_issues = arg.split('=')[1].split(',').map((i) => i.trim());
    } else if (arg.startsWith('--related-prs=')) {
      options.related_prs = arg.split('=')[1].split(',').map((p) => p.trim());
    } else if (arg.startsWith('--supersedes=')) {
      options.supersedes = arg.split('=')[1];
    } else if (arg.startsWith('--expires-in-days=')) {
      options.expires_in_days = parseInt(arg.split('=')[1], 10);
    } else if (arg === '--validated') {
      options.validated = true;
    }
  }

  // Validate required fields
  if (!options.content || !options.type || !options.repo || !options.domain) {
    console.error('❌ Missing required options: --content, --type, --repo, --domain');
    console.error('   Run with --help for usage information');
    process.exit(1);
  }

  try {
    const memoryIds = await writeMemory(options as WriteMemoryOptions);

    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ Memory written successfully!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log(`📊 Details:`);
    console.log(`   Type: ${options.type}`);
    console.log(`   Namespace: ${options.repo}.${options.domain}`);
    console.log(`   Chunks: ${memoryIds.length}`);
    console.log(`   IDs: ${memoryIds.join(', ')}`);
    console.log(`   Tags: ${options.tags?.join(', ') || 'none'}`);
    console.log(`   Confidence: ${options.confidence ?? 0.8}`);
    console.log(`   Importance: ${options.importance || 'medium'}`);

    // Output JSON for programmatic consumption
    if (process.env.OUTPUT_JSON === 'true') {
      console.log(JSON.stringify({ success: true, memory_ids: memoryIds }, null, 2));
    }
  } catch (error) {
    console.error('❌ Write failed:', error);
    if (error instanceof Error) {
      console.error(`   Error: ${error.message}`);
    }
    process.exit(1);
  }
}

// Export for use in hooks
export { writeMemory, WriteMemoryOptions, MemoryMetadata, MemoryType, Importance };

// Run CLI directly
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
