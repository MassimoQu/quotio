/**
 * @quotio/server - Quotio Proxy Server
 *
 * TypeScript-native replacement for CLIProxyAPI written in Go.
 * Built with Hono for high-performance HTTP handling.
 *
 * @packageDocumentation
 */

import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";

const app = new Hono();

// Middleware
app.use("*", logger());
app.use("*", cors());

// Health check
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

// Placeholder for OpenAI-compatible API
app.all("/v1/*", (c) => {
	return c.json(
		{
			error: {
				message: "quotio-server is under development",
				type: "not_implemented",
				code: "not_implemented",
			},
		},
		501,
	);
});

// Start server
const port = Number(Bun.env.PORT ?? 18317);
const host = Bun.env.HOST ?? "127.0.0.1";

console.log(`🚀 quotio-server starting on http://${host}:${port}`);

export default {
	port,
	hostname: host,
	fetch: app.fetch,
};
