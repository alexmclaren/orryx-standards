#!/usr/bin/env tsx
/**
 * Pre-Edit Memory Retrieval Hook
 *
 * Triggered before editing any file
 * Retrieves relevant code review findings, debugging history, and patterns
 *
 * Hook Configuration in .claude/settings.json:
 * {
 *   "hooks": {
 *     "pre-edit": ".claude/hooks/pre-edit-memory-retrieval.ts"
 *   }
 * }
 */

import { queryMemory, QueryOptions } from '../scripts/pinecone-memory-query';
import * as path from 'path';

interface EditContext {
  file_path: string;
  repo: string;
  edit_reason?: string; // 'bug_fix', 'feature', 'refactor', etc.
}

interface FileMemoryContext {
  code_review_findings: any[];
  debugging_history: any[];
  successful_patterns: any[];
  recent_changes: any[];
  warnings: string[];
}

function extractModule(filePath: string): string {
  // Extract module/package name from file path
  // Example: backend/auth/login.py → auth
  const parts = filePath.split(/[/\\]/);
  return parts.length > 1 ? parts[parts.length - 2] : path.dirname(filePath);
}

async function retrieveEditContext(context: EditContext): Promise<FileMemoryContext> {
  console.error(`\n🧠 Retrieving memory for file: ${context.file_path}\n`);

  const module = extractModule(context.file_path);
  const fileName = path.basename(context.file_path);

  // Build queries
  const queries: string[] = [
    `code review findings for ${context.file_path}`,
    `debugging solutions in ${context.file_path}`,
    `patterns used in ${module}`,
    `recent changes to ${fileName}`,
  ];

  // Determine namespaces
  const namespaces: string[] = [
    `${context.repo}.patterns`,
    `${context.repo}.debugging`,
    `${context.repo}.sessions`,
  ];

  // If bug fix, also check incidents
  if (context.edit_reason === 'bug_fix') {
    namespaces.push('incidents.postmortems');
  }

  const allMatches: any[] = [];

  // Execute queries with file-specific filters
  for (const query of queries) {
    try {
      const options: QueryOptions = {
        query,
        namespaces,
        topK: 2, // Top 2 per query to avoid overwhelming
        minConfidence: 0.8, // Higher threshold for edit context
      };

      const result = await queryMemory(options);

      // Filter to only matches that reference this file
      const fileRelevantMatches = result.matches.filter((match) => {
        const relatedFiles = match.metadata?.related_files || [];
        return (
          relatedFiles.some((f: string) => f.includes(fileName)) ||
          relatedFiles.some((f: string) => f.includes(context.file_path))
        );
      });

      allMatches.push(...fileRelevantMatches);

      console.error(
        `   ✓ Query: "${query.substring(0, 50)}..." → ${fileRelevantMatches.length} file-specific matches`
      );
    } catch (error) {
      console.error(`   ✗ Query failed: "${query}"`, error);
    }
  }

  // Organize by type
  const fileContext: FileMemoryContext = {
    code_review_findings: allMatches.filter((m) => m.metadata?.type === 'code-review'),
    debugging_history: allMatches.filter((m) => m.metadata?.type === 'debugging-solution'),
    successful_patterns: allMatches.filter((m) => m.metadata?.type === 'pattern'),
    recent_changes: allMatches.filter((m) => m.metadata?.type === 'session-learning'),
    warnings: [],
  };

  // Extract warnings from high-importance findings
  fileContext.warnings = allMatches
    .filter((m) => m.metadata?.importance === 'critical' || m.metadata?.importance === 'high')
    .map((m) => m.metadata?.retrieval_triggers?.join(', ') || 'Warning')
    .slice(0, 3); // Max 3 warnings

  // Summary
  console.error('\n📊 File Memory Summary:');
  console.error(`   Code Review Findings: ${fileContext.code_review_findings.length}`);
  console.error(`   Debugging History: ${fileContext.debugging_history.length}`);
  console.error(`   Patterns: ${fileContext.successful_patterns.length}`);
  console.error(`   Recent Changes: ${fileContext.recent_changes.length}`);
  console.error(`   Warnings: ${fileContext.warnings.length}\n`);

  return fileContext;
}

