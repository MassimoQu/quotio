/**
 * GitHub Copilot Device Code Authentication Service
 *
 * Implements the OAuth 2.0 Device Authorization Grant flow for GitHub Copilot.
 * @see https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-with-the-cli#authenticating-with-github-copilot
 */

import { readFileSync, unlinkSync, writeFileSync } from 'node:fs';
import { readdir } from 'node:fs/promises';

const GITHUB_DEVICE_CODE_URL = 'https://github.com/login/device/code';
const GITHUB_TOKEN_URL = 'https://github.com/login/oauth/access_token';
const GITHUB_CLIENT_ID = 'Iv1.05c333666616c060';

export interface DeviceCodeResponse {
	device_code: string;
	user_code: string;
	verification_uri: string;
	expires_in: number;
	interval: number;
}

export interface TokenResponse {
	access_token: string;
	token_type: string;
	scope: string;
}

export interface DeviceCodeResult {
	success: boolean;
	userCode?: string;
	verificationUri?: string;
	deviceCode?: string;
	expiresIn?: number;
	error?: string;
}

export interface DeviceCodePollResult {
	status: 'pending' | 'success' | 'error';
	accessToken?: string;
	error?: string;
}

/**
 * Start the Device Code flow for GitHub Copilot authentication
 */
export async function startCopilotDeviceCode(): Promise<DeviceCodeResult> {
	try {
		const response = await fetch(GITHUB_DEVICE_CODE_URL, {
			method: 'POST',
			headers: {
				Accept: 'application/json',
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({
				client_id: GITHUB_CLIENT_ID,
				scope: 'read:user user:email copilot',
			}),
		});

		if (!response.ok) {
			const error = await response.text();
			return {
				success: false,
				error: `GitHub API error: ${response.status} - ${error}`,
			};
		}

		const data = (await response.json()) as DeviceCodeResponse;

		return {
			success: true,
			userCode: data.user_code,
			verificationUri: data.verification_uri,
			deviceCode: data.device_code,
			expiresIn: data.expires_in,
		};
	} catch (err) {
		return {
			success: false,
			error: err instanceof Error ? err.message : String(err),
		};
	}
}

/**
 * Poll for token completion in the Device Code flow
 */
export async function pollCopilotDeviceCode(deviceCode: string): Promise<DeviceCodePollResult> {
	try {
		const response = await fetch(GITHUB_TOKEN_URL, {
			method: 'POST',
			headers: {
				Accept: 'application/json',
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({
				client_id: GITHUB_CLIENT_ID,
				device_code: deviceCode,
				grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
			}),
		});

		const data = (await response.json()) as {
			access_token?: string;
			error?: string;
			error_description?: string;
		};

		if (data.access_token) {
			return {
				status: 'success',
				accessToken: data.access_token,
			};
		}

		if (data.error) {
			if (data.error === 'authorization_pending') {
				return { status: 'pending' };
			}
			if (data.error === 'slow_down') {
				return {
					status: 'pending',
					error: 'Please wait before polling again',
				};
			}
			return {
				status: 'error',
				error: data.error_description || data.error,
			};
		}

		return { status: 'pending' };
	} catch (err) {
		return {
			status: 'error',
			error: err instanceof Error ? err.message : String(err),
		};
	}
}

/**
 * Get user info from GitHub API using the access token
 */
export async function getGitHubUserInfo(
	accessToken: string,
): Promise<{ login: string; email: string; name?: string }> {
	const response = await fetch('https://api.github.com/user', {
		headers: {
			Authorization: `Bearer ${accessToken}`,
			Accept: 'application/vnd.github+json',
			'X-GitHub-Api-Version': '2022-11-28',
		},
	});

	if (!response.ok) {
		throw new Error(`GitHub API error: ${response.status}`);
	}

	const data = (await response.json()) as {
		login: string;
		email: string;
		name?: string;
	};
	return data;
}

/**
 * Save Copilot auth file to ~/.cli-proxy-api/
 */
export async function saveCopilotAuthFile(accessToken: string, username: string): Promise<string> {
	const authDir = getAuthDir();
	const timestamp = Date.now();
	const fileName = `github-copilot-${username}-${timestamp}.json`;
	const filePath = `${authDir}/${fileName}`;

	const content = JSON.stringify(
		{
			access_token: accessToken,
			account: username,
			created_at: timestamp,
			provider: 'github-copilot',
		},
		null,
		2,
	);

	writeFileSync(filePath, content);
	return fileName;
}

/**
 * Delete Copilot auth file
 */
export async function deleteCopilotAuthFile(username: string): Promise<boolean> {
	const authDir = getAuthDir();

	try {
		const files = await readdir(authDir);

		for (const fileName of files) {
			if (fileName.startsWith('github-copilot-') && fileName.endsWith('.json')) {
				// Extract username from filename
				let name = fileName;
				if (name.startsWith('github-copilot-')) {
					name = name.slice('github-copilot-'.length);
				}
				if (name.endsWith('.json')) {
					name = name.slice(0, -'.json'.length);
				}

				// Match by username (remove timestamp suffix if present)
				const usernamePattern = new RegExp(`^${username}(-\\d+)?$`);
				if (usernamePattern.test(name)) {
					const filePath = `${authDir}/${fileName}`;
					unlinkSync(filePath);
					return true;
				}
			}
		}
	} catch {
		// Auth directory doesn't exist or other error
	}

	return false;
}

/**
 * List all Copilot auth files
 */
export async function listCopilotAuthFiles(): Promise<
	Array<{
		username: string;
		createdAt: string;
	}>
> {
	const authDir = getAuthDir();
	const results: Array<{ username: string; createdAt: string }> = [];

	try {
		const files = await readdir(authDir);

		for (const fileName of files) {
			if (fileName.startsWith('github-copilot-') && fileName.endsWith('.json')) {
				const filePath = `${authDir}/${fileName}`;
				try {
					const content = readFileSync(filePath, 'utf-8');
					const data = JSON.parse(content);

					// Extract username from filename
					let name = fileName;
					if (name.startsWith('github-copilot-')) {
						name = name.slice('github-copilot-'.length);
					}
					if (name.endsWith('.json')) {
						name = name.slice(0, -'.json'.length);
					}

					results.push({
						username: data.account || name,
						createdAt: data.created_at
							? new Date(data.created_at).toISOString()
							: new Date().toISOString(),
					});
				} catch {
					// Skip invalid files
				}
			}
		}
	} catch {
		// Auth directory doesn't exist
	}

	return results;
}

function getAuthDir(): string {
	const home = process.env.HOME ?? Bun.env.HOME ?? '';
	return `${home}/.cli-proxy-api`;
}
