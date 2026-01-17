# Phase 3: Auth Handlers

**Duration:** 3 weeks
**Goal:** Port all OAuth/authentication handlers from CLIProxyAPI Go to TypeScript

## Provider Overview

| Provider | Auth Type | Complexity | Priority |
|----------|-----------|------------|----------|
| Gemini CLI | OAuth2 + PKCE | High | P0 |
| Claude | OAuth2 | Medium | P0 |
| Codex/OpenAI | OAuth2 | Medium | P0 |
| GitHub Copilot | Device Code | Medium | P1 |
| Antigravity | OAuth2 (Google) | Medium | P1 |
| Vertex AI | Service Account | Low | P1 |
| Kiro | OAuth2 (AWS) | High | P2 |
| iFlow | OAuth2 | Medium | P2 |
| Qwen | OAuth2 | Medium | P2 |

## Common Auth Infrastructure

### Auth File Schema

```typescript
// packages/core/src/models/auth-file.ts
import { z } from 'zod';

export const AuthFileSchema = z.object({
  id: z.string(),
  provider: z.string(),
  email: z.string().optional(),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
  
  // Token data
  accessToken: z.string().optional(),
  refreshToken: z.string().optional(),
  expiresAt: z.string().datetime().optional(),
  
  // Provider-specific
  projectId: z.string().optional(),
  region: z.string().optional(),
  
  // Status
  status: z.enum(['ready', 'cooling', 'error', 'refreshing']),
  statusMessage: z.string().optional(),
  disabled: z.boolean().default(false),
  
  // Quota
  quotaUsed: z.number().optional(),
  quotaLimit: z.number().optional(),
  quotaResetAt: z.string().datetime().optional(),
});

export type AuthFile = z.infer<typeof AuthFileSchema>;
```

### OAuth Base Handler

```typescript
// packages/server/src/auth/oauth/base.ts
import { generateState, generateCodeVerifier, OAuth2Client } from 'oslo/oauth2';

export interface OAuthConfig {
  clientId: string;
  clientSecret: string;
  authorizationEndpoint: string;
  tokenEndpoint: string;
  scopes: string[];
  redirectUri: string;
}

export abstract class BaseOAuthHandler {
  protected client: OAuth2Client;
  protected config: OAuthConfig;
  
  // Pending OAuth sessions
  protected pendingSessions: Map<string, {
    codeVerifier: string;
    createdAt: Date;
    provider: string;
  }> = new Map();
  
  constructor(config: OAuthConfig) {
    this.config = config;
    this.client = new OAuth2Client(
      config.clientId,
      config.authorizationEndpoint,
      config.tokenEndpoint,
      { redirectURI: config.redirectUri }
    );
  }
  
  async startOAuth(): Promise<{ url: string; state: string }> {
    const state = generateState();
    const codeVerifier = generateCodeVerifier();
    
    const url = await this.client.createAuthorizationURL({
      state,
      scopes: this.config.scopes,
      codeVerifier, // PKCE
    });
    
    this.pendingSessions.set(state, {
      codeVerifier,
      createdAt: new Date(),
      provider: this.getProviderName(),
    });
    
    // Cleanup old sessions (> 10 minutes)
    this.cleanupSessions();
    
    return { url: url.toString(), state };
  }
  
  async handleCallback(
    code: string,
    state: string
  ): Promise<AuthFile> {
    const session = this.pendingSessions.get(state);
    if (!session) {
      throw new Error('Invalid or expired OAuth session');
    }
    
    const tokens = await this.client.validateAuthorizationCode(code, {
      codeVerifier: session.codeVerifier,
      credentials: this.config.clientSecret,
    });
    
    this.pendingSessions.delete(state);
    
    return this.createAuthFile(tokens);
  }
  
  abstract getProviderName(): string;
  abstract createAuthFile(tokens: TokenResponse): Promise<AuthFile>;
  abstract refreshToken(authFile: AuthFile): Promise<AuthFile>;
  
  protected cleanupSessions() {
    const tenMinutesAgo = Date.now() - 10 * 60 * 1000;
    for (const [state, session] of this.pendingSessions) {
      if (session.createdAt.getTime() < tenMinutesAgo) {
        this.pendingSessions.delete(state);
      }
    }
  }
}
```

