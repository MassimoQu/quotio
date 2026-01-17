/**
 * @quotio/server - Quotio Proxy Server
 *
 * TypeScript-native replacement for CLIProxyAPI written in Go.
 * Built with Hono for high-performance HTTP handling.
 *
 * @packageDocumentation
 */

import { loadConfig } from "./config/index.ts";
import { createApp } from "./api/index.ts";

async function main() {
	// Load configuration
	const config = await loadConfig();

	// Create Hono app
	const app = createApp({ config });

	// Start server
	const server = Bun.serve({
		port: config.port,
		hostname: config.host || "0.0.0.0",
		fetch: app.fetch,
	});

	console.log(`🚀 quotio-server v0.1.0`);
	console.log(`   Listening on http://${server.hostname}:${server.port}`);
	console.log(`   Passthrough: ${config.passthrough.enabled ? `enabled (CLIProxyAPI @ :${config.passthrough.cliProxyPort})` : "disabled"}`);
	console.log(`   Debug: ${config.debug}`);
}

main().catch((err) => {
	console.error("Failed to start server:", err);
	process.exit(1);
});
