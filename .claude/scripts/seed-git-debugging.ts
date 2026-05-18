#!/usr/bin/env tsx
/**
 * Pinecone Memory Seeding: Git Debugging Solutions
 *
 * Extracts bug fixes from git commit history and writes them to Pinecone memory.
 *
 * Expected output: ~250 debugging solutions
 */

import { execSync } from 'child_process';
import { existsSync } from 'fs';
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

interface RepoLocation {
  repo: string;
  path: string;
}

const REPO_LOCATIONS: RepoLocation[] = [
  { repo: 'orryx-brain', path: 'D:\\orryx-brain' },
  { repo: 'pillarworks', path: 'D:\\pillarworks-build-mvp' },
  { repo: 'clinical-trials', path: 'D:\\Clinical.Trials' }
];

interface Commit {
  hash: string;
  subject: string;
  body: string;
  repo: string;
}

function getCommitsFromRepo(repoPath: string, repoName: string, maxCommits: number = 200): Commit[] {
  if (!existsSync(repoPath)) {
    return [];
  }

  try {
    const output = execSync(
      `cd "${repoPath}" && git log --grep="fix\\|bug\\|error\\|debug" --format="%H|%s|%b" --since="1 year ago" -n ${maxCommits}`,
      { encoding: 'utf-8', maxBuffer: 10 * 1024 * 1024 }
    );

    const commits: Commit[] = [];
    const lines = output.trim().split('\n');

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;

      const parts = line.split('|');
      if (parts.length >= 2) {
        const hash = parts[0];
        const subject = parts[1];
        const body = parts.slice(2).join('|');

        // Only include meaningful bug fixes
        const textLower = (subject + ' ' + body).toLowerCase();
        if (textLower.includes('fix') || textLower.includes('bug') ||
            textLower.includes('error') || textLower.includes('debug')) {
          commits.push({ hash, subject, body, repo: repoName });
        }
      }
    }

    return commits;
  } catch (error) {
    console.error(`   ⚠️  Error scanning ${repoName}: ${error}`);
    return [];
  }
}

async function seedGitDebugging() {
  console.log('🌱 Seeding git debugging solutions to Pinecone...\n');

  let totalCommits = 0;
  let allCommits: Commit[] = [];

  // Gather all commits
  for (const location of REPO_LOCATIONS) {
    console.log(`🔍 Scanning ${location.repo}...`);
    const commits = getCommitsFromRepo(location.path, location.repo);
    console.log(`   Found ${commits.length} bug fix commits`);
    allCommits.push(...commits);
  }

  console.log(`\n📊 Total commits to seed: ${allCommits.length}\n`);

  // Seed each commit
  for (const commit of allCommits) {
    try {
      const content = `${commit.subject}\n\n${commit.body}`;

      // Auto-tag based on content
      const contentLower = content.toLowerCase();
      const tags = ['bug-fix', 'git-history', commit.repo];

      if (contentLower.includes('database')) tags.push('database');
      if (contentLower.includes('api')) tags.push('api');
      if (contentLower.includes('auth')) tags.push('authentication');
      if (contentLower.includes('frontend')) tags.push('frontend');
      if (contentLower.includes('backend')) tags.push('backend');
      if (contentLower.includes('test')) tags.push('testing');

      // Generate embedding
      const embeddingResponse = await openai.embeddings.create({
        model: 'text-embedding-3-small',
        input: content,
        dimensions: 1536
      });

      const embedding = embeddingResponse.data[0].embedding;
      const memoryId = uuidv4();

      // Write to Pinecone
      await index.namespace(`${commit.repo}.debugging`).upsert([{
        id: memoryId,
        values: embedding,
        metadata: {
          type: 'debugging-solution',
          repo: commit.repo,
          domain: 'debugging',
          title: commit.subject,
          commit_hash: commit.hash,
          content: content.substring(0, 1000),
          tags: tags,
          importance: 'medium',
          confidence: 0.8,
          validated: true,
          created_at: new Date().toISOString(),
          author: 'git-history',
          author_type: 'human'
        }
      }]);

      totalCommits++;
      console.log(`   ✅ ${commit.subject.substring(0, 80)}`);

      // Small delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 1000));

    } catch (error) {
      console.error(`   ❌ Failed to seed commit ${commit.hash}: ${error}`);
    }
  }

  console.log(`\n🎉 Seeded ${totalCommits} debugging solutions successfully!`);
}

// Run directly
seedGitDebugging().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});

export { seedGitDebugging };
