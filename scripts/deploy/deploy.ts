import { ethers, upgrades } from "hardhat";
import { updateEnvFile } from "../common/address";
import { 
  Helper, 
  EntryPoint, 
  AccountFactory, 
  PayableAccount, 
  WebAuthnAndECDSAValidator, 
  Config, 
  TokenReceiver, 
  MockRecoveryModule, 
  TestToken20,
  Pay
} from "typechain";
import { printContractAddresses } from "../sendUopBatch";

enum ModuleType {
  Validator = 1,
  Executor = 2,
  Fallback = 3,
  Hook = 4,
  StatelessValidator = 7,
}

export const getContractsFromDelopyFixture = async () => {
  const network = await ethers.provider.getNetwork();
  console.log("using network : ", network.name, network.chainId);
  const [signer] = await ethers.getSigners();
  console.log("deployer address is", signer.address);

  const EntryPoint = await ethers.getContractFactory(
    "contracts/entryPoint/core/EntryPoint.sol:EntryPoint"
  );
  const entryPoint = await EntryPoint.deploy();
  await entryPoint.waitForDeployment();

  // deploy Helper
  const helperFactory = await ethers.getContractFactory("Helper");
  const helper = await helperFactory.deploy();
  await helper.waitForDeployment();

  const TestToken20 = await ethers.getContractFactory("TestToken20");
  const testERC20 = await TestToken20.deploy();
  await testERC20.waitForDeployment();

  // deploy FallbackHandler
  const FallbackHandler = await ethers.getContractFactory("TokenReceiver");
  const fallbackHandler = await FallbackHandler.deploy();
  await fallbackHandler.waitForDeployment();

  // deploy Config
  const Config = await ethers.getContractFactory("Config");
  const config = await upgrades.deployProxy(Config, [fallbackHandler.target, signer.address], {
    initializer: "initialize",
    kind: "uups",
  });
  // const config = await Config.deploy(fallbackHandler.target, signer.address);
  await config.waitForDeployment();

  // deploy WebAuthnAndECDSAValidator
  const WebAuthnAndECDSAValidator = await ethers.getContractFactory("WebAuthnAndECDSAValidator");
  const webAuthnAndECDSAValidator = await WebAuthnAndECDSAValidator.deploy(config.target);
  await webAuthnAndECDSAValidator.waitForDeployment();

  // deploy PayableAccount
  const SmartAccountTemplate = await ethers.getContractFactory("PayableAccount");
  const accountTemplate = await SmartAccountTemplate.deploy(entryPoint.target, config.target);
  await accountTemplate.waitForDeployment();

  // deploy AccountFactory
  const AccountFactory = await ethers.getContractFactory("AccountFactory");
  const accountFactory = await upgrades.deployProxy(AccountFactory, [signer.address], {
    initializer: "initialize",
    kind: "uups",
    constructorArgs: [config.target],
    unsafeAllow: ["delegatecall"],
  });
  // const accountFactory = await AccountFactory.deploy(config.target);
  await accountFactory.waitForDeployment();

  const MockRecoveryFC = await ethers.getContractFactory("MockRecoveryModule");
  const mockRecovery = await MockRecoveryFC.deploy();
  await mockRecovery.waitForDeployment();

  const Pay = await ethers.getContractFactory("Pay");
  const pay = await Pay.deploy(accountFactory.target, config.target, signer.address);
  await pay.waitForDeployment();

  // config add auth
  const addWhitelistedModulesTx = await config.addWhitelistedModules(
    [webAuthnAndECDSAValidator.target, fallbackHandler.target, mockRecovery.target],
    [ModuleType.StatelessValidator, ModuleType.Fallback, ModuleType.Executor],
  );

  await addWhitelistedModulesTx.wait();
  
  await config.addSafeSingleton(accountTemplate.target);
  await config.addWhitelistedBundlers([signer.address]);
  await config.setFactorySigner(signer.address);
  await config.setPaySigner(signer.address);
  await config.addWhitelistedVerifier(0);
  await config.addWhitelistedVerifier(1);
  await config.addWhitelistedVerifier(2);
  await pay.addWhitelistedTokens([testERC20.target]);

  const contracts = {
    entryPoint: entryPoint as unknown as EntryPoint,
    accountFactory: accountFactory as unknown as AccountFactory,
    smartAccount: accountTemplate as unknown as PayableAccount,
    validator: webAuthnAndECDSAValidator as unknown as WebAuthnAndECDSAValidator,
    config: config as unknown as Config,
    helper: helper as unknown as Helper,
    fallbackHandler: fallbackHandler as unknown as TokenReceiver,
    recoveryModule: mockRecovery as unknown as MockRecoveryModule,
    testERC20: testERC20 as unknown as TestToken20,
    pay: pay as unknown as Pay,
  };

  await printContractAddresses(contracts);

  const addresses = {
    ENTRYPOINT: entryPoint.target,
    HELPER: helper.target,
    TOKEN_RECEIVER: fallbackHandler.target,
    CONFIG: config.target,
    WEBAUTHN_VALIDATOR: webAuthnAndECDSAValidator.target,
    PAYABLE_ACCOUNT: accountTemplate.target,
    ACCOUNT_FACTORY: accountFactory.target,
    MOCK_RECOVERY_MODULE: mockRecovery.target,
    TEST_ERC20: testERC20.target,
    PAY: pay.target,
  };

  updateEnvFile(addresses);

  return contracts;
};

// Only run if this file is being run directly, not when imported
if (require.main === module) {
  getContractsFromDelopyFixture().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
