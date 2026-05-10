# Stage 1
FROM node:24-slim AS deps
WORKDIR /app

RUN apt-get update && apt-get install -y python3 make g++ && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
COPY .npmrc ./
COPY vendor ./vendor

RUN npm ci --ignore-scripts && npm cache clean --force

# Stage 2
FROM deps AS frontend-builder
WORKDIR /app

COPY . .

RUN find public/fonts -name "*.ttf" ! -name "*Regular.ttf" ! -name "*Bold.ttf" ! -name "*Italic.ttf" -delete

RUN NODE_OPTIONS="--max-old-space-size=3072" npm run build

# Stage 3
FROM deps AS backend-builder
WORKDIR /app

COPY . .

RUN npm rebuild better-sqlite3
RUN npm run build:backend

# Stage 4
FROM node:24-slim

WORKDIR /app

CMD ["/entrypoint.sh"]
