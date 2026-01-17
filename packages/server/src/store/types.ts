/**
 * Token store types and interfaces
 * @packageDocumentation
 */

import { z } from "zod";

/**
 * Stored auth file schema with all token data
 */
export const StoredAuthFileSchema = z.object({
	id: z.string(),
	provider: z.string(),
	email: z.string().optional(),
	name: z.string().optional(),
	label: z.string().optional(),

	// Timestamps
	createdAt: z.string().datetime(),
	updatedAt: z.string().datetime(),

	// Token data
	accessToken: z.string().optional(),
	refreshToken: z.string().optional(),
	expiresAt: z.string().datetime().optional(),

	// Provider-specific
	projectId: z.string().optional(),
	region: z.string().optional(),

	// For Vertex service account (encrypted)
	serviceAccountJson: z.string().optional(),

	// For Copilot/Kiro - additional token data
	tokenData: z.record(z.unknown()).optional(),

	// Status
	status: z.enum(["ready", "cooling", "error", "refreshing"]),
	statusMessage: z.string().optional(),
	disabled: z.boolean().default(false),

	// Quota tracking
	quotaUsed: z.number().optional(),
	quotaLimit: z.number().optional(),
	quotaResetAt: z.string().datetime().optional(),

	// Tier info
	tier: z.enum(["paid", "free", "unknown"]).optional(),

	// Cooldown tracking
	cooldownUntil: z.string().datetime().optional(),
	cooldownReason: z.string().optional(),
});

export type StoredAuthFile = z.infer<typeof StoredAuthFileSchema>;

/**
 * Pending OAuth session data
 */
export interface OAuthSession {
	state: string;
	codeVerifier: string;
	provider: string;
	createdAt: Date;
	expiresAt: Date;
	// For Device Code flow
	deviceCode?: string;
	userCode?: string;
	verificationUri?: string;
	pollInterval?: number;
}

/**
 * Token store interface for persistence
 */
export interface TokenStore {
	/**
	 * List all stored auth files
	 */
	listAuthFiles(): Promise<StoredAuthFile[]>;

	/**
	 * Get a specific auth file by ID
	 */
	getAuthFile(id: string): Promise<StoredAuthFile | null>;

	/**
	 * Save an auth file (create or update)
	 */
	saveAuthFile(authFile: StoredAuthFile): Promise<void>;

	/**
	 * Delete an auth file by ID
	 */
	deleteAuthFile(id: string): Promise<void>;

	/**
	 * Delete all auth files for a provider
	 */
	deleteAuthFilesByProvider(provider: string): Promise<void>;

	/**
	 * Update auth file status
	 */
	updateStatus(
		id: string,
		status: StoredAuthFile["status"],
		statusMessage?: string,
	): Promise<void>;

	/**
	 * Set cooldown for an auth file
	 */
	setCooldown(id: string, until: Date, reason: string): Promise<void>;

	/**
	 * Clear cooldown for an auth file
	 */
	clearCooldown(id: string): Promise<void>;

	/**
	 * Store a pending OAuth session
	 */
	savePendingSession(session: OAuthSession): Promise<void>;

	/**
	 * Get a pending OAuth session by state
	 */
	getPendingSession(state: string): Promise<OAuthSession | null>;

	/**
	 * Delete a pending OAuth session
	 */
	deletePendingSession(state: string): Promise<void>;

	/**
	 * Cleanup expired sessions
	 */
	cleanupExpiredSessions(): Promise<void>;
}

/**
 * Storage paths configuration
 */
export interface StorageConfig {
	authDir: string;
	configDir: string;
}
