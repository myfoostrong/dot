# 🔧 FastMCP Implementation Patterns & Templates

This document provides ready-to-use code patterns for building your FastMCP tool server.

---

## 1. pyproject.toml Configuration

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "fastmcp_tool_server"
version = "0.1.0"
description = "Production-grade headless MCP Tool Server with REST, SQL, and RAG tools"
readme = "README.md"
requires-python = ">=3.10"
license = {text = "MIT"}
authors = [
    {name = "Your Team", email = "team@example.com"}
]
keywords = ["mcp", "fastapi", "tool-server", "llm"]

dependencies = [
    "fastmcp>=0.6.0",
    "fastapi>=0.104.0",
    "uvicorn[standard]>=0.24.0",
    "httpx>=0.25.0",
    "sqlalchemy>=2.0.0",
    "pydantic>=2.0.0",
    "pydantic-settings>=2.0.0",
    "python-dotenv>=1.0.0",
    "python-json-logger>=2.0.0",
    "prometheus-client>=0.19.0",
    "slowapi>=0.1.9",
    "redis>=5.0.0",
]

[project.optional-dependencies]
rag = [
    "sentence-transformers>=2.2.0",
    "faiss-cpu>=1.7.0",
    "langchain>=0.1.0",
]
vault = [
    "hvac>=1.2.0",
]

[project.scripts]
fastmcp = "fastmcp_tool_server.main:run"

[tool.uv]
dev-dependencies = [
    "pytest>=7.4.0",
    "pytest-asyncio>=0.21.0",
    "pytest-cov>=4.1.0",
    "pytest-mock>=3.12.0",
    "ruff>=0.1.0",
    "mypy>=1.7.0",
    "black>=23.12.0",
    "isort>=5.13.0",
    "httpx[testing]>=0.25.0",
]

[tool.ruff]
line-length = 100
target-version = "py310"

[tool.ruff.lint]
select = [
    "E",      # pycodestyle errors
    "W",      # pycodestyle warnings
    "F",      # Pyflakes
    "I",      # isort
    "C",      # flake8-comprehensions
    "B",      # flake8-bugbear
    "S",      # flake8-bandit (security)
    "UP",     # pyupgrade
]
ignore = ["E501", "S101"]  # Long lines, assert statements

[tool.ruff.lint.per-file-ignores]
"tests/*" = ["S101"]  # Allow assert in tests

[tool.mypy]
python_version = "3.10"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true

[[tool.mypy.overrides]]
module = "fastmcp.*"
ignore_missing_imports = true

[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
addopts = "--cov=fastmcp_tool_server --cov-report=term-missing --strict-markers"
markers = [
    "integration: marks tests as integration tests",
    "security: marks tests as security tests",
    "performance: marks tests as performance tests",
]

[tool.coverage.run]
omit = [
    "*/tests/*",
    "*/venv/*",
    "setup.py",
]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise AssertionError",
    "raise NotImplementedError",
    "if __name__ == .__main__.:",
    "if TYPE_CHECKING:",
]
fail_under = 80
```

---

## 2. Configuration Module

```python
# fastmcp_tool_server/config.py
from pydantic_settings import BaseSettings
from functools import lru_cache
from typing import Literal

class Settings(BaseSettings):
    """Application configuration loaded from environment variables."""
    
    # Server
    environment: Literal["development", "staging", "production"] = "development"
    log_level: str = "INFO"
    host: str = "0.0.0.0"
    port: int = 8000
    
    # Authentication
    api_key_primary: str
    api_key_secondary: str | None = None
    
    # Rate limiting
    rate_limit_rpm: int = 100
    rate_limit_storage: Literal["memory", "redis"] = "memory"
    redis_url: str = "redis://localhost:6379/0"
    
    # REST API
    api_base_url: str
    api_timeout_seconds: int = 10
    api_max_retries: int = 3
    api_backoff_factor: float = 2.0
    api_max_connections: int = 10
    
    # Database
    db_url: str
    db_pool_size: int = 5
    db_pool_max_overflow: int = 10
    db_pool_recycle_seconds: int = 3600
    db_query_timeout_seconds: int = 30
    
    # Features
    enable_rag: bool = False
    rag_embedding_model: str = "all-MiniLM-L6-v2"
    
    # Monitoring
    metrics_enabled: bool = True
    health_check_enabled: bool = True
    trace_sampling_rate: float = 1.0
    
    # Logging
    log_format: Literal["json", "text"] = "json"
    log_output: Literal["stdout", "file", "both"] = "stdout"
    log_file: str = "/tmp/fastmcp.log"
    
    class Config:
        env_file = ".env"
        case_sensitive = False
    
    @property
    def valid_api_keys(self) -> set[str]:
        """Get all valid API keys."""
        keys = {self.api_key_primary}
        if self.api_key_secondary:
            keys.add(self.api_key_secondary)
        return keys
    
    @property
    def is_production(self) -> bool:
        return self.environment == "production"

