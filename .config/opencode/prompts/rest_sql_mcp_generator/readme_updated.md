# 🧩 FastMCP Tool Server — Production README

## Overview
This project implements a **production-grade, headless MCP Tool Server** using **FastMCP**, **FastAPI**, and **uv**. It exposes REST, SQL, and optional RAG tools as secure, authenticated, rate-limited, and fully observable MCP-compatible endpoints for LLM clients.

The server does **not** perform inference; it acts as a **secure, monitored data access layer** between your LLM backend and existing APIs/databases.

---

## 🧱 Architecture

```
Mobile App ⇄ Mobile Backend (LLM + Auth) ⇄ MCP Tool Server ⇄ REST API / SQL DB
                                              ↓ Logs (JSON)
                                              ↓ Metrics (Prometheus)
                                          Observability Stack
```

| Component | Role |
|-----------|------|
| **Mobile Backend** | Hosts the LLM, manages conversations, calls MCP tools with Bearer token |
| **FastMCP Tool Server** | Validates requests, provides structured data access, enforces rate limits & security |
| **REST API / SQL DB** | System of record; tool server is read-only |
| **Observability Stack** | Receives logs, metrics, traces; used for debugging and alerting |

---

## ⚙️ Quick Start

### 1. Install uv
Follow the [uv installation guide](https://docs.astral.sh/uv/getting-started/):

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 2. Clone and Initialize
```bash
git clone <repo-url>
cd fastmcp_tool_server
uv sync
```

### 3. Configure Environment
Copy `.env.example` to `.env` and update:

```env
# API Configuration
API_BASE_URL=https://api.example.com
API_TIMEOUT_SECONDS=10
API_MAX_RETRIES=3

# Database
DB_URL=postgresql://user:password@localhost:5432/dbname
DB_POOL_SIZE=5
DB_POOL_MAX_OVERFLOW=10
DB_POOL_RECYCLE_SECONDS=3600

# Authentication
API_KEY_PRIMARY=sk_prod_xxxxxxxxxxxx
API_KEY_SECONDARY=sk_prod_yyyyyyyyyyyy

# Rate Limiting
RATE_LIMIT_RPM=100  # requests per minute

# Features
ENABLE_RAG=false
LOG_LEVEL=INFO
ENVIRONMENT=production  # development, staging, production
```

### 4. Run the Server
```bash
uv run fastmcp_tool_server.main
```

The server will start at `http://localhost:8000`:
- 📖 **API Docs**: http://localhost:8000/docs (Swagger UI)
- 🏥 **Health Check**: http://localhost:8000/health
- 📊 **Metrics**: http://localhost:8000/metrics

---

## 🔐 Security

### Authentication
All tool endpoints require Bearer token authentication:

```bash
curl -H "Authorization: Bearer sk_prod_xxxxxxxxxxxx" \
  http://localhost:8000/v1/mcp/get_customer \
  -d '{"customer_id": 42}'
```

Valid API keys are listed in `.env` (rotate quarterly minimum).

### Rate Limiting
- **100 requests/minute** per API key (configurable).
- Exceeding the limit returns HTTP 429 with `Retry-After` header.
- Response:
  ```json
  {
    "error": "Rate limit exceeded",
    "retry_after_seconds": 60,
    "request_id": "uuid-here"
  }
  ```

### Input Validation
- All tool inputs validated via Pydantic with strict bounds.
- Example: SQL `limit` parameter capped at 1000 to prevent runaway queries.
- Invalid inputs return HTTP 400 with clear error messages.

### SQL Injection Prevention
- **Only parameterized queries** allowed (`:named` or `?` placeholders).
- No f-strings or string concatenation in SQL.
- Linter (`ruff`) enforces this automatically.
- Example:
  ```python
  # ✅ SAFE
  query_db("SELECT * FROM users WHERE id = :id", {"id": user_id})
  
  # ❌ NOT ALLOWED
  query_db(f"SELECT * FROM users WHERE id = {user_id}")
  ```

### Error Handling
- All errors return JSON without stack traces or internal details.
- Full stack traces logged server-side with request ID for tracing.
- Example error response:
  ```json
  {
    "error": "Customer not found",
    "status": "not_found",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
  ```

### Secrets Management
- API keys and database credentials loaded from `.env` (never committed).
- For production, integrate with:
  - AWS Secrets Manager
  - HashiCorp Vault
  - Azure Key Vault
- Rotate keys quarterly and immediately on compromise.

---

## 📊 Observability

### Structured Logging
All operations logged as JSON with request IDs for tracing:

```json
{
  "timestamp": "2025-01-15T10:30:45.123Z",
  "level": "INFO",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "tool_name": "get_customer",
  "user_id": "user_123",
  "latency_ms": 250,
  "message": "Tool executed successfully"
}
```

**View logs:**
```bash
# Docker
docker logs <container_id> | jq '.'

# Local dev
tail -f /tmp/fastmcp.log | jq '.'
```

### Health Checks
```bash
curl http://localhost:8000/health
```

Response:
```json
{
  "status": "healthy",
  "database": "connected",
  "upstream_api": "responding",
  "memory_usage_percent": 65,
  "timestamp": "2025-01-15T10:30:45.123Z"
}
```

Health checks verify:
- ✅ Database connectivity (`SELECT 1` with 5s timeout)
- ✅ Upstream REST API responsiveness
- ✅ Memory usage (<80% of available heap)

### Prometheus Metrics
Expose metrics for your monitoring stack:

```bash
curl http://localhost:8000/metrics
```

Tracked metrics:
- `tool_calls_total{tool_name, status}`: Tool invocation counts
- `tool_duration_seconds{tool_name}`: Latency (p50, p95, p99)
- `http_requests_total{endpoint, status_code}`: Request counts
- `api_errors_total{source, status_code}`: Upstream errors
- `db_query_duration_seconds{query_name}`: SQL latency
- `rate_limit_hits_total{client_id}`: Rate limit violations

**Integration example (Prometheus config):**
```yaml
scrape_configs:
  - job_name: 'fastmcp_tool_server'
    static_configs:
      - targets: ['localhost:8000']
    metrics_path: '/metrics'
```

---

## 🚀 Usage Examples

### REST Tool Example
Fetch customer details:

```bash
curl -X POST http://localhost:8000/v1/mcp/get_customer \
  -H "Authorization: Bearer sk_prod_xxxx" \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 42}'
```

Response:
```json
{
  "id": 42,
  "name": "Acme Corp",
  "email": "contact@acme.com"
}
```

### SQL Tool Example
Get top customers with pagination:

```bash
curl -X POST http://localhost:8000/v1/mcp/get_top_customers \
  -H "Authorization: Bearer sk_prod_xxxx" \
  -H "Content-Type: application/json" \
  -d '{"limit": 10, "offset": 0}'
```

Response:
```json
{
  "customers": [
    {"name": "Acme Corp", "total": 150000},
    {"name": "Beta Inc", "total": 120000}
  ],
  "limit": 10,
  "offset": 0,
  "total_count": 243
}
```

---

## 🧰 Adding New Tools

### Step 1: Define Input Model
```python
# fastmcp_tool_server/tools/rest_tools.py
from pydantic import BaseModel, Field

class GetOrdersInput(BaseModel):
    customer_id: int = Field(..., gt=0, description="Customer ID")
    status: str = Field(default="all", description="Filter by status")
```

### Step 2: Register Tool with Error Handling
```python
from fastmcp import tool
from utils.api_client import call_api_with_retries

@tool("get_orders", description="Fetch orders for a customer")
def get_orders(input: GetOrdersInput) -> dict:
    try:
        response = call_api_with_retries(
            method="GET",
            url=f"{API_BASE}/customers/{input.customer_id}/orders",
            params={"status": input.status},
            timeout=10,
            max_retries=3
        )
        return response.json()
    except httpx.TimeoutException:
        logger.error("API timeout", extra={"tool": "get_orders", "request_id": get_request_id()})
        return {"error": "API timeout", "status": "retry"}
    except httpx.HTTPStatusError as e:
        if e.response.status_code >= 500:
            return {"error": "Upstream error", "status": "retry"}
        return {"error": "Not found", "status": "not_found"}
```

### Step 3: Test It
```bash
# See new tool in /docs
curl http://localhost:8000/docs

# Call it
curl -X POST http://localhost:8000/v1/mcp/get_orders \
  -H "Authorization: Bearer sk_prod_xxxx" \
  -d '{"customer_id": 42, "status": "completed"}'
```

---

## 🧪 Testing

Run all tests:
```bash
uv run pytest
```

Run with coverage:
```bash
uv run pytest --cov=fastmcp_tool_server --cov-report=html
```

Test categories:
- **Unit tests**: Mock external dependencies, test tool logic.
- **Integration tests**: Test error handling, retries, rate limiting.
- **Security tests**: SQL injection, auth bypass, input bounds.

Example test:
```python
# tests/test_rest_tools.py
import pytest
from unittest.mock import patch
import httpx

@pytest.mark.asyncio
async def test_get_customer_timeout():
    """Verify timeout is handled gracefully"""
    with patch("httpx.get") as mock_get:
        mock_get.side_effect = httpx.TimeoutException("Timeout")
        result = get_customer(GetCustomerInput(customer_id=42))
        assert result["status"] == "retry"
        assert "error" in result

@pytest.mark.asyncio
async def test_sql_injection_prevented():
    """Verify parameterized queries are enforced"""
    with pytest.raises(ValueError):
        query_db("SELECT * FROM users WHERE id = 42")  # Not parameterized
```

---

## 🐳 Docker Deployment

### Build Image
```bash
docker build -t fastmcp-tool-server:latest .
```

### Run Container
```bash
docker run -d \
  --name fastmcp \
  -p 8000:8000 \
  --env-file .env \
  -e LOG_LEVEL=INFO \
  --health-cmd="curl -f http://localhost:8000/health" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  fastmcp-tool-server:latest
```

### Docker Compose (with monitoring stack)
```yaml
version: '3.8'

services:
  fastmcp:
    build: .
    ports:
      - "8000:8000"
    env_file: .env
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    depends_on:
      postgres:
        condition: service_healthy

  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus

volumes:
  postgres_data:
  prometheus_data:
```

---

## 📈 Scaling & Performance

### Horizontal Scaling
The server is stateless and can run multiple instances:

```bash
# Start 3 instances behind a load balancer
docker run -d --name fastmcp-1 -p 8001:8000 fastmcp-tool-server
docker run -d --name fastmcp-2 -p 8002:8000 fastmcp-tool-server
docker run -d --name fastmcp-3 -p 8003:8000 fastmcp-tool-server
```

**Load balancer config (nginx):**
```nginx
upstream fastmcp {
    server localhost:8001;
    server localhost:8002;
    server localhost:8003;
}

server {
    listen 80;
    location / {
        proxy_pass http://fastmcp;
        proxy_set_header Authorization $http_authorization;
    }
}
```

### Connection Pooling
Database and HTTP client connections are pooled to minimize overhead:

```env
# SQL connection pooling
DB_POOL_SIZE=5              # Connections per process
DB_POOL_MAX_OVERFLOW=10     # Additional temp connections
DB_POOL_RECYCLE_SECONDS=3600  # Recycle stale connections

# HTTP client pooling
API_MAX_CONNECTIONS=10
API_MAX_KEEPALIVE=30
```

### Caching (Optional)
For frequently accessed data, consider Redis caching:

```python
# tools/rest_tools.py
import redis

cache = redis.Redis(host='localhost', port=6379, decode_responses=True)

@tool("get_customer", description="Fetch customer (cached)")
def get_customer(input: GetCustomerInput) -> dict:
    cache_key = f"customer:{input.customer_id}"
    cached = cache.get(cache_key)
    if cached:
        return json.loads(cached)
    
    # Fetch from API
    result = call_api_with_retries(...)
    cache.setex(cache_key, 3600, json.dumps(result))  # Cache 1 hour
    return result
```

---

## 🔍 Monitoring & Alerting

### Set Up Monitoring
Recommended: Prometheus + Grafana + AlertManager

**Prometheus scrape config:**
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'fastmcp'
    static_configs:
      - targets: ['localhost:8000']
    metrics_path: '/metrics'
```

**Grafana Dashboard Queries:**
```promql
# Request rate (requests/sec)
rate(http_requests_total[1m])

# Error rate (%)
100 * rate(tool_calls_total{status="error"}[5m]) / rate(tool_calls_total[5m])

# P99 latency
histogram_quantile(0.99, tool_duration_seconds)

# Rate limit hits
rate(rate_limit_hits_total[1m])
```

### Critical Alerts
Configure alerts in AlertManager:

```yaml
groups:
  - name: fastmcp
    rules:
      - alert: HighErrorRate
        expr: 'rate(tool_calls_total{status="error"}[5m]) > 0.05'
        for: 5m
        annotations:
          summary: "Error rate > 5%"

      - alert: HighLatency
        expr: 'histogram_quantile(0.99, tool_duration_seconds) > 1'
        for: 5m
        annotations:
          summary: "P99 latency > 1 second"

      - alert: HealthCheckFailing
        expr: 'up{job="fastmcp"} == 0'
        for: 1m
        annotations:
          summary: "Health check endpoint not responding"
```

---

## 🛠️ Troubleshooting

### Server won't start
```bash
# Check logs
docker logs fastmcp 2>&1 | grep ERROR

# Verify environment variables
env | grep -E "API_|DB_|RATE_"

# Test database connection
psql $DB_URL -c "SELECT 1"
```

### Slow tool execution
```bash
# Check metrics
curl http://localhost:8000/metrics | grep tool_duration_seconds

# Review structured logs for slow queries
cat /tmp/fastmcp.log | jq 'select(.latency_ms > 1000)'

# Verify database indexes
psql $DB_URL -c "\d+ orders"
```

### Rate limiting issues
```bash
# Check current rate limit status
curl -X POST http://localhost:8000/v1/mcp/get_customer \
  -H "Authorization: Bearer sk_prod_xxxx" \
  -v

# Look for headers: X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset
```

### Authentication failures
```bash
# Test with invalid token
curl -H "Authorization: Bearer invalid" \
  http://localhost:8000/v1/mcp/get_customer

# Should return 401 Unauthorized

# Check logs for auth failures
cat /tmp/fastmcp.log | jq 'select(.level == "WARNING" and .message | contains("Invalid"))'
```

### SQL errors
```bash
# Check parameterized query usage (ruff should catch this)
ruff check --select=S608 fastmcp_tool_server/

# Test a query directly
psql $DB_URL -c "SELECT * FROM orders LIMIT 10"
```

---

## 🚢 Deployment Checklist

Before going to production, verify:

**Security**
- [ ] All endpoints require Bearer token authentication
- [ ] API keys rotated and stored securely (not in git)
- [ ] HTTPS enforced (SSL/TLS certificate)
- [ ] CORS policy configured appropriately
- [ ] SQL injection tests passing (ruff, pytest)

**Performance**
- [ ] Database connection pooling configured
- [ ] HTTP client timeouts set (default 10s)
- [ ] Rate limiting enabled (100 req/min per key)
- [ ] Caching enabled for frequently accessed data

**Observability**
- [ ] Structured logging enabled (JSON format)
- [ ] Prometheus metrics exposed and scraped
- [ ] Health check endpoint responding
- [ ] Request ID tracing working end-to-end

**Testing**
- [ ] Unit tests: 80%+ coverage
- [ ] Integration tests passing (timeouts, retries, errors)
- [ ] Security tests passing (injection, auth, bounds)
- [ ] Load tests show acceptable P99 latency (<1s)

**Operations**
- [ ] Docker image builds successfully
- [ ] Health check passes consistently
- [ ] Logs are readable and structured
- [ ] Monitoring and alerts configured
- [ ] Runbook written for common issues
- [ ] On-call rotation set up

---

## 📖 API Documentation

Once running, visit http://localhost:8000/docs for interactive API docs generated from tool schemas.

All tools include:
- **Description**: What the tool does
- **Parameters**: Input schema with validation rules
- **Example requests/responses**: Try it live

---

## 🔄 Updating Tools

### Non-Breaking Changes
Update tool logic directly; no versioning needed if input/output unchanged.

```bash
# Update code
vim fastmcp_tool_server/tools/rest_tools.py

# Restart server (stateless)
docker restart fastmcp

# Verify at /docs
curl http://localhost:8000/docs
```

### Breaking Changes
Create a new version-prefixed endpoint:

```python
# Old endpoint (deprecated)
@tool("get_customer_v1", deprecated=True)
def get_customer_v1(input: GetCustomerInputV1) -> dict:
    ...

# New endpoint
@tool("get_customer_v2")
def get_customer_v2(input: GetCustomerInputV2) -> dict:
    ...
```

Document deprecation in README and set removal date.

---

## 📚 References

- **FastMCP**: https://github.com/modelcontextprotocol/fastmcp
- **FastAPI**: https://fastapi.tiangolo.com/
- **uv**: https://docs.astral.sh/uv/
- **Pydantic**: https://docs.pydantic.dev/
- **SQLAlchemy**: https://sqlalchemy.org/
- **Prometheus**: https://prometheus.io/docs/
- **MCP Protocol**: https://modelcontextprotocol.io/

---

## 📄 License
MIT License — use freely with attribution.

---

## 💡 Support & Contributing

For issues, questions, or contributions:
1. Check the **Troubleshooting** section above
2. Review structured logs and metrics
3. File an issue with `request_id` for reproduction
4. Propose changes via pull request with tests