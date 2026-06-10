#!/usr/bin/env tsx
/**
 * Pinecone Connection Verification Script
 *
 * Verifies Pinecone connection and performs basic read/write tests
 * Run after index creation: npx tsx .claude/scripts/pinecone-verify.ts
 *
 * Prerequisites:
 * - PINECONE_API_KEY environment variable set
 * - Index created via pinecone-init.ts
 */

import { Pinecone } from '@pinecone-database/pinecone';

const INDEX_NAME = 'orryx-dev-intelligence';
const TEST_NAMESPACE = 'test.verification';

async function verifyPinecone(): Promise<void> {
  console.log('🔍 Verifying Pinecone connection...\n');

  const apiKey = process.env.PINECONE_API_KEY;
  if (!apiKey) {
    console.error('❌ PINECONE_API_KEY environment variable not set');
    process.exit(1);
  }

  try {
    const pinecone = new Pinecone({ apiKey });

    // Step 1: Check if index exists
    console.log('1️⃣  Checking index existence...');
    const existingIndexes = await pinecone.listIndexes();
    const indexExists = existingIndexes.indexes?.some(
      (idx) => idx.name === INDEX_NAME
    );

    if (!indexExists) {
      console.error(`❌ Index "${INDEX_NAME}" not found`);
      console.error('   Create it first with: npx tsx .claude/scripts/pinecone-init.ts');
      process.exit(1);
    }
    console.log(`✅ Index "${INDEX_NAME}" exists\n`);

    // Step 2: Get index stats
    console.log('2️⃣  Fetching index statistics...');
    const index = pinecone.index(INDEX_NAME);
    const stats = await index.describeIndexStats();
    console.log(`✅ Index stats retrieved:`);
    console.log(`   Total vectors: ${stats.totalRecordCount || 0}`);
    console.log(`   Dimensions: ${stats.dimension}`);
    console.log(`   Namespaces: ${Object.keys(stats.namespaces || {}).length}\n`);

    // Step 3: Test upsert (write)
    console.log('3️⃣  Testing upsert (write) operation...');
    const testId = `test-${Date.now()}`;
    const testVector = Array(1536).fill(0.1);  // Dummy vector

    await index.namespace(TEST_NAMESPACE).upsert([
      {
        id: testId,
        values: testVector,
        metadata: {
          type: 'test',
          repo: 'verification',
          domain: 'test',
          namespace: TEST_NAMESPACE,
          created_at: new Date().toISOString(),
          tags: ['test', 'verification'],
          confidence: 1.0,
          importance: 'low',
        },
      },
    ]);
    console.log(`✅ Test vector upserted: ${testId}\n`);

    // Step 4: Test query (read)
    console.log('4️⃣  Testing query (read) operation...');
    const queryResults = await index.namespace(TEST_NAMESPACE).query({
      vector: testVector,
      topK: 1,
      includeMetadata: true,
    });

    if (queryResults.matches && queryResults.matches.length > 0) {
      const match = queryResults.matches[0];
      console.log(`✅ Query successful:`);
      console.log(`   Match ID: ${match.id}`);
      console.log(`   Score: ${match.score?.toFixed(4)}`);
      console.log(`   Metadata: ${JSON.stringify(match.metadata, null, 2)}\n`);
    } else {
      console.log('⚠️  No matches found (this is unusual)\n');
    }

    // Step 5: Test deletion (cleanup)
    console.log('5️⃣  Testing delete operation (cleanup)...');
    await index.namespace(TEST_NAMESPACE).deleteOne(testId);
    console.log(`✅ Test vector deleted: ${testId}\n`);

    // Final summary
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ All verification tests passed!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log('🎉 Pinecone is ready for use');
    console.log('📝 Next steps:');
    console.log('   - Start using memory-query and memory-write commands');
    console.log('   - Deploy hooks to enable auto-retrieval and auto-write');

  } catch (error) {
    console.error('❌ Verification failed:', error);
    if (error instanceof Error) {
      console.error(`   Error: ${error.message}`);
    }
    process.exit(1);
  }
}

verifyPinecone().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
