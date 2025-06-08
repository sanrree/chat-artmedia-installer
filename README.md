# Chat Artmedia Installer

This repository provides a simple one-command installer to deploy the **Chat Artmedia** platform on any server using Docker.

It pulls prebuilt images from Docker Hub, configures your environment, and starts all services automatically using Docker Compose.

---

## 🚀 One-Command Installation

To install on a fresh server (Docker required):

```bash
curl -sO https://raw.githubusercontent.com/sanrree/chat-artmedia-installer/main/installer.sh
bash installer.sh
```

Or execute directly from memory (no file saved):

```bash
bash <(curl -s https://raw.githubusercontent.com/sanrree/chat-artmedia-installer/main/installer.sh)
```

---

## 🧠 What This Installer Does

- Prompts you for:
  - Public port (default: `3000`)
  - Docker image tag (e.g. `v0.1.0-alpha`)
  - Instance name (default: `production`)
- Generates a `.env.[instance]` file
- Downloads the latest `docker-compose.base.yml` and NGINX config
- Runs all required services with Docker:
  - NestJS backend
  - ReactJS frontend
  - Widget API (Express)
  - Socket server
  - PostgreSQL, MongoDB, Redis, MinIO
  - NGINX as reverse proxy

---

## 📦 Prerequisites

- Docker & Docker Compose installed
- Server with basic Linux environment
- Optional: pre-allocated port and domain (e.g., `chat.example.com`)

---

## 🛠 Configuration

The script generates a `.env.[instance]` file with default secrets and options. You can customize the following:

- `PORT` – main public HTTP port
- `TAG` – Docker image tag to use
- `MINIO`, `JWT_SECRET`, and other secrets

If you're deploying multiple instances (e.g., `staging`, `client1`, etc.), each will have its own `.env.[instance]` and container namespace.

---

## 🧰 Project Structure

```
.
├── installer.sh                   # Main installation script
├── docker-compose.base.yml        # Compose file used for all deployments
└── nginx/
    └── default.template.conf      # Template for NGINX reverse proxy config
```

---

## 🧼 Uninstall

To stop and remove a specific instance:

```bash
docker compose -p chat-artmedia-<instance> down
rm .env.<instance>
```

---

## 🧾 License

This installer is released under the MIT License.

---

## 🙋 Need Help?

Open an issue or contact the main [Chat Artmedia](https://github.com/sanrree) project team.
