/**
 * PKCE (Proof Key for Code Exchange) utilities
 * @packageDocumentation
 */

/**
 * Generate a cryptographically random state string
 */
export function generateState(length = 32): string {
	const array = new Uint8Array(length);
	crypto.getRandomValues(array);
	return base64URLEncode(array);
}

/**
 * Generate a code verifier for PKCE
 * Must be 43-128 characters using [A-Z, a-z, 0-9, -, ., _, ~]
 */
export function generateCodeVerifier(length = 64): string {
	const array = new Uint8Array(length);
	crypto.getRandomValues(array);
	return base64URLEncode(array);
}

/**
 * Generate code challenge from code verifier using SHA-256
 */
export async function generateCodeChallenge(
	codeVerifier: string,
): Promise<string> {
	const encoder = new TextEncoder();
	const data = encoder.encode(codeVerifier);
	const digest = await crypto.subtle.digest("SHA-256", data);
	return base64URLEncode(new Uint8Array(digest));
}

/**
 * Base64 URL encode (no padding, URL-safe characters)
 */
function base64URLEncode(buffer: Uint8Array): string {
	const base64 = btoa(String.fromCharCode(...buffer));
	return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/**
 * Build OAuth authorization URL with all parameters
 */
export async function buildAuthorizationURL(options: {
	authorizationEndpoint: string;
	clientId: string;
	redirectUri: string;
	scopes: string[];
	state: string;
	codeChallenge?: string;
	codeChallengeMethod?: "S256" | "plain";
	/** Additional custom parameters */
	extraParams?: Record<string, string>;
}): Promise<string> {
	const url = new URL(options.authorizationEndpoint);

	url.searchParams.set("client_id", options.clientId);
	url.searchParams.set("redirect_uri", options.redirectUri);
	url.searchParams.set("response_type", "code");
	url.searchParams.set("state", options.state);

	if (options.scopes.length > 0) {
		url.searchParams.set("scope", options.scopes.join(" "));
	}

	if (options.codeChallenge) {
		url.searchParams.set("code_challenge", options.codeChallenge);
		url.searchParams.set(
			"code_challenge_method",
			options.codeChallengeMethod || "S256",
		);
	}

	if (options.extraParams) {
		for (const [key, value] of Object.entries(options.extraParams)) {
			url.searchParams.set(key, value);
		}
	}

	return url.toString();
}

/**
 * Exchange authorization code for tokens
 */
export async function exchangeCodeForTokens(options: {
	tokenEndpoint: string;
	clientId: string;
	clientSecret?: string;
	code: string;
	redirectUri: string;
	codeVerifier?: string;
}): Promise<{
	accessToken: string;
	refreshToken?: string;
	expiresIn?: number;
	tokenType?: string;
	scope?: string;
	raw: Record<string, unknown>;
}> {
	const body = new URLSearchParams({
		grant_type: "authorization_code",
		client_id: options.clientId,
		code: options.code,
		redirect_uri: options.redirectUri,
	});

	if (options.clientSecret) {
		body.set("client_secret", options.clientSecret);
	}

	if (options.codeVerifier) {
		body.set("code_verifier", options.codeVerifier);
	}

	const response = await fetch(options.tokenEndpoint, {
		method: "POST",
		headers: {
			"Content-Type": "application/x-www-form-urlencoded",
			Accept: "application/json",
		},
		body: body.toString(),
	});

	if (!response.ok) {
		const errorText = await response.text();
		throw new Error(
			`Token exchange failed: ${response.status} ${response.statusText} - ${errorText}`,
		);
	}

	const data = (await response.json()) as Record<string, unknown>;

	if (data.error) {
		throw new Error(
			`Token exchange error: ${data.error} - ${(data.error_description as string) || ""}`,
		);
	}

	return {
		accessToken: data.access_token as string,
		refreshToken: data.refresh_token as string | undefined,
		expiresIn: data.expires_in as number | undefined,
		tokenType: data.token_type as string | undefined,
		scope: data.scope as string | undefined,
		raw: data,
	};
}

/**
 * Refresh an access token
 */
export async function refreshAccessToken(options: {
	tokenEndpoint: string;
	clientId: string;
	clientSecret?: string;
	refreshToken: string;
}): Promise<{
	accessToken: string;
	refreshToken?: string;
	expiresIn?: number;
	raw: Record<string, unknown>;
}> {
	const body = new URLSearchParams({
		grant_type: "refresh_token",
		client_id: options.clientId,
		refresh_token: options.refreshToken,
	});

	if (options.clientSecret) {
		body.set("client_secret", options.clientSecret);
	}

	const response = await fetch(options.tokenEndpoint, {
		method: "POST",
		headers: {
			"Content-Type": "application/x-www-form-urlencoded",
			Accept: "application/json",
		},
		body: body.toString(),
	});

	if (!response.ok) {
		const errorText = await response.text();
		throw new Error(
			`Token refresh failed: ${response.status} ${response.statusText} - ${errorText}`,
		);
	}

	const data = (await response.json()) as Record<string, unknown>;

	if (data.error) {
		throw new Error(
			`Token refresh error: ${data.error} - ${(data.error_description as string) || ""}`,
		);
	}

	return {
		accessToken: data.access_token as string,
		refreshToken: data.refresh_token as string | undefined,
		expiresIn: data.expires_in as number | undefined,
		raw: data,
	};
}

/**
 * Decode a JWT token (without verification)
 * Only for extracting claims like email - NOT for security validation
 */
export function decodeJWT(token: string): Record<string, unknown> {
	try {
		const parts = token.split(".");
		if (parts.length !== 3) {
			throw new Error("Invalid JWT format");
		}

		// Add padding if needed
		let payload = parts[1];
		while (payload.length % 4 !== 0) {
			payload += "=";
		}

		const decoded = atob(payload.replace(/-/g, "+").replace(/_/g, "/"));
		return JSON.parse(decoded);
	} catch {
		return {};
	}
}
