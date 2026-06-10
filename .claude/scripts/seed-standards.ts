#!/usr/bin/env tsx
/**
 * Pinecone Memory Seeding: Standards & Conventions
 *
 * Extracts Orryx-wide standards from CLAUDE.base.md, AGENTS.md, and governance docs.
 *
 * Expected output: ~50 standards
 */

import { readFileSync, existsSync } from 'fs';
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

interface Standard {
  title: string;
  content: string;
  type: string;
  source: string;
}

const STANDARDS_SOURCES = [
  { path: 'D:\\orryx-standards\\CLAUDE.base.md', type: 'execution-protocol' },
  { path: 'D:\\orryx-standards\\AGENTS.md', type: 'agent-standards' },
  { path: 'D:\\orryx-governance\\security\\security-policy.md', type: 'security' },
  { path: 'D:\\orryx-governance\\compliance\\privacy-compliance.md', type: 'compliance' }
];

function extractStandards(filePath: string, sourceType: string): Standard[] {
  const standards: Standard[] = [];

  if (!existsSync(filePath)) {
    return standards;
  }

  try {
    const content = readFileSync(filePath, 'utf-8');

    // Extract level-2 and level-3 headers with content
    const headerRegex = /^(##\s+|###\s+)(.+)$/gm;
    let match;

    const positions: Array<{ title: string; start: number; level: number }> = [];

    while ((match = headerRegex.exec(content)) !== null) {
      const level = match[1].trim().length; // ## = 2, ### = 3
      const title = match[2].trim();
      const start = match.index + match[0].length;

      positions.push({ title, start, level });
    }

    // Extract content between headers
    for (let i = 0; i < positions.length; i++) {
      const current = positions[i];
      const next = positions[i + 1];
      const end = next ? next.start - next.title.length - 10 : content.length;

      const sectionContent = content.substring(current.start, end).trim();

      if (sectionContent.length > 100 && sectionContent.length < 3000) {
        standards.push({
          title: current.title,
          content: sectionContent,
          type: sourceType,
          source: filePath
        });
      }
    }
  } catch (error) {
    console.warn(`⚠️  Failed to extract standards from ${filePath}: ${error}`);
  }

  return standards;
}

async function seedStandards() {
  console.log('🌱 Seeding standards to Pinecone...\n');

  let totalStandards = 0;

  for (const source of STANDARDS_SOURCES) {
    if (!existsSync(source.path)) {
      console.log(`⚠️  ${source.path} not found, skipping`);
      continue;
    }

    console.log(`📂 Processing ${source.type} from ${source.path}`);

    const standards = extractStandards(source.path, source.type);
    console.log(`   Found ${standards.length} standards`);

    for (const standard of standards) {
      try {
        const memoryContent = `${standard.title}\n\n${standard.content}`;

        // Generate embedding
        const embeddingResponse = await openai.embeddings.create({
          model: 'text-embedding-3-small',
          input: memoryContent,
          dimensions: 1536
        });

        const embedding = embeddingResponse.data[0].embedding;
        const memoryId = uuidv4();

        // Write to Pinecone
        await index.namespace('standards.global').upsert([{
          id: memoryId,
          values: embedding,
          metadata: {
            type: 'standard',
            repo: 'all',
            domain: 'standards',
            title: standard.title,
            standard_type: standard.type,
            source_file: standard.source,
            content: memoryContent.substring(0, 1000),
            tags: ['standard', standard.type, 'global'],
            importance: 'critical',
            confidence: 1.0,
            validated: true,
            created_at: new Date().toISOString(),
            author: 'orryx-standards',
            author_type: 'human'
          }
        }]);

        totalStandards++;
        console.log(`   ✅ ${standard.title}`);

      } catch (error) {
        console.error(`   ❌ Failed to seed standard "${standard.title}": ${error}`);
      }
    }
  }

  console.log(`\n🎉 Seeded ${totalStandards} standards successfully!`);
}

seedStandards().catch(console.error);
