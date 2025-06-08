#!/bin/bash

set -e

# Step 1: Ask for Port
read -p "Enter public port [default: 3000]: " PORT
PORT=${PORT:-3000}

# Step 2: Ask for version tag
read -p "Enter Docker image tag (leave blank to use latest): " TAG

if [ -z "$TAG" ]; then
  echo "Fetching latest tag from Docker Hub..."
  TAG=$(curl -s "https://registry.hub.docker.com/v2/repositories/${DOCKERHUB_USERNAME}/chat-artmedia-backend/tags?page_size=1" | grep -oP '"name":\s*"\K[^"]+')
  if [ -z "$TAG" ]; then
    echo "❌ Failed to fetch latest tag. Please enter it manually."
    exit 1
  fi
  echo "✅ Using latest tag: $TAG"
fi

# Step 3: Ask for instance name
read -p "Enter instance name [default: production]: " INSTANCE
INSTANCE=${INSTANCE:-production}

# Step 4: Set up environment file
ENV_FILE=".env.$INSTANCE"

cat > $ENV_FILE <<EOF
INSTANCE=$INSTANCE
PORT=$PORT
PUBLIC_URL=http://localhost:$PORT
MINIO_PORT=9001

API_KEY=$(openssl rand -hex 16)
WIDGET_JWT_SECRET=$(openssl rand -hex 16)
JWT_SECRET=$(openssl rand -hex 16)

MINIO_ACCESS_KEY=ROOTNAME
MINIO_SECRET_KEY=CHANGEME123

GMAIL_CLIENT_ID=
GMAIL_CLIENT_SECRET=
GMAIL_REFRESH_TOKEN=

TAG=$TAG
EOF

echo "✅ Generated $ENV_FILE"

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
