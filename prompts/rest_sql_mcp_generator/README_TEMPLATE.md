# 🧩 Hybrid MCP Backend — README Template

## Overview
This repository implements a **Hybrid MCP Backend** that integrates:
- Existing REST API (via auto-generated tools from its OpenAPI spec)
- Read-only SQL database access (for analytical queries)
- Optional RAG (Retrieval-Augmented Generation) layer for unstructured data
- LLM orchestration via Model Context Protocol (MCP)

The result is a secure, modular system that allows an LLM to reason over both structured and unstructured data without directly exposing the database or legacy backend.

---

## 🏗 Architecture

```
LLM  ⇄  MCP Backend  ⇄  REST API
                 ⇄  SQL (read-only)
                 ⇄  Vector Store / RAG (optional)
```

### Core Components
| Module | Purpose |
|---------|----------|
| `main.py` | FastAPI app entrypoint; registers routes for `/mcp/*` and `/chat` |
| `config.py` | Loads environment variables for DB + API |
| `llm_client.py` | Handles LLM communication and tool orchestration |
| `tools/rest_tools.py` | Auto-generated REST API wrappers |
| `tools/sql_tools.py` | Parameterized SQL query tools |
| `tools/rag_tools.py` | (Optional) document retrieval and embedding search |
| `utils/db.py` | Safe SQL connection helpers |
| `utils/api_client.py` | HTTP client for calling the existing API |
| `tests/` | Unit tests for each layer |

---

## ⚙️ Setup

### 1. Clone and Install
```bash
git clone <repo-url>
cd mcp_backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 2. Configure Environment
Create a `.env` file or edit `config.py`:

```env
API_BASE_URL=https://your-existing-api.com
API_KEY=your_api_key_here

DB_URL=sqlite:///./data.db
OPENAI_API_KEY=your_openai_key_here

ENABLE_RAG=false
VECTOR_STORE_PATH=./vectors/
```

---

## 🚀 Running the Server
```bash
uvicorn main:app --reload --port 8080
```

Server will start on **http://localhost:8080**.

---

## 🧠 Using the Chat Endpoint

Send user messages that will be processed by the LLM and routed to tools as needed.

```bash
curl -X POST http://localhost:8080/chat   -H "Content-Type: application/json"   -d '{"message": "Show me the top 10 customers by revenue"}'
```

Example response:
```json
{
  "response": "Here are the top 10 customers by total revenue.",
  "data": [...]
}
```

---

## 🧰 Using MCP Tool Endpoints

Each MCP tool is exposed at `/mcp/<tool_name>`.

### Example: REST API Wrapper
```bash
curl -X POST http://localhost:8080/mcp/get_customer   -H "Content-Type: application/json"   -d '{"customer_id": 42}'
```

### Example: SQL Query Tool
```bash
curl -X POST http://localhost:8080/mcp/get_top_customers   -H "Content-Type: application/json"   -d '{"limit": 5}'
```

---

## 🧩 Adding New Tools

To define a new REST or SQL tool:

1. Add a new function under the correct module (`rest_tools.py` or `sql_tools.py`).
2. Define a Pydantic model for inputs.
3. Register the tool in `llm_client.py`.

Example:
```python
@app.post("/mcp/get_order_summary")
def get_order_summary(input: OrderSummaryInput):
    query = "SELECT ... FROM orders WHERE order_id = ?"
    rows = db.query(query, (input.order_id,))
    return {"summary": rows[0]}
```

---

## 🔒 Security Considerations
- SQL tools are **read-only** (`SELECT` only).  
- All inputs validated via **Pydantic models**.  
- Secrets and keys stored in `.env` or system environment.  
- REST calls use **API keys** or bearer tokens.  
- Rate limiting recommended for production deployments.

---

## 🧪 Testing
```bash
pytest -v
```

Includes tests for:
- REST tool wrappers  
- SQL tool correctness  
- LLM orchestration logic  
- Chat flow integration

---

## 🐳 Optional: Docker Usage

```bash
docker build -t mcp-backend .
docker run -p 8080:8080 --env-file .env mcp-backend
```

---

## 📚 References
- [FastAPI Docs](https://fastapi.tiangolo.com/)  
- [OpenAI API Reference](https://platform.openai.com/docs/)  
- [Model Context Protocol](https://github.com/modelcontextprotocol)  

---

## 📄 License
MIT License — use freely with attribution.
