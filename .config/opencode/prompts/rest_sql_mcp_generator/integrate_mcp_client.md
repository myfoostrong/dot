# Integrating a FastMCP Client

You are an expert Python backend and Model Context Protocol (MCP) architect tasked with establishing complete tool coverage with the supporting REST API

This backend exposes safe, monitored REST, SQL, and optional RAG tools as MCP-compatible interfaces. It does **not** perform LLM inference — external clients (e.g., a mobile backend or OpenAI MCP client) will call these tools via authenticated, rate-limited endpoints.

---

## Context

You are provided:
- An existing **FastMCP Server Project** in the current directory
- Other relevant documentation in @AGENTS/
- An **OpenAPI JSON** specification: @AGENTS/squad-api.json

---

## Objectives
* Incorporate an MCP Client which takes a URL base from an env var to specify the backend server it communicates with
* This MCP server should be integrated into the process of prompting the LLM with User input, allowing the LLM to query paintball competition data related to the user's query
* We plan to use OpenRouter for LLM hosting
* Think hard to decide whether to use the FastMCP MCP client, Anthropic SDK client, or a combination of the two.

Below you will find the documentation provided by FastMCP for setting up MCP clients

---

# The FastMCP Client

> Programmatic client for interacting with MCP servers through a well-typed, Pythonic interface.

export const VersionBadge = ({version}) => {
  return <code className="version-badge-container">
            <p className="version-badge">
                <span className="version-badge-label">New in version:</span> 
                <code className="version-badge-version">{version}</code>
            </p>
        </code>;
};

<VersionBadge version="2.0.0" />

The central piece of MCP client applications is the `fastmcp.Client` class. This class provides a **programmatic interface** for interacting with any Model Context Protocol (MCP) server, handling protocol details and connection management automatically.

The FastMCP Client is designed for deterministic, controlled interactions rather than autonomous behavior, making it ideal for:

* **Testing MCP servers** during development
* **Building deterministic applications** that need reliable MCP interactions
* **Creating the foundation for agentic or LLM-based clients** with structured, type-safe operations

All client operations require using the `async with` context manager for proper connection lifecycle management.

<Note>
  This is not an agentic client - it requires explicit function calls and provides direct control over all MCP operations. Use it as a building block for higher-level systems.
</Note>

## Creating a Client

Creating a client is straightforward. You provide a server source and the client automatically infers the appropriate transport mechanism.

```python  theme={null}
import asyncio
from fastmcp import Client, FastMCP

# In-memory server (ideal for testing)
server = FastMCP("TestServer")
client = Client(server)

# HTTP server
client = Client("https://example.com/mcp")

# Local Python script
client = Client("my_mcp_server.py")

async def main():
    async with client:
        # Basic server interaction
        await client.ping()
        
        # List available operations
        tools = await client.list_tools()
        resources = await client.list_resources()
        prompts = await client.list_prompts()
        
        # Execute operations
        result = await client.call_tool("example_tool", {"param": "value"})
        print(result)

asyncio.run(main())
```

## Client-Transport Architecture

The FastMCP Client separates concerns between protocol and connection:

* **`Client`**: Handles MCP protocol operations (tools, resources, prompts) and manages callbacks
* **`Transport`**: Establishes and maintains the connection (WebSockets, HTTP, Stdio, in-memory)

### Transport Inference

The client automatically infers the appropriate transport based on the input:

1. **`FastMCP` instance** → In-memory transport (perfect for testing)
2. **File path ending in `.py`** → Python Stdio transport
3. **File path ending in `.js`** → Node.js Stdio transport
4. **URL starting with `http://` or `https://`** → HTTP transport
5. **`MCPConfig` dictionary** → Multi-server client

```python  theme={null}
from fastmcp import Client, FastMCP

# Examples of transport inference
client_memory = Client(FastMCP("TestServer"))
client_script = Client("./server.py") 
client_http = Client("https://api.example.com/mcp")
```