@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
```

---

## 3. Authentication Middleware

```python
# fastmcp_tool_server/middleware/auth.py
import logging
from fastapi import HTTPException, Request
from functools import wraps
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

async def verify_bearer_token(request: Request) -> str:
    """
    Extract and validate Bearer token from request headers.
    
    Returns:
        The validated API key
        
    Raises:
        HTTPException: 401 if token is invalid or missing
    """
    auth_header = request.headers.get("Authorization", "")
    
    if not auth_header.startswith("Bearer "):
        logger.warning(
            "Missing or invalid Authorization header",
            extra={
                "request_id": request.state.request_id,
                "path": request.url.path,
                "source": request.client.host if request.client else "unknown"
            }
        )
        raise HTTPException(
            status_code=401,
            detail={"error": "Unauthorized", "request_id": request.state.request_id}
        )
    
    token = auth_header[7:]  # Remove "Bearer " prefix
    
    if token not in settings.valid_api_keys:
        logger.warning(
            "Invalid API key attempt",
            extra={
                "request_id": request.state.request_id,
                "source": request.client.host if request.client else "unknown"
            }
        )
        raise HTTPException(
            status_code=401,
            detail={"error": "Unauthorized", "request_id": request.state.request_id}
        )
    
    logger.debug(
        "API key validated",
        extra={"request_id": request.state.request_id}
    )
    
    return token

def require_auth(func):
    """Decorator to require authentication on a handler."""
    @wraps(func)
    async def wrapper(request: Request, *args, **kwargs):
        api_key = await verify_bearer_token(request)
        request.state.api_key = api_key
        return await func(request, *args, **kwargs)
    return wrapper
```

---

## 4. Request ID Middleware

```python
# fastmcp_tool_server/middleware/request_id.py
import uuid
import logging
from fastapi import Request
from contextvars import ContextVar
from typing import Callable

request_id_var: ContextVar[str] = ContextVar("request_id", default="")
logger = logging.getLogger(__name__)

def get_request_id() -> str:
    """Get current request ID from context."""
    return request_id_var.get()

async def add_request_id_middleware(
    request: Request,
    call_next: Callable
) -> any:
    """Add unique request ID to each request."""
    request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
    request.state.request_id = request_id
    request_id_var.set(request_id)
    
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    
    return response
```

---

## 5. REST Tool Pattern

```python
# fastmcp_tool_server/tools/rest_tools.py
import logging
from fastmcp import tool
from pydantic import BaseModel, Field
from utils.api_client import call_api_with_retries
from middleware.request_id import get_request_id
import httpx

logger = logging.getLogger(__name__)

class GetCustomerInput(BaseModel):
    """Input model for get_customer tool."""
    customer_id: int = Field(..., gt=0, description="Customer ID")

@tool("get_customer", description="Fetch customer details from REST API")
def get_customer(input: GetCustomerInput) -> dict:
    """
    Fetch customer details with automatic retry on transient errors.
    
    Args:
        input: GetCustomerInput with customer_id
        
    Returns:
        Customer data or error response
    """
    request_id = get_request_id()
    
    try:
        logger.info(
            "Fetching customer",
            extra={"customer_id": input.customer_id, "request_id": request_id}
        )
        
        response = call_api_with_retries(
            method="GET",
            url=f"/customers/{input.customer_id}",
            timeout=10,
            max_retries=3
        )
        
        result = response.json()
        
        logger.info(
            "Customer fetch succeeded",
            extra={"customer_id": input.customer_id, "request_id": request_id}
        )
        
        return result
        
    except httpx.TimeoutException:
        logger.error(
            "API timeout",
            extra={"customer_id": input.customer_id, "request_id": request_id}
        )
        return {
            "error": "API timeout",
            "status": "retry",
            "request_id": request_id
        }
        
    except httpx.HTTPStatusError as e:
        if e.response.status_code >= 500:
            logger.error(
                "Upstream API error",
                extra={
                    "customer_id": input.customer_id,
                    "status_code": e.response.status_code,
                    "request_id": request_id
                }
            )
            return {
                "error": "Upstream service error",
                "status": "retry",
                "request_id": request_id
            }
        else:
            logger.warning(
                "Customer not found",
                extra={"customer_id": input.customer_id, "request_id": request_id}
            )
            return {
                "error": "Customer not found",
                "status": "not_found",
                "request_id": request_id
            }
            
    except Exception as e:
        logger.error(
            "Unexpected error",
            exc_info=True,
            extra={"customer_id": input.customer_id, "request_id": request_id}
        )
        return {
            "error": "Internal server error",
            "status": "error",
            "request_id": request_id
        }
