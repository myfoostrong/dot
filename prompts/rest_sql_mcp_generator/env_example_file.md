# FastMCP Tool Server - Environment Configuration
# Copy this file to .env and fill in your actual values
# NEVER commit .env to git - it contains secrets

# ============================================================================
# SERVER CONFIGURATION
# ============================================================================
ENVIRONMENT=development  # development, staging, production
LOG_LEVEL=INFO          # DEBUG, INFO, WARNING, ERROR
HOST=0.0.0.0
PORT=8000

# ============================================================================
# AUTHENTICATION
# ============================================================================
# API keys for Bearer token authentication
# Generate with: python -c "import secrets; print(secrets.token_urlsafe(32))"
API_KEY_PRIMARY=sk_prod_change_me_in_production_xxxxxxxxxxxxx
API_KEY_SECONDARY=sk_prod_secondary_key_xxxxxxxxxxxxx

# For production, rotate these quarterly
# Revoke compromised keys immediately
# Use AWS Secrets Manager / Vault for key rotation

# ============================================================================
# RATE LIMITING
# ============================================================================
RATE_LIMIT_RPM=100                    # Requests per minute per API key
RATE_LIMIT_STORAGE=memory             # memory, redis
REDIS_URL=redis://localhost:6379/0    # Only needed if RATE_LIMIT_STORAGE=redis

# ============================================================================
# REST API CONFIGURATION
# ============================================================================
API_BASE_URL=https://api.example.com
API_TIMEOUT_SECONDS=10
API_MAX_RETRIES=3
API_BACKOFF_FACTOR=2.0                # Exponential backoff multiplier
API_MAX_CONNECTIONS=10
API_MAX_KEEPALIVE=30

# Optional: API authentication for upstream service
API_AUTH_TYPE=bearer                  # bearer, basic, api_key
API_AUTH_TOKEN=sk_upstream_xxxxx      # If using bearer or api_key auth
API_AUTH_HEADER=Authorization         # Custom header name

# ============================================================================
# DATABASE CONFIGURATION
# ============================================================================
# Connection string format depends on your database:
# PostgreSQL: postgresql://user:password@host:5432/dbname
# SQLite:     sqlite:///./data.db
# MySQL:      mysql+pymysql://user:password@host:3306/dbname

DB_URL=postgresql://postgres:password@localhost:5432/fastmcp_db
DB_POOL_SIZE=5                        # Connection pool size
DB_POOL_MAX_OVERFLOW=10               # Additional temp connections
DB_POOL_RECYCLE_SECONDS=3600          # Recycle connections after this time
DB_QUERY_TIMEOUT_SECONDS=30           # Max time per query

# ============================================================================
# FEATURES
# ============================================================================
ENABLE_RAG=false                      # Enable RAG/semantic search tools
RAG_EMBEDDING_MODEL=all-MiniLM-L6-v2  # Hugging Face model name
RAG_CHUNK_SIZE=512
RAG_CHUNK_OVERLAP=50

# ============================================================================
# MONITORING & OBSERVABILITY
# ============================================================================
# Prometheus metrics
METRICS_ENABLED=true
METRICS_PORT=8000                     # Same as server (exposed at /metrics)

# Health check configuration
HEALTH_CHECK_ENABLED=true
HEALTH_CHECK_DB_TIMEOUT=5
HEALTH_CHECK_API_TIMEOUT=5
HEALTH_CHECK_MEMORY_THRESHOLD=80      # Warn if memory usage > this %

# Request tracing
REQUEST_ID_HEADER=X-Request-ID
TRACE_SAMPLING_RATE=1.0               # 1.0 = log all, 0.1 = log 10%

# ============================================================================
# LOGGING CONFIGURATION
# ============================================================================
LOG_FORMAT=json                       # json, text
LOG_OUTPUT=stdout                     # stdout, file, both
LOG_FILE=/tmp/fastmcp.log
LOG_FILE_ROTATION=daily               # daily, size
LOG_FILE_MAX_SIZE_MB=100              # For size-based rotation
LOG_RETENTION_DAYS=7                  # Delete logs older than this

# ============================================================================
# SECRETS & VAULT (Production Only)
# ============================================================================
# Uncomment for production integration with secret managers

# AWS Secrets Manager
# SECRETS_PROVIDER=aws_secrets_manager
# AWS_REGION=us-east-1
# AWS_SECRET_NAME=fastmcp/prod
# AWS_ENDPOINT_URL=            # Optional: for local testing

# HashiCorp Vault
# SECRETS_PROVIDER=vault
# VAULT_ADDR=https://vault.example.com
# VAULT_TOKEN=s.xxxxxxxxxxxx
# VAULT_PATH=secret/data/fastmcp/prod

# ============================================================================
# CACHING (Optional)
# ============================================================================
CACHE_ENABLED=false
CACHE_TYPE=redis                      # redis, memory
REDIS_URL=redis://localhost:6379/1    # Different DB than rate limiting
CACHE_TTL_SECONDS=3600                # Default cache time-to-live
CACHE_MAX_SIZE_MB=100                 # For in-memory cache

# ============================================================================
# CORS CONFIGURATION
# ============================================================================
CORS_ORIGINS=http://localhost:3000,http://localhost:8080
CORS_CREDENTIALS=true
CORS_METHODS=GET,POST,PUT,DELETE,OPTIONS
CORS_HEADERS=*
CORS_MAX_AGE=3600

# ============================================================================
# SECURITY HEADERS
# ============================================================================
ENABLE_SECURITY_HEADERS=true
REQUIRE_HTTPS=false                   # Set to true in production
HSTS_MAX_AGE=31536000                 # HTTP Strict Transport Security (1 year)

# ============================================================================
# PAGINATION DEFAULTS
# ============================================================================
DEFAULT_PAGE_SIZE=10
MAX_PAGE_SIZE=1000
MIN_PAGE_SIZE=1

# ============================================================================
# API VERSIONING
# ============================================================================
API_VERSION=v1
DEPRECATED_API_VERSIONS=               # Comma-separated list, e.g. "v0,v1beta"

# ============================================================================
# ALERTING (Integration with monitoring systems)
# ============================================================================
# Error rate threshold for alerts
ALERT_ERROR_RATE_THRESHOLD=0.05       # 5%

# Latency threshold for alerts (milliseconds)
ALERT_P99_LATENCY_THRESHOLD_MS=1000   # 1 second

# Health check failure threshold
ALERT_HEALTH_CHECK_FAILURES=3

# ============================================================================
# MAINTENANCE & DEBUGGING
# ============================================================================
# Debug mode (only for development)
DEBUG=false

# Query profiling (logs slow queries)
PROFILE_QUERIES=false
SLOW_QUERY_THRESHOLD_MS=500           # Log queries slower than this

# Request logging (logs all request/response bodies)
LOG_REQUEST_BODY=false
LOG_RESPONSE_BODY=false

# ============================================================================
# NOTES
# ============================================================================
# 1. Update all "change_me" values for your environment
# 2. Use strong, unique values for all API keys
# 3. Store this file securely - it contains secrets
# 4. Never commit .env to git
# 5. For production, use AWS Secrets Manager or Vault
# 6. Rotate API keys quarterly at minimum
# 7. Verify all settings before deploying
# 8. Test health check: curl http://localhost:8000/health
# 9. View logs: docker logs <container> | jq '.'
# 10. Verify metrics: curl http://localhost:8000/metrics | head -20
