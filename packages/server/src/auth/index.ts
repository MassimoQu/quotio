/**
 * AuthManager - Unified authentication management
 * @packageDocumentation
 */

import type { Config } from "../config/index.js";
import type { TokenStore, StoredAuthFile } from "../store/types.js";
import type {
	OAuthHandler,
	DeviceCodeHandler,
	ServiceAccountHandler,
	OAuthStartResult,
	OAuthPollResult,
} from "./types.js";
import {
	GeminiOAuthHandler,
	ClaudeOAuthHandler,
	CodexOAuthHandler,
	KiroOAuthHandler,
	CopilotOAuthHandler,
	VertexAuthHandler,
} from "./oauth/index.js";

/**
 * Supported provider types
 */
export type ProviderType =
	| "gemini-cli"
	| "claude"
	| "codex"
	| "github-copilot"
	| "vertex"
	| "kiro";

/**
 * Unified auth manager for all providers
 */
export class AuthManager {
	private oauthHandlers: Map<string, OAuthHandler> = new Map();
	private deviceCodeHandlers: Map<string, DeviceCodeHandler> = new Map();
	private serviceAccountHandlers: Map<string, ServiceAccountHandler> =
		new Map();
	private store: TokenStore;
	private port: number;

	constructor(config: Config, store: TokenStore) {
		this.store = store;
		this.port = config.port;

		// Initialize OAuth handlers
		this.oauthHandlers.set(
			"gemini-cli",
			new GeminiOAuthHandler(store, this.port),
		);
		this.oauthHandlers.set("claude", new ClaudeOAuthHandler(store, this.port));
		this.oauthHandlers.set("codex", new CodexOAuthHandler(store, this.port));
		this.oauthHandlers.set("kiro", new KiroOAuthHandler(store, this.port));

		// Initialize Device Code handlers
		this.deviceCodeHandlers.set("github-copilot", new CopilotOAuthHandler(store));

		// Initialize Service Account handlers
		this.serviceAccountHandlers.set("vertex", new VertexAuthHandler(store));
	}

	// === Auth File Management ===

	/**
	 * List all stored auth files
	 */
	async listAuthFiles(): Promise<StoredAuthFile[]> {
		return this.store.listAuthFiles();
	}

	/**
	 * Get auth file by provider
	 */
	async getAuthFile(provider: string): Promise<StoredAuthFile | null> {
		const files = await this.store.listAuthFiles();
		return files.find((f) => f.provider === provider) ?? null;
	}

	/**
	 * Get auth file by ID
	 */
	async getAuthFileById(id: string): Promise<StoredAuthFile | null> {
		return this.store.getAuthFile(id);
	}

	/**
	 * Delete auth file by ID
	 */
	async deleteAuthFile(id: string): Promise<void> {
		return this.store.deleteAuthFile(id);
	}

	/**
	 * Delete all auth files for a provider
	 */
	async deleteAuthFilesByProvider(provider: string): Promise<void> {
		return this.store.deleteAuthFilesByProvider(provider);
	}

	// === OAuth Flow ===

	/**
	 * Start OAuth flow for a provider
	 */
	async startOAuth(provider: ProviderType): Promise<OAuthStartResult> {
		const handler = this.oauthHandlers.get(provider);
		if (!handler) {
			throw new Error(`No OAuth handler for provider: ${provider}`);
		}

		return handler.startOAuth();
	}

	/**
	 * Handle OAuth callback
	 */
	async handleCallback(
		provider: ProviderType,
		code: string,
		state: string,
	): Promise<StoredAuthFile> {
		const handler = this.oauthHandlers.get(provider);
		if (!handler) {
			throw new Error(`No OAuth handler for provider: ${provider}`);
		}

		return handler.handleCallback(code, state);
	}

	/**
	 * Get OAuth status by state
	 */
	async getOAuthStatus(
		state: string,
	): Promise<{ completed: boolean; authFile?: StoredAuthFile; error?: string }> {
		const session = await this.store.getPendingSession(state);

		if (!session) {
			return { completed: false, error: "Session not found" };
		}

		if (new Date() > session.expiresAt) {
			await this.store.deletePendingSession(state);
			return { completed: false, error: "Session expired" };
		}

		// Check if auth file was created for this session
		const files = await this.store.listAuthFiles();
		const authFile = files.find(
			(f) =>
				f.provider === session.provider &&
				new Date(f.createdAt) >= session.createdAt,
		);

		if (authFile) {
			await this.store.deletePendingSession(state);
			return { completed: true, authFile };
		}

		return { completed: false };
	}

