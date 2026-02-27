const http = require('http');
const express = require('express');
const { initialize } = require('@oas-tools/core');

const serverPort = 8080;
const app = express();
app.use(express.json({ limit: '50mb' }));

const config = {
    oasFile: './api/oas-doc.yaml',
    middleware: {
        router: { disable: false, controllers: './controllers' },
        validator: { requestValidation: true, responseValidation: false, strict: false },
        security: { disable: true },
        swagger: { disable: false, path: '/docs' },
        error: { disable: false, printStackTrace: false }
    }
};

async function start() {
    await initialize(app, config);
    http.createServer(app).listen(serverPort, () => {
        console.log(`\nSearch API running at http://localhost:${serverPort}`);
        console.log('________________________________________________________________');
        console.log(`API docs (Swagger UI) available on http://localhost:${serverPort}/docs`);
        console.log('________________________________________________________________');
    });
}

start();
