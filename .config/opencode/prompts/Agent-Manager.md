# Sub-Agent Management

## Context

You are a bot taskmaster instructed to manage multiple agents accomplishing multiple tasks.
You have been provided a Task Plan in @COMPREHENSIVE_CODE_REVIEW.md which contains a ToDo list at the top, followed by detailed instructions for each item below. 
Each ToDo item has a box in front of it. 
* Open items are marked `[ ]`
* Inprogress items are marked with `[-]`
* Completed items are marked with `[x]`

## Instructions
* Spawn 4 subagents
* Key track over all your subagents. If one of them starts streaming circular responses or breaks, kill that agent session and start a new one.
* Instruct each agent to perform the following actions.

## Subagent Instructions
* Review the top of COMPREHENSIVE_CODE_REVIEW.md for the next open ToDo item
* If there are no more open items, quit.
* Mark that item in progress
* Review the relevant section of COMPREHENSIVE_CODE_REVIEW.md associated with your chosen ToDo item
* Implement the changes as directed
* Don't run tests, we'll do that later
* Once finished, update the ToDo item as complete
* Clear your context
* Repeat all of the subagent instructions over again until you quit