	// === Device Code Flow ===

	/**
	 * Start Device Code flow
	 */
	async startDeviceFlow(provider: ProviderType): Promise<OAuthStartResult> {
		const handler = this.deviceCodeHandlers.get(provider);
		if (!handler) {
			throw new Error(`No Device Code handler for provider: ${provider}`);
		}

		return handler.startDeviceFlow();
	}

	/**
	 * Poll for Device Code token
	 */
	async pollDeviceCode(
		provider: ProviderType,
		deviceCode: string,
	): Promise<OAuthPollResult> {
		const handler = this.deviceCodeHandlers.get(provider);
		if (!handler) {
			throw new Error(`No Device Code handler for provider: ${provider}`);
		}

		return handler.pollForToken(deviceCode);
	}

	// === Service Account ===

	/**
	 * Import service account JSON
	 */
	async importServiceAccount(
		provider: ProviderType,
		json: string,
	): Promise<StoredAuthFile> {
		const handler = this.serviceAccountHandlers.get(provider);
		if (!handler) {
			throw new Error(`No Service Account handler for provider: ${provider}`);
		}

		return handler.importServiceAccount(json);
	}

	// === Token Refresh ===

	/**
	 * Refresh token if needed
	 */
	async refreshIfNeeded(authFile: StoredAuthFile): Promise<StoredAuthFile> {
		// Check if token is expired or about to expire (5 min buffer)
		if (authFile.expiresAt) {
			const expiresAt = new Date(authFile.expiresAt);
			const bufferMs = 5 * 60 * 1000;

			if (expiresAt.getTime() > Date.now() + bufferMs) {
				// Token still valid
				return authFile;
			}
		}

		// Token expired or expiring soon, try to refresh
		const provider = authFile.provider as ProviderType;

		// Try OAuth handler first
		const oauthHandler = this.oauthHandlers.get(provider);
		if (oauthHandler) {
			return oauthHandler.refreshToken(authFile);
		}

		// Try Device Code handler
		const deviceHandler = this.deviceCodeHandlers.get(provider);
		if (deviceHandler) {
			return deviceHandler.refreshToken(authFile);
		}

		// Try Service Account handler
		const saHandler = this.serviceAccountHandlers.get(provider);
		if (saHandler) {
			return saHandler.refreshToken(authFile);
		}

		throw new Error(`No refresh handler for provider: ${provider}`);
	}

	/**
	 * Get valid credential for a provider (refreshes if needed)
	 */
	async getValidCredential(
		provider: ProviderType,
	): Promise<StoredAuthFile | null> {
		const authFile = await this.getAuthFile(provider);
		if (!authFile) {
			return null;
		}

		if (authFile.disabled || authFile.status === "error") {
			return null;
		}

		try {
			return await this.refreshIfNeeded(authFile);
		} catch (error) {
			console.error(`Failed to refresh token for ${provider}:`, error);
			// Update status to error
			await this.store.updateStatus(
				authFile.id,
				"error",
				error instanceof Error ? error.message : "Refresh failed",
			);
			return null;
		}
	}

	// === Provider Info ===

	/**
	 * Get all OAuth providers
	 */
	getOAuthProviders(): ProviderType[] {
		return ["gemini-cli", "claude", "codex", "kiro"];
	}

	/**
	 * Get all Device Code providers
	 */
	getDeviceCodeProviders(): ProviderType[] {
		return ["github-copilot"];
	}

	/**
	 * Get all Service Account providers
	 */
	getServiceAccountProviders(): ProviderType[] {
		return ["vertex"];
	}

	/**
	 * Get all supported providers
	 */
	getAllProviders(): ProviderType[] {
		return [
			"gemini-cli",
			"claude",
			"codex",
			"github-copilot",
			"vertex",
			"kiro",
		];
	}

	/**
	 * Check if provider supports OAuth
	 */
	isOAuthProvider(provider: ProviderType): boolean {
		return this.oauthHandlers.has(provider);
	}

	/**
	 * Check if provider uses Device Code flow
	 */
	isDeviceCodeProvider(provider: ProviderType): boolean {
		return this.deviceCodeHandlers.has(provider);
	}

	/**
	 * Check if provider uses Service Account
	 */
	isServiceAccountProvider(provider: ProviderType): boolean {
		return this.serviceAccountHandlers.has(provider);
	}
}

// Re-export types
export * from "./types.js";
