#!/usr/bin/env tsx
/**
 * Pre-Planning Memory Retrieval Hook
 *
 * Triggered before entering PLAN MODE
 * Retrieves relevant memories from Pinecone to inform planning
 *
 * Hook Configuration in .claude/settings.json:
 * {
 *   "hooks": {
 *     "pre-planning": ".claude/hooks/pre-planning-memory-retrieval.ts"
 *   }
 * }
 */

import { queryMemory, QueryOptions } from '../scripts/pinecone-memory-query';

interface PlanningContext {
  task_description: string;
  task_type: string; // 'feature', 'bug_fix', 'refactor', 'architecture', etc.
  repo: string;
  domain?: string;
  files_mentioned?: string[];
  keywords?: string[];
}

interface MemoryContext {
  relevant_adrs: any[];
  relevant_patterns: any[];
  relevant_solutions: any[];
  lessons_learned: any[];
  related_incidents: any[];
}

async function retrievePlanningContext(context: PlanningContext): Promise<MemoryContext> {
  console.error('\n🧠 Retrieving relevant memories from Pinecone...\n');

  // Build queries based on task context
  const queries: string[] = [];

  // Query 1: Similar implementations
  if (context.task_type) {
    queries.push(`similar ${context.task_type} implementations in ${context.repo}`);
  }

  // Query 2: Architecture decisions
  if (context.domain) {
    queries.push(`architecture decisions related to ${context.domain}`);
  }

  // Query 3: Debugging solutions (if applicable)
  if (context.task_type === 'bug_fix' && context.keywords) {
    queries.push(`debugging solutions for ${context.keywords.join(' ')}`);
  }

  // Query 4: Patterns
  queries.push(`patterns for ${context.task_description}`);

  // Query 5: Related incidents (for critical domains)
  const criticalDomains = ['authentication', 'authorization', 'payment', 'data-migration'];
  if (context.domain && criticalDomains.includes(context.domain)) {
    queries.push(`incidents related to ${context.domain}`);
  }

  // Determine namespaces to search
  const namespaces: string[] = [
    `${context.repo}.architecture`,
    `${context.repo}.patterns`,
    `${context.repo}.debugging`,
    `architecture.cross-repo`,
    `standards.global`,
  ];

  if (context.task_type === 'bug_fix' || context.keywords?.some((k) => k.includes('error'))) {
    namespaces.push('incidents.postmortems');
  }

  // Execute queries
  const allMatches: any[] = [];

  for (const query of queries) {
    try {
      const options: QueryOptions = {
        query,
        namespaces,
        topK: 3, // Top 3 per query
        minConfidence: 0.7,
        recencyBias: 0.3, // Prefer recent memories
        prioritizeValidated: true,
      };

      const result = await queryMemory(options);
      allMatches.push(...result.matches);

      console.error(`   ✓ Query: "${query}" → ${result.matches.length} matches`);
    } catch (error) {
      console.error(`   ✗ Query failed: "${query}"`, error);
    }
  }

  // Organize by type
  const memoryContext: MemoryContext = {
    relevant_adrs: allMatches.filter((m) => m.metadata?.type === 'adr'),
    relevant_patterns: allMatches.filter((m) => m.metadata?.type === 'pattern'),
    relevant_solutions: allMatches.filter((m) => m.metadata?.type === 'debugging-solution'),
    lessons_learned: allMatches.filter((m) => m.metadata?.type === 'session-learning'),
    related_incidents: allMatches.filter((m) => m.metadata?.type === 'incident'),
  };

  // Summary
  console.error('\n📊 Memory Retrieval Summary:');
  console.error(`   ADRs: ${memoryContext.relevant_adrs.length}`);
  console.error(`   Patterns: ${memoryContext.relevant_patterns.length}`);
  console.error(`   Solutions: ${memoryContext.relevant_solutions.length}`);
  console.error(`   Learnings: ${memoryContext.lessons_learned.length}`);
  console.error(`   Incidents: ${memoryContext.related_incidents.length}`);
  console.error(`   Total: ${allMatches.length}\n`);

  return memoryContext;
}

