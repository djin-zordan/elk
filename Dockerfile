FROM docker.io/library/node:lts-alpine AS base

# Prepare work directory
WORKDIR /elk

FROM base AS builder

# Install corepack and Bun
RUN npm i -g corepack@latest && corepack enable
RUN npm i -g bun@latest

# Install dependencies
RUN apk update && apk add git --no-cache

# Copy package files first
COPY package.json ./
COPY bun.lock ./
COPY patches ./patches

# Install dependencies (ignore postinstall scripts)
RUN bun install --frozen-lockfile --ignore-scripts

# Copy all source files
COPY . ./

# Run full install with postinstall scripts
RUN bun install --frozen-lockfile

# Ensure the output directory exists
RUN mkdir -p .output

# Build the project
RUN bun run build

FROM base AS runner

# Ensure Bun is installed in the runtime container
RUN npm i -g bun@latest  

ARG UID=911
ARG GID=911

# Create a dedicated user and group
RUN set -eux; \
    addgroup -g $GID elk; \
    adduser -u $UID -D -G elk elk;

USER elk

ENV NODE_ENV=production

# Copy build output
COPY --from=builder /elk/.output ./.output

# Expose the application port
EXPOSE 5314/tcp

# Set the runtime environment variables
ENV PORT=5314
ENV NUXT_STORAGE_FS_BASE='/elk/data'

# Define persistent storage volume
VOLUME [ "/elk/data" ]

# Run the Bun application
CMD ["bun", ".output/server/index.mjs"]
