#!/usr/bin/env tsx
/**
 * Post-Story Memory Write Hook
 *
 * Triggered after story completion or every 3 stories (auto-compaction)
 * Writes learnings, patterns, and decisions to Pinecone
 *
 * Hook Configuration in .claude/settings.json:
 * {
 *   "hooks": {
 *     "post-story": ".claude/hooks/post-story-memory-write.ts"
 *   }
 * }
 */

import { writeMemory, WriteMemoryOptions, MemoryType, Importance } from '../scripts/pinecone-memory-write';

interface SessionSummary {
  session_id: string;
  repo: string;
  stories_completed: number;
  task_type: string; // 'feature', 'bug_fix', 'refactor', etc.
  files_modified: string[];
  tests_added: string[];
  issues_fixed: string[];
  prs_created: string[];
  learnings: Learning[];
  patterns_discovered: Pattern[];
  gotchas_encountered: Gotcha[];
  decisions_made: Decision[];
  human_reviewed: boolean;
  agent: string;
  user?: string;
}

interface Learning {
  description: string;
  domain: string;
  type: MemoryType;
  tags: string[];
  files: string[];
  confidence: number;
  importance: Importance;
  task_types: string[];
}

interface Pattern {
  description: string;
  domain: string;
  tags: string[];
  files: string[];
  confidence: number;
  what_worked: string;
  why_it_worked: string;
}

interface Gotcha {
  description: string;
  domain: string;
  tags: string[];
  files: string[];
  what_went_wrong: string;
  how_to_avoid: string;
}

interface Decision {
  description: string;
  domain: string;
  tags: string[];
  rationale: string;
  alternatives_considered: string[];
  importance: Importance;
}

function calculateConfidence(learning: Learning): number {
  // Base confidence
  let confidence = learning.confidence || 0.7;

  // Boost if human-reviewed
  // (Will be checked at session level)

  // Boost if tests added
  if (learning.files.some((f) => f.includes('test') || f.includes('spec'))) {
    confidence += 0.1;
  }

  // Reduce if low file coverage
  if (learning.files.length < 2) {
    confidence -= 0.05;
  }

  return Math.max(0.1, Math.min(1.0, confidence));
}

function determineImportance(learning: Learning): Importance {
  if (learning.importance) return learning.importance;

  // Critical: Security, auth, data integrity
  const criticalTags = ['security', 'authentication', 'authorization', 'data-integrity', 'migration'];
  if (learning.tags.some((tag) => criticalTags.includes(tag.toLowerCase()))) {
    return 'critical';
  }

  // High: Architecture decisions, performance, debugging
  const highTags = ['architecture', 'performance', 'debugging', 'incident'];
  if (learning.tags.some((tag) => highTags.includes(tag.toLowerCase()))) {
    return 'high';
  }

  // Low: Documentation, minor fixes
  const lowTags = ['docs', 'documentation', 'typo', 'formatting'];
  if (learning.tags.some((tag) => lowTags.includes(tag.toLowerCase()))) {
    return 'low';
  }

  // Default: Medium
  return 'medium';
}

