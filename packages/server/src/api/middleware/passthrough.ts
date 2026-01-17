/**
 * Proxy pass-through middleware
 *
 * Forwards requests to CLIProxyAPI (Go binary) for endpoints not yet
 * implemented natively. This enables incremental migration.
 */
import type { Context, Next } from "hono";
import type { Config } from "../../config/index.ts";

// Paths that should be forwarded to CLIProxyAPI
// Remove from this list as features are implemented natively
const PASSTHROUGH_PATHS = new Set([
	"/v1/messages", // Claude native format
	"/v1/chat/completions", // OpenAI format
	"/v1/completions", // Legacy completions
	"/anthropic/callback", // OAuth callbacks
	"/google/callback",
	"/kiro/callback",
	"/openai/callback",
	"/github/callback",
]);

// Prefixes that should be forwarded
const PASSTHROUGH_PREFIXES = [
	"/v1beta", // Gemini native format
];

/**
 * Check if CLIProxyAPI is running
 */
async function checkCLIProxyHealth(port: number): Promise<boolean> {
	try {
		const response = await fetch(`http://localhost:${port}/health`, {
			signal: AbortSignal.timeout(1000),
		});
		return response.ok;
	} catch {
		return false;
	}
}

/**
 * Forward request to CLIProxyAPI
 */
async function forwardRequest(
	c: Context,
	port: number,
	timeout: number,
): Promise<Response> {
	const targetUrl = `http://localhost:${port}${c.req.path}${c.req.url.includes("?") ? `?${c.req.url.split("?")[1]}` : ""}`;

	try {
		const headers = new Headers();
		c.req.raw.headers.forEach((value, key) => {
			// Skip hop-by-hop headers
			if (
				!["host", "connection", "keep-alive", "transfer-encoding"].includes(
					key.toLowerCase(),
				)
			) {
				headers.set(key, value);
			}
		});

		const response = await fetch(targetUrl, {
			method: c.req.method,
			headers,
			body: c.req.raw.body,
			duplex: "half",
			signal: AbortSignal.timeout(timeout * 1000),
		});

		// Stream response back with original headers
		const responseHeaders = new Headers();
		response.headers.forEach((value, key) => {
			responseHeaders.set(key, value);
		});

		return new Response(response.body, {
			status: response.status,
			headers: responseHeaders,
		});
	} catch (error) {
		const message = error instanceof Error ? error.message : String(error);

		// Check if it's a timeout
		if (message.includes("timeout") || message.includes("aborted")) {
			return c.json(
				{ error: "Request timeout", details: "CLIProxyAPI took too long" },
				504,
			);
		}

		// CLIProxyAPI not running or connection refused
		return c.json(
			{
				error: "Backend proxy unavailable",
				details: message,
				hint: "Make sure CLIProxyAPI is running on port " + port,
			},
			503,
		);
	}
}

/**
 * Create passthrough middleware with config
 */
export function createPassthroughMiddleware(config: Config) {
	const { enabled, cliProxyPort, timeout } = config.passthrough;

	return async function passthroughMiddleware(
		c: Context,
		next: Next,
	): Promise<Response | void> {
		// Skip if passthrough is disabled
		if (!enabled) {
			return next();
		}

		const path = c.req.path;

		// Check exact match
		if (PASSTHROUGH_PATHS.has(path)) {
			return forwardRequest(c, cliProxyPort, timeout);
		}

		// Check prefix match
		for (const prefix of PASSTHROUGH_PREFIXES) {
			if (path.startsWith(prefix)) {
				return forwardRequest(c, cliProxyPort, timeout);
			}
		}

		// Not a passthrough path, continue to native handlers
		return next();
	};
}

/**
 * Health check for CLIProxyAPI
 */
export { checkCLIProxyHealth };
