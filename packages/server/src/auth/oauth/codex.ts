/**
 * Codex (OpenAI) OAuth handler
 * @packageDocumentation
 */

import type { StoredAuthFile, TokenStore } from "../../store/types.js";
import type { OAuthConfig } from "../types.js";
import { decodeJWT, refreshAccessToken } from "./pkce.js";
import { BaseOAuthHandler } from "./base.js";

/**
 * OpenAI Codex OAuth configuration
 * Uses OpenAI's platform OAuth
 */
const CODEX_CONFIG: OAuthConfig = {
	clientId: "app_live_xMF2yQKrWNkDwLaB",
	clientSecret: "",
	authorizationEndpoint: "https://auth.openai.com/authorize",
	tokenEndpoint: "https://auth.openai.com/oauth/token",
	scopes: ["openid", "profile", "email", "offline_access"],
	redirectUri: "http://localhost:PORT/codex/callback",
	usePKCE: true,
};

/**
 * Codex OAuth handler
 */
export class CodexOAuthHandler extends BaseOAuthHandler {
	constructor(store: TokenStore, port: number) {
		super({ ...CODEX_CONFIG }, store, port);
	}

	getProviderName(): string {
		return "codex";
	}

	/**
	 * Get extra auth params for OpenAI OAuth
	 */
	protected override getExtraAuthParams(): Record<string, string> {
		return {
			audience: "https://api.openai.com/v1",
		};
	}

	/**
	 * Create auth file from tokens
	 */
	protected override async createAuthFile(
		accessToken: string,
		refreshToken: string | undefined,
		expiresAt: Date | undefined,
		raw: Record<string, unknown>,
	): Promise<StoredAuthFile> {
		// Try to get email from ID token or access token
		let email: string | undefined;

		// Check for id_token in raw response
		const idToken = raw.id_token as string | undefined;
		if (idToken) {
			const claims = decodeJWT(idToken);
			email = claims.email as string | undefined;
		}

		// Fallback: try to decode access token
		if (!email) {
			const claims = decodeJWT(accessToken);
			email = (claims.email as string) || (claims.sub as string);
		}

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
		if (!authFile.refreshToken) {
			throw new Error("No refresh token available");
		}

		const tokens = await refreshAccessToken({
			tokenEndpoint: this.config.tokenEndpoint,
			clientId: this.config.clientId,
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
