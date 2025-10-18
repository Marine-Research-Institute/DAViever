#!/usr/bin/env python3
"""
Gunicorn configuration for MarineSABRES Demonstration Area Tool - DEVELOPMENT
Deployed at: http://laguna.ku.lt:5003

Development configuration with:
- Single worker for easier debugging
- Auto-reload on code changes
- Detailed logging
- Shorter timeouts for faster feedback
- Direct port access (no subpath)
"""

import os
import multiprocessing

# Server socket - bind to all interfaces for direct access on port 5003
bind = f"0.0.0.0:{os.getenv('PORT', '5003')}"
backlog = 2048

# Worker processes - single worker for development
workers = 1
worker_class = 'sync'
worker_connections = 100
threads = 2

# Timeouts - shorter for development
timeout = int(os.getenv('TIMEOUT', '60'))
graceful_timeout = int(os.getenv('GRACEFUL_TIMEOUT', '10'))
keepalive = int(os.getenv('KEEPALIVE', '2'))

# Auto-reload on code changes (DEVELOPMENT ONLY)
reload = True
reload_extra_files = [
    'templates/',
    'static/',
]

# Restart workers to prevent memory leaks
max_requests = int(os.getenv('MAX_REQUESTS', '100'))
max_requests_jitter = int(os.getenv('MAX_REQUESTS_JITTER', '10'))

# Logging - verbose for development
accesslog = 'logs/gunicorn-access-dev.log'
errorlog = 'logs/gunicorn-error-dev.log'
loglevel = os.getenv('LOG_LEVEL', 'debug').lower()
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# Process naming
proc_name = 'marinesabres-da-dev'

# Server mechanics
preload_app = False  # Don't preload for hot reload
daemon = False

# Environment variables passed to workers
raw_env = [
    'FLASK_ENV=development',
    'FLASK_DEBUG=1',
    # No APPLICATION_ROOT - development runs on dedicated port
]

# Security - limit request sizes
limit_request_line = 4094
limit_request_fields = 100
limit_request_field_size = 8190

def when_ready(server):
    """Called just after the server is started."""
    server.log.info("MarineSABRES DA Tool [DEVELOPMENT] server is ready. Listening on %s", bind)

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
    worker.log.info("Worker initialized [DEVELOPMENT] (pid: %s)", worker.pid)

def worker_abort(worker):
    """Called when a worker received the SIGABRT signal."""
    worker.log.info("Worker aborted (pid: %s)", worker.pid)
