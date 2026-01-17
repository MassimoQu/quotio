/**
 * Hono app factory
 *
 * Creates the main Hono application with all routes and middleware.
 */
import { Hono } from "hono";
import type { Config } from "../config/index.js";
import type { AuthManager } from "../auth/index.js";
import type { TokenStore } from "../store/index.js";
import { loggingMiddleware } from "./middleware/logging.js";
import { corsMiddleware } from "./middleware/cors.js";
import { createPassthroughMiddleware } from "./middleware/passthrough.js";
import { v1Routes } from "./routes/v1/index.js";
import { managementRoutes } from "./routes/management/index.js";
import { oauthRoutes } from "./routes/oauth/index.js";

export interface AppDependencies {
	config: Config;
	authManager: AuthManager;
	store: TokenStore;
}

export function createApp(deps: AppDependencies): Hono {
	const app = new Hono();
	const { config, authManager, store } = deps;

	// Global middleware
	app.use("*", loggingMiddleware);
	app.use("*", corsMiddleware);

	// Passthrough middleware (forwards unimplemented endpoints to CLIProxyAPI)
	const passthrough = createPassthroughMiddleware(config);
	app.use("*", passthrough);

	// Root health check (simple)
	app.get("/health", (c) => {
		return c.json({
			status: "ok",
			version: "0.1.0",
			timestamp: new Date().toISOString(),
		});
	});

	// Version endpoint
	app.get("/version", (c) => {
		return c.json({
			version: "0.1.0",
			runtime: "bun",
			framework: "hono",
		});
	});

	// OAuth callback routes (at root level for provider redirects)
	app.route("/", oauthRoutes({ authManager }));

	// OpenAI-compatible API (v1)
	app.route("/v1", v1Routes());

	// Management API
	app.route("/v0/management", managementRoutes({ config, authManager }));

	// 404 handler
	app.notFound((c) => {
		return c.json(
			{
				error: {
					message: `Not Found: ${c.req.path}`,
					type: "invalid_request_error",
					code: "not_found",
				},
			},
			404,
		);
	});

	// Error handler
	app.onError((err, c) => {
		console.error(`[ERROR] ${c.req.method} ${c.req.path}:`, err);
		return c.json(
			{
				error: {
					message: err.message || "Internal server error",
					type: "server_error",
					code: "internal_error",
				},
			},
			500,
		);
	});

	return app;
}
