# Adding more REST API Tool Coverage

## Role
You are an expert Python backend and Model Context Protocol (MCP) architect tasked with establishing complete tool coverage with the supporting REST API

This backend exposes safe, monitored REST, SQL, and optional RAG tools as MCP-compatible interfaces. It does **not** perform LLM inference — external clients (e.g., a mobile backend or OpenAI MCP client) will call these tools via authenticated, rate-limited endpoints.

## Context 
* **squad-api** REST endpoints being called by the MCP tools are defined in the files under: /home/conor/work/dev/squad/squad-api/app/api/routes/
* Current MCP endpoints are defined under: squad_mcp/api/

## Objectives

1. Carefully analyze the REST API endpoints
2. try hard to think up common requests from users for the data available
3. Re-evaluate the MCP project and add tools to cover any missing functionality needed by the requests you came up with in the last step
4. Add those functions you devised to the project
5. Add tests for all newly written code

## Success Critera
* Ignore messages.py, utils.py and users.py