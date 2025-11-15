const http = require('http');

// Bind to 0.0.0.0 to accept connections from 'localhost' (Nginx proxy)
const hostname = '0.0.0.0';

// Listen on the port specified by the systemd service environment
const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.url}`);

  res.statusCode = 200;
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify({ message: 'Hello World from Node.js!' }));
});

server.listen(port, hostname, () => {
  console.log(`Server running at http://${hostname}:${port}/`);
});
