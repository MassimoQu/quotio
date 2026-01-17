/**
 * File-based token store implementation
 * @packageDocumentation
 */

import { mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";
import {
	type OAuthSession,
	type StorageConfig,
	type StoredAuthFile,
	StoredAuthFileSchema,
	type TokenStore,
} from "./types.js";

/**
 * Expands ~ to home directory
 */
function expandPath(path: string): string {
	if (path.startsWith("~")) {
		const home = process.env.HOME || process.env.USERPROFILE || "";
		return join(home, path.slice(1));
	}
	return path;
}

/**
 * File-based implementation of TokenStore
 * Stores auth files as JSON files in a directory
 */
export class FileTokenStore implements TokenStore {
	private authDir: string;
	private sessionsDir: string;
	private pendingSessions: Map<string, OAuthSession> = new Map();

	constructor(config: StorageConfig) {
		this.authDir = expandPath(config.authDir);
		this.sessionsDir = join(expandPath(config.configDir), "sessions");
	}

	/**
	 * Ensure directories exist
	 */
	private async ensureDirs(): Promise<void> {
		await mkdir(this.authDir, { recursive: true });
		await mkdir(this.sessionsDir, { recursive: true });
	}

	/**
	 * Get file path for an auth file
	 */
	private getAuthFilePath(id: string): string {
		// Sanitize ID to prevent path traversal
		const sanitizedId = id.replace(/[^a-zA-Z0-9-_]/g, "_");
		return join(this.authDir, `${sanitizedId}.json`);
	}

	async listAuthFiles(): Promise<StoredAuthFile[]> {
		await this.ensureDirs();

		const files: StoredAuthFile[] = [];

		if (!existsSync(this.authDir)) {
			return files;
		}

		const entries = await readdir(this.authDir, { withFileTypes: true });

		for (const entry of entries) {
			if (entry.isFile() && entry.name.endsWith(".json")) {
				try {
					const filePath = join(this.authDir, entry.name);
					const content = await readFile(filePath, "utf-8");
					const data = JSON.parse(content);
					const parsed = StoredAuthFileSchema.safeParse(data);

					if (parsed.success) {
						files.push(parsed.data);
					} else {
						console.warn(
							`Skipping invalid auth file ${entry.name}:`,
							parsed.error.message,
						);
					}
				} catch (error) {
					console.warn(`Error reading auth file ${entry.name}:`, error);
				}
			}
		}

		// Sort by updatedAt descending
		files.sort((a, b) => {
			const dateA = new Date(a.updatedAt).getTime();
			const dateB = new Date(b.updatedAt).getTime();
			return dateB - dateA;
		});

		return files;
	}

	async getAuthFile(id: string): Promise<StoredAuthFile | null> {
		const filePath = this.getAuthFilePath(id);

		if (!existsSync(filePath)) {
			return null;
		}

		try {
			const content = await readFile(filePath, "utf-8");
			const data = JSON.parse(content);
			const parsed = StoredAuthFileSchema.safeParse(data);

			if (parsed.success) {
				return parsed.data;
			}

			console.warn(`Invalid auth file format for ${id}`);
			return null;
		} catch (error) {
			console.warn(`Error reading auth file ${id}:`, error);
			return null;
		}
	}

	async saveAuthFile(authFile: StoredAuthFile): Promise<void> {
		await this.ensureDirs();

		const filePath = this.getAuthFilePath(authFile.id);
		const content = JSON.stringify(authFile, null, 2);

		await writeFile(filePath, content, "utf-8");
	}

	async deleteAuthFile(id: string): Promise<void> {
		const filePath = this.getAuthFilePath(id);

		if (existsSync(filePath)) {
			await rm(filePath);
		}
	}

	async deleteAuthFilesByProvider(provider: string): Promise<void> {
		const files = await this.listAuthFiles();

		for (const file of files) {
			if (file.provider === provider) {
				await this.deleteAuthFile(file.id);
			}
		}
	}

	async updateStatus(
		id: string,
		status: StoredAuthFile["status"],
		statusMessage?: string,
	): Promise<void> {
		const authFile = await this.getAuthFile(id);

		if (authFile) {
			authFile.status = status;
			authFile.statusMessage = statusMessage;
			authFile.updatedAt = new Date().toISOString();
			await this.saveAuthFile(authFile);
		}
	}

	async setCooldown(id: string, until: Date, reason: string): Promise<void> {
		const authFile = await this.getAuthFile(id);

		if (authFile) {
			authFile.status = "cooling";
			authFile.cooldownUntil = until.toISOString();
			authFile.cooldownReason = reason;
			authFile.updatedAt = new Date().toISOString();
			await this.saveAuthFile(authFile);
		}
	}

	async clearCooldown(id: string): Promise<void> {
		const authFile = await this.getAuthFile(id);

		if (authFile) {
			authFile.status = "ready";
			authFile.cooldownUntil = undefined;
			authFile.cooldownReason = undefined;
			authFile.updatedAt = new Date().toISOString();
			await this.saveAuthFile(authFile);
		}
	}

	async savePendingSession(session: OAuthSession): Promise<void> {
		this.pendingSessions.set(session.state, session);

		// Also persist to disk for recovery
		await this.ensureDirs();
		const filePath = join(this.sessionsDir, `${session.state}.json`);
		const content = JSON.stringify(session, null, 2);
		await writeFile(filePath, content, "utf-8");
	}

	async getPendingSession(state: string): Promise<OAuthSession | null> {
		// Check memory first
		const memSession = this.pendingSessions.get(state);
		if (memSession) {
			if (new Date() > memSession.expiresAt) {
				await this.deletePendingSession(state);
				return null;
			}
			return memSession;
		}

		// Check disk
		const filePath = join(this.sessionsDir, `${state}.json`);
		if (!existsSync(filePath)) {
			return null;
		}

		try {
			const content = await readFile(filePath, "utf-8");
			const data = JSON.parse(content);

			const session: OAuthSession = {
				...data,
				createdAt: new Date(data.createdAt),
				expiresAt: new Date(data.expiresAt),
			};

			if (new Date() > session.expiresAt) {
				await this.deletePendingSession(state);
				return null;
			}

			// Cache in memory
			this.pendingSessions.set(state, session);
			return session;
		} catch (error) {
			console.warn(`Error reading session ${state}:`, error);
			return null;
		}
	}

	async deletePendingSession(state: string): Promise<void> {
		this.pendingSessions.delete(state);

		const filePath = join(this.sessionsDir, `${state}.json`);
		if (existsSync(filePath)) {
			await rm(filePath);
		}
	}

	async cleanupExpiredSessions(): Promise<void> {
		const now = new Date();

		// Cleanup memory
		for (const [state, session] of this.pendingSessions) {
			if (now > session.expiresAt) {
				this.pendingSessions.delete(state);
			}
		}

		// Cleanup disk
		if (!existsSync(this.sessionsDir)) {
			return;
		}

		const entries = await readdir(this.sessionsDir, { withFileTypes: true });

		for (const entry of entries) {
			if (entry.isFile() && entry.name.endsWith(".json")) {
				try {
					const filePath = join(this.sessionsDir, entry.name);
					const content = await readFile(filePath, "utf-8");
					const data = JSON.parse(content);
					const expiresAt = new Date(data.expiresAt);

					if (now > expiresAt) {
						await rm(filePath);
					}
				} catch (error) {
					// Ignore errors during cleanup
				}
			}
		}
	}
}
