/**
 * GitHub Copilot OAuth handler (Device Code flow)
 * @packageDocumentation
 */

import type { StoredAuthFile, TokenStore, OAuthSession } from "../../store/types.js";
import type { DeviceCodeHandler, OAuthPollResult, OAuthStartResult } from "../types.js";

/**
 * GitHub Copilot configuration
 */
const COPILOT_CONFIG = {
	clientId: "Iv1.b507a08c87ecfe98", // GitHub CLI client ID
	deviceCodeEndpoint: "https://github.com/login/device/code",
	tokenEndpoint: "https://github.com/login/oauth/access_token",
	scopes: ["copilot"],
};

/**
 * Device code session data
 */
interface DeviceCodeSession extends OAuthSession {
	deviceCode: string;
	userCode: string;
	verificationUri: string;
	pollInterval: number;
	expiresAt: Date;
}

/**
 * GitHub token for getting Copilot token
 */
interface CopilotTokenResponse {
	token: string;
	expires_at: number;
}

/**
 * Copilot OAuth handler using Device Code flow
 */
export class CopilotOAuthHandler implements DeviceCodeHandler {
	private store: TokenStore;

	constructor(store: TokenStore) {
		this.store = store;
	}

	getProviderName(): string {
		return "github-copilot";
	}

	/**
	 * Start Device Code flow
	 */
	async startDeviceFlow(): Promise<OAuthStartResult> {
		const response = await fetch(COPILOT_CONFIG.deviceCodeEndpoint, {
			method: "POST",
			headers: {
				Accept: "application/json",
				"Content-Type": "application/x-www-form-urlencoded",
			},
			body: new URLSearchParams({
				client_id: COPILOT_CONFIG.clientId,
				scope: COPILOT_CONFIG.scopes.join(" "),
			}),
		});

		if (!response.ok) {
			const error = await response.text();
			throw new Error(`Failed to start device flow: ${error}`);
		}

		const data = (await response.json()) as Record<string, unknown>;

		const deviceCode = data.device_code as string;
		const userCode = data.user_code as string;
		const verificationUri = data.verification_uri as string;
		const expiresIn = data.expires_in as number;
		const interval = data.interval as number;

		// Store session
		const session: DeviceCodeSession = {
			state: deviceCode, // Use device code as state for lookup
			codeVerifier: "",
			provider: this.getProviderName(),
			createdAt: new Date(),
			expiresAt: new Date(Date.now() + expiresIn * 1000),
			deviceCode,
			userCode,
			verificationUri,
			pollInterval: interval,
		};

		await this.store.savePendingSession(session);

		return {
			url: verificationUri,
			state: deviceCode,
			deviceCode,
			userCode,
			verificationUri,
			expiresIn,
			interval,
		};
	}

	/**
	 * Poll for token
	 */
	async pollForToken(deviceCode: string): Promise<OAuthPollResult> {
		// Validate session
		const session = await this.store.getPendingSession(deviceCode);
		if (!session) {
			return { status: "expired", error: "Session not found or expired" };
		}

		if (new Date() > session.expiresAt) {
			await this.store.deletePendingSession(deviceCode);
			return { status: "expired", error: "Device code expired" };
		}

		// Poll GitHub for token
		const response = await fetch(COPILOT_CONFIG.tokenEndpoint, {
			method: "POST",
			headers: {
				Accept: "application/json",
				"Content-Type": "application/x-www-form-urlencoded",
			},
			body: new URLSearchParams({
				client_id: COPILOT_CONFIG.clientId,
				device_code: deviceCode,
				grant_type: "urn:ietf:params:oauth:grant-type:device_code",
			}),
		});

		const data = (await response.json()) as Record<string, unknown>;

		// Check for pending authorization
		if (data.error === "authorization_pending") {
			return { status: "pending" };
		}

		// Check for slow down request
		if (data.error === "slow_down") {
			return { status: "pending" };
		}

		// Check for other errors
		if (data.error) {
			await this.store.deletePendingSession(deviceCode);
			return {
				status: "error",
				error: (data.error_description as string) || (data.error as string),
			};
		}

		// Success - exchange GitHub token for Copilot token
		const githubToken = data.access_token as string;

		try {
			const copilotToken = await this.getCopilotToken(githubToken);

			const now = new Date().toISOString();
			const authFile: StoredAuthFile = {
				id: `github-copilot-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
				provider: this.getProviderName(),
				createdAt: now,
				updatedAt: now,
				accessToken: copilotToken.token,
				expiresAt: new Date(copilotToken.expires_at * 1000).toISOString(),
				status: "ready",
				disabled: false,
				// Store GitHub token for refresh
				tokenData: {
					github_token: githubToken,
				},
			};

			await this.store.saveAuthFile(authFile);
			await this.store.deletePendingSession(deviceCode);

			return { status: "completed", authFile };
		} catch (error) {
			await this.store.deletePendingSession(deviceCode);
			return {
				status: "error",
				error: error instanceof Error ? error.message : "Failed to get Copilot token",
			};
		}
	}

	/**
	 * Refresh token
	 */
	async refreshToken(authFile: StoredAuthFile): Promise<StoredAuthFile> {
		const githubToken = authFile.tokenData?.github_token as string | undefined;
		if (!githubToken) {
			throw new Error("No GitHub token available for refresh");
		}

		const copilotToken = await this.getCopilotToken(githubToken);

		const updated: StoredAuthFile = {
			...authFile,
			accessToken: copilotToken.token,
			expiresAt: new Date(copilotToken.expires_at * 1000).toISOString(),
			updatedAt: new Date().toISOString(),
			status: "ready",
		};

		await this.store.saveAuthFile(updated);
		return updated;
	}

	/**
	 * Get Copilot token from GitHub token
	 */
	private async getCopilotToken(githubToken: string): Promise<CopilotTokenResponse> {
		const response = await fetch(
			"https://api.github.com/copilot_internal/v2/token",
			{
				headers: {
					Authorization: `token ${githubToken}`,
					"User-Agent": "GithubCopilot/1.0",
					Accept: "application/json",
				},
			},
		);

		if (!response.ok) {
			const error = await response.text();
			throw new Error(`Failed to get Copilot token: ${error}`);
		}

		return response.json() as Promise<CopilotTokenResponse>;
	}
}
