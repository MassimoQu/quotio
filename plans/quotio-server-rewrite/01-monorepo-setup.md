# Phase 1: Monorepo Setup

**Duration:** 1 week
**Goal:** Convert current repository to Bun workspaces with Turborepo

## Current Structure

```
karachi/
├── Quotio/              # Swift macOS app
├── quotio-cli/          # Bun CLI tool (~16K LOC)
├── scripts/             # Build scripts
├── docs/                # Documentation
└── plans/               # Implementation plans
```

## Target Structure

```
karachi/
├── Quotio/                      # Swift macOS app (unchanged)
├── apps/
│   └── tauri/                   # Future Tauri app (placeholder)
├── packages/
│   ├── core/                    # Shared types, models, utils
│   │   ├── src/
│   │   │   ├── types/           # Shared TypeScript types
│   │   │   ├── models/          # Data models (AuthFile, Provider, etc.)
│   │   │   ├── utils/           # Common utilities
│   │   │   └── index.ts         # Package exports
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── server/                  # quotio-server (NEW)
│   │   ├── src/
│   │   │   ├── api/             # HTTP routes
│   │   │   ├── auth/            # OAuth handlers
│   │   │   ├── proxy/           # Request proxying
│   │   │   ├── translator/      # Format conversion
│   │   │   ├── store/           # Token storage
│   │   │   └── index.ts         # Server entry
│   │   ├── package.json
│   │   └── tsconfig.json
│   └── cli/                     # quotio-cli (refactored)
│       ├── src/
│       │   ├── commands/        # CLI commands
│       │   ├── ipc/             # IPC protocol (for Swift app)
│       │   └── index.ts         # CLI entry
│       ├── package.json
│       └── tsconfig.json
├── package.json                 # Workspace root
├── turbo.json                   # Turborepo config
├── biome.json                   # Shared linting
├── tsconfig.base.json           # Shared TS config
├── scripts/                     # Build scripts
├── docs/                        # Documentation
└── plans/                       # Implementation plans
```

## Implementation Steps

### Step 1: Initialize Workspace Root

Create root `package.json`:

```json
{
  "name": "quotio-monorepo",
  "private": true,
  "workspaces": [
    "packages/*",
    "apps/*"
  ],
  "scripts": {
    "build": "turbo run build",
    "dev": "turbo run dev",
    "test": "turbo run test",
    "lint": "turbo run lint",
    "format": "turbo run format",
    "typecheck": "turbo run typecheck"
  },
  "devDependencies": {
    "@types/bun": "^1.3.5",
    "@biomejs/biome": "^1.9.4",
    "turbo": "^2.5.0",
    "typescript": "^5.8.0"
  },
  "engines": {
    "bun": ">=1.1.0"
  }
}
```

### Step 2: Create Turborepo Config

Create `turbo.json`:

```json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": ["**/.env.*local"],
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**", "!.next/cache/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "test": {
      "dependsOn": ["build"]
    },
    "lint": {
      "dependsOn": ["^build"]
    },
    "typecheck": {
      "dependsOn": ["^build"]
    },
    "format": {
      "cache": false
    }
  }
}
```

### Step 3: Create Shared TypeScript Config

Create `tsconfig.base.json`:

```json
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ESNext"],
    "types": ["bun-types"],
    "strict": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "declaration": true,
    "declarationMap": true,
    "composite": true,
    "noEmit": false,
    "outDir": "dist",
    "rootDir": "src",
    "resolveJsonModule": true,
    "allowSyntheticDefaultImports": true,
    "forceConsistentCasingInFileNames": true,
    "noImplicitAny": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  }
}
```

### Step 4: Create Shared Biome Config

Create `biome.json`:

```json
{
  "$schema": "https://biomejs.dev/schemas/1.9.4/schema.json",
  "organizeImports": {
    "enabled": true
  },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true
    }
  },
  "formatter": {
    "enabled": true,
    "indentStyle": "tab",
    "indentWidth": 2
  }
}
```

### Step 5: Create `@quotio/core` Package

**`packages/core/package.json`:**

```json
{
  "name": "@quotio/core",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "import": "./dist/index.js",
      "types": "./dist/index.d.ts"
    },
    "./types": {
      "import": "./dist/types/index.js",
      "types": "./dist/types/index.d.ts"
    },
    "./models": {
      "import": "./dist/models/index.js",
      "types": "./dist/models/index.d.ts"
    }
  },
  "scripts": {
    "build": "tsc",
    "dev": "tsc --watch",
    "typecheck": "tsc --noEmit",
    "lint": "biome check src/",
    "format": "biome format --write src/"
  },
  "devDependencies": {
    "typescript": "^5"
  }
}
```

