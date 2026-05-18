#!/usr/bin/env tsx
/**
 * Seed Git Debugging History to Pinecone
 *
 * Extracts debugging solutions from git commit history by searching for commits
 * with keywords like "fix", "bug", "error", "debug".
 *
 * Usage:
 *   npx tsx seed-git-debugging.ts
 *
 * Environment:
 *   PINECONE_API_KEY - Required
 *   OPENAI_API_KEY - Required
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import { existsSync } from 'fs';
import { join } from 'path';

const execAsync = promisify(exec);

interface RepoLocation {
  name: string;
  path: string;
}

// Repository locations
const REPOS: RepoLocation[] = [
  {
    name: 'orryx-brain',
    path: 'D:\\orryx-brain',
  },
  {
    name: 'pillarworks',
    path: 'D:\\pillarworks-build-mvp',
  },
  {
    name: 'clinical-trials',
    path: 'D:\\Clinical.Trials',
  },
];

interface CommitInfo {
  repo: string;
  hash: string;
  subject: string;
  body: string;
  author: string;
  date: string;
  files: string[];
}

function extractErrorType(message: string): string[] {
  const types: string[] = [];

  if (/null|undefined|none/i.test(message)) types.push('null-check');
  if (/type.?error/i.test(message)) types.push('type-error');
  if (/race.?condition|async|await/i.test(message)) types.push('race-condition');
  if (/auth|authentication|permission/i.test(message)) types.push('authentication');
  if (/timeout|latency|performance/i.test(message)) types.push('performance');
  if (/validation|invalid/i.test(message)) types.push('validation');
  if (/memory|leak/i.test(message)) types.push('memory');
  if (/sql|database|query/i.test(message)) types.push('database');
  if (/api|endpoint|request/i.test(message)) types.push('api');
  if (/ui|frontend|render/i.test(message)) types.push('frontend');

  return types.length > 0 ? types : ['general'];
}

function extractIssueIds(message: string): string[] {
  // Extract GitHub issue references like #123, GH-123, fixes #123
  const matches = message.match(/#\d+|GH-\d+|fixes\s+#\d+|closes\s+#\d+/gi);
  if (!matches) return [];

  return matches.map((match) => match.replace(/fixes\s+|closes\s+/i, '').trim());
}

function determineImportance(commit: CommitInfo): 'critical' | 'high' | 'medium' | 'low' {
  const message = commit.subject + ' ' + commit.body;

  // Production bugs are high priority
  if (/production|prod|critical|urgent|hotfix/i.test(message)) return 'critical';
  if (/security|vulnerability|exploit|injection/i.test(message)) return 'critical';

  // Multiple file changes suggest larger fix
  if (commit.files.length >= 5) return 'high';

  // Error patterns that affect users
  if (/crash|fatal|exception/i.test(message)) return 'high';

  // Standard bug fixes
  if (/bug|fix|error/i.test(message)) return 'medium';

  return 'low';
}

async function getCommitsFromRepo(repo: RepoLocation): Promise<CommitInfo[]> {
  if (!existsSync(repo.path)) {
    console.log(`⏭️  Skipping non-existent repo: ${repo.path}`);
    return [];
  }

  console.log(`🔍 Scanning ${repo.name} for bug fixes...`);

  try {
    // Get commits with bug fix keywords from the last year
    const grepPattern = 'fix\\|bug\\|error\\|debug\\|crash\\|null\\|undefined\\|broken';
    const gitCommand = `cd "${repo.path}" && git log --grep="${grepPattern}" -i --format="%H|%s|%b|%an|%ai" --since="1 year ago"`;

    const { stdout } = await execAsync(gitCommand, {
      maxBuffer: 50 * 1024 * 1024, // 50MB buffer
    });

    if (!stdout.trim()) {
      console.log(`   No matching commits found`);
      return [];
    }

    const lines = stdout.trim().split('\n');
    const commits: CommitInfo[] = [];

    for (const line of lines) {
      if (!line.trim()) continue;

      const parts = line.split('|');
      if (parts.length < 4) continue;

      const [hash, subject, body, author, date] = parts;

      // Get files changed in this commit
      const filesCommand = `cd "${repo.path}" && git show --name-only --format="" ${hash}`;
      let files: string[] = [];

      try {
        const { stdout: filesOutput } = await execAsync(filesCommand);
        files = filesOutput
          .trim()
          .split('\n')
          .filter((f) => f.trim().length > 0);
      } catch {
        // If file list fails, continue without it
      }

      commits.push({
        repo: repo.name,
        hash,
        subject: subject.trim(),
        body: body.trim(),
        author: author.trim(),
        date: date.trim(),
        files,
      });
    }

    console.log(`   Found ${commits.length} bug fix commits`);
    return commits;
  } catch (error) {
    console.error(`❌ Error scanning ${repo.name}:`, error);
    return [];
  }
}

async function writeCommitToMemory(commit: CommitInfo): Promise<void> {
  // Build content with structured format
  const content = `Error/Bug Fix: ${commit.subject}

${commit.body ? `Description:\n${commit.body}\n\n` : ''}Commit: ${commit.hash}
Author: ${commit.author}
Date: ${commit.date}

Files modified:
${commit.files.slice(0, 10).join('\n')}${commit.files.length > 10 ? `\n... and ${commit.files.length - 10} more` : ''}

Root cause: ${commit.subject}
Fix applied: See commit ${commit.hash}
`;

  // Extract metadata
  const errorTypes = extractErrorType(commit.subject + ' ' + commit.body);
  const issueIds = extractIssueIds(commit.subject + ' ' + commit.body);
  const importance = determineImportance(commit);

  const tags = ['bug-fix', 'historical', ...errorTypes];

  // Call pinecone-memory-write.ts
  const scriptPath = join(__dirname, 'pinecone-memory-write.ts');

  const command = [
    'npx tsx',
    `"${scriptPath}"`,
    `--content="${content.replace(/"/g, '\\"')}"`,
    `--type=debugging-solution`,
    `--repo=${commit.repo}`,
    `--domain=debugging`,
    `--tags=${tags.join(',')}`,
    `--importance=${importance}`,
    `--author=${commit.author}`,
    `--author-type=human`,
    issueIds.length > 0 ? `--related-issues=${issueIds.join(',')}` : '',
    commit.files.length > 0 ? `--related-files=${commit.files.slice(0, 5).join(',')}` : '',
    `--validated`,
  ]
    .filter(Boolean)
    .join(' ');

  try {
    const { stdout, stderr } = await execAsync(command, {
      maxBuffer: 10 * 1024 * 1024, // 10MB buffer
    });

    if (stderr) {
      console.error(`   Stderr: ${stderr}`);
    }

    const shortHash = commit.hash.substring(0, 7);
    console.log(`✅ ${commit.repo}: ${shortHash} - ${commit.subject.substring(0, 60)}`);
  } catch (error) {
    console.error(`❌ Failed to write commit ${commit.hash}:`, error);
    throw error;
  }
}

async function seedGitDebugging(): Promise<void> {
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('🐛 Seeding Git Debugging History to Pinecone');
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

  // Collect commits from all repos
  const allCommits: CommitInfo[] = [];

  for (const repo of REPOS) {
    const commits = await getCommitsFromRepo(repo);
    allCommits.push(...commits);
  }

  if (allCommits.length === 0) {
    console.log('\n⚠️  No bug fix commits found. Exiting.');
    return;
  }

  console.log(`\n📊 Total commits to seed: ${allCommits.length}\n`);

  // Sort by date (newest first)
  allCommits.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

  // Limit to most recent 300 commits to avoid overwhelming Pinecone
  const commitsToSeed = allCommits.slice(0, 300);

  if (commitsToSeed.length < allCommits.length) {
    console.log(`⚠️  Limiting to most recent ${commitsToSeed.length} commits\n`);
  }

  // Write each commit to Pinecone
  let successCount = 0;
  let errorCount = 0;

  for (const commit of commitsToSeed) {
    try {
      await writeCommitToMemory(commit);
      successCount++;

      // Add delay to avoid rate limiting
      await new Promise((resolve) => setTimeout(resolve, 1000));
    } catch (error) {
      console.error(`❌ Error writing commit ${commit.hash}:`, error);
      errorCount++;

      // Continue on error, but stop if too many errors
      if (errorCount > 10) {
        console.error('\n❌ Too many errors. Stopping.');
        break;
      }
    }
  }

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📊 Seeding Complete');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  console.log(`✅ Successfully seeded: ${successCount} commits`);
  console.log(`❌ Errors: ${errorCount} commits`);
  console.log(`📁 Total processed: ${commitsToSeed.length} commits\n`);

  if (errorCount > 0) {
    console.log('⚠️  Some commits failed to seed. Check errors above.');
  }
}

// Run if executed directly
if (require.main === module) {
  seedGitDebugging().catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

export { seedGitDebugging };