## Provider Implementations

### 1. Gemini CLI OAuth

**Reference:** `internal/auth/gemini/oauth_server.go`

```typescript
// packages/server/src/auth/oauth/gemini.ts
import { BaseOAuthHandler } from './base';

const GEMINI_CONFIG = {
  clientId: '681255809395-oo8ft2oprdrnp9e3aqf6av3hmdib135j.apps.googleusercontent.com',
  clientSecret: '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',
  authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  tokenEndpoint: 'https://oauth2.googleapis.com/token',
  scopes: [
    'https://www.googleapis.com/auth/cloud-platform',
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ],
  redirectUri: 'http://localhost:PORT/google/callback',
};

export class GeminiOAuthHandler extends BaseOAuthHandler {
  constructor(port: number) {
    super({
      ...GEMINI_CONFIG,
      redirectUri: GEMINI_CONFIG.redirectUri.replace('PORT', String(port)),
    });
  }
  
  getProviderName(): string {
    return 'gemini-cli';
  }
  
  async createAuthFile(tokens: TokenResponse): Promise<AuthFile> {
    // Fetch user info to get email
    const userInfo = await this.fetchUserInfo(tokens.accessToken);
    
    return {
      id: `gemini-cli-${Date.now()}`,
      provider: 'gemini-cli',
      email: userInfo.email,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresAt: tokens.expiresAt?.toISOString(),
      status: 'ready',
    };
  }
  
  async refreshToken(authFile: AuthFile): Promise<AuthFile> {
    if (!authFile.refreshToken) {
      throw new Error('No refresh token available');
    }
    
    const tokens = await this.client.refreshAccessToken(authFile.refreshToken);
    
    return {
      ...authFile,
      accessToken: tokens.accessToken,
      expiresAt: tokens.expiresAt?.toISOString(),
      updatedAt: new Date().toISOString(),
      status: 'ready',
    };
  }
  
  private async fetchUserInfo(accessToken: string) {
    const response = await fetch(
      'https://www.googleapis.com/oauth2/v2/userinfo',
      { headers: { Authorization: `Bearer ${accessToken}` } }
    );
    return response.json();
  }
}
```

### 2. Claude OAuth

**Reference:** `internal/auth/claude/oauth_server.go`

```typescript
// packages/server/src/auth/oauth/claude.ts
import { BaseOAuthHandler } from './base';

const CLAUDE_CONFIG = {
  clientId: 'claude-cli',
  clientSecret: '', // No secret for public client
  authorizationEndpoint: 'https://console.anthropic.com/oauth/authorize',
  tokenEndpoint: 'https://console.anthropic.com/v1/oauth/token',
  scopes: ['claude'],
  redirectUri: 'http://localhost:PORT/anthropic/callback',
};

export class ClaudeOAuthHandler extends BaseOAuthHandler {
  constructor(port: number) {
    super({
      ...CLAUDE_CONFIG,
      redirectUri: CLAUDE_CONFIG.redirectUri.replace('PORT', String(port)),
    });
  }
  
  getProviderName(): string {
    return 'claude';
  }
  
  async createAuthFile(tokens: TokenResponse): Promise<AuthFile> {
    // Claude tokens include user info in JWT
    const userInfo = this.decodeJWT(tokens.accessToken);
    
    return {
      id: `claude-${Date.now()}`,
      provider: 'claude',
      email: userInfo.email,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresAt: tokens.expiresAt?.toISOString(),
      status: 'ready',
    };
  }
  
  async refreshToken(authFile: AuthFile): Promise<AuthFile> {
    // Claude uses long-lived tokens, rarely needs refresh
    if (!authFile.refreshToken) {
      throw new Error('No refresh token available');
    }
    
    const tokens = await this.client.refreshAccessToken(authFile.refreshToken);
    
    return {
      ...authFile,
      accessToken: tokens.accessToken,
      expiresAt: tokens.expiresAt?.toISOString(),
      updatedAt: new Date().toISOString(),
      status: 'ready',
    };
  }
  
  private decodeJWT(token: string) {
    const parts = token.split('.');
    const payload = JSON.parse(atob(parts[1]));
    return { email: payload.email || payload.sub };
  }
}
```

