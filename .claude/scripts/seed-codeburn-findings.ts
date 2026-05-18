#!/usr/bin/env tsx
/**
 * Pinecone Memory Seeding: Codeburn Findings
 *
 * Extracts optimization patterns and anti-patterns from Codeburn analysis reports.
 *
 * Expected output: ~50 findings
 */

import { readFileSync, readdirSync, existsSync } from 'fs';
import { join } from 'path';
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

interface CodeburnFinding {
  issue: string;
  antiPattern: string;
  recommendation: string;
  potentialSavings: string;
  severity: 'high' | 'medium' | 'low';
  category: string;
}

const CODEBURN_SOURCES = [
  'D:\\orryx-audit\\governance\\CODEBURN_BASELINE.md',
  'D:\\orryx-audit\\governance\\CODEBURN_DASHBOARD.md'
];

function parseCodeburnReport(content: string): CodeburnFinding[] {
  const findings: CodeburnFinding[] = [];

  // Parse findings from markdown tables or structured sections
  const issueRegex = /\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|/g;
  let match;

  while ((match = issueRegex.exec(content)) !== null) {
    const [_, issue, impact, savings] = match;

    if (issue && issue.trim() !== 'Issue' && issue.trim() !== '---') {
      findings.push({
        issue: issue.trim(),
        antiPattern: 'See issue description',
        recommendation: impact.trim(),
        potentialSavings: savings.trim(),
        severity: savings.includes('high') || savings.includes('critical') ? 'high' :
                 savings.includes('medium') ? 'medium' : 'low',
        category: 'optimization'
      });
    }
  }

  // Also extract from "Critical Issues" sections
  const criticalRegex = /###\s+(.+?)\n([\s\S]+?)(?=###|$)/g;

  while ((match = criticalRegex.exec(content)) !== null) {
    const [_, title, description] = match;

    if (title.toLowerCase().includes('issue') || title.toLowerCase().includes('finding')) {
      const lines = description.split('\n').filter(l => l.trim());

      findings.push({
        issue: title.trim(),
        antiPattern: lines[0]?.trim() || 'See description',
        recommendation: lines.find(l => l.includes('Recommendation') || l.includes('Fix'))?.trim() || '',
        potentialSavings: lines.find(l => l.includes('saving') || l.includes('token'))?.trim() || '',
        severity: 'high',
        category: 'optimization'
      });
    }
  }

  return findings;
}

async function seedCodeburnFindings() {
  console.log('🌱 Seeding Codeburn findings to Pinecone...\n');

  let totalFindings = 0;

  for (const sourcePath of CODEBURN_SOURCES) {
    if (!existsSync(sourcePath)) {
      console.log(`⚠️  ${sourcePath} not found, skipping`);
      continue;
    }

    console.log(`📂 Processing ${sourcePath}`);

    try {
      const content = readFileSync(sourcePath, 'utf-8');
      const findings = parseCodeburnReport(content);

      console.log(`   Found ${findings.length} findings`);

      for (const finding of findings) {
        try {
          const memoryContent = `Issue: ${finding.issue}\n\nAnti-pattern: ${finding.antiPattern}\n\nRecommendation: ${finding.recommendation}\n\nPotential Savings: ${finding.potentialSavings}`;

          // Generate embedding
          const embeddingResponse = await openai.embeddings.create({
            model: 'text-embedding-3-small',
            input: memoryContent,
            dimensions: 1536
          });

          const embedding = embeddingResponse.data[0].embedding;
          const memoryId = uuidv4();

          // Write to Pinecone
          await index.namespace('codeburn.findings').upsert([{
            id: memoryId,
            values: embedding,
            metadata: {
              type: 'codeburn-finding',
              repo: 'all',
              domain: 'optimization',
              issue: finding.issue,
              anti_pattern: finding.antiPattern,
              recommendation: finding.recommendation,
              potential_savings: finding.potentialSavings,
              severity: finding.severity,
              category: finding.category,
              content: memoryContent.substring(0, 1000),
              tags: ['codeburn', 'optimization', finding.severity],
              importance: finding.severity === 'high' ? 'high' : 'medium',
              confidence: 0.9,
              validated: true,
              created_at: new Date().toISOString(),
              author: 'codeburn-analysis',
              author_type: 'agent'
            }
          }]);

          totalFindings++;
          console.log(`   ✅ ${finding.issue}`);

        } catch (error) {
          console.error(`   ❌ Failed to seed finding "${finding.issue}": ${error}`);
        }
      }
    } catch (error) {
      console.error(`❌ Failed to process ${sourcePath}: ${error}`);
    }
  }

  console.log(`\n🎉 Seeded ${totalFindings} Codeburn findings successfully!`);
}

seedCodeburnFindings().catch(console.error);
