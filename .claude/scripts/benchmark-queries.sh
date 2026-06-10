#!/bin/bash
# Query Performance Benchmark
# Runs 10 queries and measures latency

# Check for required environment variables
if [ -z "$PINECONE_API_KEY" ]; then
  echo "❌ Error: PINECONE_API_KEY not set"
  echo "Please set: export PINECONE_API_KEY=your-key"
  exit 1
fi

if [ -z "$OPENAI_API_KEY" ]; then
  echo "❌ Error: OPENAI_API_KEY not set"
  echo "Please set: export OPENAI_API_KEY=your-key"
  exit 1
fi

echo "🏁 Query Performance Benchmark"
echo "Running 10 queries..."
echo ""

QUERIES=(
  "bug fix error"
  "authentication"
  "database migration"
  "API endpoint"
  "test coverage"
  "deployment"
  "configuration"
  "logging"
  "validation"
  "optimization"
)

TOTAL_TIME=0
SUCCESS_COUNT=0

for i in "${!QUERIES[@]}"; do
  QUERY="${QUERIES[$i]}"
  echo "Query $((i+1))/10: \"$QUERY\""

  START=$(date +%s%3N)
  npx tsx pinecone-memory-query.ts "$QUERY" --repo=orryx-brain --domain=debugging --top-k=5 > /dev/null 2>&1
  RESULT=$?
  END=$(date +%s%3N)

  LATENCY=$((END - START))

  if [ $RESULT -eq 0 ]; then
    echo "  ✅ Success - ${LATENCY}ms"
    TOTAL_TIME=$((TOTAL_TIME + LATENCY))
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo "  ❌ Failed"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Results:"
echo "  Total queries: 10"
echo "  Successful: $SUCCESS_COUNT"
echo "  Failed: $((10 - SUCCESS_COUNT))"

if [ $SUCCESS_COUNT -gt 0 ]; then
  AVG_LATENCY=$((TOTAL_TIME / SUCCESS_COUNT))
  echo "  Avg latency: ${AVG_LATENCY}ms"

  if [ $AVG_LATENCY -lt 500 ]; then
    echo "  ✅ PASS: < 500ms target"
  else
    echo "  ❌ FAIL: > 500ms target"
  fi
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
