#!/usr/bin/env tsx
/**
 * Test Pinecone connectivity and index stats
 * Phase 4 Track 5 validation
 */

import { Pinecone } from '@pinecone-database/pinecone';

async function main() {
  const pc = new Pinecone({ apiKey: process.env.PINECONE_API_KEY! });
  const index = pc.index('orryx-dev-intelligence');
  const stats = await index.describeIndexStats();
  console.log(JSON.stringify(stats, null, 2));
}

main().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
