import { chmodSync, existsSync, unlinkSync } from "node:fs";
import { mkdir } from "node:fs/promises";
import { dirname } from "node:path";
import type {
	Socket,
	SocketListener,
	TCPSocketListener,
	UnixSocketListener,
} from "bun";
import { logger } from "../utils/logger.ts";
import {
	type IPCConnectionInfo,
	getIPCConnectionInfo,
} from "../utils/paths.ts";
import {
	ErrorCodes,
	type JsonRpcErrorResponse,
	type JsonRpcRequest,
	type JsonRpcResponse,
	createErrorResponse,
	createMessageParser,
	createSuccessResponse,
	encodeMessage,
	parseRequest,
} from "./protocol.ts";

export type MethodHandler = (params: unknown) => Promise<unknown>;

interface ClientConnection {
	socket: Socket<SocketData>;
	connectedAt: Date;
}

interface SocketData {
	parser: (chunk: Buffer | string) => void;
	pendingWrites: Uint8Array[];
	isWriting: boolean;
}
type IPCServer = TCPSocketListener<SocketData> | UnixSocketListener<SocketData>;

interface IPCServerState {
	running: boolean;
	connectionInfo: IPCConnectionInfo | null;
	connections: Map<number, ClientConnection>;
	handlers: Map<string, MethodHandler>;
	server: IPCServer | null;
}

const state: IPCServerState = {
	running: false,
	connectionInfo: null,
	connections: new Map(),
	handlers: new Map(),
	server: null,
};

let connectionIdCounter = 0;

export function registerHandler(method: string, handler: MethodHandler): void {
	state.handlers.set(method, handler);
}

export function registerHandlers(
	handlers: Record<string, MethodHandler>,
): void {
	for (const [method, handler] of Object.entries(handlers)) {
		state.handlers.set(method, handler);
	}
}

async function handleRequest(
	request: JsonRpcRequest,
): Promise<JsonRpcResponse> {
	const handler = state.handlers.get(request.method);

	if (!handler) {
		return createErrorResponse(
			request.id,
			ErrorCodes.METHOD_NOT_FOUND,
			`Method not found: ${request.method}`,
		);
	}

	try {
		const result = await handler(request.params ?? {});
		return createSuccessResponse(request.id, result);
	} catch (error) {
		const message = error instanceof Error ? error.message : String(error);
		logger.error(`Handler error for ${request.method}: ${message}`);
		return createErrorResponse(request.id, ErrorCodes.INTERNAL_ERROR, message);
	}
}

function isJsonRpcErrorResponse(obj: unknown): obj is JsonRpcErrorResponse {
	return typeof obj === "object" && obj !== null && "error" in obj;
}

function processMessage(socket: Socket<SocketData>, rawMessage: string): void {
	const parsed = parseRequest(rawMessage);

	if (isJsonRpcErrorResponse(parsed)) {
		writeToSocket(socket, encodeMessage(parsed));
		return;
	}

	handleRequest(parsed)
		.then((response) => {
			writeToSocket(socket, encodeMessage(response));
		})
		.catch((error) => {
			const message = error instanceof Error ? error.message : String(error);
			writeToSocket(
				socket,
				encodeMessage(
					createErrorResponse(parsed.id, ErrorCodes.INTERNAL_ERROR, message),
				),
			);
		});
}

function flushPendingWrites(socket: Socket<SocketData>): void {
	const data = socket.data;
	if (data.isWriting || data.pendingWrites.length === 0) return;

	data.isWriting = true;

	while (data.pendingWrites.length > 0) {
		const chunk = data.pendingWrites[0];
		if (!chunk) break;

		const written = socket.write(chunk);

		if (written === 0) {
			break;
		}

		if (written < chunk.byteLength) {
			data.pendingWrites[0] = chunk.subarray(written);
			break;
		}

		data.pendingWrites.shift();
	}

	data.isWriting = false;
}

function writeToSocket(socket: Socket<SocketData>, message: string): void {
	const encoded = new TextEncoder().encode(message);
	socket.data.pendingWrites.push(encoded);
	flushPendingWrites(socket);
}

export async function startServer(): Promise<void> {
	if (state.running) {
		throw new Error("IPC server is already running");
	}

	const connInfo = getIPCConnectionInfo();
	state.connectionInfo = connInfo;

	const socketHandlers = {
		open(socket: Socket<SocketData>) {
			const connId = ++connectionIdCounter;
			const parser = createMessageParser((msg) => processMessage(socket, msg));
			socket.data = { parser, pendingWrites: [], isWriting: false };

			state.connections.set(connId, {
				socket,
				connectedAt: new Date(),
			});

			logger.debug("IPC client connected", { connId });
		},

		data(socket: Socket<SocketData>, buffer: Buffer) {
			socket.data.parser(buffer);
		},

		drain(socket: Socket<SocketData>) {
			flushPendingWrites(socket);
		},

		close(socket: Socket<SocketData>) {
			for (const [id, conn] of state.connections) {
				if (conn.socket === socket) {
					state.connections.delete(id);
					logger.debug("IPC client disconnected", { connId: id });
					break;
				}
			}
		},

		error(_socket: Socket<SocketData>, error: Error) {
			logger.error(`IPC socket error: ${error.message}`);
		},
	};

	if (connInfo.type === "unix") {
		const socketDir = dirname(connInfo.path);
		await mkdir(socketDir, { recursive: true });

		if (existsSync(connInfo.path)) {
			try {
				unlinkSync(connInfo.path);
			} catch {
				throw new Error(`Cannot remove existing socket at ${connInfo.path}`);
			}
		}

		state.server = Bun.listen<SocketData>({
			unix: connInfo.path,
			socket: socketHandlers,
		});

		try {
			chmodSync(connInfo.path, 0o600);
		} catch {
			logger.warn("Could not set socket permissions");
		}

		logger.info(`IPC server listening on unix:${connInfo.path}`);
	} else {
		state.server = Bun.listen<SocketData>({
			hostname: connInfo.host,
			port: connInfo.port,
			socket: socketHandlers,
		});

		logger.info(
			`IPC server listening on tcp:${connInfo.host}:${connInfo.port}`,
		);
	}

	state.running = true;
}

export async function stopServer(): Promise<void> {
	if (!state.running || !state.server) {
		return;
	}

	for (const [, conn] of state.connections) {
		try {
			conn.socket.end();
		} catch {}
	}
	state.connections.clear();

	state.server.stop();
	state.server = null;

	const connInfo = state.connectionInfo;
	if (connInfo?.type === "unix" && existsSync(connInfo.path)) {
		try {
			unlinkSync(connInfo.path);
		} catch {}
	}

	state.connectionInfo = null;
	state.running = false;
	logger.info("IPC server stopped");
}

export function isServerRunning(): boolean {
	return state.running;
}

export function getConnectionInfo(): IPCConnectionInfo | null {
	return state.connectionInfo;
}

export function getConnectionCount(): number {
	return state.connections.size;
}

export function broadcast(response: JsonRpcResponse): void {
	const message = encodeMessage(response);
	for (const [, conn] of state.connections) {
		try {
			writeToSocket(conn.socket, message);
		} catch {}
	}
}