```

---

## 6. SQL Tool Pattern

```python
# fastmcp_tool_server/tools/sql_tools.py
import logging
from fastmcp import tool
from pydantic import BaseModel, Field
from utils.db import query_db, get_count
from middleware.request_id import get_request_id

logger = logging.getLogger(__name__)

class TopCustomersInput(BaseModel):
    """Paginated input for top customers query."""
    limit: int = Field(default=10, ge=1, le=1000, description="Max results")
    offset: int = Field(default=0, ge=0, description="Pagination offset")

@tool("get_top_customers", description="Return top customers by revenue with pagination")
def get_top_customers(input: TopCustomersInput) -> dict:
    """
    Fetch top customers with pagination.
    
    Args:
        input: TopCustomersInput with limit and offset
        
    Returns:
        Paginated list of customers or error response
    """
    request_id = get_request_id()
    
    try:
        logger.info(
            "Fetching top customers",
            extra={
                "limit": input.limit,
                "offset": input.offset,
                "request_id": request_id
            }
        )
        
        # Parameterized query - no f-strings!
        query = '''
            SELECT name, SUM(amount) AS total
            FROM orders
            GROUP BY name
            ORDER BY total DESC
            LIMIT :limit OFFSET :offset
        '''
        
        rows = query_db(query, {"limit": input.limit, "offset": input.offset})
        total = get_count("SELECT COUNT(DISTINCT name) FROM orders")
        
        result = {
            "customers": [{"name": r[0], "total": r[1]} for r in rows],
            "limit": input.limit,
            "offset": input.offset,
            "total_count": total
        }
        
        logger.info(
            "Top customers query succeeded",
            extra={
                "result_count": len(rows),
                "total_count": total,
                "request_id": request_id
            }
        )
        
        return result
        
    except Exception as e:
        logger.error(
            "Database query failed",
            exc_info=True,
            extra={"request_id": request_id}
        )
        return {
            "error": "Query failed",
            "status": "error",
            "request_id": request_id
        }
```

---

## 7. HTTP Client Utility

```python
# fastmcp_tool_server/utils/api_client.py
import httpx
import logging
import time
from config import get_settings
from typing import Optional

logger = logging.getLogger(__name__)
settings = get_settings()

# Thread-safe HTTP client with connection pooling
_client: Optional[httpx.AsyncClient] = None

async def get_http_client() -> httpx.AsyncClient:
    """Get or create async HTTP client with pooling."""
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            base_url=settings.api_base_url,
            timeout=settings.api_timeout_seconds,
            limits=httpx.Limits(
                max_connections=settings.api_max_connections,
                max_keepalive_connections=10
            ),
            verify=True
        )
    return _client

