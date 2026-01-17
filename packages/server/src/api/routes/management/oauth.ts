/**
 * Management OAuth routes
 *
 * API endpoints for authentication management.
 * @packageDocumentation
 */
import { Hono, type Context } from "hono";
import type { AuthManager, ProviderType } from "../../../auth/index.js";

interface OAuthManagementDeps {
	authManager: AuthManager;
}

/**
 * Create OAuth management routes
 */
export function oauthManagementRoutes(deps: OAuthManagementDeps): Hono {
	const app = new Hono();
	const { authManager } = deps;

	// === Auth File Management ===

	/**
	 * List all auth files
	 * GET /auth
	 */
	app.get("/auth", async (c) => {
		const authFiles = await authManager.listAuthFiles();

		return c.json({
			auth_files: authFiles.map((f) => ({
				id: f.id,
				provider: f.provider,
				email: f.email,
				name: f.name,
				status: f.status,
				disabled: f.disabled,
				expires_at: f.expiresAt,
				is_expired: f.expiresAt ? new Date(f.expiresAt) < new Date() : false,
				created_at: f.createdAt,
				updated_at: f.updatedAt,
			})),
		});
	});

	/**
	 * Get auth file by provider
	 * GET /auth/:provider
	 */
	app.get("/auth/:provider", async (c) => {
		const provider = c.req.param("provider");
		const authFile = await authManager.getAuthFile(provider);

		if (!authFile) {
			return c.json({ error: "Not authenticated" }, 404);
		}

		return c.json({
			id: authFile.id,
			provider: authFile.provider,
			email: authFile.email,
			name: authFile.name,
			status: authFile.status,
			disabled: authFile.disabled,
			expires_at: authFile.expiresAt,
			is_expired: authFile.expiresAt
				? new Date(authFile.expiresAt) < new Date()
				: false,
			created_at: authFile.createdAt,
			updated_at: authFile.updatedAt,
		});
	});

	/**
	 * Delete auth file by ID
	 * DELETE /auth/:id
	 */
	app.delete("/auth/:id", async (c) => {
		const id = c.req.param("id");
		await authManager.deleteAuthFile(id);
		return c.json({ success: true });
	});

	/**
	 * Delete all auth files for a provider
	 * DELETE /auth/provider/:provider
	 */
	app.delete("/auth/provider/:provider", async (c) => {
		const provider = c.req.param("provider");
		await authManager.deleteAuthFilesByProvider(provider);
		return c.json({ success: true });
	});

	// === OAuth Flow ===

	/**
	 * Start OAuth flow
	 * POST /oauth/start
	 * Body: { provider: "gemini-cli" | "claude" | "codex" | "kiro" }
	 */
	app.post("/oauth/start", async (c) => {
		try {
			const body = await c.req.json<{ provider?: string }>();
			const provider = body.provider as ProviderType | undefined;

			if (!provider) {
				return c.json({ error: "Missing provider" }, 400);
			}

			const validOAuthProviders = authManager.getOAuthProviders();
			if (!validOAuthProviders.includes(provider)) {
				return c.json(
					{
						error: `Invalid OAuth provider: ${provider}. Valid: ${validOAuthProviders.join(", ")}`,
					},
					400,
				);
			}

			const result = await authManager.startOAuth(provider);

			return c.json({
				auth_url: result.url,
				state: result.state,
				incognito: result.incognito,
			});
		} catch (err) {
			const message = err instanceof Error ? err.message : "Unknown error";
			console.error("[OAuth] Start error:", err);
			return c.json({ error: message }, 500);
		}
	});

	/**
	 * Check OAuth status by state
	 * GET /oauth/status?state=xxx
	 */
	app.get("/oauth/status", async (c) => {
		const state = c.req.query("state");

		if (!state) {
			return c.json({ error: "Missing state parameter" }, 400);
		}

		const result = await authManager.getOAuthStatus(state);

		if (result.error) {
			return c.json({ completed: false, error: result.error });
		}

		if (result.completed && result.authFile) {
			return c.json({
				completed: true,
				provider: result.authFile.provider,
				email: result.authFile.email,
			});
		}

		return c.json({ completed: false });
	});

	// === Device Code Flow ===

	/**
	 * Start Device Code flow
	 * POST /oauth/device-start
	 * Body: { provider: "github-copilot" }
	 */
	app.post("/oauth/device-start", async (c) => {
		try {
			const body = await c.req.json<{ provider?: string }>();
			const provider = body.provider as ProviderType | undefined;

			if (!provider) {
				return c.json({ error: "Missing provider" }, 400);
			}

			const validDeviceProviders = authManager.getDeviceCodeProviders();
			if (!validDeviceProviders.includes(provider)) {
				return c.json(
					{
						error: `Invalid device code provider: ${provider}. Valid: ${validDeviceProviders.join(", ")}`,
					},
					400,
				);
			}

			const result = await authManager.startDeviceFlow(provider);

			return c.json({
				device_code: result.deviceCode,
				user_code: result.userCode,
				verification_uri: result.verificationUri,
				expires_in: result.expiresIn,
				interval: result.interval,
			});
		} catch (err) {
			const message = err instanceof Error ? err.message : "Unknown error";
			console.error("[OAuth] Device start error:", err);
			return c.json({ error: message }, 500);
		}
	});

	/**
	 * Poll Device Code for token
	 * POST /oauth/device-poll
	 * Body: { provider: "github-copilot", device_code: "xxx" }
	 */
	app.post("/oauth/device-poll", async (c) => {
		try {
			const body = await c.req.json<{
				provider?: string;
				device_code?: string;
			}>();
			const provider = body.provider as ProviderType | undefined;
			const deviceCode = body.device_code;

			if (!provider || !deviceCode) {
				return c.json({ error: "Missing provider or device_code" }, 400);
			}

			const result = await authManager.pollDeviceCode(provider, deviceCode);

			if (result.status === "completed" && result.authFile) {
				return c.json({
					status: "completed",
					provider: result.authFile.provider,
					email: result.authFile.email,
				});
			}

			if (result.status === "error") {
				return c.json({ status: "error", error: result.error });
			}

			if (result.status === "expired") {
				return c.json({ status: "expired", error: result.error });
			}

			return c.json({ status: "pending" });
		} catch (err) {
			const message = err instanceof Error ? err.message : "Unknown error";
			console.error("[OAuth] Device poll error:", err);
			return c.json({ status: "error", error: message }, 500);
		}
	});

	// === Service Account ===

	/**
	 * Import service account
	 * POST /oauth/import-service-account
	 * Body: { provider: "vertex", key_file: "<json content>" }
	 */
	app.post("/oauth/import-service-account", async (c) => {
		try {
			const body = await c.req.json<{ provider?: string; key_file?: string }>();
			const provider = body.provider as ProviderType | undefined;
			const keyFile = body.key_file;

			if (!provider || !keyFile) {
				return c.json({ error: "Missing provider or key_file" }, 400);
			}

			const validSAProviders = authManager.getServiceAccountProviders();
			if (!validSAProviders.includes(provider)) {
				return c.json(
					{
						error: `Invalid service account provider: ${provider}. Valid: ${validSAProviders.join(", ")}`,
					},
					400,
				);
			}

			const result = await authManager.importServiceAccount(provider, keyFile);

			return c.json({
				success: true,
				provider: result.provider,
				email: result.email,
				project_id: result.projectId,
			});
		} catch (err) {
			const message = err instanceof Error ? err.message : "Unknown error";
			console.error("[OAuth] Import service account error:", err);
			return c.json({ error: message }, 500);
		}
	});

	// === Token Refresh ===

	/**
	 * Refresh token for a provider
	 * POST /oauth/refresh/:provider
	 */
	app.post("/oauth/refresh/:provider", async (c) => {
		const provider = c.req.param("provider") as ProviderType;

		try {
			const authFile = await authManager.getAuthFile(provider);
			if (!authFile) {
				return c.json({ error: "No auth found for provider" }, 404);
			}

			const result = await authManager.refreshIfNeeded(authFile);

			return c.json({
				success: true,
				provider: result.provider,
				email: result.email,
				expires_at: result.expiresAt,
			});
		} catch (err) {
			const message = err instanceof Error ? err.message : "Unknown error";
			console.error(`[OAuth] Refresh error for ${provider}:`, err);
			return c.json({ error: message }, 500);
		}
	});

	// === Provider Info ===

	/**
	 * Get supported providers
	 * GET /oauth/providers
	 */
	app.get("/oauth/providers", (c) => {
		return c.json({
			oauth: authManager.getOAuthProviders(),
			device_code: authManager.getDeviceCodeProviders(),
			service_account: authManager.getServiceAccountProviders(),
			all: authManager.getAllProviders(),
		});
	});

	return app;
}
