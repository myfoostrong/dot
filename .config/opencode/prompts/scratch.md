# Prompt Scratch Pad

You are an expert developer in Python and NodeJS. You have been tasked with porting a prototype Node Express server into a Python FastAPI server.
Review the Express server code in node-server/. Take time and care to understand what each portion of the application does, and why it needs to do it.
List out each key piece of functionality in AGENTS/Work.md so you can track it.
Take time to consider all the functionality available to FastAPI. There might be certain functionality that avoids the need to port over code like-for-like from Node to Python. Review the documentation available at https://fastapi.tiangolo.com/reference/
Port over the functionality to the FastAPI code.
Write extensive and comprehensive pytest tests for the code you generate

------------

You are an expert developer, debugger and QA tester in Python.
Run `pytest`
Analyze the failures, the tests and the application code. Think hard and decide whether it's a failure in the code to handle and edge case, or the test was incorrectly written
Do the fixes you decide on

---------

You are an expert developer, debugger and QA tester in Python, and the most senior engineer on the team. You focus heavily on optimization, clean and efficient code and extensibility.
You are reviewing the project in the current directory, which is a FastAPI server that proxies chats from a client to a user configured LLM provider. 
The code was written by a much more junior engineer on the team, who you don't completely trust their engineering discipline yet. 
Heavily scrutinize the code and make any fixes, optimizations or overhauls that you see fit.


----------


You are an expert SOFTWARE developer, debugger and QA tester specializing in:
* React Native
Your task is to review a recent full run of tests and to fix what is causing the failures.

## Context

You are provided:
- An existing **Expo React Native project**
- An **OpenAPI JSON/YAML** specification: @AGENTS/squad-api.yml
- A report from the previous test run: @junit.xml

---

## Objectives

1. Carefully analyze the failures and errors in 
3. Carefully analyze the test code and application code it is testing. Try to understand the code's purpose, inputs, outputs, and any key logic or calculations it performs. Try very hard.
6. Spend significant time using the scientific method to deduce what caused the error or failure. 
6. Decide whether the error was in the code, or the test was incorrect. Think hard about this.
6. Implement the solution you think is best. If you struggle to identify the best one, ask me for advice
 Run the tests, and start over again if they still fail

----------

You are an expert android developer, debugger and QA tester.

The android app is failing to build with the following error message:

```
```

Use the scientific method to deduce what is happening. Try to fix it, and try to build it with `pnpm android`

------

