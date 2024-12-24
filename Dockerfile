# Stage 1: Base image for development and build
FROM debian:bookworm-slim AS base

# Set build-time arguments
ARG PYTHON_VERSION=3.12.0
ARG UV_PROJECT_ENVIRONMENT=production
ARG UV_EXTRA_GROUPS=""

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gcc libffi-dev && \
    rm -rf /var/lib/apt/lists/*

# Install uv
RUN curl -sSL https://astral.sh/uv/install.sh | sh

# Set environment variables
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ENV UV_PROJECT_ENVIRONMENT=${UV_PROJECT_ENVIRONMENT}

# Install Python using uv
RUN uv install python --version $PYTHON_VERSION --path /usr/local

# Create and activate virtual environment
RUN python -m venv $VIRTUAL_ENV

# Set working directory
WORKDIR /app

# Copy project files
COPY pyproject.toml uv.lock ./

# Install dependencies dynamically based on the environment and optional groups
RUN if [ "$UV_PROJECT_ENVIRONMENT" = "development" ]; then \
    uv sync --groups="$UV_EXTRA_GROUPS"; \
    else \
    uv sync --frozen --no-dev --groups="$UV_EXTRA_GROUPS"; \
    fi

# Copy project source code
COPY src/ src/

# Make entrypoint script executable
RUN chmod +x src/entrypoint.sh

# Stage 2: Runtime image
FROM debian:bookworm-slim AS runtime

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libffi-dev && \
    rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Copy virtual environment from the build stage
COPY --from=base $VIRTUAL_ENV $VIRTUAL_ENV

# Copy project source code
WORKDIR /app
COPY src/ src/

# Set entrypoint to script
ENTRYPOINT ["src/entrypoint.sh"]
