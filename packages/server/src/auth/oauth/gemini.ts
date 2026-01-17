/**
 * Gemini CLI OAuth handler
 * @packageDocumentation
 */

import type { StoredAuthFile, TokenStore } from "../../store/types.js";
import type { OAuthConfig } from "../types.js";
import { refreshAccessToken } from "./pkce.js";
import { BaseOAuthHandler } from "./base.js";

/**
 * Gemini CLI OAuth configuration
 * Client ID and secret from the Gemini CLI official app
 */
const GEMINI_CONFIG: OAuthConfig = {
	clientId: "681255809395-oo8ft2oprdrnp9e3aqf6av3hmdib135j.apps.googleusercontent.com",
	clientSecret: "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",
	authorizationEndpoint: "https://accounts.google.com/o/oauth2/v2/auth",
	tokenEndpoint: "https://oauth2.googleapis.com/token",
	scopes: [
		"https://www.googleapis.com/auth/cloud-platform",
		"https://www.googleapis.com/auth/userinfo.email",
		"https://www.googleapis.com/auth/userinfo.profile",
	],
	redirectUri: "http://localhost:PORT/google/callback",
	usePKCE: true,
};

/**
 * Google user info response
 */
interface GoogleUserInfo {
	email?: string;
	name?: string;
	picture?: string;
	id?: string;
}

/**
 * Gemini CLI OAuth handler
 */
export class GeminiOAuthHandler extends BaseOAuthHandler {
	constructor(store: TokenStore, port: number) {
		super({ ...GEMINI_CONFIG }, store, port);
	}

	getProviderName(): string {
		return "gemini-cli";
	}

	/**
	 * Get extra auth params for Google OAuth
	 */
	protected override getExtraAuthParams(): Record<string, string> {
		return {
			access_type: "offline",
			prompt: "consent",
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
		// Fetch user info
		const userInfo = await this.fetchUserInfo(accessToken);

		const now = new Date().toISOString();

		return {
			id: this.generateAuthFileId(),
			provider: this.getProviderName(),
			email: userInfo.email,
			name: userInfo.name || userInfo.email,
			createdAt: now,
			updatedAt: now,
			accessToken,
			refreshToken,
			expiresAt: expiresAt?.toISOString(),
			status: "ready",
			disabled: false,
			// Store additional token data for refresh
			tokenData: {
				token_uri: this.config.tokenEndpoint,
				client_id: this.config.clientId,
				client_secret: this.config.clientSecret,
				scopes: this.config.scopes,
				...raw,
			},
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
			clientSecret: this.config.clientSecret,
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

	/**
	 * Fetch user info from Google
	 */
	private async fetchUserInfo(accessToken: string): Promise<GoogleUserInfo> {
		const response = await fetch(
			"https://www.googleapis.com/oauth2/v2/userinfo",
			{
				headers: {
					Authorization: `Bearer ${accessToken}`,
				},
			},
		);

		if (!response.ok) {
			console.warn("Failed to fetch user info:", response.statusText);
			return {};
		}

		return response.json() as Promise<GoogleUserInfo>;
	}
}
