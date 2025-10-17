#!/usr/bin/env python3
"""
Gunicorn configuration for MarineSABRES Demonstration Area Tool
Deployed at: http://laguna.ku.lt/DA/

Optimized configuration with:
- Environment-based scaling (auto-scaled based on CPU cores)
- Production security settings
- Performance tuning for EMODnet WMS requests (120s timeout)
- Connection pooling for WMS services
- Subpath deployment support (/DA/)
"""

import os
import multiprocessing

# Server socket - bind to localhost only (nginx reverse proxy handles external access)
bind = f"127.0.0.1:{os.getenv('PORT', '5002')}"
backlog = 2048

# Worker processes - optimized for I/O bound WMS requests
workers = int(os.getenv('WORKERS', multiprocessing.cpu_count() * 2 + 1))
worker_class = 'sync'
worker_connections = 1000

# Timeouts - increased for WMS GetCapabilities requests
timeout = int(os.getenv('TIMEOUT', '120'))  # Increased from 30s for WMS operations
graceful_timeout = int(os.getenv('GRACEFUL_TIMEOUT', '30'))
keepalive = int(os.getenv('KEEPALIVE', '5'))

# Restart workers to prevent memory leaks
max_requests = int(os.getenv('MAX_REQUESTS', '1000'))
max_requests_jitter = int(os.getenv('MAX_REQUESTS_JITTER', '100'))

# Logging
accesslog = 'logs/gunicorn-access.log'
errorlog = 'logs/gunicorn-error.log'
loglevel = os.getenv('LOG_LEVEL', 'info').lower()
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# Process naming
proc_name = 'marinesabres-da-tool'

# Server mechanics
preload_app = True
daemon = False

# Environment variables passed to workers
raw_env = [
    'FLASK_ENV=production',
    'APPLICATION_ROOT=/DA',
]

# Security - limit request sizes
limit_request_line = 4094
limit_request_fields = 100
limit_request_field_size = 8190

# SSL (if needed)
# keyfile = '/path/to/keyfile'
# certfile = '/path/to/certfile'

def when_ready(server):
    """Called just after the server is started."""
    server.log.info("MarineSABRES DA Tool server is ready. Listening on %s", bind)

def worker_int(worker):
    """Called just after a worker has been interrupted by SIGINT"""
    worker.log.info("Worker received SIGINT signal")

def pre_fork(server, worker):
    """Called just before a worker is forked."""
    server.log.info("Worker spawned (pid: %s)", worker.pid)

def post_fork(server, worker):
    """Called just after a worker has been forked."""
    server.log.info("Worker spawned (pid: %s)", worker.pid)

def post_worker_init(worker):
    """Called just after a worker has initialized the application."""
    worker.log.info("Worker initialized (pid: %s)", worker.pid)

def worker_abort(worker):
    """Called when a worker received the SIGABRT signal."""
    worker.log.info("Worker aborted (pid: %s)", worker.pid)
