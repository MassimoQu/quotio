/**
 * Management API routes
 *
 * Endpoints for server administration and monitoring.
 */
import { Hono } from "hono";
import type { Config } from "../../../config/index.js";
import type { AuthManager } from "../../../auth/index.js";
import { healthRoutes } from "./health.js";
import { oauthManagementRoutes } from "./oauth.js";

interface ManagementRoutesDeps {
	config: Config;
	authManager: AuthManager;
}

export function managementRoutes(deps: ManagementRoutesDeps): Hono {
	const app = new Hono();
	const { config, authManager } = deps;

	// Mount health routes at /
	app.route("/", healthRoutes({ config }));

	// Mount OAuth management routes
	app.route("/", oauthManagementRoutes({ authManager }));

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
