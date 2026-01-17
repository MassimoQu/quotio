# Phase 2: Server Architecture

**Duration:** 1 week (scaffold) + ongoing
**Goal:** Design and scaffold quotio-server - the TypeScript replacement for CLIProxyAPI

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          quotio-server                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
│  │   Hono      │  │   Auth      │  │   Proxy     │  │ Management │ │
│  │   Router    │  │   Handlers  │  │   Engine    │  │    API     │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬──────┘ │
│         │                │                │                │        │
│         └────────────────┼────────────────┼────────────────┘        │
│                          │                │                         │
│                   ┌──────┴──────┐  ┌──────┴──────┐                  │
│                   │ Translator  │  │   Token     │                  │
│                   │   Matrix    │  │    Store    │                  │
│                   └─────────────┘  └─────────────┘                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
packages/server/
├── src/
│   ├── index.ts                 # Server entry point
│   ├── config/
│   │   ├── index.ts             # Config loader
│   │   ├── schema.ts            # Zod config schema
│   │   └── defaults.ts          # Default configuration
│   ├── api/
│   │   ├── index.ts             # Hono app factory
│   │   ├── routes/
│   │   │   ├── v1/
│   │   │   │   ├── chat.ts      # /v1/chat/completions
│   │   │   │   ├── models.ts    # /v1/models
│   │   │   │   ├── messages.ts  # /v1/messages (Claude)
│   │   │   │   └── gemini.ts    # /v1beta/* (Gemini)
│   │   │   └── management/
│   │   │       ├── index.ts     # /v0/management/*
│   │   │       ├── auth.ts      # Auth file management
│   │   │       ├── config.ts    # Config management
│   │   │       ├── logs.ts      # Request logs
│   │   │       ├── usage.ts     # Usage statistics
│   │   │       └── api-keys.ts  # API key management
│   │   └── middleware/
│   │       ├── auth.ts          # API key authentication
│   │       ├── cors.ts          # CORS handling
│   │       ├── logging.ts       # Request logging
│   │       └── ratelimit.ts     # Rate limiting
│   ├── auth/
│   │   ├── index.ts             # Auth manager
│   │   ├── oauth/
│   │   │   ├── base.ts          # Base OAuth handler
│   │   │   ├── claude.ts        # Claude OAuth
│   │   │   ├── gemini.ts        # Gemini OAuth
│   │   │   ├── codex.ts         # Codex/OpenAI OAuth
│   │   │   ├── copilot.ts       # GitHub Copilot (Device Code)
│   │   │   ├── vertex.ts        # Vertex AI (Service Account)
│   │   │   ├── iflow.ts         # iFlow OAuth
│   │   │   ├── antigravity.ts   # Antigravity OAuth
│   │   │   ├── kiro.ts          # Kiro/CodeWhisperer OAuth
│   │   │   └── qwen.ts          # Qwen OAuth
│   │   └── refresh.ts           # Token refresh logic
│   ├── proxy/
│   │   ├── index.ts             # Proxy engine
│   │   ├── router.ts            # Credential routing
│   │   ├── executor.ts          # Request execution
│   │   ├── stream.ts            # SSE streaming
│   │   └── retry.ts             # Retry logic
│   ├── translator/
│   │   ├── index.ts             # Translation registry
│   │   ├── types.ts             # Common types
│   │   ├── openai/
│   │   │   ├── to-claude.ts
│   │   │   ├── to-gemini.ts
│   │   │   └── from-*.ts
│   │   ├── claude/
│   │   │   ├── to-openai.ts
│   │   │   ├── to-gemini.ts
│   │   │   └── from-*.ts
│   │   ├── gemini/
│   │   │   ├── to-openai.ts
│   │   │   ├── to-claude.ts
│   │   │   └── from-*.ts
│   │   └── kiro/
│   │       ├── to-openai.ts
│   │       └── to-claude.ts
│   ├── store/
│   │   ├── index.ts             # Store interface
│   │   ├── file.ts              # File-based store
│   │   ├── sqlite.ts            # SQLite store (Bun native)
│   │   └── postgres.ts          # PostgreSQL store (future)
│   ├── usage/
│   │   ├── index.ts             # Usage tracker
│   │   ├── statistics.ts        # Aggregation
│   │   └── quota.ts             # Quota management
│   └── utils/
│       ├── logger.ts            # Logging
│       ├── crypto.ts            # Hashing, encryption
│       └── pkce.ts              # PKCE helpers
├── tests/
│   ├── unit/
│   └── integration/
├── package.json
└── tsconfig.json
```

## Core Components

### 1. Server Entry (`src/index.ts`)

```typescript
import { serve } from 'bun';
import { createApp } from './api';
import { loadConfig } from './config';
import { initializeStore } from './store';
import { initializeAuthManager } from './auth';