function formatMemoryForEdit(context: EditContext, memoryContext: FileMemoryContext): string {
  let output = `\n## 🧠 Memory for File: ${context.file_path}\n\n`;

  // Critical warnings first
  if (memoryContext.warnings.length > 0) {
    output += '### ⚠️ Critical Warnings\n\n';
    memoryContext.warnings.forEach((warning, i) => {
      output += `${i + 1}. ${warning}\n`;
    });
    output += '\n';
  }

  // Debugging history
  if (memoryContext.debugging_history.length > 0) {
    output += '### 🐛 Known Issues and Fixes\n\n';
    memoryContext.debugging_history.forEach((bug, i) => {
      output += `${i + 1}. **${bug.id}**\n`;
      output += `   - Tags: ${bug.metadata?.tags?.join(', ')}\n`;
      output += `   - Confidence: ${bug.metadata?.confidence}\n`;
      output += `   - Effectiveness: ${bug.metadata?.effectiveness_score || 'Not rated'}\n`;
      output += `   - Created: ${bug.metadata?.created_at}\n\n`;
    });
  }

  // Code review findings
  if (memoryContext.code_review_findings.length > 0) {
    output += '### 📝 Code Review History\n\n';
    memoryContext.code_review_findings.forEach((review, i) => {
      output += `${i + 1}. **${review.id}**\n`;
      output += `   - Tags: ${review.metadata?.tags?.join(', ')}\n`;
      output += `   - Related PRs: ${review.metadata?.related_prs?.join(', ') || 'N/A'}\n`;
      output += `   - Created: ${review.metadata?.created_at}\n\n`;
    });
  }

  // Successful patterns
  if (memoryContext.successful_patterns.length > 0) {
    output += '### ✅ Proven Patterns\n\n';
    memoryContext.successful_patterns.forEach((pattern, i) => {
      output += `${i + 1}. **${pattern.id}** (Score: ${pattern.score.toFixed(3)})\n`;
      output += `   - Tags: ${pattern.metadata?.tags?.join(', ')}\n`;
      output += `   - Validated: ${pattern.metadata?.validated ? '✅ Yes' : '❌ No'}\n\n`;
    });
  }

  // Recent changes
  if (memoryContext.recent_changes.length > 0) {
    output += '### 🕒 Recent Changes\n\n';
    memoryContext.recent_changes.forEach((change, i) => {
      output += `${i + 1}. **${change.id}**\n`;
      output += `   - Session: ${change.metadata?.session_id || 'N/A'}\n`;
      output += `   - Created: ${change.metadata?.created_at}\n\n`;
    });
  }

  if (
    memoryContext.code_review_findings.length === 0 &&
    memoryContext.debugging_history.length === 0 &&
    memoryContext.successful_patterns.length === 0 &&
    memoryContext.recent_changes.length === 0
  ) {
    output += '> No file-specific memories found. Proceed with caution.\n\n';
  }

  output +=
    '> **Pre-Edit Checklist:**\n' +
    '> - ✅ Reviewed known issues and warnings\n' +
    '> - ✅ Checked for successful patterns to follow\n' +
    '> - ✅ Aware of recent changes to this file\n' +
    '> - ✅ Ready to apply best practices\n\n';

  return output;
}

// Main hook execution
async function main() {
  try {
    // Parse hook input
    const filePath = process.env.FILE_PATH || process.argv[2];
    const repo = process.env.REPO || process.argv[3] || 'unknown';
    const editReason = process.env.EDIT_REASON || process.argv[4];

    if (!filePath) {
      console.error('❌ FILE_PATH not provided');
      process.exit(1);
    }

    const context: EditContext = {
      file_path: filePath,
      repo,
      edit_reason: editReason,
    };

    // Retrieve memories
    const memoryContext = await retrieveEditContext(context);

    // Format for Claude
    const formattedOutput = formatMemoryForEdit(context, memoryContext);

    // Output to stdout
    console.log(formattedOutput);

    process.exit(0);
  } catch (error) {
    console.error('❌ Pre-edit memory retrieval failed:', error);
    console.error('   Continuing without memory context...');
    process.exit(0); // Don't block edit if memory fails
  }
}

// Export for testing
export { retrieveEditContext, formatMemoryForEdit, EditContext, FileMemoryContext };

// Run if executed directly
if (require.main === module) {
  main();
}
