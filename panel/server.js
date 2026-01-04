import express from 'express';
import Docker from 'dockerode';

const app = express();
const docker = new Docker({ socketPath: '/var/run/docker.sock' });

const RDS_CONTAINER_NAME = 'raft_rds';
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || 'changeme';

app.use(express.json());

// simple auth middleware for API routes
function auth(req, res, next) {
  const token = req.headers['x-admin-token'];
  if (token === ADMIN_TOKEN) return next();
  return res.status(401).json({ error: 'Unauthorized' });
}

// Home page UI
app.get('/', async (req, res) => {
  let status = 'unknown';

  try {
    const container = docker.getContainer(RDS_CONTAINER_NAME);
    const info = await container.inspect();
    status = info.State.Status;
  } catch (e) {
    status = 'not found';
  }

  res.send(`
    <html>
      <head>
        <title>Raft RDS Panel</title>
        <style>
          body { font-family: system-ui, sans-serif; padding: 20px; background: #050810; color: #e5e7eb; }
          h1 { margin-bottom: 0.5rem; }
          .status { margin-bottom: 1rem; }
          .pill { display: inline-block; padding: 2px 10px; border-radius: 999px; font-size: 0.9rem; }
          .pill-running { background: #16a34a33; color: #bbf7d0; border: 1px solid #16a34a; }
          .pill-stopped { background: #b91c1c33; color: #fecaca; border: 1px solid #b91c1c; }
          .pill-unknown { background: #374151; color: #e5e7eb; border: 1px solid #4b5563; }
          button { margin: 4px; padding: 8px 18px; border-radius: 999px; border: none; cursor: pointer; font-weight: 500; }
          button.start { background: #16a34a; color: #ecfdf5; }
          button.stop { background: #b91c1c; color: #fef2f2; }
          button.restart { background: #0ea5e9; color: #e0f2fe; }
          input { padding: 6px 10px; border-radius: 999px; border: 1px solid #4b5563; background:#020617; color:#e5e7eb; }
          pre { background:#020617; padding:10px; border-radius:8px; border:1px solid #1f2937; max-height:200px; overflow:auto; }
        </style>
      </head>
      <body>
        <h1>Raft RDS Panel</h1>
        <div class="status">
          Status:
          <span class="pill ${
            status === 'running'
              ? 'pill-running'
              : status === 'exited' || status === 'stopped'
              ? 'pill-stopped'
              : 'pill-unknown'
          }">
            ${status}
          </span>
        </div>

        <div>
          <input type="password" id="token" placeholder="Admin token (X-Admin-Token)" />
        </div>

        <div style="margin-top:10px;">
          <button class="start" onclick="callApi('start')">Start</button>
          <button class="stop" onclick="callApi('stop')">Stop</button>
          <button class="restart" onclick="callApi('restart')">Restart</button>
        </div>

        <pre id="output" style="margin-top:20px;"></pre>

        <script>
          async function callApi(action) {
            const token = document.getElementById('token').value;
            const res = await fetch('/api/' + action, {
              method: 'POST',
              headers: { 'X-Admin-Token': token }
            });
            const text = await res.text();
            document.getElementById('output').textContent = text;
          }
        </script>
      </body>
    </html>
  `);
});

app.post('/api/start', auth, async (req, res) => {
  try {
    const container = docker.getContainer(RDS_CONTAINER_NAME);
    await container.start();
    res.send('Started raft_rds');
  } catch (e) {
    res.status(500).send(String(e));
  }
});

app.post('/api/stop', auth, async (req, res) => {
  try {
    const container = docker.getContainer(RDS_CONTAINER_NAME);
    await container.stop();
    res.send('Stopped raft_rds');
  } catch (e) {
    res.status(500).send(String(e));
  }
});

app.post('/api/restart', auth, async (req, res) => {
  try {
    const container = docker.getContainer(RDS_CONTAINER_NAME);
    await container.restart();
    res.send('Restarted raft_rds');
  } catch (e) {
    res.status(500).send(String(e));
  }
});

const port = 3000;
app.listen(port, () => {
  console.log(\`RDS panel listening on port \${port}\`);
});
