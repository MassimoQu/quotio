/**
 * Kiro (AWS CodeWhisperer) OAuth handler
 * @packageDocumentation
 */

import type { StoredAuthFile, TokenStore } from "../../store/types.js";
import type { OAuthConfig, OAuthStartResult } from "../types.js";
import { BaseOAuthHandler } from "./base.js";

/**
 * Kiro OAuth configuration
 * Uses AWS Builder ID authentication
 */
const KIRO_CONFIG: OAuthConfig = {
	clientId: "builderIdPublicClient",
	clientSecret: "",
	authorizationEndpoint: "https://kiro.dev/api/sso/v1/login",
	tokenEndpoint: "https://kiro.dev/api/sso/v1/token",
	scopes: ["codewhisperer:conversations", "codewhisperer:completions"],
	redirectUri: "http://localhost:PORT/kiro/callback",
	usePKCE: true,
};

/**
 * Kiro OAuth handler
 */
export class KiroOAuthHandler extends BaseOAuthHandler {
	constructor(store: TokenStore, port: number) {
		super({ ...KIRO_CONFIG }, store, port);
	}

	getProviderName(): string {
		return "kiro";
	}

	/**
	 * Start OAuth - Kiro uses incognito for multi-account support
	 */
	override async startOAuth(): Promise<OAuthStartResult> {
		const result = await super.startOAuth();
		return {
			...result,
			incognito: true, // Open in incognito for multi-account
		};
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
		const now = new Date().toISOString();

		return {
			id: this.generateAuthFileId(),
			provider: this.getProviderName(),
			createdAt: now,
			updatedAt: now,
			accessToken,
			refreshToken,
			expiresAt: expiresAt?.toISOString(),
			region: "us-east-1", // Kiro only operates in us-east-1
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

		const response = await fetch(this.config.tokenEndpoint, {
			method: "POST",
			headers: {
				"Content-Type": "application/x-www-form-urlencoded",
			},
			body: new URLSearchParams({
				grant_type: "refresh_token",
				refresh_token: authFile.refreshToken,
				client_id: this.config.clientId,
			}),
		});

		if (!response.ok) {
			const error = await response.text();
			throw new Error(`Token refresh failed: ${error}`);
		}

		const data = (await response.json()) as Record<string, unknown>;

		let expiresAt: string | undefined;
		const expiresIn = data.expires_in as number | undefined;
		if (expiresIn) {
			expiresAt = new Date(Date.now() + expiresIn * 1000).toISOString();
		}

		const updated: StoredAuthFile = {
			...authFile,
			accessToken: data.access_token as string,
			refreshToken: (data.refresh_token as string) || authFile.refreshToken,
			expiresAt,
			updatedAt: new Date().toISOString(),
			status: "ready",
		};

		await this.store.saveAuthFile(updated);
		return updated;
	}
}
