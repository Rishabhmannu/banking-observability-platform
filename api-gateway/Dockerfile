FROM node:18-alpine
WORKDIR /app

# Add New Relic environment variables
ENV NEW_RELIC_LICENSE_KEY=59829ffc48a17aa6783a0ee3cd15e230FFFFNRAL
ENV NEW_RELIC_APP_NAME="Banking API Gateway"
ENV NEW_RELIC_DISTRIBUTED_TRACING_ENABLED=true
ENV NEW_RELIC_LOG_LEVEL=info
ENV NEW_RELIC_LOG=stdout
ENV NEW_RELIC_ENABLED=true
ENV NODE_ENV=production

COPY package.json .
COPY newrelic.js .
COPY server.js .
RUN npm install
EXPOSE 8080
CMD ["node", "server.js"]
