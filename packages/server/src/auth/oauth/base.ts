/**
 * Base OAuth handler abstract class
 * @packageDocumentation
 */

import type { OAuthSession, TokenStore } from "../../store/types.js";
import type { OAuthConfig, OAuthHandler, OAuthStartResult } from "../types.js";
import type { StoredAuthFile } from "../../store/types.js";
import {
	buildAuthorizationURL,
	exchangeCodeForTokens,
	generateCodeChallenge,
	generateCodeVerifier,
	generateState,
} from "./pkce.js";

/**
 * Session expiry time in milliseconds (10 minutes)
 */
const SESSION_EXPIRY_MS = 10 * 60 * 1000;

/**
 * Abstract base class for OAuth handlers
 */
export abstract class BaseOAuthHandler implements OAuthHandler {
	protected config: OAuthConfig;
	protected store: TokenStore;
	protected port: number;

	constructor(config: OAuthConfig, store: TokenStore, port: number) {
		this.config = config;
		this.store = store;
		this.port = port;

		// Replace PORT placeholder in redirect URI
		this.config.redirectUri = this.config.redirectUri.replace(
			"PORT",
			String(port),
		);
	}

	/**
	 * Get the provider name
	 */
	abstract getProviderName(): string;

	/**
	 * Create an auth file from tokens - implemented by each provider
	 */
	protected abstract createAuthFile(
		accessToken: string,
		refreshToken: string | undefined,
		expiresAt: Date | undefined,
		raw: Record<string, unknown>,
	): Promise<StoredAuthFile>;

	/**
	 * Start OAuth flow
	 */
	async startOAuth(): Promise<OAuthStartResult> {
		const state = generateState();

		let codeVerifier: string | undefined;
		let codeChallenge: string | undefined;

		if (this.config.usePKCE) {
			codeVerifier = generateCodeVerifier();
			codeChallenge = await generateCodeChallenge(codeVerifier);
		}

		const url = await buildAuthorizationURL({
			authorizationEndpoint: this.config.authorizationEndpoint,
			clientId: this.config.clientId,
			redirectUri: this.config.redirectUri,
			scopes: this.config.scopes,
			state,
			codeChallenge,
			codeChallengeMethod: this.config.usePKCE ? "S256" : undefined,
			extraParams: this.getExtraAuthParams(),
		});

		// Store pending session
		const session: OAuthSession = {
			state,
			codeVerifier: codeVerifier || "",
			provider: this.getProviderName(),
			createdAt: new Date(),
			expiresAt: new Date(Date.now() + SESSION_EXPIRY_MS),
		};

		await this.store.savePendingSession(session);

		return { url, state };
	}

	/**
	 * Get extra authorization URL parameters (override for provider-specific params)
	 */
	protected getExtraAuthParams(): Record<string, string> | undefined {
		return undefined;
	}

	/**
	 * Handle OAuth callback
	 */
	async handleCallback(code: string, state: string): Promise<StoredAuthFile> {
		// Get and validate session
		const session = await this.store.getPendingSession(state);
		if (!session) {
			throw new Error("Invalid or expired OAuth session");
		}

		if (session.provider !== this.getProviderName()) {
			throw new Error(`Session provider mismatch: expected ${this.getProviderName()}, got ${session.provider}`);
		}

		try {
			// Exchange code for tokens
			const tokens = await exchangeCodeForTokens({
				tokenEndpoint: this.config.tokenEndpoint,
				clientId: this.config.clientId,
				clientSecret: this.config.clientSecret || undefined,
				code,
				redirectUri: this.config.redirectUri,
				codeVerifier: this.config.usePKCE ? session.codeVerifier : undefined,
			});

			// Calculate expiry
			let expiresAt: Date | undefined;
			if (tokens.expiresIn) {
				expiresAt = new Date(Date.now() + tokens.expiresIn * 1000);
			}

			// Create auth file
			const authFile = await this.createAuthFile(
				tokens.accessToken,
				tokens.refreshToken,
				expiresAt,
				tokens.raw,
			);

			// Save to store
			await this.store.saveAuthFile(authFile);

			// Cleanup session
			await this.store.deletePendingSession(state);

			return authFile;
		} catch (error) {
			// Cleanup session on error
			await this.store.deletePendingSession(state);
			throw error;
		}
	}

	/**
	 * Refresh an auth file's token - must be implemented by each provider
	 */
	abstract refreshToken(authFile: StoredAuthFile): Promise<StoredAuthFile>;

	/**
	 * Generate a unique ID for an auth file
	 */
	protected generateAuthFileId(): string {
		return `${this.getProviderName()}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
	}
}
