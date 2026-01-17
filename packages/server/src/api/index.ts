/**
 * Hono app factory
 *
 * Creates the main Hono application with all routes and middleware.
 */
import { Hono } from "hono";
import type { Config } from "../config/index.ts";
import { loggingMiddleware } from "./middleware/logging.ts";
import { corsMiddleware } from "./middleware/cors.ts";
import { createPassthroughMiddleware } from "./middleware/passthrough.ts";
import { v1Routes } from "./routes/v1/index.ts";
import { managementRoutes } from "./routes/management/index.ts";

export interface AppDependencies {
	config: Config;
}

export function createApp(deps: AppDependencies): Hono {
	const app = new Hono();

	// Global middleware
	app.use("*", loggingMiddleware);
	app.use("*", corsMiddleware);

	// Passthrough middleware (forwards unimplemented endpoints to CLIProxyAPI)
	const passthrough = createPassthroughMiddleware(deps.config);
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

	// OpenAI-compatible API (v1)
	app.route("/v1", v1Routes());

	// Management API
	app.route("/v0/management", managementRoutes(deps));

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
