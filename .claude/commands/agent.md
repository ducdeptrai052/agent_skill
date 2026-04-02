Design a multi-agent execution plan for the given task description.

@.claude/skills/ai-agent.md
@.claude/skills/backend.md

$ARGUMENTS

Read the task description above and produce a complete agent execution plan. Output must be structured as:

1. **Task Analysis**
   - Goal: what success looks like (one sentence)
   - Complexity: Simple (1 agent) / Medium (2-3 agents) / Complex (orchestrator + specialists)
   - Estimated tool calls: approximate count
   - Risks: what could go wrong

2. **Agent Architecture**
   - List each agent role:
     - Name: e.g., `orchestrator`, `scraper`, `analyst`, `writer`
     - Responsibility: one sentence
     - Model: `claude-sonnet-4-6` (default) or `claude-haiku-4-5-20251001` (for simple/fast tasks)
     - Runs: sequentially after X / in parallel with Y

3. **Tool Definitions** — For each tool the agents will use:
   ```ts
   {
     name: "tool_name",
     description: "What this tool does and when to use it",
     input_schema: {
       type: "object",
       properties: {
         param1: { type: "string", description: "..." },
       },
       required: ["param1"]
     }
   }
   ```

4. **Orchestrator System Prompt** — Complete system prompt for the orchestrator agent:
   ```
   You are an orchestrator agent responsible for...
   Your goal: ...
   Available sub-agents: ...
   Decision rules: ...
   Output format: ...
   ```

5. **Execution Plan** — Step-by-step numbered plan:
   - Step 1: [Agent Name] → [Action] → [Expected Output]
   - Step 2: [Agent Name] → [Action] → [Expected Output]
   - Branching logic: "If step 3 returns empty, skip to step 7"

6. **Memory Strategy**
   - Short-term: what to keep in context window
   - Long-term: what to persist to database/file (key, format)
   - Context passing: how agent N passes state to agent N+1

7. **Error Handling Plan**
   - Retry logic: which steps retry, max attempts
   - Fallback: what happens if a step fails permanently
   - Partial success: how to handle partial completion

8. **TypeScript Implementation Skeleton**
   ```ts
   // Skeleton showing the main orchestrator loop
   import Anthropic from '@anthropic-ai/sdk';

   async function runAgentTask(taskDescription: string): Promise<void> {
     // ... skeleton with TODO comments
   }
   ```

Rules:
- Prefer sequential over parallel unless there is a clear independence between steps.
- Each tool must have a single, clear responsibility — no god tools.
- System prompts must be specific, not generic — include the actual task context.
- If the task can be done without agents (simple API call), say so and explain why agents are overkill.
