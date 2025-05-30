import { readFileSync, writeFileSync } from 'fs';
import { Addressable } from 'ethers';

/**
 * Updates or creates a .env file with new key-value pairs
 * @param newKV - Object containing environment variables to update or add
 * @description
 * - If .env file exists, updates existing values and adds new ones
 * - If .env file doesn't exist, creates it with the provided key-value pairs
 * - Preserves comments and empty lines in existing file
 */
export const updateEnvFile = (newKV: Record<string, string | Addressable>) => {
  let existingContent = '';
  try {
    existingContent = readFileSync('.env', 'utf8');
  } catch {
    // File doesn't exist, start with empty content
  }

  // Keep track of processed keys
  const processedKeys = new Set<string>();

  // Split content into lines and process each line
  const updatedLines = existingContent.split('\n').map(line => {
    // Preserve comments and empty lines
    if (line.trim().startsWith('#') || line.trim() === '') {
      return line;
    }

    // For actual env variables
    const [key] = line.split('=');
    if (!key) return line;

    const trimmedKey = key.trim();
    // If we have a new value for this key, update it
    if (newKV[trimmedKey] !== undefined) {
      processedKeys.add(trimmedKey);
      return `${trimmedKey}=${newKV[trimmedKey]}`;
    }

    // Otherwise keep the existing line
    return line;
  });

  // Append any new keys that weren't in the original file
  Object.entries(newKV).forEach(([key, value]) => {
    if (!processedKeys.has(key)) {
      updatedLines.push(`${key}=${value}`);
    }
  });

  writeFileSync('.env', updatedLines.join('\n') + '\n');
};

/// sepolia
const ENTRYPOINT_ADDRESS = process.env.ENTRYPOINT;
const SMARTACCOUNT_ADDRESS = process.env.PAYABLE_ACCOUNT;
const FACTORYPROXY_ADDRESS = process.env.ACCOUNT_FACTORY;
const WEBAUTH_VALIDATOR_ADDRESS = process.env.WEBAUTHN_VALIDATOR;
const CONFIG_ADDRESS = process.env.CONFIG;
const HELPER_ADDRESS = process.env.HELPER;
const FALLBACK_HANDLER = process.env.TOKEN_RECEIVER;
const MOCK_RECOVERY_MODULE = process.env.MOCK_RECOVERY_MODULE;
const PAY = process.env.PAY;
const TEST_ERC20 = process.env.TEST_ERC20;

export const address = {
  ENTRYPOINT_ADDRESS,
  SMARTACCOUNT_ADDRESS,
  FACTORYPROXY_ADDRESS,
  WEBAUTH_VALIDATOR_ADDRESS,
  CONFIG_ADDRESS,
  HELPER_ADDRESS,
  FALLBACK_HANDLER,
  MOCK_RECOVERY_MODULE,
  PAY,
  TEST_ERC20
};
