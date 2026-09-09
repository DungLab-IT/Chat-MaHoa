const http = require('http');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');

const PORT = Number(process.env.PORT || 48485);
const PUBLIC_DIR = path.join(__dirname, 'public');
const clients = new Map();
const offlineQueue = new Map();

const allowedOrigins = new Set(
  (process.env.ALLOWED_ORIGINS || 'http://localhost,http://127.0.0.1')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
);

const httpServer = http.createServer((request, response) => {
  const requestPath = decodeURIComponent((request.url || '/').split('?')[0]);
  const relativePath = requestPath === '/'
    ? 'index.html'
    : requestPath.endsWith('/')
      ? `${requestPath.replace(/^\/+|\/+$/g, '')}/index.html`
      : requestPath.replace(/^\/+/, '');
  const filePath = path.resolve(PUBLIC_DIR, relativePath);

  if (!filePath.startsWith(`${PUBLIC_DIR}${path.sep}`)) {
    response.writeHead(403);
    response.end('Forbidden');
    return;
  }

  fs.stat(filePath, (error, fileInfo) => {
    if (error || !fileInfo.isFile()) {
      response.writeHead(404);
      response.end('Not found');
      return;
    }

    const contentTypes = {
      '.css': 'text/css; charset=utf-8',
      '.html': 'text/html; charset=utf-8',
      '.js': 'text/javascript; charset=utf-8',
      '.json': 'application/json; charset=utf-8',
      '.svg': 'image/svg+xml',
    };
    response.writeHead(200, {
      'Cache-Control': requestPath === '/' ? 'no-cache' : 'public, max-age=3600',
      'Content-Type': contentTypes[path.extname(filePath).toLowerCase()] || 'application/octet-stream',
    });
    fs.createReadStream(filePath).pipe(response);
  });
});

const server = new WebSocketServer({
  server: httpServer,
  verifyClient: ({ origin }) => {
    if (!origin || allowedOrigins.has('*')) return true;
    return [...allowedOrigins].some((allowed) => origin === allowed || origin.startsWith(`${allowed}:`));
  },
});

function sendJson(socket, message) {
  if (socket.readyState === socket.OPEN) {
    socket.send(JSON.stringify(message));
    return true;
  }
  return false;
}

function sendError(socket, message) {
  sendJson(socket, { type: 'ERROR', message });
}

function registerClient(socket, clientId) {
  const previousSocket = clients.get(clientId);
  if (previousSocket && previousSocket !== socket) {
    previousSocket.close(4001, 'Replaced by a new connection');
  }

  socket.clientId = clientId;
  clients.set(clientId, socket);
  console.log(`[REGISTER] ${clientId} connected (${clients.size} online)`);
  sendJson(socket, { type: 'REGISTERED', client_id: clientId });

  const pendingMessages = offlineQueue.get(clientId) || [];
  for (const message of pendingMessages) {
    sendJson(socket, message);
  }
  if (pendingMessages.length > 0) {
    console.log(`[QUEUE] delivered ${pendingMessages.length} message(s) to ${clientId}`);
    offlineQueue.delete(clientId);
  }
}

function forwardMessage(socket, message) {
  const { to, from, payload } = message;
  if (socket.clientId !== from) {
    sendError(socket, 'Sender is not registered or does not match the from field');
    return;
  }
  if (typeof to !== 'string' || typeof payload !== 'object' || payload === null) {
    sendError(socket, 'MESSAGE_FORWARD requires to and payload');
    return;
  }

  const forwardedMessage = {
    type: 'MESSAGE_FORWARD',
    to,
    from,
    ...(message.timestamp === undefined ? {} : { timestamp: message.timestamp }),
    payload,
  };
  const recipient = clients.get(to);
  if (recipient && sendJson(recipient, forwardedMessage)) {
    const payloadBytes = Buffer.byteLength(JSON.stringify(payload), 'utf8');
    console.log(`[FORWARD] ${from} -> ${to} (${payloadBytes} bytes, fields: ${Object.keys(payload).join(',')})`);
    return;
  }

  const queue = offlineQueue.get(to) || [];
  queue.push(forwardedMessage);
  offlineQueue.set(to, queue);
  const payloadBytes = Buffer.byteLength(JSON.stringify(payload), 'utf8');
  console.log(`[QUEUE] ${from} -> ${to} (${payloadBytes} bytes, fields: ${Object.keys(payload).join(',')}, ${queue.length} pending)`);
  sendJson(socket, { type: 'QUEUED', to });
}

server.on('connection', (socket) => {
  socket.clientId = null;
  console.log('[CONNECT] client connected');

  socket.on('message', (rawMessage) => {
    let message;
    try {
      message = JSON.parse(rawMessage.toString());
    } catch (error) {
      sendError(socket, 'Message must be valid JSON');
      return;
    }

    if (!message || typeof message.type !== 'string') {
      sendError(socket, 'Message type is required');
      return;
    }

    if (message.type === 'REGISTER') {
      if (typeof message.client_id !== 'string' || message.client_id.trim() === '') {
        sendError(socket, 'REGISTER requires a non-empty client_id');
        return;
      }
      registerClient(socket, message.client_id.trim());
      return;
    }

    if (message.type === 'MESSAGE_FORWARD') {
      if (!socket.clientId) {
        sendError(socket, 'Register before forwarding messages');
        return;
      }
      forwardMessage(socket, message);
      return;
    }

    sendError(socket, `Unsupported message type: ${message.type}`);
  });

  socket.on('close', () => {
    if (socket.clientId && clients.get(socket.clientId) === socket) {
      clients.delete(socket.clientId);
      console.log(`[DISCONNECT] ${socket.clientId} disconnected (${clients.size} online)`);
    } else {
      console.log('[DISCONNECT] unregistered client disconnected');
    }
  });

  socket.on('error', (error) => {
    console.error(`[SOCKET_ERROR] ${socket.clientId || 'unregistered'}: ${error.message}`);
  });
});

httpServer.listen(PORT, '0.0.0.0', () => {
  console.log(`LAN Secure Messenger portal and relay listening on port ${PORT}`);
});

httpServer.on('error', (error) => {
  console.error(`[SERVER_ERROR] ${error.message}`);
});