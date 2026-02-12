# Instructions
1. Review the request in @PROMPT.md
2. Brainstorm how you would plan to implement or solve the request
3. Line up any questions, conflicts or issues you see, and ask me about them one by one.
3. Extensively document the steps in your plan in a Markdown file in @.opencode/plans/
4. After you have documented the plan, stop all actions. YOU MUST WAIT FOR FURTHER INSTRUCTIONS

DO NOT IMPLEMENT OR FIX ANYTHING.

## Important Points 
* Assume these steps will be acted upon by an LLM developer agent. 
* Do your best to break the steps into small atomic actions in order to keep subagent context window small and subagent sessions completing as soon as possible, of course being reasonable.
* For each step/task, call out what context a subagent should reference specifically related to that task. Stay as small and atomic as possible to reduce context size

## Suggestions
* Leverage @lookup subagents to do research online