**Initial types to migrate from quotio-cli:**
- `AIProvider` enum
- `AuthFile` interface
- `ProviderQuotaData` interface
- `UsageStats` interface
- `RequestLog` interface
- `FallbackConfiguration` interface
- `VirtualModel` interface
- `CLIAgent` enum

### Step 6: Create `@quotio/server` Package Scaffold

**`packages/server/package.json`:**

```json
{
  "name": "@quotio/server",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "./dist/index.js",
  "bin": {
    "quotio-server": "./dist/index.js"
  },
  "scripts": {
    "build": "bun build src/index.ts --compile --outfile dist/quotio-server",
    "dev": "bun run --hot src/index.ts",
    "start": "bun run src/index.ts",
    "test": "bun test",
    "typecheck": "tsc --noEmit",
    "lint": "biome check src/",
    "format": "biome format --write src/"
  },
  "dependencies": {
    "@quotio/core": "workspace:*",
    "hono": "^4.7.0",
    "zod": "^3.24.0"
  },
  "devDependencies": {
    "@types/bun": "^1.3.5",
    "typescript": "^5"
  }
}
```

### Step 7: Refactor `@quotio/cli` Package

Move `quotio-cli/` contents to `packages/cli/`:

**`packages/cli/package.json`:**

```json
{
  "name": "@quotio/cli",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "bin": {
    "quotio": "./dist/quotio"
  },
  "scripts": {
    "build": "bun build src/index.ts --compile --outfile dist/quotio",
    "dev": "bun run src/index.ts",
    "test": "bun test",
    "typecheck": "tsc --noEmit",
    "lint": "biome check src/",
    "format": "biome format --write src/"
  },
  "dependencies": {
    "@quotio/core": "workspace:*"
  },
  "devDependencies": {
    "@types/bun": "^1.3.5",
    "typescript": "^5"
  }
}
```

### Step 8: Update CI/CD

**GitHub Actions workflow updates:**

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest
      - run: bun install
      - run: bun run typecheck
      - run: bun run lint
      - run: bun run test
      - run: bun run build
```

## Migration Checklist

- [ ] Create root `package.json` with workspaces
- [ ] Create `turbo.json`
- [ ] Create `tsconfig.base.json`
- [ ] Create `biome.json`
- [ ] Create `packages/core/` directory structure
- [ ] Migrate shared types to `@quotio/core`
- [ ] Create `packages/server/` scaffold
- [ ] Move `quotio-cli/` to `packages/cli/`
- [ ] Update imports in CLI to use `@quotio/core`
- [ ] Update CI/CD workflows
- [ ] Run `bun install` to link workspaces
- [ ] Verify `bun run build` works for all packages
- [ ] Test CLI still functions correctly

## Files to Create

| File | Purpose |
|------|---------|
| `package.json` | Workspace root |
| `turbo.json` | Turborepo config |
| `tsconfig.base.json` | Shared TS config |
| `biome.json` | Shared linter config |
| `packages/core/package.json` | Core package config |
| `packages/core/tsconfig.json` | Core TS config |
| `packages/core/src/index.ts` | Core entry |
| `packages/server/package.json` | Server package config |
| `packages/server/tsconfig.json` | Server TS config |
| `packages/server/src/index.ts` | Server entry (placeholder) |
| `packages/cli/package.json` | CLI package config |
| `packages/cli/tsconfig.json` | CLI TS config |

## Files to Move

| Source | Destination |
|--------|-------------|
| `quotio-cli/src/*` | `packages/cli/src/` |
| `quotio-cli/src/models/*` | `packages/core/src/models/` (shared) |

## Files to Delete

| File | Reason |
|------|--------|
| `quotio-cli/package.json` | Replaced by `packages/cli/package.json` |
| `quotio-cli/tsconfig.json` | Replaced by `packages/cli/tsconfig.json` |

## Verification

1. `bun install` - Installs all workspace dependencies
2. `bun run typecheck` - All packages type-check
3. `bun run build` - All packages build successfully
4. `./packages/cli/dist/quotio --help` - CLI works
5. `./packages/cli/dist/quotio proxy status` - Communicates with proxy

## Risks

| Risk | Mitigation |
|------|------------|
| Import path breakage | Use TypeScript path aliases carefully |
| Binary embedding issues | Test `bun build --compile` early |
| CI/CD failures | Update workflows before merging |
