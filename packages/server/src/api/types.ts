/**
 * Application context types
 */
import type { Config } from "../config/index.ts";

export interface AppContext {
	config: Config;
}

export interface AppEnv {
	Variables: {
		config: Config;
	};
}
