/**
 * Health check endpoints
 */
import { Hono } from "hono";
import type { Config } from "../../../config/index.ts";
import { checkCLIProxyHealth } from "../../middleware/passthrough.ts";

interface HealthRoutesDeps {
	config: Config;
}

export function healthRoutes(deps: HealthRoutesDeps): Hono {
	const app = new Hono();

	// Basic health check
	app.get("/health", async (c) => {
		const cliProxyHealthy = deps.config.passthrough.enabled
			? await checkCLIProxyHealth(deps.config.passthrough.cliProxyPort)
			: null;

		return c.json({
			status: "ok",
			version: "0.1.0",
			timestamp: new Date().toISOString(),
			services: {
				server: "ok",
				cliProxy: cliProxyHealthy === null ? "disabled" : cliProxyHealthy ? "ok" : "unavailable",
			},
		});
	});

	// Readiness probe
	app.get("/ready", async (c) => {
		// In future phases, check database, auth manager, etc.
		return c.json({ ready: true });
	});

	// Liveness probe
	app.get("/live", (c) => {
		return c.json({ alive: true });
	});

	return app;
}
