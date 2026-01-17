/**
 * Logging middleware
 */
import type { Context, Next } from "hono";

const LOG_LEVELS = {
	DEBUG: 0,
	INFO: 1,
	WARN: 2,
	ERROR: 3,
} as const;

let currentLevel: number = LOG_LEVELS.INFO;

export function setLogLevel(level: keyof typeof LOG_LEVELS): void {
	currentLevel = LOG_LEVELS[level];
}

function formatTime(): string {
	return new Date().toISOString();
}

function colorStatus(status: number): string {
	if (status >= 500) return `\x1b[31m${status}\x1b[0m`; // Red
	if (status >= 400) return `\x1b[33m${status}\x1b[0m`; // Yellow
	if (status >= 300) return `\x1b[36m${status}\x1b[0m`; // Cyan
	return `\x1b[32m${status}\x1b[0m`; // Green
}

export async function loggingMiddleware(
	c: Context,
	next: Next,
): Promise<Response | void> {
	const start = performance.now();
	const method = c.req.method;
	const path = c.req.path;

	await next();

	const status = c.res.status;
	const duration = (performance.now() - start).toFixed(2);

	if (currentLevel <= LOG_LEVELS.INFO) {
		console.log(
			`[${formatTime()}] ${method} ${path} ${colorStatus(status)} ${duration}ms`,
		);
	}
}
