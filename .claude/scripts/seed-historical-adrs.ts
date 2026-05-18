#!/usr/bin/env tsx
/**
 * Seed Historical ADRs to Pinecone
 *
 * Extracts Architecture Decision Records from docs/architecture/ADRs/ directories
 * and writes them to Pinecone memory for future retrieval.
 *
 * Usage:
 *   npx tsx seed-historical-adrs.ts
 *
 * Environment:
 *   PINECONE_API_KEY - Required
 *   OPENAI_API_KEY - Required
 */

import { readdirSync, readFileSync, existsSync, statSync } from 'fs';
import { join, basename } from 'path';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

interface ADRLocation {
  repo: string;
  path: string;
}

// ADR locations across repositories
const ADR_LOCATIONS: ADRLocation[] = [
  {
    repo: 'orryx-brain',
    path: 'D:\\orryx-brain\\docs\\architecture\\ADRs',
  },
  {
    repo: 'orryx-brain',
    path: 'D:\\orryx-brain\\architecture\\decisions',
  },
  {
    repo: 'pillarworks',
    path: 'D:\\pillarworks-build-mvp\\docs\\architecture\\ADRs',
  },
  {
    repo: 'pillarworks',
    path: 'D:\\pillarworks-build-mvp\\architecture\\decisions',
  },
  {
    repo: 'clinical-trials',
    path: 'D:\\Clinical.Trials\\docs\\architecture\\ADRs',
  },
  {
    repo: 'clinical-trials',
    path: 'D:\\Clinical.Trials\\architecture\\decisions',
  },
];

interface ADRFile {
  repo: string;
  path: string;
  filename: string;
  content: string;
  number?: number;
  title?: string;
}

function extractADRMetadata(content: string, filename: string): { number?: number; title?: string } {
  // Try to extract ADR number from filename (e.g., "ADR-001-something.md", "001-something.md")
  const fileNumberMatch = filename.match(/(?:ADR-)?(\d+)/i);
  const number = fileNumberMatch ? parseInt(fileNumberMatch[1], 10) : undefined;

  // Try to extract title from first heading
  const headingMatch = content.match(/^#\s+(.+)$/m);
  const title = headingMatch ? headingMatch[1].trim() : basename(filename, '.md');

  return { number, title };
}

async function writeToMemory(adr: ADRFile): Promise<void> {
  // Build content with metadata
  const contentWithMetadata = `# ADR ${adr.number || 'N/A'}: ${adr.title}\n\n${adr.content}`;

  // Extract tags from content
  const tags = ['adr', 'decision', 'architecture'];

  // Look for common ADR keywords to add as tags
  const contentLower = adr.content.toLowerCase();
  if (contentLower.includes('security')) tags.push('security');
  if (contentLower.includes('performance')) tags.push('performance');
  if (contentLower.includes('scalability')) tags.push('scalability');
  if (contentLower.includes('database')) tags.push('database');
  if (contentLower.includes('api')) tags.push('api');
  if (contentLower.includes('authentication')) tags.push('authentication');
  if (contentLower.includes('frontend')) tags.push('frontend');
  if (contentLower.includes('backend')) tags.push('backend');

  // Call pinecone-memory-write.ts via exec
  const scriptPath = join(__dirname, 'pinecone-memory-write.ts');

  const command = [
    'npx tsx',
    `"${scriptPath}"`,
    `--content="${contentWithMetadata.replace(/"/g, '\\"')}"`,
    `--type=adr`,
    `--repo=${adr.repo}`,
    `--domain=architecture`,
    `--tags=${tags.join(',')}`,
    `--importance=high`,
    `--author=historical-seed`,
    `--author-type=human`,
    `--validated`,
  ].join(' ');

  try {
    const { stdout, stderr } = await execAsync(command, {
      maxBuffer: 10 * 1024 * 1024, // 10MB buffer for large ADRs
    });

    if (stderr) {
      console.error(`   Stderr: ${stderr}`);
    }

    console.log(`✅ ${adr.repo}: ADR ${adr.number || '?'} - ${adr.title}`);
  } catch (error) {
    console.error(`❌ Failed to write ${adr.filename}:`, error);
    throw error;
  }
}

async function seedADRs(): Promise<void> {
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📚 Seeding Historical ADRs to Pinecone');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // Validate environment
  if (!process.env.PINECONE_API_KEY) {
    console.error('❌ PINECONE_API_KEY environment variable not set');
    process.exit(1);
  }

  if (!process.env.OPENAI_API_KEY) {
    console.error('❌ OPENAI_API_KEY environment variable not set');
    process.exit(1);
  }

  // Collect all ADR files
  const adrFiles: ADRFile[] = [];

  for (const location of ADR_LOCATIONS) {
    if (!existsSync(location.path)) {
      console.log(`⏭️  Skipping non-existent path: ${location.path}`);
      continue;
    }

    const stat = statSync(location.path);
    if (!stat.isDirectory()) {
      console.log(`⏭️  Skipping non-directory: ${location.path}`);
      continue;
    }

    console.log(`📂 Scanning ${location.repo}: ${location.path}`);

    try {
      const files = readdirSync(location.path);
      const mdFiles = files.filter((f) => f.endsWith('.md'));

      console.log(`   Found ${mdFiles.length} markdown files`);

      for (const file of mdFiles) {
        const filePath = join(location.path, file);
        const content = readFileSync(filePath, 'utf-8');
        const metadata = extractADRMetadata(content, file);

        adrFiles.push({
          repo: location.repo,
          path: filePath,
          filename: file,
          content,
          number: metadata.number,
          title: metadata.title,
        });
      }
    } catch (error) {
      console.error(`❌ Error scanning ${location.path}:`, error);
    }
  }

  if (adrFiles.length === 0) {
    console.log('\n⚠️  No ADR files found. Exiting.');
    return;
  }

  console.log(`\n📊 Total ADRs to seed: ${adrFiles.length}\n`);

  // Sort by number if available
  adrFiles.sort((a, b) => {
    if (a.number !== undefined && b.number !== undefined) {
      return a.number - b.number;
    }
    return a.filename.localeCompare(b.filename);
  });

  // Write each ADR to Pinecone
  let successCount = 0;
  let errorCount = 0;

  for (const adr of adrFiles) {
    try {
      await writeToMemory(adr);
      successCount++;

      // Add delay to avoid rate limiting
      await new Promise((resolve) => setTimeout(resolve, 1000));
    } catch (error) {
      console.error(`❌ Error writing ${adr.filename}:`, error);
      errorCount++;
    }
  }

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📊 Seeding Complete');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  console.log(`✅ Successfully seeded: ${successCount} ADRs`);
  console.log(`❌ Errors: ${errorCount} ADRs`);
  console.log(`📁 Total processed: ${adrFiles.length} ADRs\n`);

  if (errorCount > 0) {
    console.log('⚠️  Some ADRs failed to seed. Check errors above.');
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  seedADRs().catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

export { seedADRs };