### 3. GitHub Copilot (Device Code Flow)

**Reference:** `internal/auth/copilot/oauth_server.go`

```typescript
// packages/server/src/auth/oauth/copilot.ts

const COPILOT_CONFIG = {
  clientId: 'Iv1.b507a08c87ecfe98', // GitHub CLI client ID
  deviceCodeEndpoint: 'https://github.com/login/device/code',
  tokenEndpoint: 'https://github.com/login/oauth/access_token',
  scopes: ['copilot'],
};

export class CopilotOAuthHandler {
  private pendingDeviceCodes: Map<string, DeviceCodeSession> = new Map();
  
  async startDeviceFlow(): Promise<DeviceCodeResponse> {
    const response = await fetch(COPILOT_CONFIG.deviceCodeEndpoint, {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        client_id: COPILOT_CONFIG.clientId,
        scope: COPILOT_CONFIG.scopes.join(' '),
      }),
    });
    
    const data = await response.json();
    
    // Store session
    this.pendingDeviceCodes.set(data.device_code, {
      deviceCode: data.device_code,
      userCode: data.user_code,
      verificationUri: data.verification_uri,
      expiresAt: new Date(Date.now() + data.expires_in * 1000),
      interval: data.interval,
    });
    
    return {
      userCode: data.user_code,
      verificationUri: data.verification_uri,
      expiresIn: data.expires_in,
      interval: data.interval,
    };
  }
  
  async pollForToken(deviceCode: string): Promise<AuthFile | null> {
    const session = this.pendingDeviceCodes.get(deviceCode);
    if (!session) {
      throw new Error('Invalid device code');
    }
    
    if (new Date() > session.expiresAt) {
      this.pendingDeviceCodes.delete(deviceCode);
      throw new Error('Device code expired');
    }
    
    const response = await fetch(COPILOT_CONFIG.tokenEndpoint, {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        client_id: COPILOT_CONFIG.clientId,
        device_code: deviceCode,
        grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
      }),
    });
    
    const data = await response.json();
    
    if (data.error === 'authorization_pending') {
      return null; // Still waiting for user
    }
    
    if (data.error) {
      this.pendingDeviceCodes.delete(deviceCode);
      throw new Error(data.error_description || data.error);
    }
    
    this.pendingDeviceCodes.delete(deviceCode);
    
    // Get Copilot token using GitHub token
    const copilotToken = await this.getCopilotToken(data.access_token);
    
    return {
      id: `github-copilot-${Date.now()}`,
      provider: 'github-copilot',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      accessToken: copilotToken.token,
      expiresAt: copilotToken.expiresAt,
      status: 'ready',
    };
  }
  
  private async getCopilotToken(githubToken: string) {
    const response = await fetch(
      'https://api.github.com/copilot_internal/v2/token',
      {
        headers: {
          'Authorization': `token ${githubToken}`,
          'User-Agent': 'GithubCopilot/1.0',
        },
      }
    );
    
    const data = await response.json();
    return {
      token: data.token,
      expiresAt: new Date(data.expires_at).toISOString(),
    };
  }
}
```

### 4. Vertex AI (Service Account)

**Reference:** `internal/auth/vertex/service_account.go`

