#!/usr/bin/env tsx
/**
 * Pinecone Memory Seeding: Historical ADRs
 *
 * Extracts Architecture Decision Records from architecture/decisions/ directories
 * and writes them to Pinecone memory.
 *
 * Expected output: ~100 ADRs
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

interface ADRLocation {
  repo: string;
  path: string;
}

const ADR_LOCATIONS: ADRLocation[] = [
  { repo: 'orryx-brain', path: 'D:\\orryx-brain\\docs\\architecture\\ADRs' },
  { repo: 'orryx-brain', path: 'D:\\orryx-brain\\architecture\\decisions' },
  { repo: 'pillarworks', path: 'D:\\pillarworks-build-mvp\\docs\\architecture\\ADRs' },
  { repo: 'pillarworks', path: 'D:\\pillarworks-build-mvp\\architecture\\decisions' },
  { repo: 'clinical-trials', path: 'D:\\Clinical.Trials\\docs\\architecture\\ADRs' },
  { repo: 'clinical-trials', path: 'D:\\Clinical.Trials\\architecture\\decisions' }
];

async function seedADRs() {
  console.log('🌱 Seeding historical ADRs to Pinecone...\n');

  let totalADRs = 0;

  for (const location of ADR_LOCATIONS) {
    if (!existsSync(location.path)) {
      console.log(`⚠️  ${location.path} not found, skipping`);
      continue;
    }

    console.log(`📂 Processing ${location.repo} ADRs from ${location.path}`);

    const files = readdirSync(location.path).filter(f => f.endsWith('.md'));
    console.log(`   Found ${files.length} ADR files`);

    for (const file of files) {
      const filePath = join(location.path, file);

      try {
        const content = readFileSync(filePath, 'utf-8');

        // Extract title from filename or first header
        const titleMatch = content.match(/^#\s+(.+)$/m);
        const title = titleMatch ? titleMatch[1] : file.replace('.md', '');

        // Auto-tag based on content
        const contentLower = content.toLowerCase();
        const tags = ['adr', location.repo];

        if (contentLower.includes('database')) tags.push('database');
        if (contentLower.includes('api')) tags.push('api');
        if (contentLower.includes('authentication')) tags.push('authentication');
        if (contentLower.includes('frontend')) tags.push('frontend');
        if (contentLower.includes('backend')) tags.push('backend');

        // Generate embedding
        const embeddingResponse = await openai.embeddings.create({
          model: 'text-embedding-3-small',
          input: content,
          dimensions: 1536
        });

        const embedding = embeddingResponse.data[0].embedding;
        const memoryId = uuidv4();

        // Write to Pinecone
        await index.namespace(`${location.repo}.architecture`).upsert([{
          id: memoryId,
          values: embedding,
          metadata: {
            type: 'adr',
            repo: location.repo,
            domain: 'architecture',
            title: title,
            filename: file,
            source_file: filePath,
            content: content.substring(0, 1000),
            tags: tags,
            importance: 'high',
            confidence: 1.0,
            validated: true,
            created_at: new Date().toISOString(),
            author: 'historical-seed',
            author_type: 'human'
          }
        }]);

        totalADRs++;
        console.log(`   ✅ ${title}`);

        // Small delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 500));

      } catch (error) {
        console.error(`   ❌ Failed to seed ${file}: ${error}`);
      }
    }
  }

  console.log(`\n🎉 Seeded ${totalADRs} ADRs successfully!`);
}

// Run directly
seedADRs().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});

export { seedADRs };