<Tip>
  For testing and development, always prefer the in-memory transport by passing a `FastMCP` server directly to the client. This eliminates network complexity and separate processes.
</Tip>

## Configuration-Based Clients

<VersionBadge version="2.4.0" />

Create clients from MCP configuration dictionaries, which can include multiple servers. While there is no official standard for MCP configuration format, FastMCP follows established conventions used by tools like Claude Desktop.

### Configuration Format

```python  theme={null}
config = {
    "mcpServers": {
        "server_name": {
            # Remote HTTP/SSE server
            "transport": "http",  # or "sse" 
            "url": "https://api.example.com/mcp",
            "headers": {"Authorization": "Bearer token"},
            "auth": "oauth"  # or bearer token string
        },
        "local_server": {
            # Local stdio server
            "transport": "stdio",
            "command": "python",
            "args": ["./server.py", "--verbose"],
            "env": {"DEBUG": "true"},
            "cwd": "/path/to/server",
        }
    }
}
```

### Multi-Server Example

```python  theme={null}
config = {
    "mcpServers": {
        "weather": {"url": "https://weather-api.example.com/mcp"},
        "assistant": {"command": "python", "args": ["./assistant_server.py"]}
    }
}

client = Client(config)

async with client:
    # Tools are prefixed with server names
    weather_data = await client.call_tool("weather_get_forecast", {"city": "London"})
    response = await client.call_tool("assistant_answer_question", {"question": "What's the capital of France?"})
    
    # Resources use prefixed URIs
    icons = await client.read_resource("weather://weather/icons/sunny")
    templates = await client.read_resource("resource://assistant/templates/list")
```

## Connection Lifecycle

The client operates asynchronously and uses context managers for connection management:

```python  theme={null}
async def example():
    client = Client("my_mcp_server.py")
    
    # Connection established here
    async with client:
        print(f"Connected: {client.is_connected()}")
        
        # Make multiple calls within the same session
        tools = await client.list_tools()
        result = await client.call_tool("greet", {"name": "World"})
        
    # Connection closed automatically here
    print(f"Connected: {client.is_connected()}")
```

## Operations

FastMCP clients can interact with several types of server components:

### Tools

Tools are server-side functions that the client can execute with arguments.

```python  theme={null}
async with client:
    # List available tools
    tools = await client.list_tools()
    
    # Execute a tool
    result = await client.call_tool("multiply", {"a": 5, "b": 3})
    print(result.data)  # 15
```

See [Tools](/clients/tools) for detailed documentation.

### Resources

Resources are data sources that the client can read, either static or templated.

```python  theme={null}
async with client:
    # List available resources
    resources = await client.list_resources()
    
    # Read a resource
    content = await client.read_resource("file:///config/settings.json")
    print(content[0].text)
```

See [Resources](/clients/resources) for detailed documentation.

### Prompts

Prompts are reusable message templates that can accept arguments.

```python  theme={null}
async with client:
    # List available prompts
    prompts = await client.list_prompts()
    
    # Get a rendered prompt
    messages = await client.get_prompt("analyze_data", {"data": [1, 2, 3]})
    print(messages.messages)
```

See [Prompts](/clients/prompts) for detailed documentation.

### Server Connectivity

Use `ping()` to verify the server is reachable:

```python  theme={null}
async with client:
    await client.ping()
    print("Server is reachable")
```

## Client Configuration

Clients can be configured with additional handlers and settings for specialized use cases.

### Callback Handlers

The client supports several callback handlers for advanced server interactions:

```python  theme={null}
from fastmcp import Client
from fastmcp.client.logging import LogMessage

async def log_handler(message: LogMessage):
    print(f"Server log: {message.data}")

async def progress_handler(progress: float, total: float | None, message: str | None):
    print(f"Progress: {progress}/{total} - {message}")

async def sampling_handler(messages, params, context):
    # Integrate with your LLM service here
    return "Generated response"

client = Client(
    "my_mcp_server.py",
    log_handler=log_handler,
    progress_handler=progress_handler,
    sampling_handler=sampling_handler,
    timeout=30.0
)
```

