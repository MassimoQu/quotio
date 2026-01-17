/**
 * v1 API routes
 *
 * OpenAI-compatible API endpoints.
 */
import { Hono } from "hono";
import { modelsRoutes } from "./models.ts";

export function v1Routes(): Hono {
	const app = new Hono();

	// Mount models routes
	app.route("/", modelsRoutes());

	// Placeholder for chat completions (Phase 4+)
	app.post("/chat/completions", (c) => {
		return c.json(
			{
				error: {
					message: "Chat completions not yet implemented - use passthrough",
					type: "not_implemented",
					code: "not_implemented",
				},
			},
			501,
		);
	});

	// Placeholder for Claude messages (Phase 5+)
	app.post("/messages", (c) => {
		return c.json(
			{
				error: {
					message: "Messages API not yet implemented - use passthrough",
					type: "not_implemented",
					code: "not_implemented",
				},
			},
			501,
		);
	});

	return app;
}