```typescript
// packages/server/src/auth/oauth/vertex.ts
import { SignJWT } from 'jose';

export class VertexAuthHandler {
  async importServiceAccount(
    serviceAccountJson: string
  ): Promise<AuthFile> {
    const sa = JSON.parse(serviceAccountJson);
    
    // Validate required fields
    if (!sa.client_email || !sa.private_key || !sa.project_id) {
      throw new Error('Invalid service account JSON');
    }
    
    // Generate access token
    const accessToken = await this.generateAccessToken(sa);
    
    return {
      id: `vertex-${Date.now()}`,
      provider: 'vertex',
      email: sa.client_email,
      projectId: sa.project_id,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      accessToken,
      expiresAt: new Date(Date.now() + 3600 * 1000).toISOString(),
      status: 'ready',
      // Store service account for refresh
      _serviceAccount: serviceAccountJson, // Encrypted in store
    };
  }
  
  async refreshToken(authFile: AuthFile): Promise<AuthFile> {
    if (!authFile._serviceAccount) {
      throw new Error('No service account available for refresh');
    }
    
    const sa = JSON.parse(authFile._serviceAccount);
    const accessToken = await this.generateAccessToken(sa);
    
    return {
      ...authFile,
      accessToken,
      expiresAt: new Date(Date.now() + 3600 * 1000).toISOString(),
      updatedAt: new Date().toISOString(),
      status: 'ready',
    };
  }
  
  private async generateAccessToken(sa: ServiceAccount): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    
    const jwt = await new SignJWT({
      iss: sa.client_email,
      sub: sa.client_email,
      aud: 'https://oauth2.googleapis.com/token',
      scope: 'https://www.googleapis.com/auth/cloud-platform',
    })
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
      .setIssuedAt(now)
      .setExpirationTime(now + 3600)
      .sign(await importPKCS8(sa.private_key, 'RS256'));
    
    const response = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    });
    
    const data = await response.json();
    return data.access_token;
  }
}
```

### 5. Kiro/AWS CodeWhisperer

**Reference:** `internal/auth/kiro/oauth_server.go`

```typescript
// packages/server/src/auth/oauth/kiro.ts
import { BaseOAuthHandler } from './base';

const KIRO_CONFIG = {
  clientId: 'builderIdPublicClient',
  authorizationEndpoint: 'https://kiro.dev/api/sso/v1/login',
  tokenEndpoint: 'https://kiro.dev/api/sso/v1/token',
  scopes: ['codewhisperer:conversations', 'codewhisperer:completions'],
  redirectUri: 'http://localhost:PORT/kiro/callback',
};

export class KiroOAuthHandler extends BaseOAuthHandler {
  constructor(port: number) {
    super({
      ...KIRO_CONFIG,
      redirectUri: KIRO_CONFIG.redirectUri.replace('PORT', String(port)),
      clientSecret: '', // Public client
    });
  }
  
  getProviderName(): string {
    return 'kiro';
  }
  
  async startOAuth(): Promise<{ url: string; state: string }> {
    // Kiro uses incognito browser by default for multi-account
    const result = await super.startOAuth();
    return { ...result, incognito: true };
  }
  
  async createAuthFile(tokens: TokenResponse): Promise<AuthFile> {
    return {
      id: `kiro-${Date.now()}`,
      provider: 'kiro',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresAt: tokens.expiresAt?.toISOString(),
      region: 'us-east-1', // Kiro only operates in us-east-1
      status: 'ready',
    };
  }
  
  async refreshToken(authFile: AuthFile): Promise<AuthFile> {
    if (!authFile.refreshToken) {
      throw new Error('No refresh token available');
    }
    
    const response = await fetch(KIRO_CONFIG.tokenEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: authFile.refreshToken,
        client_id: KIRO_CONFIG.clientId,
      }),
    });
    
    const tokens = await response.json();
    
    return {
      ...authFile,
      accessToken: tokens.access_token,
      expiresAt: new Date(Date.now() + tokens.expires_in * 1000).toISOString(),
      updatedAt: new Date().toISOString(),
      status: 'ready',
    };
  }
}
```

