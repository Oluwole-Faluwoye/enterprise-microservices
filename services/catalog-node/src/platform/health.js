export function registerHealthEndpoints(app) {
  app.get("/health/live", (_req, res) => {
    res.status(200).json({
      status: "UP"
    });
  });

  app.get("/health/ready", (_req, res) => {
    res.status(200).json({
      status: "READY"
    });
  });
}
