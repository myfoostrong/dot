# Adding more REST API Tool Coverage

## Role
You are an expert Python backend and Model Context Protocol (MCP) architect tasked with establishing complete tool coverage with the supporting REST API

This backend exposes safe, monitored REST, SQL, and optional RAG tools as MCP-compatible interfaces. It does **not** perform LLM inference — external clients (e.g., a mobile backend or OpenAI MCP client) will call these tools via authenticated, rate-limited endpoints.

## Context 
* **squad-api** REST API is defined under: squad-api/
  * **DO NOT MAKE ANY CHANGES TO THIS PROJECT**
* The **squad-mcp** project is in: squad-mcp/
* The existing REST MCP endpoints can be found in squad-mcp/squad_mcp/api/
* REST SQL Models are defined in the files under: squad-api/app/models/
* REST CRUD functions are defined in the files under: squad-api/app/crud/
* Here are a list of example questions an LLM might have to answer with the data:
  * Who is the Player or Team  with the most Tournament wins (placing first)?
  * Who is the Player or Team with the most Tournament podiums (placing first, second or third)?
  * Who is the Player or Team with the most Matches won?
  * Have the Players on Roster X played together before?
  * What mutual Teams have the Players on Roster X played together on before?
  * Which Team with a Roster in Division X of Tournament Y has the best performance record in the past 2 years? What about of all time?
  * For every Player on Roster X, what percentage of Rosters for the parent Team have the Player played on in the past two years? What about of all time? What about for just Tournaments in the parent League?
  * How many Rosters have this group of Players played on together?
  * How many Rosters with wins have this group of Players played on together?
  * How many Rosters with Podiums have this group of Players played on together?


## Objectives

1. Review the existing REST MCP endpoints to understand the existing functionality and data available
2. Review the model schemas in the documentation under AGENTS/
2. Closely analyze the example questions in the above section and think very hard about different ways to leverage the model schema relationships in question to query the data to answer the question.
3. Think about if it's possible to answer the question using API calls. If so, how many calls?
4. How much more efficient would a SQL query be?
5. Also consider if some change to the REST API project would greatly reduce complexity or increase efficiency. We would prefer adding or updating an MCP Tool, but if a small change could provide major efficiency gains on the MCP side, document the requested change in AGENTS/REST_UPDATE_REQUEST.md 
5. Add tests for all newly written code

## Success Critera
* Make sure to not provide any SQL query tools that can be accomplished with existing tools calling the REST API
* Ignore anything related to Messages, Utils and Users
* Do not cover any queries related to "me" or "my X" as the User of the chat client is not the same kind of User as found in the model schemas.
* We prioritize making REST API tool calls over SQL queries, as it retains business logic, pagination and filtering