## Auth Manager

```typescript
// packages/server/src/auth/index.ts
import type { Config } from '../config/schema';
import type { TokenStore } from '../store';
import { GeminiOAuthHandler } from './oauth/gemini';
import { ClaudeOAuthHandler } from './oauth/claude';
import { CopilotOAuthHandler } from './oauth/copilot';
import { VertexAuthHandler } from './oauth/vertex';
import { KiroOAuthHandler } from './oauth/kiro';
// ... other handlers

export class AuthManager {
  private handlers: Map<string, BaseOAuthHandler>;
  private store: TokenStore;
  private config: Config;
  
  constructor(config: Config, store: TokenStore) {
    this.config = config;
    this.store = store;
    this.handlers = new Map();
    
    // Initialize handlers
    this.handlers.set('gemini-cli', new GeminiOAuthHandler(config.port));
    this.handlers.set('claude', new ClaudeOAuthHandler(config.port));
    this.handlers.set('github-copilot', new CopilotOAuthHandler());
    this.handlers.set('vertex', new VertexAuthHandler());
    this.handlers.set('kiro', new KiroOAuthHandler(config.port));
    // ... other handlers
  }
  
  async listAuthFiles(): Promise<AuthFile[]> {
    return this.store.listAuthFiles();
  }
  
  async getAuthFile(id: string): Promise<AuthFile | null> {
    return this.store.getAuthFile(id);
  }
  
  async deleteAuthFile(id: string): Promise<void> {
    return this.store.deleteAuthFile(id);
  }
  
  async startOAuth(provider: string): Promise<{ url: string; state: string }> {
    const handler = this.handlers.get(provider);
    if (!handler) {
      throw new Error(`Unknown provider: ${provider}`);
    }
    return handler.startOAuth();
  }
  
  async handleCallback(
    provider: string,
    code: string,
    state: string
  ): Promise<AuthFile> {
    const handler = this.handlers.get(provider);
    if (!handler) {
      throw new Error(`Unknown provider: ${provider}`);
    }
    
    const authFile = await handler.handleCallback(code, state);
    await this.store.saveAuthFile(authFile);
    return authFile;
  }
  
  async refreshIfNeeded(authFile: AuthFile): Promise<AuthFile> {
    // Check if token expires within 5 minutes
    if (authFile.expiresAt) {
      const expiresAt = new Date(authFile.expiresAt);
      const fiveMinutesFromNow = new Date(Date.now() + 5 * 60 * 1000);
      
      if (expiresAt > fiveMinutesFromNow) {
        return authFile; // Still valid
      }
    }
    
    const handler = this.handlers.get(authFile.provider);
    if (!handler) {
      throw new Error(`Unknown provider: ${authFile.provider}`);
    }
    
    const refreshed = await handler.refreshToken(authFile);
    await this.store.saveAuthFile(refreshed);
    return refreshed;
  }
  
  async getValidCredential(
    provider: string,
    model?: string
  ): Promise<AuthFile | null> {
    const authFiles = await this.store.listAuthFiles();
    const candidates = authFiles.filter(
      (af) => af.provider === provider && af.status === 'ready' && !af.disabled
    );
    
    if (candidates.length === 0) {
      return null;
    }
    
    // Apply routing strategy
    const selected = this.selectCredential(candidates);
    
    // Refresh if needed
    return this.refreshIfNeeded(selected);
  }
  
  private selectCredential(candidates: AuthFile[]): AuthFile {
    // TODO: Implement round-robin / fill-first
    return candidates[0];
  }
}
```

## Implementation Checklist

### Week 1: Core Infrastructure
- [ ] Create `BaseOAuthHandler` abstract class
- [ ] Implement token store interface
- [ ] Implement file-based token store
- [ ] Create `AuthManager` class
- [ ] Add OAuth callback routes to Hono app

