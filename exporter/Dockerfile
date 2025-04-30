# Start from a lightweight Node.js base image
FROM node:20-alpine AS builder

# Create app directory
WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm install

# Copy the rest of the source files
COPY tsconfig.json ./
COPY src ./src

# Build the TypeScript code
RUN npm run build

# --- Production Stage ---
FROM node:20-alpine

# Create app directory
WORKDIR /app

# Only copy the built code and minimal files
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/dist ./dist
RUN npm install --omit=dev

# Environment Variables (can be overwritten at runtime)
ENV PORT=3000

# Expose the port
EXPOSE 3000

# Start the app
CMD ["node", "dist/server.js"]
