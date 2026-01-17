/**
 * /v1/models endpoint
 *
 * Returns a static list of available models.
 * In future phases, this will dynamically reflect authenticated providers.
 */
import { Hono } from "hono";

// Static model list - will be dynamic in later phases
const STATIC_MODELS = [
	// Claude
	{
		id: "claude-sonnet-4-20250514",
		object: "model",
		created: 1700000000,
		owned_by: "anthropic",
	},
	{
		id: "claude-opus-4-20250514",
		object: "model",
		created: 1700000000,
		owned_by: "anthropic",
	},
	// Gemini
	{
		id: "gemini-2.5-pro",
		object: "model",
		created: 1700000000,
		owned_by: "google",
	},
	{
		id: "gemini-2.5-flash",
		object: "model",
		created: 1700000000,
		owned_by: "google",
	},
	// OpenAI
	{
		id: "gpt-4.1",
		object: "model",
		created: 1700000000,
		owned_by: "openai",
	},
	{
		id: "o3",
		object: "model",
		created: 1700000000,
		owned_by: "openai",
	},
];

export function modelsRoutes(): Hono {
	const app = new Hono();

	app.get("/models", (c) => {
		return c.json({
			object: "list",
			data: STATIC_MODELS,
		});
	});

	app.get("/models/:id", (c) => {
		const modelId = c.req.param("id");
		const model = STATIC_MODELS.find((m) => m.id === modelId);

		if (!model) {
			return c.json(
				{
					error: {
						message: `Model '${modelId}' not found`,
						type: "invalid_request_error",
						code: "model_not_found",
					},
				},
				404,
			);
		}

		return c.json(model);
	});

	return app;
}
