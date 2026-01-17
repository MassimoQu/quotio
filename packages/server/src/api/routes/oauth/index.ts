/**
 * OAuth callback routes
 *
 * Handles OAuth redirects from providers after user authorization.
 * @packageDocumentation
 */
import { Hono, type Context } from "hono";
import type { AuthManager, ProviderType } from "../../../auth/index.js";

/**
 * Success page HTML template
 */
const successHtml = (provider: string) => `
<!DOCTYPE html>
<html>
<head>
  <title>Authentication Successful</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    }
    .container {
      text-align: center;
      padding: 3rem;
      background: white;
      border-radius: 16px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
      max-width: 400px;
    }
    .icon {
      font-size: 4rem;
      margin-bottom: 1rem;
    }
    h1 {
      color: #22c55e;
      margin: 0 0 0.5rem 0;
      font-size: 1.5rem;
    }
    p {
      color: #666;
      margin: 0.5rem 0;
      line-height: 1.6;
    }
    .provider {
      display: inline-block;
      background: #f0fdf4;
      color: #16a34a;
      padding: 0.25rem 0.75rem;
      border-radius: 999px;
      font-weight: 500;
      margin-top: 1rem;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">✓</div>
    <h1>Authentication Successful</h1>
    <p>You have successfully authenticated.</p>
    <p>You can close this window and return to the CLI.</p>
    <span class="provider">${provider}</span>
  </div>
</body>
</html>`;

/**
 * Error page HTML template
 */
const errorHtml = (error: string, details?: string) => `
<!DOCTYPE html>
<html>
<head>
  <title>Authentication Failed</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    }
    .container {
      text-align: center;
      padding: 3rem;
      background: white;
      border-radius: 16px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
      max-width: 400px;
    }
    .icon {
      font-size: 4rem;
      margin-bottom: 1rem;
    }
    h1 {
      color: #ef4444;
      margin: 0 0 0.5rem 0;
      font-size: 1.5rem;
    }
    p {
      color: #666;
      margin: 0.5rem 0;
      line-height: 1.6;
    }
    .error-box {
      background: #fef2f2;
      color: #dc2626;
      padding: 1rem;
      border-radius: 8px;
      margin-top: 1rem;
      font-family: monospace;
      font-size: 0.875rem;
      word-break: break-word;
    }
    .details {
      color: #9ca3af;
      font-size: 0.75rem;
      margin-top: 0.5rem;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">✗</div>
    <h1>Authentication Failed</h1>
    <p>An error occurred during authentication.</p>
    <div class="error-box">
      ${error}
      ${details ? `<div class="details">${details}</div>` : ""}
    </div>
    <p>Please try again or check the CLI for more information.</p>
  </div>
</body>
</html>`;

interface OAuthRoutesDeps {
	authManager: AuthManager;
}

/**
 * Handle OAuth callback for a provider
 */
async function handleOAuthCallback(
	c: Context,
	authManager: AuthManager,
	provider: ProviderType,
	displayName: string,
): Promise<Response> {
	const code = c.req.query("code");
	const state = c.req.query("state");
	const error = c.req.query("error");
	const errorDescription = c.req.query("error_description");

	if (error) {
		console.error(`[OAuth] ${provider} error:`, error, errorDescription);
		return c.html(errorHtml(error, errorDescription), 400);
	}

	if (!code || !state) {
		return c.html(errorHtml("Missing code or state parameter"), 400);
	}

	try {
		await authManager.handleCallback(provider, code, state);
		console.log(`[OAuth] ${provider} authentication successful`);
		return c.html(successHtml(displayName));
	} catch (err) {
		const message = err instanceof Error ? err.message : "Unknown error";
		console.error(`[OAuth] ${provider} callback error:`, err);
		return c.html(errorHtml(message), 500);
	}
}

/**
 * Create OAuth callback routes
 */
export function oauthRoutes(deps: OAuthRoutesDeps): Hono {
	const app = new Hono();
	const { authManager } = deps;

	// Google callback (gemini-cli)
	app.get("/google/callback", (c) =>
		handleOAuthCallback(c, authManager, "gemini-cli", "Google (Gemini)"),
	);

	// Anthropic callback (claude)
	app.get("/anthropic/callback", (c) =>
		handleOAuthCallback(c, authManager, "claude", "Anthropic (Claude)"),
	);

	// OpenAI callback (codex)
	app.get("/codex/callback", (c) =>
		handleOAuthCallback(c, authManager, "codex", "OpenAI (Codex)"),
	);

	// Kiro callback
	app.get("/kiro/callback", (c) =>
		handleOAuthCallback(c, authManager, "kiro", "Kiro"),
	);

	return app;
}
