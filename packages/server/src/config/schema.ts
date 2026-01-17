/**
 * Configuration schema for quotio-server
 * Uses Zod for runtime validation and TypeScript inference
 */
import { z } from "zod";

export const TLSConfigSchema = z.object({
	enable: z.boolean().default(false),
	cert: z.string().optional(),
	key: z.string().optional(),
});

export const RemoteManagementSchema = z.object({
	allowRemote: z.boolean().default(false),
	secretKey: z.string().optional(),
	disableControlPanel: z.boolean().default(false),
});

export const RoutingSchema = z.object({
	strategy: z.enum(["round-robin", "fill-first"]).default("round-robin"),
});

export const QuotaExceededSchema = z.object({
	switchProject: z.boolean().default(true),
	switchPreviewModel: z.boolean().default(true),
});

export const ProviderAPIKeySchema = z.object({
	apiKey: z.string(),
	prefix: z.string().optional(),
	baseUrl: z.string().optional(),
});

export const ConfigSchema = z.object({
	// Server
	host: z.string().default("127.0.0.1"),
	port: z.number().default(18317),
	tls: TLSConfigSchema.default({}),

	// Remote management
	remoteManagement: RemoteManagementSchema.default({}),

	// Paths
	authDir: z.string().default("~/.cli-proxy-api"),
	configDir: z.string().default("~/.config/quotio"),

	// API Keys for accessing the management API
	apiKeys: z.array(z.string()).default([]),

	// Debug and logging
	debug: z.boolean().default(false),
	loggingToFile: z.boolean().default(false),

	// Routing
	routing: RoutingSchema.default({}),

	// Retry configuration
	requestRetry: z.number().default(3),
	maxRetryInterval: z.number().default(30),

	// Quota handling
	quotaExceeded: QuotaExceededSchema.default({}),

	// Provider-specific API keys (optional)
	geminiApiKeys: z.array(ProviderAPIKeySchema).optional(),
	claudeApiKeys: z.array(ProviderAPIKeySchema).optional(),
	openaiApiKeys: z.array(ProviderAPIKeySchema).optional(),

	// Passthrough configuration (for migration)
	passthrough: z
		.object({
			enabled: z.boolean().default(true),
			cliProxyPort: z.number().default(18317),
			timeout: z.number().default(120), // seconds
		})
		.default({}),
});

export type Config = z.infer<typeof ConfigSchema>;
export type TLSConfig = z.infer<typeof TLSConfigSchema>;
export type RemoteManagement = z.infer<typeof RemoteManagementSchema>;
export type Routing = z.infer<typeof RoutingSchema>;
export type QuotaExceeded = z.infer<typeof QuotaExceededSchema>;
export type ProviderAPIKey = z.infer<typeof ProviderAPIKeySchema>;
