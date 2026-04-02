# AI Agent Skill — Claude API + Multi-Agent Architecture

## Tool Definition Format (Claude API tool_use)

```ts
import Anthropic from '@anthropic-ai/sdk';

// Define tools as typed constants — never inline in the API call
const searchTool: Anthropic.Tool = {
  name: 'search_web',
  description: 'Search the web for current information. Use when you need facts not in your training data. Returns the top 5 results with titles, URLs, and snippets.',
  input_schema: {
    type: 'object' as const,
    properties: {
      query: {
        type: 'string',
        description: 'The search query. Be specific. Include year if you want recent results.',
      },
      num_results: {
        type: 'number',
        description: 'Number of results to return (1-10). Default 5.',
      },
    },
    required: ['query'],
  },
};

const dbQueryTool: Anthropic.Tool = {
  name: 'query_database',
  description: 'Execute a read-only SQL query against the PostgreSQL database. Only SELECT statements allowed.',
  input_schema: {
    type: 'object' as const,
    properties: {
      sql: { type: 'string', description: 'The SELECT SQL query to execute.' },
      params: {
        type: 'array',
        items: { type: 'string' },
        description: 'Parameterized query values [$1, $2, ...]',
      },
    },
    required: ['sql'],
  },
};
```

## Agent Run Loop Pattern

```ts
// src/agents/agent-runner.ts
import Anthropic from '@anthropic-ai/sdk';
import { logger } from '../config/logger';

const client = new Anthropic();

interface ToolHandler {
  [toolName: string]: (input: Record<string, unknown>) => Promise<unknown>;
}

export async function runAgentLoop(
  systemPrompt: string,
  userMessage: string,
  tools: Anthropic.Tool[],
  toolHandlers: ToolHandler,
  maxIterations = 10
): Promise<string> {
  const messages: Anthropic.MessageParam[] = [
    { role: 'user', content: userMessage },
  ];

  for (let iteration = 0; iteration < maxIterations; iteration++) {
    logger.info({ iteration }, 'Agent iteration');

    const response = await client.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 4096,
      system: systemPrompt,
      tools,
      messages,
    });

    // Append assistant turn
    messages.push({ role: 'assistant', content: response.content });

    // Stop conditions
    if (response.stop_reason === 'end_turn') {
      const textBlock = response.content.find((b) => b.type === 'text');
      return textBlock?.type === 'text' ? textBlock.text : '';
    }

    if (response.stop_reason !== 'tool_use') {
      throw new Error(`Unexpected stop reason: ${response.stop_reason}`);
    }

    // Process all tool calls in parallel
    const toolUseBlocks = response.content.filter(
      (b): b is Anthropic.ToolUseBlock => b.type === 'tool_use'
    );

    const toolResults = await Promise.all(
      toolUseBlocks.map(async (toolUse) => {
        const handler = toolHandlers[toolUse.name];
        if (!handler) {
          return {
            type: 'tool_result' as const,
            tool_use_id: toolUse.id,
            content: `Error: Unknown tool "${toolUse.name}"`,
            is_error: true,
          };
        }
        try {
          const result = await handler(toolUse.input as Record<string, unknown>);
          return {
            type: 'tool_result' as const,
            tool_use_id: toolUse.id,
            content: JSON.stringify(result),
          };
        } catch (err) {
          logger.error({ err, toolName: toolUse.name }, 'Tool execution failed');
          return {
            type: 'tool_result' as const,
            tool_use_id: toolUse.id,
            content: `Error: ${err instanceof Error ? err.message : 'Tool failed'}`,
            is_error: true,
          };
        }
      })
    );

    messages.push({ role: 'user', content: toolResults });
  }

  throw new Error(`Agent exceeded max iterations (${maxIterations})`);
}
```

## System Prompt Template for Agent

```ts
function buildSystemPrompt(context: {
  agentRole: string;
  goal: string;
  constraints: string[];
  outputFormat: string;
}): string {
  return `You are ${context.agentRole}.

## Goal
${context.goal}

## Available Tools
You have access to tools. Use them when you need information you don't have.
Think step-by-step before using tools. Always verify your results before concluding.

## Constraints
${context.constraints.map((c) => `- ${c}`).join('\n')}

## Output Format
${context.outputFormat}

