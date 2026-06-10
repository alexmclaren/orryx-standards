#!/usr/bin/env tsx
/**
 * Pinecone Memory Seeding: Implementation Patterns
 *
 * Extracts implementation patterns from orchestration docs, session states,
 * and workflow documentation.
 *
 * Expected output: ~150 patterns
 */

import { readFileSync, readdirSync, existsSync } from 'fs';
import { join } from 'path';
import { Pinecone } from '@pinecone-database/pinecone';
import OpenAI from 'openai';
import { v4 as uuidv4 } from 'uuid';

const PINECONE_API_KEY = process.env.PINECONE_API_KEY;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

if (!PINECONE_API_KEY || !OPENAI_API_KEY) {
  console.error('❌ Missing API keys. Set PINECONE_API_KEY and OPENAI_API_KEY');
  process.exit(1);
}

const pc = new Pinecone({ apiKey: PINECONE_API_KEY });
const openai = new OpenAI({ apiKey: OPENAI_API_KEY });
const index = pc.index('orryx-dev-intelligence');

interface Pattern {
  title: string;
  description: string;
  repo: string;
  domain: string;
  source_file: string;
  pattern_type: string;
}

const PATTERN_SOURCES = [
  { repo: 'orryx-brain', path: 'D:\\orryx-brain\\orchestration', type: 'orchestration' },
  { repo: 'orryx-brain', path: 'D:\\orryx-brain\\docs\\workflows', type: 'workflow' },
  { repo: 'orryx-brain', path: 'D:\\orryx-brain\\.orryx\\routines', type: 'routine' },
  { repo: 'pillarworks', path: 'D:\\pillarworks-build-mvp\\docs\\workflows', type: 'workflow' },
];

function extractPatterns(filePath: string, repoName: string, patternType: string): Pattern[] {
  const patterns: Pattern[] = [];

  if (!existsSync(filePath)) {
    return patterns;
  }

  try {
    const content = readFileSync(filePath, 'utf-8');

    // Extract markdown sections as patterns
    const sectionRegex = /^##\s+(.+)$/gm;
    let match;

    while ((match = sectionRegex.exec(content)) !== null) {
      const sectionTitle = match[1];
      const startPos = match.index + match[0].length;
      const nextMatch = sectionRegex.exec(content);
      const endPos = nextMatch ? nextMatch.index : content.length;
      sectionRegex.lastIndex = nextMatch ? nextMatch.index : content.length;

      const sectionContent = content.substring(startPos, endPos).trim();

      if (sectionContent.length > 100) {
        patterns.push({
          title: sectionTitle,
          description: sectionContent.substring(0, 500),
          repo: repoName,
          domain: 'patterns',
          source_file: filePath,
          pattern_type: patternType
        });
      }
    }
  } catch (error) {
    console.warn(`⚠️  Failed to extract patterns from ${filePath}: ${error}`);
  }

  return patterns;
}

async function seedPatterns() {
  console.log('🌱 Seeding implementation patterns to Pinecone...\n');

  let totalPatterns = 0;

  for (const source of PATTERN_SOURCES) {
    console.log(`📂 Processing ${source.repo} ${source.type} patterns from ${source.path}`);

    if (!existsSync(source.path)) {
      console.log(`   ⚠️  Path not found, skipping`);
      continue;
    }

    const files = readdirSync(source.path).filter(f => f.endsWith('.md') || f.endsWith('.yaml'));

    for (const file of files) {
      const filePath = join(source.path, file);
      const patterns = extractPatterns(filePath, source.repo, source.type);

      for (const pattern of patterns) {
        try {
          const content = `${pattern.title}\n\n${pattern.description}`;

          // Generate embedding
          const embeddingResponse = await openai.embeddings.create({
            model: 'text-embedding-3-small',
            input: content,
            dimensions: 1536
          });

          const embedding = embeddingResponse.data[0].embedding;
          const memoryId = uuidv4();

          // Write to Pinecone
          await index.namespace(`${source.repo}.patterns`).upsert([{
            id: memoryId,
            values: embedding,
            metadata: {
              type: 'pattern',
              repo: source.repo,
              domain: 'patterns',
              title: pattern.title,
              pattern_type: pattern.pattern_type,
              source_file: pattern.source_file,
              content: content.substring(0, 1000),
              tags: [pattern.pattern_type, source.repo],
              importance: 'medium',
              confidence: 0.75,
              validated: false,
              created_at: new Date().toISOString(),
              author: 'seed-patterns',
              author_type: 'agent'
            }
          }]);

          totalPatterns++;
          console.log(`   ✅ ${pattern.title}`);

        } catch (error) {
          console.error(`   ❌ Failed to seed pattern "${pattern.title}": ${error}`);
        }
      }
    }
  }

  console.log(`\n🎉 Seeded ${totalPatterns} patterns successfully!`);
}

seedPatterns().catch(console.error);
