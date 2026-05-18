#!/usr/bin/env tsx
/**
 * Pinecone Index Initialization Script
 *
 * Creates the orryx-dev-intelligence index with proper configuration
 * Run once during initial setup: npx tsx .claude/scripts/pinecone-init.ts
 *
 * Prerequisites:
 * - PINECONE_API_KEY environment variable set
 * - @pinecone-database/pinecone package installed
 */

import { Pinecone } from '@pinecone-database/pinecone';

const INDEX_NAME = 'orryx-dev-intelligence';
const DIMENSION = 1536;  // OpenAI ada-002 / Claude embeddings
const METRIC = 'cosine';
const CLOUD = 'aws';
const REGION = 'us-east-1';

async function initializePinecone(): Promise<void> {
  console.log('🚀 Initializing Pinecone index...\n');

  // Validate API key
  const apiKey = process.env.PINECONE_API_KEY;
  if (!apiKey) {
    console.error('❌ PINECONE_API_KEY environment variable not set');
    console.error('   Set it in your .env file or export it:');
    console.error('   export PINECONE_API_KEY="your-api-key-here"');
    process.exit(1);
  }

  try {
    // Initialize Pinecone client
    const pinecone = new Pinecone({ apiKey });

    // Check if index already exists
    const existingIndexes = await pinecone.listIndexes();
    const indexExists = existingIndexes.indexes?.some(
      (idx) => idx.name === INDEX_NAME
    );

    if (indexExists) {
      console.log(`⚠️  Index "${INDEX_NAME}" already exists`);
      console.log('   Delete it first if you want to recreate:');
      console.log(`   pinecone.deleteIndex("${INDEX_NAME}")`);
      process.exit(0);
    }

    // Create index
    console.log(`📦 Creating index: ${INDEX_NAME}`);
    console.log(`   Dimension: ${DIMENSION}`);
    console.log(`   Metric: ${METRIC}`);
    console.log(`   Cloud: ${CLOUD}`);
    console.log(`   Region: ${REGION}\n`);

    await pinecone.createIndex({
      name: INDEX_NAME,
      dimension: DIMENSION,
      metric: METRIC,
      spec: {
        serverless: {
          cloud: CLOUD,
          region: REGION,
        },
      },
    });

    console.log('✅ Index created successfully!');
    console.log('\n📊 Index details:');
    console.log(`   Name: ${INDEX_NAME}`);
    console.log(`   Status: Initializing (this may take a few minutes)`);
    console.log(`   Endpoint: Will be available once initialization completes`);

    console.log('\n🔍 Verify connection with:');
    console.log('   npx tsx .claude/scripts/pinecone-verify.ts');

  } catch (error) {
    console.error('❌ Failed to create index:', error);
    if (error instanceof Error) {
      console.error(`   Error: ${error.message}`);
    }
    process.exit(1);
  }
}

// Run initialization
initializePinecone().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
