import { type AIProvider, parseProvider } from '@quotio/core';
import type { ProviderQuotaData } from '@quotio/core';
import { Hono } from 'hono';
import { CopilotAvailableModelsFetcher } from '../../../services/quota-fetchers/copilot-models.js';
import { getQuotaService } from '../../../services/quota/index.js';

// Singleton instance for caching
const copilotModelsFetcher = new CopilotAvailableModelsFetcher();

interface QuotaResponseEntry {
	provider: AIProvider;
	account: string;
	data: ProviderQuotaData;
}

function normalizeQuotaData(data: ProviderQuotaData) {
	return {
		...data,
		lastUpdated:
			data.lastUpdated instanceof Date ? data.lastUpdated.toISOString() : data.lastUpdated,
		tokenExpiresAt:
			data.tokenExpiresAt instanceof Date ? data.tokenExpiresAt.toISOString() : data.tokenExpiresAt,
	};
}

export function quotaRoutes(): Hono {
	const app = new Hono();
	const quotaService = getQuotaService();

	app.get('/quota', async (c) => {
		const result = await quotaService.fetchAllQuotas();
		const quotas: QuotaResponseEntry[] = [];

		for (const [key, data] of result.quotas) {
			const [provider, account] = key.split(':');
			quotas.push({
				provider: provider as AIProvider,
				account: account ?? '',
				data,
			});
		}

		return c.json({
			quotas: quotas.map((entry) => ({
				...entry,
				data: normalizeQuotaData(entry.data),
			})),
			errors: result.errors,
		});
	});

	app.get('/quota/:provider', async (c) => {
		const providerParam = c.req.param('provider');
		const provider = parseProvider(providerParam) ?? (providerParam as AIProvider);
		const results = await quotaService.fetchQuotaForProvider(provider);

		const entries = results
			.filter((result) => result.data)
			.map((result) => ({
				provider: result.provider,
				account: result.account,
				data: normalizeQuotaData(result.data as ProviderQuotaData),
			}));

		const errors = results
			.filter((result) => result.error)
			.map((result) => ({
				account: result.account,
				provider: result.provider,
				error: result.error ?? 'Unknown error',
			}));

		return c.json({
			provider,
			quotas: entries,
			errors,
		});
	});

	app.post('/quota/refresh', async (c) => {
		const body = (await c.req.json().catch(() => ({
			providers: undefined,
		}))) as { providers?: string[] };

		const providers = body.providers
			?.map((p) => parseProvider(p))
			.filter((p): p is AIProvider => Boolean(p));

		const result = await quotaService.fetchAllQuotas(
			providers && providers.length > 0 ? providers : undefined,
		);

		const quotas: QuotaResponseEntry[] = [];
		for (const [key, data] of result.quotas) {
			const [provider, account] = key.split(':');
			quotas.push({
				provider: provider as AIProvider,
				account: account ?? '',
				data,
			});
		}

		return c.json({
			refreshed: quotas.length,
			quotas: quotas.map((entry) => ({
				...entry,
				data: normalizeQuotaData(entry.data),
			})),
			errors: result.errors,
		});
	});

	app.post('/quota/:provider/refresh', async (c) => {
		const providerParam = c.req.param('provider');
		const provider = parseProvider(providerParam) ?? (providerParam as AIProvider);
		const results = await quotaService.fetchQuotaForProvider(provider);

		const entries = results
			.filter((result) => result.data)
			.map((result) => ({
				provider: result.provider,
				account: result.account,
				data: normalizeQuotaData(result.data as ProviderQuotaData),
			}));

		const errors = results
			.filter((result) => result.error)
			.map((result) => ({
				account: result.account,
				provider: result.provider,
				error: result.error ?? 'Unknown error',
			}));

		return c.json({
			provider,
			refreshed: entries.length,
			quotas: entries,
			errors,
		});
	});

	app.get('/quota/copilot/models', async (c) => {
		const models = await copilotModelsFetcher.fetchAllAvailableModels();
		const modelIds = models.filter((m) => m.model_picker_enabled === true).map((m) => m.id);
		return c.json({ model_ids: modelIds });
	});

	return app;
}
