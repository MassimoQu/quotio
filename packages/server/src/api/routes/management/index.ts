/**
 * Management API routes
 *
 * Endpoints for server administration and monitoring.
 */
import { Hono } from "hono";
import type { Config } from "../../../config/index.ts";
import { healthRoutes } from "./health.ts";

interface ManagementRoutesDeps {
	config: Config;
}

export function managementRoutes(deps: ManagementRoutesDeps): Hono {
	const app = new Hono();

	// Mount health routes at /
	app.route("/", healthRoutes(deps));

	// Placeholder for auth file management (Phase 3+)
	app.get("/auth-files", (c) => {
		return c.json({
			error: {
				message: "Auth file management not yet implemented",
				type: "not_implemented",
			},
		}, 501);
	});

	// Placeholder for usage stats (Phase 6+)
	app.get("/usage", (c) => {
		return c.json({
			error: {
				message: "Usage statistics not yet implemented",
				type: "not_implemented",
			},
		}, 501);
	});

	// Placeholder for logs (Phase 6+)
	app.get("/logs", (c) => {
		return c.json({
			error: {
				message: "Logs not yet implemented",
				type: "not_implemented",
			},
		}, 501);
	});

	return app;
}
