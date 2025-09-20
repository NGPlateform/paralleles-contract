// WebSocket testing example for NGP project (fixed)
import WS from 'jest-websocket-mock';

const waitForExactMessageAfterSend = (ws: WebSocket, expected: string, send: () => void): Promise<void> => {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('timeout waiting exact message')), 3000);
    const onMessage = (event: MessageEvent) => {
      try {
        if (event.data === expected) {
          clearTimeout(timer);
          ws.removeEventListener('message', onMessage as any);
          resolve();
        }
      } catch (e) {
        clearTimeout(timer);
        ws.removeEventListener('message', onMessage as any);
        reject(e);
      }
    };
    ws.addEventListener('message', onMessage as any);
    ws.addEventListener('error', (err) => {
      clearTimeout(timer);
      ws.removeEventListener('message', onMessage as any);
      reject(err as any);
    }, { once: true } as any);
    // Trigger the send after listeners are attached
    send();
  });
};

describe('WebSocket Tests for NGP Project', () => {
  let server: WS;
  let client: WebSocket;

  beforeEach(() => {
    server = new WS('ws://localhost:8080');
  });

  afterEach(() => {
    try {
      if (client && client.readyState === WebSocket.OPEN) client.close();
    } finally {
      WS.clean();
    }
  });

  test('connects successfully', async () => {
    client = new WebSocket('ws://localhost:8080');
    await server.connected;
    expect(server).toHaveReceivedMessages([]);
    expect(client.readyState).toBe(WebSocket.OPEN);
  });

  test('broadcasts blockchain event', async () => {
    client = new WebSocket('ws://localhost:8080');
    const socket: any = await server.connected;

    const payload = { type: 'ClaimMint', data: { meshID: 'E12147N3123' } };
    const text = JSON.stringify(payload);
    await waitForExactMessageAfterSend(client, text, () => socket.send(text));
  });

  test('heatmap updates', async () => {
    client = new WebSocket('ws://localhost:8080');
    const socket: any = await server.connected;
    const payload = { type: 'heatmap_update', data: { meshID: 'E12147N3123', coordinates: { lat: 31.23 } } };
    const text = JSON.stringify(payload);
    await waitForExactMessageAfterSend(client, text, () => socket.send(text));
  });

  test('transaction confirmations', async () => {
    client = new WebSocket('ws://localhost:8080');
    const socket: any = await server.connected;
    const payload = { type: 'transaction_confirmed', data: { status: 'success' } };
    const text = JSON.stringify(payload);
    await waitForExactMessageAfterSend(client, text, () => socket.send(text));
  });

  test('client to server message', async () => {
    client = new WebSocket('ws://localhost:8080');
    await server.connected;
    const subscription = { type: 'subscribe', data: { user: '0xabc...' } };
    client.send(JSON.stringify(subscription));
    await expect(server).toReceiveMessage(JSON.stringify(subscription));
  });

  test('multiple clients', async () => {
    const sockets: any[] = [];
    server.on('connection', (s: any) => sockets.push(s));

    const c1 = new WebSocket('ws://localhost:8080');
    const c2 = new WebSocket('ws://localhost:8080');
    // wait for both connections
    await new Promise<void>((resolve) => {
      const check = () => {
        if (sockets.length === 2) resolve();
        else setTimeout(check, 0);
      };
      check();
    });
    const payload = { type: 'global_announcement', data: { message: 'hi' } };
    const text = JSON.stringify(payload);

    const waitOn = (ws: WebSocket, expected: string) => new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('timeout waiting exact message')), 3000);
      const onMessage = (event: MessageEvent) => {
        if (event.data === expected) {
          clearTimeout(timer);
          ws.removeEventListener('message', onMessage as any);
          resolve();
        }
      };
      ws.addEventListener('message', onMessage as any);
    });

    const p1 = waitOn(c1, text);
    const p2 = waitOn(c2, text);
    sockets.forEach(s => s.send(text));
    await Promise.all([p1, p2]);
    c1.close();
    c2.close();
  });

  test('mining rewards updates', async () => {
    client = new WebSocket('ws://localhost:8080');
    const socket: any = await server.connected;
    const payload = { type: 'mining_reward', data: { dailyReward: '100.5' } };
    const text = JSON.stringify(payload);
    await waitForExactMessageAfterSend(client, text, () => socket.send(text));
  });
});