async def call_api_with_retries(
    method: str,
    url: str,
    params: Optional[dict] = None,
    data: Optional[dict] = None,
    timeout: int = 10,
    max_retries: int = 3,
    backoff_factor: float = 2.0
) -> httpx.Response:
    """
    Make HTTP request with exponential backoff retry logic.
    
    Args:
        method: HTTP method (GET, POST, etc.)
        url: Endpoint URL
        params: Query parameters
        data: Request body
        timeout: Request timeout in seconds
        max_retries: Number of retry attempts
        backoff_factor: Exponential backoff multiplier
        
    Returns:
        HTTP response
        
    Raises:
        httpx.HTTPError: After max retries exhausted
    """
    client = await get_http_client()
    retry_count = 0
    wait_time = 1.0
    
    while retry_count < max_retries:
        try:
            response = await client.request(
                method,
                url,
                params=params,
                json=data,
                timeout=timeout
            )
            response.raise_for_status()
            return response
            
        except (httpx.TimeoutException, httpx.ConnectError) as e:
            retry_count += 1
            if retry_count >= max_retries:
                logger.error(
                    f"Request failed after {max_retries} retries",
                    extra={"url": url, "error": str(e)}
                )
                raise
            
            logger.warning(
                f"Request timeout, retrying ({retry_count}/{max_retries})",
                extra={"url": url, "wait_time": wait_time}
            )
            
            await asyncio.sleep(wait_time)
            wait_time *= backoff_factor
            
        except httpx.HTTPStatusError as e:
            # Don't retry on 4xx errors
            if 400 <= e.response.status_code < 500:
                raise
            
            # Retry on 5xx errors
            retry_count += 1
            if retry_count >= max_retries:
                logger.error(
                    f"Request failed with {e.response.status_code} after {max_retries} retries",
                    extra={"url": url}
                )
                raise
            
            logger.warning(
                f"Request failed with {e.response.status_code}, retrying",
                extra={"url": url, "wait_time": wait_time}
            )
            
            await asyncio.sleep(wait_time)
            wait_time *= backoff_factor

async def close_http_client():
    """Clean up HTTP client connection pool."""
    global _client
    if _client:
        await _client.aclose()
        _client = None
```

---

## 8. Database Utility

```python
# fastmcp_tool_server/utils/db.py
import logging
import re
from sqlalchemy import create_engine, text
from sqlalchemy.pool import NullPool, QueuePool
from config import get_settings
from typing import List, Tuple, Any

logger = logging.getLogger(__name__)
settings = get_settings()

def get_engine():
    """Create SQLAlchemy engine with connection pooling."""
    pool_class = NullPool if settings.environment == "development" else QueuePool
    
    engine = create_engine(
        settings.db_url,
        pool_class=pool_class,
        pool_size=settings.db_pool_size,
        max_overflow=settings.db_pool_max_overflow,
        pool_recycle=settings.db_pool_recycle_seconds,
        echo=settings.log_level == "DEBUG"
    )
    
    return engine

def safe_query(query: str, params: dict) -> tuple[str, dict]:
    """
    Validate that query uses parameterized statements (no f-strings).
    
    Args:
        query: SQL query string
        params: Parameter dictionary
        
    Returns:
        (query, params) tuple if valid
        
    Raises:
        ValueError: If query appears to have unsafe string formatting
    """
    # Check for common f-string patterns
    if re.search(r'\{[^}]+\}', query):
        raise ValueError("Query contains f-string placeholders - use parameterized queries")
    
    # Check for SQL comment injection
    if "--" in query or "/*" in query:
        logger.warning("Query contains SQL comments", extra={"query": query[:100]})
    
    # Ensure placeholders exist if params provided
    if params and not (":name" in query or "?" in query):
        raise ValueError("Parameters provided but query has no placeholders")
    
    return query, params

def query_db(query: str, params: dict = None) -> List[Tuple[Any, ...]]:
    """
    Execute read-only SQL query with timeout.
    
    Args:
        query: Parameterized SQL query (must use :name or ? placeholders)
        params: Parameter dictionary
        
    Returns:
        List of result rows
        
    Raises:
        ValueError: If query appears unsafe
        sqlalchemy.exc.SQLAlchemyError: On database errors
    """
    query, params = safe_query(query, params or {})
    
    engine = get_engine()
    
    try:
        with engine.connect() as conn:
            # Set timeout
            conn.execute(
                text(f"SET statement_timeout = {settings.db_query_timeout_seconds * 1000}")
            )
            
            result = conn.execute(text(query), params or {})
            rows = result.fetchall()
            
            logger.debug(
                "Query executed",
                extra={"row_count": len(rows), "query": query[:100]}
            )
            
            return rows
            
    except Exception as e:
        logger.error(
            "Database query failed",
            exc_info=True,
            extra={"query": query[:100]}
        )
        raise

def get_count(query: str, params: dict = None) -> int:
    """Execute COUNT query and return single integer."""
    query, params = safe_query(query, params or {})
    rows = query_db(query, params)
    return rows[0][0] if rows else 0
