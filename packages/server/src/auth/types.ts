/**
 * Auth types and interfaces
 * @packageDocumentation
 */

import type { StoredAuthFile } from "../store/types.js";

/**
 * OAuth configuration for a provider
 */
export interface OAuthConfig {
	clientId: string;
	clientSecret: string;
	authorizationEndpoint: string;
	tokenEndpoint: string;
	scopes: string[];
	redirectUri: string;
	/** Use PKCE (Proof Key for Code Exchange) */
	usePKCE: boolean;
}

/**
 * Token response from OAuth provider
 */
export interface TokenResponse {
	accessToken: string;
	refreshToken?: string;
	expiresIn?: number;
	expiresAt?: Date;
	tokenType?: string;
	scope?: string;
	/** Raw response data for provider-specific fields */
	raw?: Record<string, unknown>;
}

/**
 * OAuth start result
 */
export interface OAuthStartResult {
	url: string;
	state: string;
	/** For Device Code flow */
	deviceCode?: string;
	userCode?: string;
	verificationUri?: string;
	expiresIn?: number;
	interval?: number;
	/** Open in incognito for multi-account */
	incognito?: boolean;
}

/**
 * OAuth poll result for Device Code flow
 */
export interface OAuthPollResult {
	status: "pending" | "completed" | "expired" | "error";
	authFile?: StoredAuthFile;
	error?: string;
}

/**
 * User info from provider
 */
export interface UserInfo {
	email?: string;
	name?: string;
	id?: string;
	picture?: string;
	[key: string]: unknown;
}

/**
 * Base interface for OAuth handlers
 */
export interface OAuthHandler {
	/**
	 * Get the provider name
	 */
	getProviderName(): string;

	/**
	 * Start OAuth flow
	 */
	startOAuth(): Promise<OAuthStartResult>;

	/**
	 * Handle OAuth callback
	 */
	handleCallback(code: string, state: string): Promise<StoredAuthFile>;

	/**
	 * Refresh an auth file's token
	 */
	refreshToken(authFile: StoredAuthFile): Promise<StoredAuthFile>;
}

/**
 * Device Code OAuth handler interface
 */
export interface DeviceCodeHandler {
	/**
	 * Get the provider name
	 */
	getProviderName(): string;

	/**
	 * Start Device Code flow
	 */
	startDeviceFlow(): Promise<OAuthStartResult>;

	/**
	 * Poll for token (Device Code flow)
	 */
	pollForToken(deviceCode: string): Promise<OAuthPollResult>;

	/**
	 * Refresh an auth file's token
	 */
	refreshToken(authFile: StoredAuthFile): Promise<StoredAuthFile>;
}

/**
 * Service Account handler interface (for Vertex)
 */
export interface ServiceAccountHandler {
	/**
	 * Get the provider name
	 */
	getProviderName(): string;

	/**
	 * Import a service account JSON
	 */
	importServiceAccount(json: string): Promise<StoredAuthFile>;

	/**
	 * Refresh an auth file's token
	 */
	refreshToken(authFile: StoredAuthFile): Promise<StoredAuthFile>;
}

/**
 * Combined auth handler type
 */
export type AuthHandler =
	| OAuthHandler
	| DeviceCodeHandler
	| ServiceAccountHandler;

/**
 * Type guard for OAuth handler
 */
export function isOAuthHandler(handler: AuthHandler): handler is OAuthHandler {
	return "startOAuth" in handler && "handleCallback" in handler;
}

/**
 * Type guard for Device Code handler
 */
export function isDeviceCodeHandler(
	handler: AuthHandler,
): handler is DeviceCodeHandler {
	return "startDeviceFlow" in handler && "pollForToken" in handler;
}

/**
 * Type guard for Service Account handler
 */
export function isServiceAccountHandler(
	handler: AuthHandler,
): handler is ServiceAccountHandler {
	return "importServiceAccount" in handler;
}

/**
 * Credential tier for prioritization
 */
export type CredentialTier = "paid" | "free" | "unknown";

/**
 * Tier detection info
 */
export interface TierInfo {
	tier: CredentialTier;
	quotaResetInterval: "hourly" | "daily" | "weekly" | "monthly";
	maxQuota?: number;
}
