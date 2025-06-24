#!/bin/bash

set -e

# Step 1: Ask for Port
read -p "Enter public port [default: 3000]: " PORT
PORT=${PORT:-3000}

# Step 2: Ask for version tag
read -p "Enter Docker image tag (leave blank to use latest): " TAG

if [ -z "$TAG" ]; then
  echo "Fetching latest tag from Docker Hub..."
  TAG=$(curl -s "https://registry.hub.docker.com/v2/repositories/sanreex/chat-artmedia-backend/tags?page_size=1" | sed -n 's/.*"name": *"\([^"]*\)".*/\1/p' | head -n1)
  if [ -z "$TAG" ]; then
    echo "❌ Failed to fetch latest tag. Please enter it manually."
    exit 1
  fi
  echo "✅ Using latest tag: $TAG"
fi

# Step 3: Ask for instance name
read -p "Enter instance name [default: production]: " INSTANCE
INSTANCE=${INSTANCE:-production}

# Check for openssl
if ! command -v openssl >/dev/null 2>&1; then
  echo "❌ openssl is required but not installed. Aborting."
  exit 1
fi

# Step 4: Set up environment file
read -p "Enter Sentry Auth Token (leave blank if not used): " SENTRY_AUTH_TOKEN
read -p "Enter Sentry DSN (leave blank if not used): " SENTRY_DSN

read -p "Enter Gmail Client ID (leave blank if not used): " GMAIL_CLIENT_ID
read -p "Enter Gmail Client Secret (leave blank if not used): " GMAIL_CLIENT_SECRET
read -p "Enter Gmail Refresh Token (leave blank if not used): " GMAIL_REFRESH_TOKEN

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
MINIO_PORT="9001"

API_KEY="$API_KEY"
WIDGET_JWT_SECRET="$WIDGET_JWT_SECRET"
JWT_SECRET="$JWT_SECRET"

MINIO_ACCESS_KEY="$MINIO_ACCESS_KEY"
MINIO_SECRET_KEY="$MINIO_SECRET_KEY"

POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
MONGO_ROOT_PASSWORD="$MONGO_ROOT_PASSWORD"

GMAIL_CLIENT_ID="$GMAIL_CLIENT_ID"
GMAIL_CLIENT_SECRET="$GMAIL_CLIENT_SECRET"
GMAIL_REFRESH_TOKEN="$GMAIL_REFRESH_TOKEN"

SENTRY_AUTH_TOKEN="$SENTRY_AUTH_TOKEN"
SENTRY_DSN="$SENTRY_DSN"

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

# Step 7: Run Docker Compose
echo "🚀 Starting Docker containers..."
docker compose --env-file "$ENV_FILE" -f docker-compose.base.yml -p "chat-artmedia-$INSTANCE" up -d

echo ""
echo "✅ Deployment complete!"
echo "🌐 Access it at: http://localhost:$PORT"