```

---

## 9. Health Check

```python
# fastmcp_tool_server/utils/health.py
import logging
import psutil
from datetime import datetime
from config import get_settings
from utils.db import query_db
from utils.api_client import call_api_with_retries

logger = logging.getLogger(__name__)
settings = get_settings()

async def check_database() -> dict:
    """Check database connectivity."""
    try:
        query_db("SELECT 1")
        return {"status": "connected", "latency_ms": 0}
    except Exception as e:
        logger.error("Database health check failed", exc_info=True)
        return {"status": "failed", "error": str(e)}

async def check_upstream_api() -> dict:
    """Check upstream API responsiveness."""
    try:
        response = await call_api_with_retries(
            method="GET",
            url="/health",  # or appropriate health endpoint
            timeout=5,
            max_retries=1
        )
        return {"status": "responding"}
    except Exception as e:
        logger.error("Upstream API health check failed", exc_info=True)
        return {"status": "failed", "error": str(e)}

def check_memory() -> dict:
    """Check memory usage."""
    memory = psutil.virtual_memory()
    threshold = settings.health_check_memory_threshold
    
    return {
        "usage_percent": memory.percent,
        "status": "healthy" if memory.percent < threshold else "warning",
        "threshold_percent": threshold
    }

async def get_health_status() -> dict:
    """Get overall health status."""
    checks = {
        "database": await check_database(),
        "upstream_api": await check_upstream_api(),
        "memory": check_memory()
    }
    
    # Overall status is healthy only if all checks pass
    overall_status = "healthy" if all(
        check.get("status") in ["connected", "responding", "healthy"]
        for check in checks.values()
    ) else "unhealthy"
    
    return {
        "status": overall_status,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        **checks
    }
```

---

## 10. Main Application

```python
# fastmcp_tool_server/main.py
import logging
import asyncio
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastmcp import MCPServer
from config import get_settings
from middleware.request_id import add_request_id_middleware
from middleware.auth import require_auth
from utils.health import get_health_status
from utils.api_client import close_http_client
from prometheus_client import make_asgi_app
from logging_config import setup_logging

# Import all tools
from tools.rest_tools import *
from tools.sql_tools import *

logger = logging.getLogger(__name__)
settings = get_settings()

# Setup logging
setup_logging(settings)

# Create FastAPI app with FastMCP
app = FastAPI(
    title="FastMCP Tool Server",
    version="1.0.0",
    description="Production-grade MCP tool server with REST, SQL, and RAG tools"
)

# Create MCP server
mcp = MCPServer("fastmcp_tool_server")

# Mount middleware
app.middleware("http")(add_request_id_middleware)

# Mount Prometheus metrics
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

# Health check endpoint (no auth required)
@app.get("/health")
async def health():
    """Health check endpoint."""
    status = await get_health_status()
    return status

# Root endpoint
@app.get("/")
async def root():
    return {
        "service": "FastMCP Tool Server",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
        "metrics": "/metrics"
    }

# Startup/shutdown events
@app.on_event("startup")
async def startup():
    logger.info(f"Starting FastMCP Tool Server (environment={settings.environment})")
    logger.info(f"API Base URL: {settings.api_base_url}")
    logger.info(f"Database: {settings.db_url.split('@')[0] if '@' in settings.db_url else '***'}")

@app.on_event("shutdown")
async def shutdown():
    logger.info("Shutting down FastMCP Tool Server")
    await close_http_client()

# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    request_id = getattr(request.state, "request_id", "unknown")
    logger.error(
        "Unhandled exception",
        exc_info=True,
        extra={"request_id": request_id, "path": request.url.path}
    )
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "request_id": request_id
        }
    )

def run():
    """Entry point for uvicorn."""
    import uvicorn
    uvicorn.run(
        app,
        host=settings.host,
        port=settings.port,
        log_config=None  # Use our custom logging
    )

if __name__ == "__main__":
    run()
```

---

## 11. Logging Configuration

```python
# fastmcp_tool_server/logging_config.py
import logging
import sys
from pythonjsonlogger import jsonlogger
from config import Settings

def setup_logging(settings: Settings):
    """Configure JSON logging for production."""
    logger = logging.getLogger()
    logger.setLevel(settings.log_level)
    
    if settings.log_format == "json":
        formatter = jsonlogger.JsonFormatter(
            fmt="%(timestamp)s %(level)s %(name)s %(message)s",
            timestamp=True
        )
    else:
        formatter = logging.Formatter(
            "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
        )
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    # File handler (optional)
    if settings.log_output in ["file", "both"]:
        file_handler = logging.FileHandler(settings.log_file)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