### Week 2: Primary Providers
- [ ] Implement Gemini OAuth (PKCE)
- [ ] Implement Claude OAuth
- [ ] Implement Codex/OpenAI OAuth
- [ ] Test all primary providers

### Week 3: Secondary Providers
- [ ] Implement GitHub Copilot (Device Code)
- [ ] Implement Vertex AI (Service Account)
- [ ] Implement Antigravity OAuth
- [ ] Implement Kiro OAuth
- [ ] Implement iFlow OAuth
- [ ] Implement Qwen OAuth
- [ ] Test all secondary providers

## Testing Strategy

```typescript
// packages/server/tests/auth/gemini.test.ts
import { describe, it, expect, mock } from 'bun:test';
import { GeminiOAuthHandler } from '../../src/auth/oauth/gemini';

describe('GeminiOAuthHandler', () => {
  it('should generate valid OAuth URL', async () => {
    const handler = new GeminiOAuthHandler(8317);
    const { url, state } = await handler.startOAuth();
    
    expect(url).toContain('accounts.google.com');
    expect(url).toContain('client_id=');
    expect(url).toContain('code_challenge='); // PKCE
    expect(state).toBeDefined();
  });
  
  it('should handle callback and create auth file', async () => {
    const handler = new GeminiOAuthHandler(8317);
    const { state } = await handler.startOAuth();
    
    // Mock token endpoint
    mock.module('oslo/oauth2', () => ({
      OAuth2Client: class {
        async validateAuthorizationCode() {
          return {
            accessToken: 'test-token',
            refreshToken: 'test-refresh',
            expiresAt: new Date(Date.now() + 3600000),
          };
        }
      },
    }));
    
    const authFile = await handler.handleCallback('test-code', state);
    
    expect(authFile.provider).toBe('gemini-cli');
    expect(authFile.accessToken).toBeDefined();
    expect(authFile.status).toBe('ready');
  });
});
```

## Security Considerations

1. **Token Storage**: Encrypt tokens at rest
2. **PKCE**: Always use for public clients
3. **State Validation**: Prevent CSRF attacks
4. **Session Cleanup**: Expire old OAuth sessions
5. **Secure Comparison**: Use constant-time comparison for secrets

## Credential Prioritization

Based on patterns from LLM-API-Key-Proxy, implement intelligent credential selection.

### Tier Detection

```typescript
// packages/server/src/auth/tier-detector.ts

type CredentialTier = 'paid' | 'free' | 'unknown';

interface TierInfo {
  tier: CredentialTier;
  quotaResetInterval: 'hourly' | 'daily' | 'weekly' | 'monthly';
  maxQuota?: number;
}

export async function detectCredentialTier(
  authFile: AuthFile
): Promise<TierInfo> {
  switch (authFile.provider) {
    case 'gemini-cli':
      return detectGeminiTier(authFile);
    case 'antigravity':
      return detectAntigravityTier(authFile);
    case 'claude':
      return detectClaudeTier(authFile);
    default:
      return { tier: 'unknown', quotaResetInterval: 'daily' };
  }
}

async function detectGeminiTier(authFile: AuthFile): Promise<TierInfo> {
  // Gemini: Check billing status via Cloud Billing API
  try {
    const billingInfo = await fetchBillingInfo(authFile.accessToken, authFile.projectId);
    
    if (billingInfo.billingEnabled) {
      return {
        tier: 'paid',
        quotaResetInterval: 'monthly',
        maxQuota: undefined, // Pay-as-you-go
      };
    }
    
    return {
      tier: 'free',
      quotaResetInterval: 'daily',
      maxQuota: 1500, // Free tier limit
    };
  } catch {
    return { tier: 'unknown', quotaResetInterval: 'daily' };
  }
}

async function detectAntigravityTier(authFile: AuthFile): Promise<TierInfo> {
  // Antigravity: Paid tier resets every 5 hours, free tier weekly
  // Detection based on quota response patterns
  try {
    const quota = await fetchAntigravityQuota(authFile.accessToken);
    
    // Paid tier has 5-hour reset window
    if (quota.resetWindowHours <= 5) {
      return {
        tier: 'paid',
        quotaResetInterval: 'hourly', // Actually 5-hourly
        maxQuota: quota.limit,
      };
    }
    
    return {
      tier: 'free',
      quotaResetInterval: 'weekly',
      maxQuota: quota.limit,
    };
  } catch {
    return { tier: 'unknown', quotaResetInterval: 'weekly' };
  }
}
```

