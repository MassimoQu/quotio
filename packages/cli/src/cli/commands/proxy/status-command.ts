import { ManagementAPIClient } from "../../../services/management-api.ts";
import {
	checkHealth,
	getProcessState,
	getProxyPid,
	isProxyRunning,
} from "../../../services/proxy-process/index.ts";
import { colors, formatJson, logger } from "../../../utils/index.ts";
import type { CLIContext, CommandResult } from "../../index.ts";

export async function proxyStatus(
	port: number,
	ctx: CLIContext,
): Promise<CommandResult> {
	try {
		const managedRunning = await isProxyRunning();
		const managedPid = await getProxyPid();
		const managedState = getProcessState();
		const healthy = await checkHealth(port);

		let config = null;
		if (healthy) {
			try {
				const client = new ManagementAPIClient({
					baseURL: `http://localhost:${port}`,
					authKey: "",
				});
				config = await client.fetchConfig();
			} catch {
				// intentionally empty - config fetch is optional
			}
		}

		const status = {
			process: {
				running: managedRunning || healthy,
				pid: managedPid,
				port: managedState.port || port,
				startedAt: managedState.startedAt?.toISOString() || null,
			},
			health: {
				healthy,
				url: `http://localhost:${port}`,
			},
			config: config
				? {
						debug: config.debug,
						routing: config.routing?.strategy ?? "round-robin",
					}
				: null,
		};

		if (ctx.format === "json") {
			logger.print(formatJson(status));
			return { success: true, data: status };
		}

		printProcessSection(
			managedRunning,
			healthy,
			managedPid,
			managedState,
			port,
		);
		logger.print("");
		printHealthSection(healthy, port, config);

		return { success: true, data: status };
	} catch (error) {
		const message = error instanceof Error ? error.message : String(error);
		return {
			success: false,
			message: `Failed to get server status: ${message}`,
		};
	}
}

function printProcessSection(
	managedRunning: boolean,
	healthy: boolean,
	managedPid: number | null,
	managedState: { port: number; startedAt: Date | null },
	port: number,
): void {
	logger.print(colors.bold("Server:"));
	if (managedRunning || healthy) {
		logger.print(`  Status: ${colors.green("Running")}`);
		logger.print(`  PID: ${managedPid ?? "unknown (external)"}`);
		logger.print(`  Port: ${managedState.port || port}`);
		if (managedState.startedAt) {
			logger.print(`  Started: ${managedState.startedAt.toLocaleString()}`);
		}
	} else {
		logger.print(`  Status: ${colors.red("Not running")}`);
	}
}

function printHealthSection(
	healthy: boolean,
	port: number,
	config: { debug?: boolean; routing?: { strategy?: string } } | null,
): void {
	logger.print(colors.bold("Health:"));
	if (healthy) {
		logger.print(`  Status: ${colors.green("Healthy")}`);
		logger.print(`  URL: http://localhost:${port}`);
		if (config) {
			logger.print(`  Debug: ${config.debug ? "enabled" : "disabled"}`);
			logger.print(`  Routing: ${config.routing?.strategy ?? "round-robin"}`);
		}
	} else {
		logger.print(`  Status: ${colors.red("Not responding")}`);
		logger.print(`  Expected URL: http://localhost:${port}`);
	}
}
