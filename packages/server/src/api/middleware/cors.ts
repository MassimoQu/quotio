/**
 * CORS middleware configuration
 */
import { cors } from "hono/cors";

export const corsMiddleware = cors({
	origin: "*",
	allowMethods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
	allowHeaders: ["Content-Type", "Authorization", "X-Requested-With"],
	exposeHeaders: ["Content-Length", "X-Request-Id"],
	maxAge: 86400,
	credentials: true,
});
