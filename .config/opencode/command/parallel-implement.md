---
agent: task-orchestrator
description: Split a plan into parallel tasks, execute with developer agents, and verify with a debugger.
---

# Parallel Implement Plan

You are an orchestration agent. Your goal is to execute a complex technical plan by splitting it into parallel streams of work, assigning them to `@developer` agents, and finally verifying the result with a `@debugger` agent.

## Phase 1: Analysis & Sharding

1.  **Read the Master Plan:** Read the plan file provided as an argument (or ask for one if not provided).
2.  **Analyze Dependencies:** Read the files mentioned in the plan to understand their relationships and content.
3.  **Create Shards:** Group tasks into distinct "shards" that can run in parallel.
    *   **CRITICAL RULE:** No two shards can modify the same file. If multiple tasks modify `file_A.ts`, they **MUST** be in the same shard (or run serially).
    *   Target 2-5 shards for optimal parallelism (max 10).
    *   Each shard must be atomic and self-contained.

## Phase 2: Preparation

For each shard:
1.  Create a temporary plan file using the `Write` tool (e.g., `.opencode/plans/temp/shard_[N].md`).
2.  Copy the relevant context (headers, summary) and the specific tasks for that shard into the file.
3.  Ensure the temporary plan follows the standard plan format so the developer agent can read it.

## Phase 3: Execution

Launch `@developer` subagents in parallel using the `Task` tool for each shard.

*   **Subagent Type:** `developer`
*   **Description:** Implement Shard [N]
*   **Prompt:**
    ```
    /implement_plan .opencode/plans/temp/shard_[N].md

    IMPORTANT OVERRIDES for this parallel execution:
    1. Implement the changes for this specific shard.
    2. DO NOT run the full project test suite or final verification steps (e.g. `make check`).
    3. ONLY run specific unit tests if you created/modified them strictly within your shard.
    4. Report completion once the code is implemented.
    ```

## Phase 4: Verification

1.  Wait for all `@developer` agents to complete their tasks.
2.  Launch a `@debugger` agent to verify the global integration.
    *   **Subagent Type:** `debugger`
    *   **Description:** Verify integration and run tests
    *   **Prompt:**
        ```
        Run the full project test suite (e.g., `make check` or `npm test`).
        
        If there are failures:
        1. Analyze the root cause.
        2. Provide a hypothesis for each failure.
        3. Reference the test report file location.
        ```

## Success Criteria

*   All tasks in the master plan are accounted for in the shards.
*   Parallel agents never worked on the same file.
*   The final debugger run provides a pass/fail status for the integrated work.
