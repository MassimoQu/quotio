/**
 * Application context types
 */
import type { Config } from "../config/index.js";
import type { AuthManager } from "../auth/index.js";
import type { TokenStore } from "../store/index.js";

export interface AppContext {
	config: Config;
	authManager: AuthManager;
	store: TokenStore;
}

export interface AppEnv {
	Variables: {
		config: Config;
		authManager: AuthManager;
		store: TokenStore;
	};
}