### Model-Tier Requirements

```typescript
// packages/server/src/auth/model-requirements.ts

interface ModelRequirement {
  minTier: CredentialTier;
  preferredTier?: CredentialTier;
  quotaGroup?: string; // Models sharing same quota
}

const MODEL_REQUIREMENTS: Record<string, ModelRequirement> = {
  // Gemini 3 requires paid tier
  'gemini-3-pro': { minTier: 'paid' },
  'gemini-3-pro-high': { minTier: 'paid' },
  'gemini-3-pro-low': { minTier: 'paid' },
  
  // Gemini 2.5 works with free tier but prefers paid
  'gemini-2.5-flash': { minTier: 'free', preferredTier: 'paid' },
  'gemini-2.5-flash-thinking': { minTier: 'free', preferredTier: 'paid' },
  
  // Antigravity quota groups
  'claude-sonnet-4-5': { 
    minTier: 'free',
    quotaGroup: 'antigravity-claude',
  },
  'claude-opus-4-5': { 
    minTier: 'free',
    quotaGroup: 'antigravity-claude',
  },
  'gpt-oss-120b': {
    minTier: 'free',
    quotaGroup: 'antigravity-claude', // Shares quota with Claude
  },
};

export function getModelRequirements(model: string): ModelRequirement {
  return MODEL_REQUIREMENTS[model] || { minTier: 'free' };
}
```

### Priority-Based Selection

```typescript
// packages/server/src/auth/credential-selector.ts

interface SelectionContext {
  model: string;
  strategy: 'round-robin' | 'fill-first';
  rotationTolerance: number; // 0.0 = deterministic, 2.0 = weighted random
}

export async function selectCredential(
  candidates: AuthFile[],
  context: SelectionContext,
  usageManager: UsageManager
): Promise<AuthFile | null> {
  const requirements = getModelRequirements(context.model);
  
  // 1. Filter by minimum tier requirement
  let eligible = candidates.filter(c => 
    c.tier === 'paid' || 
    (c.tier === 'free' && requirements.minTier === 'free') ||
    c.tier === 'unknown'
  );
  
  if (eligible.length === 0) {
    return null;
  }
  
  // 2. Sort by preference (paid first if preferred)
  if (requirements.preferredTier === 'paid') {
    eligible.sort((a, b) => {
      if (a.tier === 'paid' && b.tier !== 'paid') return -1;
      if (b.tier === 'paid' && a.tier !== 'paid') return 1;
      return 0;
    });
  }
  
  // 3. Filter out cooled-down credentials
  eligible = eligible.filter(c => !usageManager.isOnCooldown(c.id, context.model));
  
  if (eligible.length === 0) {
    return null;
  }
  
  // 4. Apply selection strategy
  if (context.strategy === 'fill-first') {
    return selectFillFirst(eligible, context.model, usageManager);
  }
  
  return selectRoundRobin(eligible, context, usageManager);
}

function selectRoundRobin(
  eligible: AuthFile[],
  context: SelectionContext,
  usageManager: UsageManager
): AuthFile {
  const usage = eligible.map(c => ({
    credential: c,
    count: usageManager.getUsageCount(c.id, context.model),
  }));
  
  if (context.rotationTolerance === 0) {
    // Deterministic: always pick least used
    usage.sort((a, b) => a.count - b.count);
    return usage[0].credential;
  }
  
  // Weighted random selection
  const maxUsage = Math.max(...usage.map(u => u.count));
  const weights = usage.map(u => ({
    credential: u.credential,
    weight: (maxUsage - u.count) + context.rotationTolerance + 1,
  }));
  
  const totalWeight = weights.reduce((sum, w) => sum + w.weight, 0);
  let random = Math.random() * totalWeight;
  
  for (const { credential, weight } of weights) {
    random -= weight;
    if (random <= 0) {
      return credential;
    }
  }
  
  return weights[0].credential;
}

function selectFillFirst(
  eligible: AuthFile[],
  model: string,
  usageManager: UsageManager
): AuthFile {
  // Use first credential until it's exhausted, then move to next
  for (const credential of eligible) {
    const quota = usageManager.getRemainingQuota(credential.id, model);
    if (quota > 0 || quota === undefined) {
      return credential;
    }
  }
  
  // All exhausted, return first (will likely fail but trigger cooldown)
  return eligible[0];
}
```