The `Client` constructor accepts several configuration options:

* `transport`: Transport instance or source for automatic inference
* `log_handler`: Handle server log messages
* `progress_handler`: Monitor long-running operations
* `sampling_handler`: Respond to server LLM requests
* `roots`: Provide local context to servers
* `timeout`: Default timeout for requests (in seconds)

### Transport Configuration

For detailed transport configuration (headers, authentication, environment variables), see the [Transports](/clients/transports) documentation.

## Next Steps

Explore the detailed documentation for each operation type:

### Core Operations

* **[Tools](/clients/tools)** - Execute server-side functions and handle results
* **[Resources](/clients/resources)** - Access static and templated resources
* **[Prompts](/clients/prompts)** - Work with message templates and argument serialization

### Advanced Features

* **[Logging](/clients/logging)** - Handle server log messages
* **[Progress](/clients/progress)** - Monitor long-running operations
* **[Sampling](/clients/sampling)** - Respond to server LLM requests
* **[Roots](/clients/roots)** - Provide local context to servers

### Connection Details

* **[Transports](/clients/transports)** - Configure connection methods and parameters
* **[Authentication](/clients/auth/oauth)** - Set up OAuth and bearer token authentication

<Tip>
  The FastMCP Client is designed as a foundational tool. Use it directly for deterministic operations, or build higher-level agentic systems on top of its reliable, type-safe interface.
</Tip>

---




# Client Transports

> Configure how FastMCP Clients connect to and communicate with servers.

export const VersionBadge = ({version}) => {
  return <code className="version-badge-container">
            <p className="version-badge">
                <span className="version-badge-label">New in version:</span> 
                <code className="version-badge-version">{version}</code>
            </p>
        </code>;
};

<VersionBadge version="2.0.0" />

The FastMCP `Client` communicates with MCP servers through transport objects that handle the underlying connection mechanics. While the client can automatically select a transport based on what you pass to it, instantiating transports explicitly gives you full control over configuration—environment variables, authentication, session management, and more.

Think of transports as configurable adapters between your client code and MCP servers. Each transport type handles a different communication pattern: subprocesses with pipes, HTTP connections, or direct in-memory calls.

## Choosing the Right Transport

