/**
 * @quotio/server - Quotio Proxy Server
 *
 * TypeScript-native replacement for CLIProxyAPI written in Go.
 * Built with Hono for high-performance HTTP handling.
 *
 * @packageDocumentation
 */

import { loadConfig } from "./config/index.js";
import { createApp } from "./api/index.js";
import { FileTokenStore } from "./store/index.js";
import { AuthManager } from "./auth/index.js";
import * as os from "node:os";
import * as path from "node:path";

/**
 * Expand ~ to home directory
 */
function expandPath(p: string): string {
	if (p.startsWith("~/") || p === "~") {
		return path.join(os.homedir(), p.slice(1));
	}
	return p;
}

async function main() {
	// Load configuration
	const config = await loadConfig();

	// Expand paths
	const authDir = expandPath(config.authDir);
	const configDir = expandPath(config.configDir);

	// Initialize token store
	const store = new FileTokenStore({
		authDir,
		configDir,
	});

	// Initialize auth manager
	const authManager = new AuthManager(config, store);

	// Create Hono app
	const app = createApp({ config, authManager, store });

	// Start server
	const server = Bun.serve({
		port: config.port,
		hostname: config.host || "0.0.0.0",
		fetch: app.fetch,
	});

	console.log(`🚀 quotio-server v0.1.0`);
	console.log(`   Listening on http://${server.hostname}:${server.port}`);
	console.log(`   Auth directory: ${authDir}`);
	console.log(`   Config directory: ${configDir}`);
	console.log(`   Passthrough: ${config.passthrough.enabled ? `enabled (CLIProxyAPI @ :${config.passthrough.cliProxyPort})` : "disabled"}`);
	console.log(`   Debug: ${config.debug}`);
}

main().catch((err) => {
	console.error("Failed to start server:", err);
	process.exit(1);
});
