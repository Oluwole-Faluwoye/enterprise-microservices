import express from "express";
import { registerHealthEndpoints } from "./platform/health.js";
import { registerMetricsEndpoint } from "./platform/metrics.js";

const app = express();
const port = process.env.PORT || 8080;

// Enterprise Platform runtime capabilities
registerHealthEndpoints(app);
registerMetricsEndpoint(app);

// Application routes
app.get("/", (_req, res) => {
  res.json({
    service: "orders-service",
    status: "running"
  });
});

const server = app.listen(port, () => {
  console.log(`orders-service listening on port ${port}`);
});

// Graceful shutdown
function shutdown(signal) {
  console.log(`${signal} received, shutting down...`);

  server.close(() => {
    console.log("orders-service stopped");
    process.exit(0);
  });
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
