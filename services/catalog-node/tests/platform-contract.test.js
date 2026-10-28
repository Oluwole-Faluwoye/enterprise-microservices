import { spawn } from "node:child_process";

const PORT = 8080;
const BASE_URL = `http://localhost:${PORT}`;

const endpoints = [
  "/health/live",
  "/health/ready",
  "/metrics"
];

const server = spawn("node", ["src/index.js"], {
  env: {
    ...process.env,
    PORT: String(PORT),
    SERVICE_NAME: "platform-contract-test"
  },
  stdio: ["ignore", "pipe", "pipe"]
});

let serverOutput = "";

server.stdout.on("data", (data) => {
  serverOutput += data.toString();
});

server.stderr.on("data", (data) => {
  serverOutput += data.toString();
});

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForServer(maxAttempts = 30) {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const response = await fetch(`${BASE_URL}/health/live`);

      if (response.status === 200) {
        return;
      }
    } catch {
      // Server is not ready yet.
    }

    await sleep(500);
  }

  throw new Error(
    `Node.js service did not become ready.\n${serverOutput}`
  );
}

try {
  await waitForServer();

  for (const endpoint of endpoints) {
    const response = await fetch(`${BASE_URL}${endpoint}`);

    if (response.status !== 200) {
      throw new Error(
        `${endpoint} returned HTTP ${response.status}`
      );
    }

    console.log(
      `PASS ${endpoint} -> HTTP ${response.status}`
    );
  }

  console.log(
    "Enterprise Platform service contract satisfied."
  );
} finally {
  server.kill("SIGTERM");
}