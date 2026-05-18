#!/usr/bin/env tsx
/**
 * Pre-Debugging Memory Retrieval Hook
 *
 * Triggered when debugging an error
 * Retrieves similar errors, known fixes, and related incidents
 *
 * Hook Configuration in .claude/settings.json:
 * {
 *   "hooks": {
 *     "pre-debugging": ".claude/hooks/pre-debugging-memory-retrieval.ts"
 *   }
 * }
 */

import { queryMemory, QueryOptions } from '../scripts/pinecone-memory-query';

interface DebuggingContext {
  error_message: string;
  error_type?: string; // 'TypeError', 'ValueError', 'NoneType', etc.
  stack_trace?: string;
  files_involved: string[];
  repo: string;
}

interface DebuggingMemoryContext {
  similar_errors: any[];
  known_fixes: any[];
  related_incidents: any[];
  code_review_warnings: any[];
  anti_patterns: any[];
}

function extractErrorPattern(error: string): string {
  // Extract core error pattern, removing specific values
  // Example: "NoneType object has no attribute 'email'" → "NoneType attribute error"
  return error
    .replace(/['"].*?['"]/g, '') // Remove quoted strings
    .replace(/\d+/g, '') // Remove numbers
    .replace(/\s+/g, ' ')
    .trim()
    .substring(0, 100); // Limit length
}

function extractErrorType(error: string): string {
  // Extract error type from message
  // Example: "TypeError: cannot concatenate" → "TypeError"
  const match = error.match(/^(\w+Error):/);
  return match ? match[1] : 'unknown';
}

async function retrieveDebuggingContext(
  context: DebuggingContext
): Promise<DebuggingMemoryContext> {
  console.error(`\n🧠 Retrieving debugging memories for error...\n`);
  console.error(`   Error: ${context.error_message.substring(0, 80)}...`);
  console.error(`   Files: ${context.files_involved.join(', ')}\n`);

  const errorPattern = extractErrorPattern(context.error_message);
  const errorType = context.error_type || extractErrorType(context.error_message);

  // Build queries
  const queries: string[] = [
    `similar error: ${context.error_message}`,
    `${errorType} in ${context.files_involved[0]}`,
    `debugging solutions for ${context.files_involved.join(' ')}`,
    `error pattern: ${errorPattern}`,
  ];

  // Add stack trace query if available
  if (context.stack_trace) {
    const stackFiles = context.stack_trace
      .match(/File "([^"]+)"/g)
      ?.map((f) => f.replace(/File "(.+)"/, '$1'))
      .slice(0, 3);
    if (stackFiles && stackFiles.length > 0) {
      queries.push(`errors in ${stackFiles.join(' ')}`);
    }
  }

  // Determine namespaces
  const namespaces: string[] = [
    `${context.repo}.debugging`,
    `${context.repo}.patterns`,
    `incidents.postmortems`,
    `codeburn.findings`,
  ];

  const allMatches: any[] = [];

  // Execute queries
  for (const query of queries) {
    try {
      const options: QueryOptions = {
        query,
        namespaces,
        topK: 5, // More results for debugging
        minConfidence: 0.75,
        prioritizeValidated: true, // Prefer human-verified solutions
      };

      const result = await queryMemory(options);
      allMatches.push(...result.matches);

      console.error(`   ✓ Query: "${query.substring(0, 60)}..." → ${result.matches.length} matches`);
    } catch (error) {
      console.error(`   ✗ Query failed: "${query}"`, error);
    }
  }

  // Organize by type
  const debugContext: DebuggingMemoryContext = {
    similar_errors: allMatches.filter((m) => m.metadata?.type === 'debugging-solution'),
    known_fixes: allMatches
      .filter((m) => m.metadata?.type === 'debugging-solution' && m.metadata?.validated)
      .sort((a, b) => (b.metadata?.effectiveness_score || 0) - (a.metadata?.effectiveness_score || 0)),
    related_incidents: allMatches.filter((m) => m.metadata?.type === 'incident'),
    code_review_warnings: allMatches.filter((m) => m.metadata?.type === 'code-review'),
    anti_patterns: allMatches.filter((m) => m.metadata?.tags?.includes('anti-pattern')),
  };

  // Summary
  console.error('\n📊 Debugging Memory Summary:');
  console.error(`   Similar Errors: ${debugContext.similar_errors.length}`);
  console.error(`   Validated Fixes: ${debugContext.known_fixes.length}`);
  console.error(`   Related Incidents: ${debugContext.related_incidents.length}`);
  console.error(`   Code Review Warnings: ${debugContext.code_review_warnings.length}`);
  console.error(`   Anti-Patterns: ${debugContext.anti_patterns.length}\n`);

  return debugContext;
}

function formatMemoryForDebugging(
  context: DebuggingContext,
  memoryContext: DebuggingMemoryContext
): string {
  let output = `\n## 🐛 Debugging Memory\n\n`;
  output += `**Error:** ${context.error_message}\n`;
  output += `**Files:** ${context.files_involved.join(', ')}\n\n`;

  // Known fixes first (sorted by effectiveness)
  if (memoryContext.known_fixes.length > 0) {
    output += '### ✅ Validated Fixes (Try These First)\n\n';
    memoryContext.known_fixes.forEach((fix, i) => {
      output += `${i + 1}. **${fix.id}** [Effectiveness: ${fix.metadata?.effectiveness_score?.toFixed(2) || 'N/A'}]\n`;
      output += `   - Tags: ${fix.metadata?.tags?.join(', ')}\n`;
      output += `   - Files: ${fix.metadata?.related_files?.join(', ') || 'N/A'}\n`;
      output += `   - Confidence: ${fix.metadata?.confidence}\n`;
      output += `   - ✅ Human-validated\n`;
      output += `   - Used ${fix.metadata?.usage_count || 0} times\n`;
      output += `   - Created: ${fix.metadata?.created_at}\n\n`;
    });
  }

  // Similar errors
  if (memoryContext.similar_errors.length > 0) {
    output += '### 🔍 Similar Errors\n\n';
    memoryContext.similar_errors
      .filter((err) => !memoryContext.known_fixes.includes(err)) // Exclude already shown
      .slice(0, 3) // Limit to 3
      .forEach((err, i) => {
        output += `${i + 1}. **${err.id}** (Score: ${err.score.toFixed(3)})\n`;
        output += `   - Tags: ${err.metadata?.tags?.join(', ')}\n`;
        output += `   - Files: ${err.metadata?.related_files?.join(', ') || 'N/A'}\n`;
        output += `   - Validated: ${err.metadata?.validated ? '✅ Yes' : '❌ No'}\n\n`;
      });
  }

  // Related incidents
  if (memoryContext.related_incidents.length > 0) {
    output += '### ⚠️ Related Production Incidents\n\n';
    memoryContext.related_incidents.forEach((incident, i) => {
      output += `${i + 1}. **${incident.id}** [Importance: ${incident.metadata?.importance}]\n`;
      output += `   - Tags: ${incident.metadata?.tags?.join(', ')}\n`;
      output += `   - Files: ${incident.metadata?.related_files?.join(', ') || 'N/A'}\n`;
      output += `   - Created: ${incident.metadata?.created_at}\n\n`;
    });
  }

  // Anti-patterns to avoid
  if (memoryContext.anti_patterns.length > 0) {
    output += '### 🚫 Anti-Patterns to Avoid\n\n';
    memoryContext.anti_patterns.forEach((antipattern, i) => {
      output += `${i + 1}. **${antipattern.id}**\n`;
      output += `   - Tags: ${antipattern.metadata?.tags?.join(', ')}\n`;
      output += `   - Why to avoid: ${antipattern.metadata?.retrieval_triggers?.join(', ') || 'See memory'}\n\n`;
    });
  }

  // Code review warnings
  if (memoryContext.code_review_warnings.length > 0) {
    output += '### 📝 Code Review Warnings for These Files\n\n';
    memoryContext.code_review_warnings.slice(0, 2).forEach((warning, i) => {
      output += `${i + 1}. **${warning.id}**\n`;
      output += `   - Tags: ${warning.metadata?.tags?.join(', ')}\n`;
      output += `   - Created: ${warning.metadata?.created_at}\n\n`;
    });
  }

  if (
    memoryContext.similar_errors.length === 0 &&
    memoryContext.known_fixes.length === 0 &&
    memoryContext.related_incidents.length === 0
  ) {
    output += '> ⚠️ No similar errors found in memory. This may be a novel issue.\n\n';
    output += '> **Recommended Approach:**\n';
    output += '> 1. Thorough investigation of root cause\n';
    output += '> 2. Check for similar patterns in codebase\n';
    output += '> 3. Document solution for future reference\n\n';
  } else {
    output += '> **Debugging Strategy:**\n';
    output += '> 1. Try validated fixes first (highest effectiveness score)\n';
    output += '> 2. Review similar errors for patterns\n';
    output += '> 3. Check related incidents for broader context\n';
    output += '> 4. Avoid known anti-patterns\n';
    output += '> 5. Document your fix if novel\n\n';
  }

  return output;
}

// Main hook execution
async function main() {
  try {
    // Parse hook input
    const errorMessage = process.env.ERROR_MESSAGE || process.argv[2];
    const errorType = process.env.ERROR_TYPE || process.argv[3];
    const filesInvolved = (process.env.FILES_INVOLVED || process.argv[4] || '').split(',');
    const repo = process.env.REPO || process.argv[5] || 'unknown';
    const stackTrace = process.env.STACK_TRACE;

    if (!errorMessage) {
      console.error('❌ ERROR_MESSAGE not provided');
      process.exit(1);
    }

    const context: DebuggingContext = {
      error_message: errorMessage,
      error_type: errorType,
      files_involved: filesInvolved.filter((f) => f.trim().length > 0),
      repo,
      stack_trace: stackTrace,
    };

    // Retrieve memories
    const memoryContext = await retrieveDebuggingContext(context);

    // Format for Claude
    const formattedOutput = formatMemoryForDebugging(context, memoryContext);

    // Output to stdout
    console.log(formattedOutput);

    process.exit(0);
  } catch (error) {
    console.error('❌ Pre-debugging memory retrieval failed:', error);
    console.error('   Continuing without memory context...');
    process.exit(0); // Don't block debugging if memory fails
  }
}

// Export for testing
export {
  retrieveDebuggingContext,
  formatMemoryForDebugging,
  DebuggingContext,
  DebuggingMemoryContext,
};

// Run directly
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