async function main() {
  const config = await loadConfig();
  const store = await initializeStore(config);
  const authManager = await initializeAuthManager(config, store);
  
  const app = createApp({ config, store, authManager });
  
  const server = serve({
    port: config.port,
    hostname: config.host || '0.0.0.0',
    fetch: app.fetch,
  });
  
  console.log(`quotio-server running on http://${server.hostname}:${server.port}`);
}

main().catch(console.error);
```

### 2. Hono App Factory (`src/api/index.ts`)

```typescript
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { v1Routes } from './routes/v1';
import { managementRoutes } from './routes/management';
import { authMiddleware } from './middleware/auth';
import type { AppContext } from './types';

export function createApp(deps: AppContext): Hono {
  const app = new Hono();
  
  // Global middleware
  app.use('*', logger());
  app.use('*', cors());
  
  // Health check
  app.get('/health', (c) => c.json({ status: 'ok' }));
  
  // OpenAI-compatible API (v1)
  app.route('/v1', v1Routes(deps));
  
  // Management API (v0)
  app.route('/v0/management', managementRoutes(deps));
  
  // OAuth callbacks
  app.get('/anthropic/callback', deps.authManager.handleAnthropicCallback);
  app.get('/google/callback', deps.authManager.handleGoogleCallback);
  // ... other callbacks
  
  return app;
}
```

### 3. Configuration Schema (`src/config/schema.ts`)

```typescript
import { z } from 'zod';

export const ConfigSchema = z.object({
  host: z.string().default(''),
  port: z.number().default(8317),
  
  tls: z.object({
    enable: z.boolean().default(false),
    cert: z.string().optional(),
    key: z.string().optional(),
  }).default({}),
  
  remoteManagement: z.object({
    allowRemote: z.boolean().default(false),
    secretKey: z.string().optional(),
    disableControlPanel: z.boolean().default(false),
  }).default({}),
  
  authDir: z.string().default('~/.cli-proxy-api'),
  apiKeys: z.array(z.string()).default([]),
  
  debug: z.boolean().default(false),
  loggingToFile: z.boolean().default(false),
  
  routing: z.object({
    strategy: z.enum(['round-robin', 'fill-first']).default('round-robin'),
  }).default({}),
  
  requestRetry: z.number().default(3),
  maxRetryInterval: z.number().default(30),
  
  quotaExceeded: z.object({
    switchProject: z.boolean().default(true),
    switchPreviewModel: z.boolean().default(true),
  }).default({}),
  
  // Provider-specific configs
  geminiApiKey: z.array(z.object({
    apiKey: z.string(),
    prefix: z.string().optional(),
    baseUrl: z.string().optional(),
  })).optional(),
  
  claudeApiKey: z.array(z.object({
    apiKey: z.string(),
    prefix: z.string().optional(),
    baseUrl: z.string().optional(),
  })).optional(),
  
  // ... more provider configs
});

export type Config = z.infer<typeof ConfigSchema>;
```

### 4. Proxy Engine (`src/proxy/index.ts`)

```typescript
import type { Context } from 'hono';
import type { Config } from '../config/schema';
import type { AuthManager } from '../auth';
import { selectCredential } from './router';
import { executeRequest } from './executor';
import { translateRequest, translateResponse } from '../translator';
import { streamResponse } from './stream';