function formatMemoryForPlanning(context: MemoryContext): string {
  let output = '\n## 🧠 Relevant Memories from Pinecone\n\n';

  if (context.relevant_adrs.length > 0) {
    output += '### Architecture Decisions (ADRs)\n\n';
    context.relevant_adrs.forEach((adr, i) => {
      output += `${i + 1}. **${adr.id}** (Confidence: ${adr.metadata?.confidence})\n`;
      output += `   - Tags: ${adr.metadata?.tags?.join(', ')}\n`;
      output += `   - Created: ${adr.metadata?.created_at}\n`;
      output += `   - Files: ${adr.metadata?.related_files?.join(', ') || 'N/A'}\n\n`;
    });
  }

  if (context.relevant_patterns.length > 0) {
    output += '### Implementation Patterns\n\n';
    context.relevant_patterns.forEach((pattern, i) => {
      output += `${i + 1}. **${pattern.id}** (Score: ${pattern.score.toFixed(3)})\n`;
      output += `   - Tags: ${pattern.metadata?.tags?.join(', ')}\n`;
      output += `   - Confidence: ${pattern.metadata?.confidence}\n`;
      output += `   - Validated: ${pattern.metadata?.validated ? '✅ Yes' : '❌ No'}\n\n`;
    });
  }

  if (context.relevant_solutions.length > 0) {
    output += '### Debugging Solutions\n\n';
    context.relevant_solutions.forEach((solution, i) => {
      output += `${i + 1}. **${solution.id}** (Score: ${solution.score.toFixed(3)})\n`;
      output += `   - Tags: ${solution.metadata?.tags?.join(', ')}\n`;
      output += `   - Files: ${solution.metadata?.related_files?.join(', ') || 'N/A'}\n`;
      output += `   - Effectiveness: ${solution.metadata?.effectiveness_score || 'Not rated'}\n\n`;
    });
  }

  if (context.lessons_learned.length > 0) {
    output += '### Previous Learnings\n\n';
    context.lessons_learned.forEach((learning, i) => {
      output += `${i + 1}. **${learning.id}**\n`;
      output += `   - Repo: ${learning.metadata?.repo}\n`;
      output += `   - Domain: ${learning.metadata?.domain}\n`;
      output += `   - Created: ${learning.metadata?.created_at}\n\n`;
    });
  }

  if (context.related_incidents.length > 0) {
    output += '### ⚠️ Related Incidents (Learn from Past Issues)\n\n';
    context.related_incidents.forEach((incident, i) => {
      output += `${i + 1}. **${incident.id}** (Importance: ${incident.metadata?.importance})\n`;
      output += `   - Tags: ${incident.metadata?.tags?.join(', ')}\n`;
      output += `   - Created: ${incident.metadata?.created_at}\n`;
      output += `   - Files: ${incident.metadata?.related_files?.join(', ') || 'N/A'}\n\n`;
    });
  }

  if (
    context.relevant_adrs.length === 0 &&
    context.relevant_patterns.length === 0 &&
    context.relevant_solutions.length === 0 &&
    context.lessons_learned.length === 0 &&
    context.related_incidents.length === 0
  ) {
    output += '> No relevant memories found. This may be a new area of work.\n\n';
  }

  output +=
    '> **Note:** Use these memories to inform your planning. Avoid repeating past mistakes and leverage proven patterns.\n\n';

  return output;
}

// Main hook execution
async function main() {
  try {
    // Parse hook input (passed as environment variables or args)
    const taskDescription = process.env.TASK_DESCRIPTION || process.argv[2] || 'unknown task';
    const taskType = process.env.TASK_TYPE || process.argv[3] || 'feature';
    const repo = process.env.REPO || process.argv[4] || 'unknown';
    const domain = process.env.DOMAIN || process.argv[5];

    const context: PlanningContext = {
      task_description: taskDescription,
      task_type: taskType,
      repo,
      domain,
      keywords: taskDescription.split(/\s+/).filter((w) => w.length > 3),
    };

    // Retrieve memories
    const memoryContext = await retrievePlanningContext(context);

    // Format for Claude
    const formattedOutput = formatMemoryForPlanning(memoryContext);

    // Output to stdout (will be injected into Claude's context)
    console.log(formattedOutput);

    process.exit(0);
  } catch (error) {
    console.error('❌ Pre-planning memory retrieval failed:', error);
    console.error('   Continuing without memory context...');
    process.exit(0); // Don't block planning if memory fails
  }
}

// Export for testing
export { retrievePlanningContext, formatMemoryForPlanning, PlanningContext, MemoryContext };

// Run directly
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
