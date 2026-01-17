import { Hono } from 'hono';
import type {
	AgentConfiguration,
	ConfigurationMode,
} from '../../../services/agent-detection/configuration.js';
import { getAgentConfigurationService } from '../../../services/agent-detection/configuration.js';
import { getAgentDetectionService } from '../../../services/agent-detection/service.js';
import { type CLIAgentId, CLI_AGENTS } from '../../../services/agent-detection/types.js';

interface ConfigurePayload {
	mode?: ConfigurationMode;
	storage?: 'json' | 'shell' | 'both';
	proxyURL?: string;
	apiKey?: string;
	useOAuth?: boolean;
	modelSlots?: {
		opus?: string;
		sonnet?: string;
		haiku?: string;
	};
}

function getAgent(agentId: string) {
	return CLI_AGENTS[agentId as CLIAgentId];
}

export function agentRoutes(): Hono {
	const app = new Hono();
	const detectionService = getAgentDetectionService();
	const configurationService = getAgentConfigurationService();

	app.get('/agents', async (c) => {
		const force = c.req.query('force') === 'true';
		const statuses = await detectionService.detectAllAgents(force);
		return c.json({ agents: statuses });
	});

	app.get('/agents/:agent', async (c) => {
		const agentId = c.req.param('agent');
		const agent = getAgent(agentId);
		if (!agent) {
			return c.json({ error: `Unknown agent: ${agentId}` }, 404);
		}

		const status = await detectionService.detectAgent(agent);
		return c.json({ agent: status });
	});

	app.post('/agents/:agent/configure', async (c) => {
		const agentId = c.req.param('agent');
		const agent = getAgent(agentId);
		if (!agent) {
			return c.json({ error: `Unknown agent: ${agentId}` }, 404);
		}

		const payload = (await c.req.json().catch(() => ({}))) as ConfigurePayload;
		const mode = payload.mode ?? 'manual';
		const storage = payload.storage ?? 'json';

		const proxyURL = payload.proxyURL ?? 'http://localhost:18317/v1';
		const apiKey = payload.apiKey ?? 'quotio-cli-key';

		const config: AgentConfiguration = {
			agent,
			proxyURL,
			apiKey,
			useOAuth: payload.useOAuth,
			modelSlots: payload.modelSlots,
		};

		const result = configurationService.generateConfiguration(
			agentId as CLIAgentId,
			config,
			mode,
			storage,
		);

		return c.json(result);
	});

	app.post('/agents/:agent/restore', async (c) => {
		const agentId = c.req.param('agent');
		const agent = getAgent(agentId);
		if (!agent) {
			return c.json({ error: `Unknown agent: ${agentId}` }, 404);
		}

		return c.json({ success: false, error: 'Restore not implemented' }, 501);
	});

	app.get('/agents/:agent/backup', async (c) => {
		const agentId = c.req.param('agent');
		const agent = getAgent(agentId);
		if (!agent) {
			return c.json({ error: `Unknown agent: ${agentId}` }, 404);
		}

		return c.json({ success: false, error: 'Backup not implemented' }, 501);
	});

	return app;
}