export async function proxyRequest(
  c: Context,
  config: Config,
  authManager: AuthManager,
): Promise<Response> {
  const requestBody = await c.req.json();
  const model = requestBody.model;
  
  // 1. Select credential based on routing strategy
  const credential = await selectCredential(model, config, authManager);
  if (!credential) {
    return c.json({ error: 'No available credentials' }, 503);
  }
  
  // 2. Determine source/target protocols
  const sourceProtocol = detectProtocol(c.req);
  const targetProtocol = credential.protocol;
  
  // 3. Translate request if needed
  const translatedRequest = translateRequest(
    requestBody,
    sourceProtocol,
    targetProtocol,
  );
  
  // 4. Execute request with retry logic
  const { response, stream } = await executeRequest(
    translatedRequest,
    credential,
    config,
  );
  
  // 5. Handle streaming or regular response
  if (stream) {
    return streamResponse(c, response, sourceProtocol, targetProtocol);
  }
  
  // 6. Translate response back
  const translatedResponse = translateResponse(
    await response.json(),
    targetProtocol,
    sourceProtocol,
  );
  
  return c.json(translatedResponse);
}
```

### 5. SSE Streaming (`src/proxy/stream.ts`)

```typescript
export async function streamResponse(
  c: Context,
  upstreamResponse: Response,
  sourceProtocol: Protocol,
  targetProtocol: Protocol,
): Promise<Response> {
  const reader = upstreamResponse.body?.getReader();
  if (!reader) {
    throw new Error('No response body');
  }
  
  const encoder = new TextEncoder();
  const decoder = new TextDecoder();
  
  const stream = new ReadableStream({
    async pull(controller) {
      const { done, value } = await reader.read();
      
      if (done) {
        // Send final [DONE] marker for OpenAI protocol
        if (sourceProtocol === 'openai') {
          controller.enqueue(encoder.encode('data: [DONE]\n\n'));
        }
        controller.close();
        return;
      }
      
      // Parse SSE chunks
      const text = decoder.decode(value);
      const lines = text.split('\n');
      
      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const data = line.slice(6);
          if (data === '[DONE]') continue;
          
          try {
            const chunk = JSON.parse(data);
            const translated = translateStreamChunk(
              chunk,
              targetProtocol,
              sourceProtocol,
            );
            controller.enqueue(
              encoder.encode(`data: ${JSON.stringify(translated)}\n\n`)
            );
          } catch {
            // Pass through unparseable lines
            controller.enqueue(encoder.encode(`${line}\n`));
          }
        }
      }
    },
  });
  
  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  });
}
```

## API Endpoints

### OpenAI-Compatible (v1)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/models` | GET | List available models |
| `/v1/chat/completions` | POST | Chat completion (OpenAI format) |
| `/v1/completions` | POST | Text completion (legacy) |
| `/v1/messages` | POST | Claude Messages API |
| `/v1beta/models/:model:generateContent` | POST | Gemini API |

### Management (v0)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v0/management/health` | GET | Server health |
| `/v0/management/auth-files` | GET | List auth files |
| `/v0/management/auth-files/:id` | DELETE | Delete auth file |
| `/v0/management/usage` | GET | Usage statistics |
| `/v0/management/logs` | GET | Request logs |
| `/v0/management/logs` | DELETE | Clear logs |
| `/v0/management/config` | GET/PUT | Configuration |
| `/v0/management/api-keys` | GET/POST/DELETE | API keys |
| `/v0/management/oauth/start` | POST | Start OAuth flow |
| `/v0/management/oauth/poll` | GET | Poll OAuth status |

## Technology Decisions

### Why Hono over Elysia

| Aspect | Hono | Elysia |
|--------|------|--------|
| Bundle size | Smaller | Larger |
| Streaming | Native support | Requires plugins |
| Type safety | Good | Excellent |
| Community | Larger | Growing |
| Edge runtime | Designed for | Bun-first |

**Decision:** Hono - better for streaming, simpler API, edge-compatible.

### Why Zod for Validation

- Type inference from schemas
- Transform support for config normalization
- Good error messages
- Works with OpenAPI generation

### Why SQLite for Default Store

- Zero configuration
- Bun has native SQLite support
- Fast for single-node deployment
- Easy to backup (single file)

## Performance Considerations

