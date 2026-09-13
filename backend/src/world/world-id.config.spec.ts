import { loadWorldIdConfig } from './world-id.config';

describe('loadWorldIdConfig', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
    delete process.env.REQUIRE_WORLD_ID_FOR_ESCALATIONS;
    delete process.env.WORLD_ID_APP_ID;
    delete process.env.WORLD_ID_RP_ID;
    delete process.env.WORLD_ID_SIGNING_KEY;
    delete process.env.WORLD_ID_ACTION;
    delete process.env.WORLD_ID_ENVIRONMENT;
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  const validSigningKey = '11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff';

  it('loads successfully when unconfigured and REQUIRE_WORLD_ID_FOR_ESCALATIONS is false', () => {
    process.env.REQUIRE_WORLD_ID_FOR_ESCALATIONS = 'false';

    const config = loadWorldIdConfig();
    expect(config.isWorldIdRequired).toBe(false);
    expect(config.isWorldIdConfigured).toBe(false);
    expect(config.appId).toBeUndefined();
  });

  it('loads successfully when configured with all 5 variables and REQUIRE_WORLD_ID_FOR_ESCALATIONS is true', () => {
    process.env.REQUIRE_WORLD_ID_FOR_ESCALATIONS = 'true';
    process.env.WORLD_ID_APP_ID = 'app_staging_12345';
    process.env.WORLD_ID_RP_ID = 'rp_staging_98765';
    process.env.WORLD_ID_SIGNING_KEY = `0x${validSigningKey}`;
    process.env.WORLD_ID_ACTION = 'chapter2-ledger-approver';
    process.env.WORLD_ID_ENVIRONMENT = 'staging';

    const config = loadWorldIdConfig();
    expect(config.isWorldIdRequired).toBe(true);
    expect(config.isWorldIdConfigured).toBe(true);
    expect(config.appId).toBe('app_staging_12345');
    expect(config.rpId).toBe('rp_staging_98765');
    expect(config.signingKeyHex).toBe(validSigningKey);
    expect(config.action).toBe('chapter2-ledger-approver');
    expect(config.environment).toBe('staging');
  });

  it('throws when REQUIRE_WORLD_ID_FOR_ESCALATIONS is missing', () => {
    expect(() => loadWorldIdConfig()).toThrow(
      "Environment variable REQUIRE_WORLD_ID_FOR_ESCALATIONS is required and must be exactly 'true' or 'false'",
    );
  });

  it('throws when REQUIRE_WORLD_ID_FOR_ESCALATIONS has an invalid value', () => {
    process.env.REQUIRE_WORLD_ID_FOR_ESCALATIONS = '1';
    expect(() => loadWorldIdConfig()).toThrow(
      "Environment variable REQUIRE_WORLD_ID_FOR_ESCALATIONS is required and must be exactly 'true' or 'false'",
    );
  });

  it('throws when REQUIRE_WORLD_ID_FOR_ESCALATIONS is true but no WORLD_ID_* variables are set', () => {
    process.env.REQUIRE_WORLD_ID_FOR_ESCALATIONS = 'true';
    expect(() => loadWorldIdConfig()).toThrow(
      'REQUIRE_WORLD_ID_FOR_ESCALATIONS is true, but World ID is not configured',
    );
  });

  it('throws listing missing variables when configuration is partial', () => {
    process.env.REQUIRE_WORLD_ID_FOR_ESCALATIONS = 'false';
    process.env.WORLD_ID_APP_ID = 'app_123';
    process.env.WORLD_ID_RP_ID = 'rp_456';

    expect(() => loadWorldIdConfig()).toThrow(
      'Incomplete World ID configuration. Missing: WORLD_ID_SIGNING_KEY, WORLD_ID_ACTION, WORLD_ID_ENVIRONMENT',
    );
  });

  it('throws when WORLD_ID_APP_ID does not start with app_', () => {
    process.env.REQUIRE_WORLD_ID_FOR_ESCALATIONS = 'false';
    process.env.WORLD_ID_APP_ID = 'bad_app_id';
    process.env.WORLD_ID_RP_ID = 'rp_123';
    process.env.WORLD_ID_SIGNING_KEY = validSigningKey;
    process.env.WORLD_ID_ACTION = 'test';
    process.env.WORLD_ID_ENVIRONMENT = 'staging';

    expect(() => loadWorldIdConfig()).toThrow(
      "Environment variable WORLD_ID_APP_ID must start with 'app_'",
    );
  });

  it('throws when WORLD_ID_RP_ID does not start with rp_', () => {
    process.env.REQUIRE_WORLD_ID_FOR_ESCALATIONS = 'false';
    process.env.WORLD_ID_APP_ID = 'app_123';
    process.env.WORLD_ID_RP_ID = 'bad_rp_id';
    process.env.WORLD_ID_SIGNING_KEY = validSigningKey;
    process.env.WORLD_ID_ACTION = 'test';
    process.env.WORLD_ID_ENVIRONMENT = 'staging';

    expect(() => loadWorldIdConfig()).toThrow(
      "Environment variable WORLD_ID_RP_ID must start with 'rp_'",
    );
  });

  it('throws when WORLD_ID_SIGNING_KEY is not a valid 32-byte hex string', () => {
    process.env.REQUIRE_WORLD_ID_FOR_ESCALATIONS = 'false';
    process.env.WORLD_ID_APP_ID = 'app_123';
    process.env.WORLD_ID_RP_ID = 'rp_123';
    process.env.WORLD_ID_SIGNING_KEY = 'tooshort';
    process.env.WORLD_ID_ACTION = 'test';
    process.env.WORLD_ID_ENVIRONMENT = 'staging';

    expect(() => loadWorldIdConfig()).toThrow(
      'Environment variable WORLD_ID_SIGNING_KEY must be a 32-byte hex string',
    );
  });

  it('throws when WORLD_ID_ACTION is empty', () => {
    process.env.REQUIRE_WORLD_ID_FOR_ESCALATIONS = 'false';
    process.env.WORLD_ID_APP_ID = 'app_123';
    process.env.WORLD_ID_RP_ID = 'rp_123';
    process.env.WORLD_ID_SIGNING_KEY = validSigningKey;
    process.env.WORLD_ID_ACTION = '   ';
    process.env.WORLD_ID_ENVIRONMENT = 'staging';

    expect(() => loadWorldIdConfig()).toThrow(
      'Environment variable WORLD_ID_ACTION must not be empty',
    );
  });

  it('throws when WORLD_ID_ENVIRONMENT is neither staging nor production', () => {
    process.env.REQUIRE_WORLD_ID_FOR_ESCALATIONS = 'false';
    process.env.WORLD_ID_APP_ID = 'app_123';
    process.env.WORLD_ID_RP_ID = 'rp_123';
    process.env.WORLD_ID_SIGNING_KEY = validSigningKey;
    process.env.WORLD_ID_ACTION = 'test';
    process.env.WORLD_ID_ENVIRONMENT = 'sandbox';

    expect(() => loadWorldIdConfig()).toThrow(
      "Environment variable WORLD_ID_ENVIRONMENT must be exactly 'staging' or 'production'",
    );
  });
});
