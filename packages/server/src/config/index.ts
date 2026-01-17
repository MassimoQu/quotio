/**
 * Configuration loader
 * Loads config from environment variables and config files
 */
import { homedir } from "node:os";
import { join } from "node:path";
import { ConfigSchema, type Config } from "./schema.ts";
import { DEFAULT_CONFIG } from "./defaults.ts";

export { ConfigSchema, DEFAULT_CONFIG };
export type { Config };

/**
 * Expand ~ to home directory
 */
function expandPath(path: string): string {
	if (path.startsWith("~")) {
		return join(homedir(), path.slice(1));
	}
	return path;
}

/**
 * Load configuration from environment and files
 */
export async function loadConfig(): Promise<Config> {
	// Start with defaults
	let config: Partial<Config> = { ...DEFAULT_CONFIG };

	// Override from environment variables
	if (Bun.env.HOST) config.host = Bun.env.HOST;
	if (Bun.env.PORT) config.port = Number(Bun.env.PORT);
	if (Bun.env.DEBUG === "true") config.debug = true;
	if (Bun.env.AUTH_DIR) config.authDir = Bun.env.AUTH_DIR;
	if (Bun.env.CONFIG_DIR) config.configDir = Bun.env.CONFIG_DIR;

	// Passthrough config from environment
	if (Bun.env.ENABLE_PASSTHROUGH === "false") {
		config.passthrough = { ...config.passthrough!, enabled: false };
	}
	if (Bun.env.CLI_PROXY_PORT) {
		config.passthrough = {
			...config.passthrough!,
			cliProxyPort: Number(Bun.env.CLI_PROXY_PORT),
		};
	}

	// Try to load config file
	const configPath = expandPath(
		config.configDir ?? DEFAULT_CONFIG.configDir,
	);
	const configFile = join(configPath, "server-config.json");

	try {
		const file = Bun.file(configFile);
		if (await file.exists()) {
			const fileConfig = await file.json();
			config = { ...config, ...fileConfig };
		}
	} catch {
		// Config file doesn't exist or is invalid, use defaults
	}

	// Validate and return
	const validated = ConfigSchema.parse(config);

	// Expand paths
	validated.authDir = expandPath(validated.authDir);
	validated.configDir = expandPath(validated.configDir);

	return validated;
}

/**
 * Get a single config value
 */
export function getConfigValue<K extends keyof Config>(
	config: Config,
	key: K,
): Config[K] {
	return config[key];
}
