---
description: Review the given plan document for parallelization and initiate subagnets
---

# Request
1. Review the tasks in the plan $1 and think how you could split them up to be addressed by multiple subagents in parallel, and how many agents (to a max of 10) that you could leverage. 
1. Add each of these individual taks to the todo list
1. Once you have a parallelization plan, initiate as many @developer subagents to complete the tasks as you set in your plan.

## Success Criteria
* Regardless of parallel or serial steps, every task should be as small and atmoic as possible to keep subagent context window small, and subagents returning as quickly as possible
* No two agents should ever be working on the same file.
* @developer subagents should never run tests. After a developer agent finishes their work, a @debugger agent should be spawned to run tests. The debugger agent should review the failures, and return to the orchestrator session a root cause hypothesis for each failure, as well as a reference to the resulting test report file.