```

---

## 12. Unit Test Pattern

```python
# tests/test_rest_tools.py
import pytest
from unittest.mock import patch, AsyncMock
import httpx
from tools.rest_tools import get_customer, GetCustomerInput

@pytest.mark.asyncio
async def test_get_customer_success():
    """Test successful customer fetch."""
    with patch("utils.api_client.call_api_with_retries") as mock_api:
        mock_response = AsyncMock()
        mock_response.json.return_value = {"id": 42, "name": "Acme"}
        mock_api.return_value = mock_response
        
        result = await get_customer(GetCustomerInput(customer_id=42))
        
        assert result["id"] == 42
        assert result["name"] == "Acme"

@pytest.mark.asyncio
async def test_get_customer_timeout():
    """Test timeout handling with retry."""
    with patch("utils.api_client.call_api_with_retries") as mock_api:
        mock_api.side_effect = httpx.TimeoutException("Timeout")
        
        result = await get_customer(GetCustomerInput(customer_id=42))
        
        assert result["status"] == "retry"
        assert "error" in result
        assert "request_id" in result

@pytest.mark.asyncio
async def test_get_customer_not_found():
    """Test 404 handling."""
    with patch("utils.api_client.call_api_with_retries") as mock_api:
        mock_api.side_effect = httpx.HTTPStatusError(
            "Not found",
            request=None,
            response=AsyncMock(status_code=404)
        )
        
        result = await get_customer(GetCustomerInput(customer_id=999))
        
        assert result["status"] == "not_found"

@pytest.mark.asyncio
async def test_input_validation():
    """Test input validation."""
    with pytest.raises(ValueError):
        GetCustomerInput(customer_id=-1)  # Should fail: gt=0
```

---

## 13. Security Test Pattern

```python
# tests/test_security.py
import pytest
from utils.db import safe_query

def test_sql_injection_prevention():
    """Verify parameterized queries only."""
    # ✅ Should pass
    safe_query("SELECT * FROM users WHERE id = :id", {"id": 42})
    
    # ❌ Should fail
    with pytest.raises(ValueError):
        safe_query("SELECT * FROM users WHERE id = 42", {})
    
    # ❌ Should fail - f-string pattern
    with pytest.raises(ValueError):
        safe_query("SELECT * FROM users WHERE id = {id}", {})

@pytest.mark.asyncio
async def test_auth_required():
    """Verify authentication required."""
    from fastapi.testclient import TestClient
    from main import app
    
    client = TestClient(app)
    response = client.post("/v1/mcp/get_customer", json={"customer_id": 42})
    
    assert response.status_code == 401

@pytest.mark.asyncio
async def test_invalid_api_key():
    """Verify invalid API key rejected."""
    from fastapi.testclient import TestClient
    from main import app
    
    client = TestClient(app)
    response = client.post(
        "/v1/mcp/get_customer",
        headers={"Authorization": "Bearer invalid_key"},
        json={"customer_id": 42}
    )
    
    assert response.status_code == 401
```

---

## 14. Rate Limiting Test

```python
# tests/test_rate_limiting.py
import pytest
from fastapi.testclient import TestClient
from main import app

@pytest.mark.asyncio
async def test_rate_limit_enforced():
    """Verify rate limiting works."""
    client = TestClient(app)
    valid_key = "Bearer sk_prod_xxxxxxxxxxxx"
    
    # Make 101 requests (limit is 100/min)
    for i in range(101):
        response = client.post(
            "/v1/mcp/get_customer",
            headers={"Authorization": valid_key},
            json={"customer_id": 42}
        )
        
        if i < 100:
            assert response.status_code != 429
        else:
            assert response.status_code == 429
```

---

## 15. Dockerfile Template

```dockerfile
FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir uv
COPY pyproject.toml /app/
RUN uv pip install -r pyproject.toml

# Copy app
COPY fastmcp_tool_server/ /app/fastmcp_tool_server/

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run
EXPOSE 8000
CMD ["python", "-m", "uvicorn", "fastmcp_tool_server.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

These patterns provide production-ready implementations you can adapt for your specific tools and requirements.