function extractKeywords(text: string): string[] {
  const words = text
    .toLowerCase()
    .replace(/[^\w\s]/g, ' ')
    .split(/\s+/)
    .filter((word) => word.length > 3);

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

async function writeSessionMemories(session: SessionSummary): Promise<void> {
  console.error(`\n💾 Writing memories for session: ${session.session_id}\n`);
  console.error(`   Stories completed: ${session.stories_completed}`);
  console.error(`   Files modified: ${session.files_modified.length}`);
  console.error(`   Learnings: ${session.learnings.length}`);
  console.error(`   Patterns: ${session.patterns_discovered.length}`);
  console.error(`   Gotchas: ${session.gotchas_encountered.length}`);
  console.error(`   Decisions: ${session.decisions_made.length}\n`);

  const writtenMemories: string[] = [];

  // Write learnings
  for (const learning of session.learnings) {
    try {
      const options: WriteMemoryOptions = {
        content: learning.description,
        type: learning.type,
        repo: session.repo,
        domain: learning.domain,
        tags: learning.tags,
        confidence: calculateConfidence(learning),
        importance: determineImportance(learning),
        author: session.agent || 'Claude Sonnet 4.5',
        author_type: 'agent',
        session_id: session.session_id,
        related_files: learning.files,
        related_issues: session.issues_fixed,
        related_prs: session.prs_created,
        retrieval_triggers: extractKeywords(learning.description),
        relevant_to: learning.task_types,
        validated: session.human_reviewed,
      };

      const memoryIds = await writeMemory(options);
      writtenMemories.push(...memoryIds);
      console.error(`   ✓ Learning written: ${learning.description.substring(0, 60)}...`);
    } catch (error) {
      console.error(`   ✗ Failed to write learning:`, error);
    }
  }

  // Write patterns
  for (const pattern of session.patterns_discovered) {
    try {
      const content = `Pattern: ${pattern.description}\n\nWhat worked: ${pattern.what_worked}\n\nWhy it worked: ${pattern.why_it_worked}`;

      const options: WriteMemoryOptions = {
        content,
        type: 'pattern',
        repo: session.repo,
        domain: pattern.domain,
        tags: pattern.tags,
        confidence: pattern.confidence,
        importance: 'medium',
        author: session.agent || 'Claude Sonnet 4.5',
        author_type: 'agent',
        session_id: session.session_id,
        related_files: pattern.files,
        retrieval_triggers: extractKeywords(pattern.description),
        relevant_to: [session.task_type, 'pattern-discovery'],
        validated: session.human_reviewed,
      };

      const memoryIds = await writeMemory(options);
      writtenMemories.push(...memoryIds);
      console.error(`   ✓ Pattern written: ${pattern.description.substring(0, 60)}...`);
    } catch (error) {
      console.error(`   ✗ Failed to write pattern:`, error);
    }
  }

  // Write gotchas (as lessons learned)
  for (const gotcha of session.gotchas_encountered) {
    try {
      const content = `Gotcha: ${gotcha.description}\n\nWhat went wrong: ${gotcha.what_went_wrong}\n\nHow to avoid: ${gotcha.how_to_avoid}`;

      const options: WriteMemoryOptions = {
        content,
        type: 'session-learning',
        repo: session.repo,
        domain: gotcha.domain,
        tags: [...gotcha.tags, 'gotcha', 'pitfall'],
        confidence: 0.9, // High confidence - we know it went wrong
        importance: 'high', // Gotchas are important to remember
        author: session.agent || 'Claude Sonnet 4.5',
        author_type: 'agent',
        session_id: session.session_id,
        related_files: gotcha.files,
        retrieval_triggers: [...extractKeywords(gotcha.description), 'pitfall', 'gotcha'],
        relevant_to: [session.task_type, 'debugging'],
        validated: session.human_reviewed,
      };

      const memoryIds = await writeMemory(options);
      writtenMemories.push(...memoryIds);
      console.error(`   ✓ Gotcha written: ${gotcha.description.substring(0, 60)}...`);
    } catch (error) {
      console.error(`   ✗ Failed to write gotcha:`, error);
    }
  }

  // Write decisions
  for (const decision of session.decisions_made) {
    try {
      const content = `Decision: ${decision.description}\n\nRationale: ${decision.rationale}\n\nAlternatives considered: ${decision.alternatives_considered.join(', ')}`;

      const options: WriteMemoryOptions = {
        content,
        type: 'decision',
        repo: session.repo,
        domain: decision.domain,
        tags: [...decision.tags, 'decision'],
        confidence: 0.85,
        importance: decision.importance,
        author: session.agent || 'Claude Sonnet 4.5',
        author_type: 'agent',
        session_id: session.session_id,
        retrieval_triggers: extractKeywords(decision.description),
        relevant_to: [session.task_type, 'architecture', 'planning'],
        validated: session.human_reviewed,
      };

      const memoryIds = await writeMemory(options);
      writtenMemories.push(...memoryIds);
      console.error(`   ✓ Decision written: ${decision.description.substring(0, 60)}...`);
    } catch (error) {
      console.error(`   ✗ Failed to write decision:`, error);
    }
  }

  console.error(`\n✅ Memory write complete: ${writtenMemories.length} memories written\n`);
}

// Main hook execution
async function main() {
  try {
    // Parse session summary (expected as JSON via stdin or env)
    const sessionJson = process.env.SESSION_SUMMARY || process.argv[2];

    if (!sessionJson) {
      console.error('❌ SESSION_SUMMARY not provided');
      console.error('   Provide session data as JSON via SESSION_SUMMARY env var or first argument');
      process.exit(1);
    }

    const session: SessionSummary = JSON.parse(sessionJson);

    // Validate required fields
    if (!session.session_id || !session.repo) {
      console.error('❌ Invalid session summary: missing session_id or repo');
      process.exit(1);
    }

    // Write memories
    await writeSessionMemories(session);

    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ Post-story memory write complete');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log('📊 Summary:');
    console.log(`   Session: ${session.session_id}`);
    console.log(`   Repo: ${session.repo}`);
    console.log(`   Stories: ${session.stories_completed}`);
    console.log(`   Memories written: ${session.learnings.length + session.patterns_discovered.length + session.gotchas_encountered.length + session.decisions_made.length}`);

    process.exit(0);
  } catch (error) {
    console.error('❌ Post-story memory write failed:', error);
    if (error instanceof Error) {
      console.error(`   Error: ${error.message}`);
    }
    console.error('   Session memories not saved.');
    process.exit(1); // Fail loudly - losing memories is serious
  }
}

// Export for testing
export {
  writeSessionMemories,
  SessionSummary,
  Learning,
  Pattern,
  Gotcha,
  Decision,
  calculateConfidence,
  determineImportance,
};

// Run directly
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
