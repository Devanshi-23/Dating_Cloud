import http from 'node:http';
import { createApp } from './app.js';
import { config } from './config.js';
import { attachRealtime } from './realtime.js';

const app = createApp();
const server = http.createServer(app);
attachRealtime(server);

server.listen(config.port, '0.0.0.0', () => {
  console.log(`Dating Cloud API  http://localhost:${config.port}/api/v1`);
  console.log(`Socket.IO         ws://localhost:${config.port}/v1`);
  console.log(`Demo phone         ${config.demoPhone}`);
  console.log('OTP code           set in backend/.env (DEV_OTP_CODE). No SMS is sent.');
});
