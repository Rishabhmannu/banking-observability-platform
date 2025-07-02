FROM node:18-alpine
WORKDIR /app

# Install only production dependencies
COPY package.json ./
RUN npm install --production

# Copy gateway code
COPY server.js ./

EXPOSE 8080
CMD ["node", "server.js"]