* **Use [STDIO Transport](#stdio-transport)** when you need to run local MCP servers with full control over their environment and lifecycle
* **Use [Remote Transports](#remote-transports)** when connecting to production services or shared MCP servers running independently
* **Use [In-Memory Transport](#in-memory-transport)** for testing FastMCP servers without subprocess or network overhead
* **Use [MCP JSON Configuration](#mcp-json-configuration-transport)** when you need to connect to multiple servers defined in configuration files

## STDIO Transport

STDIO (Standard Input/Output) transport communicates with MCP servers through subprocess pipes. This is the standard mechanism used by desktop clients like Claude Desktop and is the primary way to run local MCP servers.

### The Client Runs the Server

<Warning>
  **Critical Concept**: When using STDIO transport, your client actually launches and manages the server process. This is fundamentally different from network transports where you connect to an already-running server. Understanding this relationship is key to using STDIO effectively.
</Warning>

With STDIO transport, your client:

* Starts the server as a subprocess when you connect
* Manages the server's lifecycle (start, stop, restart)
* Controls the server's environment and configuration
* Communicates through stdin/stdout pipes

This architecture enables powerful local integrations but requires understanding environment isolation and process management.

### Environment Isolation

STDIO servers run in isolated environments by default. This is a security feature enforced by the MCP protocol to prevent accidental exposure of sensitive data.

When your client launches an MCP server:

* The server does NOT inherit your shell's environment variables
* API keys, paths, and other configuration must be explicitly passed
* The working directory and system paths may differ from your shell

To pass environment variables to your server, use the `env` parameter:

```python  theme={null}
from fastmcp import Client

# If your server needs environment variables (like API keys),
# you must explicitly pass them:
client = Client(
    "my_server.py",
    env={"API_KEY": "secret", "DEBUG": "true"}
)

# This won't work - the server runs in isolation:
# export API_KEY="secret"  # in your shell
# client = Client("my_server.py")  # server can't see API_KEY
```

### Basic Usage

To use STDIO transport, you create a transport instance with the command and arguments needed to run your server:

```python  theme={null}
from fastmcp.client.transports import StdioTransport

transport = StdioTransport(
    command="python",
    args=["my_server.py"]
)
client = Client(transport)
```

You can configure additional settings like environment variables, working directory, or command arguments:

```python  theme={null}
transport = StdioTransport(
    command="python",
    args=["my_server.py", "--verbose"],
    env={"LOG_LEVEL": "DEBUG"},
    cwd="/path/to/server"
)
client = Client(transport)
```

For convenience, the client can also infer STDIO transport from file paths, but this doesn't allow configuration:

```python  theme={null}
from fastmcp import Client

client = Client("my_server.py")  # Limited - no configuration options
```

### Environment Variables

Since STDIO servers don't inherit your environment, you need strategies for passing configuration. Here are two common approaches:

**Selective forwarding** passes only the variables your server actually needs:

```python  theme={null}
import os
from fastmcp.client.transports import StdioTransport

required_vars = ["API_KEY", "DATABASE_URL", "REDIS_HOST"]
env = {
    var: os.environ[var] 
    for var in required_vars 
    if var in os.environ
}

transport = StdioTransport(
    command="python",
    args=["server.py"],
    env=env
)
client = Client(transport)
```

**Loading from .env files** keeps configuration separate from code:

```python  theme={null}
from dotenv import dotenv_values
from fastmcp.client.transports import StdioTransport

env = dotenv_values(".env")
transport = StdioTransport(
    command="python",
    args=["server.py"],
    env=env
)
client = Client(transport)
```

### Session Persistence

STDIO transports maintain sessions across multiple client contexts by default (`keep_alive=True`). This improves performance by reusing the same subprocess for multiple connections, but can be controlled when you need isolation.

By default, the subprocess persists between connections:

```python  theme={null}
from fastmcp.client.transports import StdioTransport

transport = StdioTransport(
    command="python",
    args=["server.py"]
)
client = Client(transport)

async def efficient_multiple_operations():
    async with client:
        await client.ping()
    
    async with client:  # Reuses the same subprocess
        await client.call_tool("process_data", {"file": "data.csv"})
```

For complete isolation between connections, disable session persistence:

```python  theme={null}
transport = StdioTransport(
    command="python",
    args=["server.py"],
    keep_alive=False
)
client = Client(transport)
```

Use `keep_alive=False` when you need complete isolation (e.g., in test suites) or when server state could cause issues between connections.

### Specialized STDIO Transports

FastMCP provides convenience transports that are thin wrappers around `StdioTransport` with pre-configured commands:

* **`PythonStdioTransport`** - Uses `python` command for `.py` files
* **`NodeStdioTransport`** - Uses `node` command for `.js` files
* **`UvStdioTransport`** - Uses `uv` for Python packages (uses `env_vars` parameter)
* **`UvxStdioTransport`** - Uses `uvx` for Python packages (uses `env_vars` parameter)
* **`NpxStdioTransport`** - Uses `npx` for Node packages (uses `env_vars` parameter)

For most use cases, instantiate `StdioTransport` directly with your desired command. These specialized transports are primarily useful for client inference shortcuts.

## Remote Transports

Remote transports connect to MCP servers running as web services. This is a fundamentally different model from STDIO transports—instead of your client launching and managing a server process, you connect to an already-running service that manages its own environment and lifecycle.

### Streamable HTTP Transport

<VersionBadge version="2.3.0" />

Streamable HTTP is the recommended transport for production deployments, providing efficient bidirectional streaming over HTTP connections.

* **Class:** `StreamableHttpTransport`
* **Server compatibility:** FastMCP servers running with `mcp run --transport http`

The transport requires a URL and optionally supports custom headers for authentication and configuration:

```python  theme={null}
from fastmcp.client.transports import StreamableHttpTransport

# Basic connection
transport = StreamableHttpTransport(url="https://api.example.com/mcp")
client = Client(transport)

# With custom headers for authentication
transport = StreamableHttpTransport(
    url="https://api.example.com/mcp",
    headers={
        "Authorization": "Bearer your-token-here",
        "X-Custom-Header": "value"
    }
)
client = Client(transport)
```

For convenience, FastMCP also provides authentication helpers:

```python  theme={null}
from fastmcp.client.auth import BearerAuth

client = Client(
    "https://api.example.com/mcp",
    auth=BearerAuth("your-token-here")
)
```

### SSE Transport (Legacy)

Server-Sent Events transport is maintained for backward compatibility but is superseded by Streamable HTTP for new deployments.

* **Class:** `SSETransport`
* **Server compatibility:** FastMCP servers running with `mcp run --transport sse`

SSE transport supports the same configuration options as Streamable HTTP:

```python  theme={null}
from fastmcp.client.transports import SSETransport

transport = SSETransport(
    url="https://api.example.com/sse",
    headers={"Authorization": "Bearer token"}
)
client = Client(transport)
```

Use Streamable HTTP for new deployments unless you have specific infrastructure requirements for SSE.

## In-Memory Transport

In-memory transport connects directly to a FastMCP server instance within the same Python process. This eliminates both subprocess management and network overhead, making it ideal for testing and development.

* **Class:** `FastMCPTransport`

<Note>
  Unlike STDIO transports, in-memory servers have full access to your Python process's environment. They share the same memory space and environment variables as your client code—no isolation or explicit environment passing required.
</Note>

```python  theme={null}
from fastmcp import FastMCP, Client
import os

mcp = FastMCP("TestServer")

@mcp.tool
def greet(name: str) -> str:
    prefix = os.environ.get("GREETING_PREFIX", "Hello")
    return f"{prefix}, {name}!"

client = Client(mcp)

async with client:
    result = await client.call_tool("greet", {"name": "World"})
```

## MCP JSON Configuration Transport

<VersionBadge version="2.4.0" />

This transport supports the emerging MCP JSON configuration standard for defining multiple servers:

* **Class:** `MCPConfigTransport`

```python  theme={null}
config = {
    "mcpServers": {
        "weather": {
            "url": "https://weather.example.com/mcp",
            "transport": "http"
        },
        "assistant": {
            "command": "python",
            "args": ["./assistant.py"],
            "env": {"LOG_LEVEL": "INFO"}
        }
    }
}

client = Client(config)

async with client:
    # Tools are namespaced by server
    weather = await client.call_tool("weather_get_forecast", {"city": "NYC"})
    answer = await client.call_tool("assistant_ask", {"question": "What?"})
```

### Tool Transformation with FastMCP and MCPConfig

FastMCP supports basic tool transformations to be defined alongside the MCP Servers in the MCPConfig file.

```python  theme={null}
config = {
    "mcpServers": {
        "weather": {
            "url": "https://weather.example.com/mcp",
            "transport": "http",
            "tools": { }   #  <--- This is the tool transformation section
        }
    }
}
```

With these transformations, you can transform (change) the name, title, description, tags, enablement, and arguments of a tool.

For each argument the tool takes, you can transform (change) the name, description, default, visibility, whether it's required, and you can provide example values.

In the following example, we're transforming the `weather_get_forecast` tool to only retrieve the weather for `Miami` and hiding the `city` argument from the client.

```python  theme={null}
tool_transformations = {
    "weather_get_forecast": {
        "name": "miami_weather",
        "description": "Get the weather for Miami",
        "arguments": {
            "city": {
                "name": "city",
                "default": "Miami",
                "hide": True,
            }
        }
    }
}

config = {
    "mcpServers": {
        "weather": {
            "url": "https://weather.example.com/mcp",
            "transport": "http",
            "tools": tool_transformations
        }
    }
}
```

#### Allowlisting and Blocklisting Tools

Tools can be allowlisted or blocklisted from the client by applying `tags` to the tools on the server. In the following example, we're allowlisting only tools marked with the `forecast` tag, all other tools will be unavailable to the client.

```python  theme={null}
tool_transformations = {
    "weather_get_forecast": {
        "enabled": True,
        "tags": ["forecast"]
    }
}


config = {
    "mcpServers": {
        "weather": {
            "url": "https://weather.example.com/mcp",
            "transport": "http",
            "tools": tool_transformations,
            "include_tags": ["forecast"]
        }
    }
}
```


----

Now below you'll find the documentation describing using MCP servers with OpenRouter hosted LLM's.

---
title: Using MCP Servers with OpenRouter
subtitle: Use MCP Servers with OpenRouter
headline: Using MCP Servers with OpenRouter
canonical-url: 'https://openrouter.ai/docs/use-cases/mcp-servers'
'og:site_name': OpenRouter Documentation
'og:title': Using MCP Servers with OpenRouter
'og:description': Learn how to use MCP Servers with OpenRouter
'og:image':
  type: url
  value: >-
    https://openrouter.ai/dynamic-og?title=Using%20MCP%20Servers%20with%20OpenRouter&description=Learn%20how%20to%20use%20MCP%20Servers%20with%20OpenRouter
'og:image:width': 1200
'og:image:height': 630
'twitter:card': summary_large_image
'twitter:site': '@OpenRouterAI'
noindex: false
nofollow: false
---

MCP servers are a popular way of providing LLMs with tool calling abilities, and are an alternative to using OpenAI-compatible tool calling.

By converting MCP (Anthropic) tool definitions to OpenAI-compatible tool definitions, you can use MCP servers with OpenRouter.

In this example, we'll use [Anthropic's MCP client SDK](https://github.com/modelcontextprotocol/python-sdk?tab=readme-ov-file#writing-mcp-clients) to interact with the File System MCP, all with OpenRouter under the hood.

<Warning>
  Note that interacting with MCP servers is more complex than calling a REST
  endpoint. The MCP protocol is stateful and requires session management. The
  example below uses the MCP client SDK, but is still somewhat complex.
</Warning>

First, some setup. In order to run this you will need to pip install the packages, and create a `.env` file with OPENAI_API_KEY set. This example also assumes the directory `/Applications` exists.

```python
import asyncio
from typing import Optional
from contextlib import AsyncExitStack

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

from openai import OpenAI
from dotenv import load_dotenv
import json

load_dotenv()  # load environment variables from .env

MODEL = "anthropic/claude-3-7-sonnet"

SERVER_CONFIG = {
    "command": "npx",
    "args": ["-y",
              "@modelcontextprotocol/server-filesystem",
              f"/Applications/"],
    "env": None
}
```

Next, our helper function to convert MCP tool definitions to OpenAI tool definitions:

```python

def convert_tool_format(tool):
    converted_tool = {
        "type": "function",
        "function": {
            "name": tool.name,
            "description": tool.description,
            "parameters": {
                "type": "object",
                "properties": tool.inputSchema["properties"],
                "required": tool.inputSchema["required"]
            }
        }
    }
    return converted_tool

```

And, the MCP client itself; a regrettable ~100 lines of code. Note that the SERVER_CONFIG is hard-coded into the client, but of course could be parameterized for other MCP servers.

```python
class MCPClient:
    def __init__(self):
        self.session: Optional[ClientSession] = None
        self.exit_stack = AsyncExitStack()
        self.openai = OpenAI(
            base_url="https://openrouter.ai/api/v1"
        )

    async def connect_to_server(self, server_config):
        server_params = StdioServerParameters(**server_config)
        stdio_transport = await self.exit_stack.enter_async_context(stdio_client(server_params))
        self.stdio, self.write = stdio_transport
        self.session = await self.exit_stack.enter_async_context(ClientSession(self.stdio, self.write))

        await self.session.initialize()

        # List available tools from the MCP server
        response = await self.session.list_tools()
        print("\nConnected to server with tools:", [tool.name for tool in response.tools])

        self.messages = []

    async def process_query(self, query: str) -> str:

        self.messages.append({
            "role": "user",
            "content": query
        })

        response = await self.session.list_tools()
        available_tools = [convert_tool_format(tool) for tool in response.tools]

        response = self.openai.chat.completions.create(
            model=MODEL,
            tools=available_tools,
            messages=self.messages
        )
        self.messages.append(response.choices[0].message.model_dump())

        final_text = []
        content = response.choices[0].message
        if content.tool_calls is not None:
            tool_name = content.tool_calls[0].function.name
            tool_args = content.tool_calls[0].function.arguments
            tool_args = json.loads(tool_args) if tool_args else {}

            # Execute tool call
            try:
                result = await self.session.call_tool(tool_name, tool_args)
                final_text.append(f"[Calling tool {tool_name} with args {tool_args}]")
            except Exception as e:
                print(f"Error calling tool {tool_name}: {e}")
                result = None

            self.messages.append({
                "role": "tool",
                "tool_call_id": content.tool_calls[0].id,
                "name": tool_name,
                "content": result.content
            })

            response = self.openai.chat.completions.create(
                model=MODEL,
                max_tokens=1000,
                messages=self.messages,
            )

            final_text.append(response.choices[0].message.content)
        else:
            final_text.append(content.content)

        return "\n".join(final_text)

    async def chat_loop(self):
        """Run an interactive chat loop"""
        print("\nMCP Client Started!")
        print("Type your queries or 'quit' to exit.")

        while True:
            try:
                query = input("\nQuery: ").strip()
                result = await self.process_query(query)
                print("Result:")
                print(result)

            except Exception as e:
                print(f"Error: {str(e)}")

    async def cleanup(self):
        await self.exit_stack.aclose()

async def main():
    client = MCPClient()
    try:
        await client.connect_to_server(SERVER_CONFIG)
        await client.chat_loop()
    finally:
        await client.cleanup()

if __name__ == "__main__":
    import sys
    asyncio.run(main())
```

Assembling all of the above code into mcp-client.py, you get a client that behaves as follows (some outputs truncated for brevity):

```bash
% python mcp-client.py

Secure MCP Filesystem Server running on stdio
Allowed directories: [ '/Applications' ]

Connected to server with tools: ['read_file', 'read_multiple_files', 'write_file'...]

MCP Client Started!
Type your queries or 'quit' to exit.

Query: Do I have microsoft office installed?

Result:
[Calling tool list_allowed_directories with args {}]
I can check if Microsoft Office is installed in the Applications folder:

Query: continue

Result:
[Calling tool search_files with args {'path': '/Applications', 'pattern': 'Microsoft'}]
Now let me check specifically for Microsoft Office applications:

Query: continue

Result:
I can see from the search results that Microsoft Office is indeed installed on your system.
The search found the following main Microsoft Office applications:

1. Microsoft Excel - /Applications/Microsoft Excel.app
2. Microsoft PowerPoint - /Applications/Microsoft PowerPoint.app
3. Microsoft Word - /Applications/Microsoft Word.app
4. OneDrive - /Applications/OneDrive.app (which includes Microsoft SharePoint integration)
```