## Behavior Rules
- Be systematic: plan, execute, verify.
- If a tool returns an error, try an alternative approach before giving up.
- Do not hallucinate data — if you don't know, use a tool or say you don't know.
- When done, respond with your final answer only — no tool calls.`;
}
```

## Multi-Agent Orchestration — Sequential

```ts
// src/agents/orchestrator.ts
export async function runSequentialPipeline<T>(
  stages: Array<{
    name: string;
    run: (input: T) => Promise<T>;
  }>,
  initialInput: T
): Promise<T> {
  let current = initialInput;
  for (const stage of stages) {
    logger.info({ stage: stage.name }, 'Running pipeline stage');
    current = await stage.run(current);
  }
  return current;
}

// Usage:
const result = await runSequentialPipeline([
  { name: 'scraper',  run: (ctx) => scraperAgent(ctx) },
  { name: 'analyst',  run: (ctx) => analystAgent(ctx) },
  { name: 'writer',   run: (ctx) => writerAgent(ctx) },
], { url: 'https://example.com', data: null, report: null });
```

## Multi-Agent Orchestration — Parallel

```ts
export async function runParallelAgents<T>(
  tasks: Array<{ name: string; run: () => Promise<T> }>,
  concurrency = 3
): Promise<T[]> {
  const results: T[] = [];
  for (let i = 0; i < tasks.length; i += concurrency) {
    const batch = tasks.slice(i, i + concurrency);
    const batchResults = await Promise.allSettled(batch.map((t) => t.run()));
    for (const [j, result] of batchResults.entries()) {
      if (result.status === 'rejected') {
        logger.error({ task: batch[j].name, err: result.reason }, 'Parallel agent failed');
        throw result.reason; // or push null and continue, depending on task
      }
      results.push(result.value);
    }
  }
  return results;
}
```

## Memory Pattern

```ts
// Short-term: pass context via messages array (automatic in run loop)
// Long-term: persist key facts to DB/file

interface AgentMemory {
  sessionId: string;
  facts: Array<{ key: string; value: unknown; createdAt: Date }>;
}

// Store in Redis for session (TTL: 1 hour)
async function saveMemory(sessionId: string, key: string, value: unknown): Promise<void> {
  const memKey = `agent:memory:${sessionId}`;
  const existing = JSON.parse(await redis.get(memKey) ?? '{"facts":[]}') as AgentMemory;
  existing.facts.push({ key, value, createdAt: new Date() });
  await redis.setEx(memKey, 3600, JSON.stringify(existing));
}

async function recallMemory(sessionId: string): Promise<AgentMemory['facts']> {
  const memKey = `agent:memory:${sessionId}`;
  const data = await redis.get(memKey);
  return data ? (JSON.parse(data) as AgentMemory).facts : [];
}

// Inject recalled memory into system prompt:
const memories = await recallMemory(sessionId);
const memorySection = memories.length
  ? `\n## Recalled Context\n${memories.map((m) => `- ${m.key}: ${JSON.stringify(m.value)}`).join('\n')}`
  : '';
```

## Error Handling in Agent Loop

```ts
// Wrap agent runs with retry + circuit breaker
async function runAgentWithRetry(
  agentFn: () => Promise<string>,
  maxRetries = 3,
  retryDelayMs = 1000
): Promise<string> {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await agentFn();
    } catch (err) {
      const isRetryable = err instanceof Anthropic.APIError && err.status >= 500;
      if (!isRetryable || attempt === maxRetries) throw err;
      logger.warn({ attempt, err }, 'Agent failed, retrying');
      await new Promise((r) => setTimeout(r, retryDelayMs * attempt));
    }
  }
  throw new Error('Agent failed after max retries'); // unreachable but satisfies TS
}
```

## Streaming Response Pattern

```ts
// Stream agent responses to HTTP clients via SSE
import { Response } from 'express';

export async function streamAgentToClient(
  systemPrompt: string,
  userMessage: string,
  res: Response
): Promise<void> {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  const stream = await client.messages.stream({
    model: 'claude-sonnet-4-6',
    max_tokens: 4096,
    system: systemPrompt,
    messages: [{ role: 'user', content: userMessage }],
  });

  for await (const chunk of stream) {
    if (chunk.type === 'content_block_delta' && chunk.delta.type === 'text_delta') {
      res.write(`data: ${JSON.stringify({ text: chunk.delta.text })}\n\n`);
    }
  }

  res.write('data: [DONE]\n\n');
  res.end();
}
```
