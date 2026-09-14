const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const server = http.createServer((request, response) => {
  const pathname = new URL(request.url, 'http://127.0.0.1').pathname;
  if (!['/', '/index.html'].includes(pathname)) {
    response.writeHead(404).end('Not found');
    return;
  }
  fs.readFile(path.join(__dirname, 'index.html'), (error, content) => {
    if (error) {
      response.writeHead(500).end('Unable to read index.html');
      return;
    }
    response.writeHead(200, {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    });
    response.end(content);
  });
});
server.on('error', error => {
  console.error(error.code === 'EADDRINUSE'
    ? 'Port 8765 is already in use. If this app is running, open http://127.0.0.1:8765/.'
    : error.message);
  process.exitCode = 1;
});
server.listen(8765, '127.0.0.1', () => {
  console.log('SHA3-256: http://127.0.0.1:8765/');
  console.log('Press Ctrl+C to stop.');
});