1. **Streaming Efficiency**: Use Bun's native `ReadableStream`
2. **Connection Pooling**: Reuse HTTP connections to providers
3. **Credential Caching**: Cache valid tokens in memory
4. **Request Deduplication**: Prevent duplicate OAuth token refreshes

## Proxy Pass-Through (Migration Strategy)

During development, quotio-server proxies unimplemented endpoints to the CLIProxyAPI binary.

### Architecture

```
Client Request → quotio-server (port 8317)
                      ↓
         ┌────────────────────────────┐
         │  Is path implemented?       │
         └────────────────────────────┘
                 ↓ YES          ↓ NO
          Handle natively    Forward to CLIProxyAPI (port 18317)
```

### Implementation

```typescript
// packages/server/src/api/middleware/proxy-passthrough.ts
import { Context, Next } from 'hono';

// Paths that should be forwarded to CLIProxyAPI
// Remove from this list as features are implemented natively
const PASSTHROUGH_PATHS = new Set([
  '/v1/messages',           // Claude native format
  '/v1beta',                // Gemini native format (prefix match)
  '/anthropic/callback',    // OAuth callbacks
  '/google/callback',
  '/kiro/callback',
]);

const CLI_PROXY_PORT = 18317;

export async function passthroughMiddleware(c: Context, next: Next) {
  const path = c.req.path;
  
  // Check exact match
  if (PASSTHROUGH_PATHS.has(path)) {
    return forwardRequest(c);
  }
  
  // Check prefix match
  for (const prefix of PASSTHROUGH_PATHS) {
    if (path.startsWith(prefix)) {
      return forwardRequest(c);
    }
  }
  
  return next();
}

async function forwardRequest(c: Context): Promise<Response> {
  const targetUrl = `http://localhost:${CLI_PROXY_PORT}${c.req.path}`;
  
  try {
    const response = await fetch(targetUrl, {
      method: c.req.method,
      headers: c.req.raw.headers,
      body: c.req.raw.body,
      // @ts-ignore - Bun supports duplex
      duplex: 'half',
    });
    
    // Stream response back
    return new Response(response.body, {
      status: response.status,
      headers: response.headers,
    });
  } catch (error) {
    // CLIProxyAPI not running
    return c.json(
      { error: 'Backend proxy unavailable', details: String(error) },
      503
    );
  }
}
```

### Migration Timeline

| Week | Action | Paths Removed from Passthrough |
|------|--------|--------------------------------|
| 1-2 | Initial scaffold | None (all passthrough) |
| 3-4 | Translation matrix | `/v1/chat/completions` |
| 5 | Gemini support | `/v1beta/*` |
| 6-7 | Claude support | `/v1/messages` |
| 8+ | Full native | All OAuth callbacks |

### Environment Variables

```bash
# Enable/disable passthrough (default: true during development)
ENABLE_PASSTHROUGH=true

# CLIProxyAPI port (default: 18317)
CLI_PROXY_PORT=18317

# Passthrough timeout in seconds (default: 120)
PASSTHROUGH_TIMEOUT=120
```

### Health Check Coordination

The passthrough middleware also handles health coordination:

```typescript
// Check if CLIProxyAPI is running before passthrough
async function checkCLIProxyHealth(): Promise<boolean> {
  try {
    const response = await fetch(`http://localhost:${CLI_PROXY_PORT}/health`, {
      signal: AbortSignal.timeout(1000),
    });
    return response.ok;
  } catch {
    return false;
  }
}
```

## Initial Scaffold Tasks

- [ ] Create `packages/server/` structure
- [ ] Implement config loader with Zod
- [ ] Set up Hono app with basic middleware
- [ ] Add health check endpoint
- [ ] Implement `/v1/models` (static list for now)
- [ ] **Add proxy pass-through middleware** (forwards to CLIProxyAPI)
- [ ] Write basic tests

## Integration with Swift App

During migration, the Swift app can:
1. Continue using IPC to `quotio-cli` daemon
2. The daemon proxies to `quotio-server` instead of `CLIProxyAPI`
3. Gradual migration to direct HTTP calls

```
Swift App → IPC → quotio-cli → HTTP → quotio-server → AI Providers
                                  ↓
                            (replaces CLIProxyAPI)
```