### Quota Groups

Models sharing quota should be tracked together:

```typescript
// packages/server/src/auth/quota-groups.ts

const QUOTA_GROUPS: Record<string, string[]> = {
  'antigravity-claude': [
    'claude-sonnet-4-5',
    'claude-opus-4-5',
    'claude-sonnet-4-5-thinking',
    'claude-opus-4-5-thinking',
    'gpt-oss-120b-medium',
  ],
  'antigravity-gemini3': [
    'gemini-3-pro-high',
    'gemini-3-pro-low',
    'gemini-3-pro-preview',
  ],
  'antigravity-gemini25': [
    'gemini-2.5-flash',
    'gemini-2.5-flash-thinking',
    'gemini-2.5-flash-lite',
  ],
};

export function getQuotaGroupModels(model: string): string[] {
  for (const [group, models] of Object.entries(QUOTA_GROUPS)) {
    if (models.includes(model)) {
      return models;
    }
  }
  return [model]; // Model is its own group
}

// When recording usage for a model, record for all models in the group
export function recordGroupUsage(
  credentialId: string,
  model: string,
  tokens: number,
  usageManager: UsageManager
) {
  const groupModels = getQuotaGroupModels(model);
  for (const m of groupModels) {
    usageManager.recordUsage(credentialId, m, tokens);
  }
}
```

### Background Quota Refresh

```typescript
// packages/server/src/auth/background-refresher.ts

const REFRESH_INTERVAL = 5 * 60 * 1000; // 5 minutes

export class BackgroundQuotaRefresher {
  private interval: Timer | null = null;
  
  constructor(
    private authManager: AuthManager,
    private usageManager: UsageManager
  ) {}
  
  start() {
    this.interval = setInterval(() => this.refresh(), REFRESH_INTERVAL);
    this.refresh(); // Initial refresh
  }
  
  stop() {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
  }
  
  private async refresh() {
    const authFiles = await this.authManager.listAuthFiles();
    
    for (const authFile of authFiles) {
      if (authFile.status !== 'ready') continue;
      
      try {
        const quota = await this.fetchQuota(authFile);
        if (quota) {
          this.usageManager.updateQuotaBaseline(authFile.id, quota);
        }
      } catch (error) {
        console.error(`Failed to refresh quota for ${authFile.id}:`, error);
      }
    }
  }
  
  private async fetchQuota(authFile: AuthFile): Promise<QuotaInfo | null> {
    switch (authFile.provider) {
      case 'antigravity':
        return fetchAntigravityQuota(authFile.accessToken);
      case 'gemini-cli':
        return fetchGeminiQuota(authFile.accessToken, authFile.projectId);
      default:
        return null; // Provider doesn't expose quota API
    }
  }
}
```
