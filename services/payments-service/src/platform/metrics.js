import client from "prom-client";

const register = new client.Registry();

client.collectDefaultMetrics({
  register
});

export function registerMetricsEndpoint(app) {
  app.get("/metrics", async (_req, res) => {
    res.set("Content-Type", register.contentType);
    res.end(await register.metrics());
  });
}

export { register };
