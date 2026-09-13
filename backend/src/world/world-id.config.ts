export interface WorldIdConfig {
  isWorldIdRequired: boolean;
  isWorldIdConfigured: boolean;
  appId?: `app_${string}`;
  rpId?: `rp_${string}`;
  signingKeyHex?: string;
  action?: string;
  environment?: 'staging' | 'production';
}

export const WORLD_ID_CONFIG = Symbol('WORLD_ID_CONFIG');

const WORLD_ID_VAR_NAMES = [
  'WORLD_ID_APP_ID',
  'WORLD_ID_RP_ID',
  'WORLD_ID_SIGNING_KEY',
  'WORLD_ID_ACTION',
  'WORLD_ID_ENVIRONMENT',
] as const;

export function loadWorldIdConfig(): WorldIdConfig {
  const requireRaw = process.env.REQUIRE_WORLD_ID_FOR_ESCALATIONS?.trim();
  if (requireRaw !== 'true' && requireRaw !== 'false') {
    throw new Error(
      "Environment variable REQUIRE_WORLD_ID_FOR_ESCALATIONS is required and must be exactly 'true' or 'false'",
    );
  }
  const isWorldIdRequired = requireRaw === 'true';

  const isSet = (name: string) => process.env[name] !== undefined;
  const setVars = WORLD_ID_VAR_NAMES.filter(isSet);
  const nonEmptyCount = WORLD_ID_VAR_NAMES.filter((name) => (process.env[name]?.trim().length ?? 0) > 0).length;

  if (setVars.length === 0 || nonEmptyCount === 0) {
    if (isWorldIdRequired) {
      throw new Error(
        'REQUIRE_WORLD_ID_FOR_ESCALATIONS is true, but World ID is not configured (missing all WORLD_ID_* variables)',
      );
    }
    return {
      isWorldIdRequired,
      isWorldIdConfigured: false,
    };
  }

  const missingVars = WORLD_ID_VAR_NAMES.filter((name) => !isSet(name));
  if (missingVars.length > 0) {
    throw new Error(
      `Incomplete World ID configuration. Missing: ${missingVars.join(', ')}`,
    );
  }

  const appId = process.env.WORLD_ID_APP_ID!.trim();
  if (!appId.startsWith('app_')) {
    throw new Error(
      `Environment variable WORLD_ID_APP_ID must start with 'app_', got '${appId}'`,
    );
  }

  const rpId = process.env.WORLD_ID_RP_ID!.trim();
  if (!rpId.startsWith('rp_')) {
    throw new Error(
      `Environment variable WORLD_ID_RP_ID must start with 'rp_', got '${rpId}'`,
    );
  }

  const rawKey = process.env.WORLD_ID_SIGNING_KEY!.trim();
  const signingKeyHex = rawKey.startsWith('0x') || rawKey.startsWith('0X') ? rawKey.slice(2) : rawKey;
  if (!/^[0-9a-fA-F]{64}$/.test(signingKeyHex)) {
    throw new Error(
      'Environment variable WORLD_ID_SIGNING_KEY must be a 32-byte hex string',
    );
  }

  const action = process.env.WORLD_ID_ACTION!.trim();
  if (action.length === 0) {
    throw new Error('Environment variable WORLD_ID_ACTION must not be empty');
  }

  const environment = process.env.WORLD_ID_ENVIRONMENT!.trim();
  if (environment !== 'staging' && environment !== 'production') {
    throw new Error(
      `Environment variable WORLD_ID_ENVIRONMENT must be exactly 'staging' or 'production', got '${environment}'`,
    );
  }

  return {
    isWorldIdRequired,
    isWorldIdConfigured: true,
    appId: appId as `app_${string}`,
    rpId: rpId as `rp_${string}`,
    signingKeyHex,
    action,
    environment,
  };
}
