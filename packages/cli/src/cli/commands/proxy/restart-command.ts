import {
	getProcessState,
	restartProxy,
} from "../../../services/proxy-process/index.ts";
import { colors, formatJson, logger } from "../../../utils/index.ts";
import type { CLIContext, CommandResult } from "../../index.ts";

export async function proxyRestart(
	port: number,
	ctx: CLIContext,
): Promise<CommandResult> {
	try {
		logger.print("Restarting server...");
		await restartProxy(port);

		const state = getProcessState();
		if (ctx.format === "json") {
			logger.print(formatJson({ status: "restarted", ...state }));
		} else {
			logger.print(`${colors.green("✓")} Server restarted successfully`);
			logger.print(`  PID: ${state.pid}`);
			logger.print(`  Port: ${state.port}`);
		}

		return { success: true, data: { status: "restarted", ...state } };
	} catch (error) {
		const message = error instanceof Error ? error.message : String(error);
		logger.error(`Failed to restart server: ${message}`);
		return { success: false, message };
	}
}
