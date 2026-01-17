/**
 * Vertex AI Service Account handler
 * @packageDocumentation
 */

import type { StoredAuthFile, TokenStore } from "../../store/types.js";
import type { ServiceAccountHandler } from "../types.js";

/**
 * Google Cloud service account structure
 */
interface ServiceAccount {
	type: string;
	project_id: string;
	private_key_id: string;
	private_key: string;
	client_email: string;
	client_id: string;
	auth_uri: string;
	token_uri: string;
	auth_provider_x509_cert_url: string;
	client_x509_cert_url: string;
}

/**
 * Vertex AI Service Account handler
 */
export class VertexAuthHandler implements ServiceAccountHandler {
	private store: TokenStore;

	constructor(store: TokenStore) {
		this.store = store;
	}

	getProviderName(): string {
		return "vertex";
	}

	/**
	 * Import a service account JSON
	 */
	async importServiceAccount(json: string): Promise<StoredAuthFile> {
		let sa: ServiceAccount;

		try {
			sa = JSON.parse(json) as ServiceAccount;
		} catch {
			throw new Error("Invalid JSON format");
		}

		// Validate required fields
		if (!sa.client_email || !sa.private_key || !sa.project_id) {
			throw new Error(
				"Invalid service account: missing client_email, private_key, or project_id",
			);
		}

		if (sa.type !== "service_account") {
			throw new Error("Invalid service account: type must be 'service_account'");
		}

		// Generate access token
		const accessToken = await this.generateAccessToken(sa);

		const now = new Date().toISOString();

		const authFile: StoredAuthFile = {
			id: `vertex-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
			provider: this.getProviderName(),
			email: sa.client_email,
			name: sa.client_email,
			projectId: sa.project_id,
			createdAt: now,
			updatedAt: now,
			accessToken,
			expiresAt: new Date(Date.now() + 3600 * 1000).toISOString(), // 1 hour
			status: "ready",
			disabled: false,
			// Store service account for refresh (encrypted in production)
			serviceAccountJson: json,
		};

		await this.store.saveAuthFile(authFile);
		return authFile;
	}

	/**
	 * Refresh token
	 */
	async refreshToken(authFile: StoredAuthFile): Promise<StoredAuthFile> {
		if (!authFile.serviceAccountJson) {
			throw new Error("No service account available for refresh");
		}

		const sa = JSON.parse(authFile.serviceAccountJson) as ServiceAccount;
		const accessToken = await this.generateAccessToken(sa);

		const updated: StoredAuthFile = {
			...authFile,
			accessToken,
			expiresAt: new Date(Date.now() + 3600 * 1000).toISOString(),
			updatedAt: new Date().toISOString(),
			status: "ready",
		};

		await this.store.saveAuthFile(updated);
		return updated;
	}

	/**
	 * Generate access token from service account
	 * Uses JWT assertion flow
	 */
	private async generateAccessToken(sa: ServiceAccount): Promise<string> {
		const now = Math.floor(Date.now() / 1000);

		// Create JWT header and payload
		const header = {
			alg: "RS256",
			typ: "JWT",
		};

		const payload = {
			iss: sa.client_email,
			sub: sa.client_email,
			aud: "https://oauth2.googleapis.com/token",
			iat: now,
			exp: now + 3600,
			scope: "https://www.googleapis.com/auth/cloud-platform",
		};

		// Sign the JWT
		const jwt = await this.signJWT(header, payload, sa.private_key);

		// Exchange JWT for access token
		const response = await fetch("https://oauth2.googleapis.com/token", {
			method: "POST",
			headers: {
				"Content-Type": "application/x-www-form-urlencoded",
			},
			body: new URLSearchParams({
				grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
				assertion: jwt,
			}),
		});

		if (!response.ok) {
			const error = await response.text();
			throw new Error(`Failed to get access token: ${error}`);
		}

		const data = (await response.json()) as Record<string, unknown>;
		return data.access_token as string;
	}

	/**
	 * Sign a JWT with RS256
	 */
	private async signJWT(
		header: Record<string, string>,
		payload: Record<string, unknown>,
		privateKey: string,
	): Promise<string> {
		// Encode header and payload
		const encodedHeader = this.base64URLEncode(JSON.stringify(header));
		const encodedPayload = this.base64URLEncode(JSON.stringify(payload));
		const signingInput = `${encodedHeader}.${encodedPayload}`;

		// Import the private key
		const key = await crypto.subtle.importKey(
			"pkcs8",
			this.pemToBinary(privateKey),
			{
				name: "RSASSA-PKCS1-v1_5",
				hash: "SHA-256",
			},
			false,
			["sign"],
		);

		// Sign
		const signature = await crypto.subtle.sign(
			"RSASSA-PKCS1-v1_5",
			key,
			new TextEncoder().encode(signingInput),
		);

		const encodedSignature = this.base64URLEncode(
			String.fromCharCode(...new Uint8Array(signature)),
		);

		return `${signingInput}.${encodedSignature}`;
	}

	/**
	 * Convert PEM to binary
	 */
	private pemToBinary(pem: string): ArrayBuffer {
		const base64 = pem
			.replace(/-----BEGIN PRIVATE KEY-----/, "")
			.replace(/-----END PRIVATE KEY-----/, "")
			.replace(/\s/g, "");

		const binary = atob(base64);
		const bytes = new Uint8Array(binary.length);
		for (let i = 0; i < binary.length; i++) {
			bytes[i] = binary.charCodeAt(i);
		}
		return bytes.buffer;
	}

	/**
	 * Base64 URL encode
	 */
	private base64URLEncode(str: string): string {
		const base64 = btoa(str);
		return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
	}
}
