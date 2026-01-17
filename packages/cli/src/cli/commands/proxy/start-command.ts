import {
	getProcessState,
	isProxyRunning,
	startProxy,
} from "../../../services/proxy-process/index.ts";
import { colors, formatJson, logger } from "../../../utils/index.ts";
import type { CLIContext, CommandResult } from "../../index.ts";

export async function proxyStart(
	port: number,
	ctx: CLIContext,
): Promise<CommandResult> {
	try {
		const running = await isProxyRunning();
		if (running) {
			const state = getProcessState();
			if (ctx.format === "json") {
				logger.print(formatJson({ status: "already_running", ...state }));
			} else {
				logger.print(
					`${colors.yellow("Server is already running")} on port ${state.port}`,
				);
			}
			return { success: true, data: { status: "already_running", ...state } };
		}

		logger.print(`Starting server on port ${port}...`);
		await startProxy(port);

		const state = getProcessState();
		if (ctx.format === "json") {
			logger.print(formatJson({ status: "started", ...state }));
		} else {
			logger.print(`${colors.green("✓")} Server started successfully`);
			logger.print(`  PID: ${state.pid}`);
			logger.print(`  Port: ${state.port}`);
			logger.print(`  URL: http://localhost:${state.port}`);
		}

		return { success: true, data: { status: "started", ...state } };
	} catch (error) {
		const message = error instanceof Error ? error.message : String(error);
		logger.error(`Failed to start server: ${message}`);
		return { success: false, message };
	}
}
