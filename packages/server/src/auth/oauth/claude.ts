/**
 * Claude OAuth handler
 * @packageDocumentation
 */

import type { StoredAuthFile, TokenStore } from "../../store/types.js";
import type { OAuthConfig } from "../types.js";
import { decodeJWT, refreshAccessToken } from "./pkce.js";
import { BaseOAuthHandler } from "./base.js";

/**
 * Claude OAuth configuration
 * Public client - no secret required
 */
const CLAUDE_CONFIG: OAuthConfig = {
	clientId: "claude-cli",
	clientSecret: "",
	authorizationEndpoint: "https://console.anthropic.com/oauth/authorize",
	tokenEndpoint: "https://console.anthropic.com/v1/oauth/token",
	scopes: ["claude"],
	redirectUri: "http://localhost:PORT/anthropic/callback",
	usePKCE: true,
};

/**
 * Claude OAuth handler
 */
export class ClaudeOAuthHandler extends BaseOAuthHandler {
	constructor(store: TokenStore, port: number) {
		super({ ...CLAUDE_CONFIG }, store, port);
	}

	getProviderName(): string {
		return "claude";
	}

	/**
	 * Create auth file from tokens
	 */
	protected override async createAuthFile(
		accessToken: string,
		refreshToken: string | undefined,
		expiresAt: Date | undefined,
		_raw: Record<string, unknown>,
	): Promise<StoredAuthFile> {
		// Decode JWT to get email (Claude includes user info in the token)
		const claims = decodeJWT(accessToken);
		const email = (claims.email as string) || (claims.sub as string);

		const now = new Date().toISOString();

		return {
			id: this.generateAuthFileId(),
			provider: this.getProviderName(),
			email,
			name: email,
			createdAt: now,
			updatedAt: now,
			accessToken,
			refreshToken,
			expiresAt: expiresAt?.toISOString(),
			status: "ready",
			disabled: false,
		};
	}

	/**
	 * Refresh tokens
	 */
	async refreshToken(authFile: StoredAuthFile): Promise<StoredAuthFile> {
		// Claude uses long-lived tokens, rarely needs refresh
		if (!authFile.refreshToken) {
			throw new Error("No refresh token available");
		}

		const tokens = await refreshAccessToken({
			tokenEndpoint: this.config.tokenEndpoint,
			clientId: this.config.clientId,
			// No secret for public client
			refreshToken: authFile.refreshToken,
		});

		let expiresAt: string | undefined;
		if (tokens.expiresIn) {
			expiresAt = new Date(Date.now() + tokens.expiresIn * 1000).toISOString();
		}

		const updated: StoredAuthFile = {
			...authFile,
			accessToken: tokens.accessToken,
			refreshToken: tokens.refreshToken || authFile.refreshToken,
			expiresAt,
			updatedAt: new Date().toISOString(),
			status: "ready",
		};

		await this.store.saveAuthFile(updated);
		return updated;
	}
}
