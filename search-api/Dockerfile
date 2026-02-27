FROM node:18-slim

WORKDIR /usr/src/app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install --only=prod

# Copy application source
COPY . .

EXPOSE 8080

CMD ["node", "index.js"]
