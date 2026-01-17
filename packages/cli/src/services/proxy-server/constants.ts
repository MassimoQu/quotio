/**
 * Constants for the TypeScript proxy server.
 * Replaces the Go CLIProxyAPI binary.
 */

export const DEFAULT_PROXY_PORT = 8317;
export const DEFAULT_MANAGEMENT_PORT = 18317;

export function getProxyDataDir(): string {
	const home = process.env.HOME ?? Bun.env.HOME ?? "";
	return `${home}/.quotio`;
}

export function getProxyLogDir(): string {
	return `${getProxyDataDir()}/logs`;
}

export function getProxyPidPath(): string {
	return `${getProxyDataDir()}/server.pid`;
}

export function getAuthDir(): string {
	const home = process.env.HOME ?? Bun.env.HOME ?? "";
	return `${home}/.cli-proxy-api`;
}

export function getConfigDir(): string {
	const home = process.env.HOME ?? Bun.env.HOME ?? "";
	return `${home}/.config/quotio`;
}
