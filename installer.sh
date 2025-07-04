#!/bin/bash

set -e

# Step 0: Load .env if exists
if [ -f ".env" ]; then
  echo "ℹ️  Loading existing .env file..."
  export $(grep -v '^#' .env | xargs)
fi

# Step 1: Ask for Port
read -p "Enter public port [default: ${PORT:-3000}]: " INPUT_PORT
PORT=${INPUT_PORT:-${PORT:-3000}}

# Step 2: Ask for version tag
read -p "Enter Docker image tag [default: ${TAG:-latest}]: " INPUT_TAG
TAG=${INPUT_TAG:-${TAG:-latest}}

if [ "$TAG" == "latest" ]; then
  echo "Fetching latest tag from Docker Hub..."
  TAG=$(curl -s "https://registry.hub.docker.com/v2/repositories/sanreex/chat-artmedia-backend/tags?page_size=1" | sed -n 's/.*"name": *"\([^"]*\)".*/\1/p' | head -n1)
  if [ -z "$TAG" ]; then
    echo "❌ Failed to fetch latest tag. Please enter it manually."
    exit 1
  fi
  echo "✅ Using latest tag: $TAG"
fi

# Step 3: Ask for instance name
read -p "Enter instance name [default: ${INSTANCE:-production}]: " INPUT_INSTANCE
INSTANCE=${INPUT_INSTANCE:-${INSTANCE:-production}}

# Check for openssl
if ! command -v openssl >/dev/null 2>&1; then
  echo "❌ openssl is required but not installed. Aborting."
  exit 1
fi

# Step 4: Set up environment file
read -p "Enter Sentry DSN [default: ${SENTRY_DSN:-}]: " INPUT_SENTRY_DSN
SENTRY_DSN=${INPUT_SENTRY_DSN:-${SENTRY_DSN:-}}

read -p "Enter Gmail Client ID [default: ${GMAIL_CLIENT_ID:-}]: " INPUT_GMAIL_CLIENT_ID
GMAIL_CLIENT_ID=${INPUT_GMAIL_CLIENT_ID:-${GMAIL_CLIENT_ID:-}}

read -p "Enter Gmail Client Secret [default: ${GMAIL_CLIENT_SECRET:-}]: " INPUT_GMAIL_CLIENT_SECRET
GMAIL_CLIENT_SECRET=${INPUT_GMAIL_CLIENT_SECRET:-${GMAIL_CLIENT_SECRET:-}}

read -p "Enter Gmail Refresh Token [default: ${GMAIL_REFRESH_TOKEN:-}]: " INPUT_GMAIL_REFRESH_TOKEN
GMAIL_REFRESH_TOKEN=${INPUT_GMAIL_REFRESH_TOKEN:-${GMAIL_REFRESH_TOKEN:-}}

read -p "Enter PostHog API Key [default: ${POSTHOG_KEY:-}]: " INPUT_POSTHOG_KEY
POSTHOG_KEY=${INPUT_POSTHOG_KEY:-${POSTHOG_KEY:-}}

read -p "Enter PostHog Host URL [default: ${POSTHOG_HOST:-}]: " INPUT_POSTHOG_HOST
POSTHOG_HOST=${INPUT_POSTHOG_HOST:-${POSTHOG_HOST:-}}

ENV_FILE=".env.$INSTANCE"

API_KEY=$(openssl rand -hex 16)
WIDGET_JWT_SECRET=$(openssl rand -hex 16)
JWT_SECRET=$(openssl rand -hex 16)
MINIO_ACCESS_KEY=$(openssl rand -hex 12)
MINIO_SECRET_KEY=$(openssl rand -hex 16)
POSTGRES_PASSWORD=$(openssl rand -hex 16)
MONGO_ROOT_PASSWORD=$(openssl rand -hex 16)

cat > $ENV_FILE <<EOF
INSTANCE="$INSTANCE"
PORT="$PORT"
PUBLIC_URL="http://localhost:$PORT"

API_KEY="$API_KEY"
WIDGET_JWT_SECRET="$WIDGET_JWT_SECRET"
JWT_SECRET="$JWT_SECRET"

MINIO_ACCESS_KEY="$MINIO_ACCESS_KEY"
MINIO_SECRET_KEY="$MINIO_SECRET_KEY"

POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
MONGO_ROOT_PASSWORD="$MONGO_ROOT_PASSWORD"

MONGODB="mongodb://admin:$MONGO_ROOT_PASSWORD@mongo:27017"

GMAIL_CLIENT_ID="$GMAIL_CLIENT_ID"
GMAIL_CLIENT_SECRET="$GMAIL_CLIENT_SECRET"
GMAIL_REFRESH_TOKEN="$GMAIL_REFRESH_TOKEN"

SENTRY_DSN="$SENTRY_DSN"

POSTHOG_KEY="$POSTHOG_KEY"
POSTHOG_HOST="$POSTHOG_HOST"

TAG="$TAG"
EOF

chmod 600 "$ENV_FILE"
echo "✅ Generated $ENV_FILE (permissions set to 600)"

# Step 5: Download docker-compose file
echo "📦 Downloading docker-compose.base.yml..."
curl -fsSL https://raw.githubusercontent.com/sanrree/chat-artmedia-installer/main/docker-compose.base.yml -o docker-compose.base.yml

# Step 6: Download and generate NGINX config
mkdir -p ./nginx/generated
echo "📦 Downloading NGINX template..."
curl -fsSL https://raw.githubusercontent.com/sanrree/chat-artmedia-installer/main/nginx/default.template.conf -o ./nginx/default.template.conf

export INSTANCE
envsubst '${INSTANCE}' < ./nginx/default.template.conf > ./nginx/generated/${INSTANCE}_default.conf

# Step 7: Generate config.js
mkdir -p ./frontend/generated

cat > ./frontend/generated/config.js <<EOF
window.RUNTIME_CONFIG = {
  POSTHOG_KEY: "${POSTHOG_KEY}",
  POSTHOG_HOST: "${POSTHOG_HOST}"
};
EOF

echo "✅ Generated ./frontend/generated/config.js"

# Step 8: Run Docker Compose
echo "🚀 Starting Docker containers..."
docker compose --env-file "$ENV_FILE" -f docker-compose.base.yml -p "chat-artmedia-$INSTANCE" up -d

# Wait a bit for frontend container to be ready
echo "⏳ Waiting for frontend container to be ready..."
sleep 5

# Step 9: Copy config.js into running frontend container
docker cp ./frontend/generated/config.js ${INSTANCE}_frontend:/usr/share/nginx/html/config.js
echo "✅ Copied config.js into container ${INSTANCE}_frontend"

# Step 10: Clean up local file
rm ./frontend/generated/config.js
echo "🧹 Cleaned up local config.js"

echo ""
echo "✅ Deployment complete!"
echo "🌐 Access it at: http://localhost:$PORT"
