const baseUrl = process.env.SERVICE_URL || "http://localhost:8080";

const endpoints = [
  "/health/live",
  "/health/ready",
  "/metrics"
];

for (const endpoint of endpoints) {
  const response = await fetch(`${baseUrl}${endpoint}`);

  if (!response.ok) {
    throw new Error(
      `Platform contract failed: ${endpoint} returned HTTP ${response.status}`
    );
  }

  console.log(`PASS ${endpoint} -> HTTP ${response.status}`);
}

console.log("Enterprise Platform service contract satisfied.");
