import { ethers, AddressLike, BigNumberish, BytesLike, ParamType, zeroPadValue } from "ethers";

type ExecuteParams = {
  to: string | AddressLike;
  value: BigNumberish;
  data: string | BytesLike;
};

enum CallType {
  Single = "0x00",
  Batch = "0x01",
  DelegateCall = "0xff", // Unsupported CallType, just for testing
}

enum ExecType {
  Default = "0x00",
  Try = "0x01",
  Other = "0x02", // Unsupported ExecType, just for testing
}

// Not used in this version, fields retained only for compliance with ERC-7579
enum ModeSelector {
  Default = "0x00000000",
  Offset = "0xeda86f9b",
}

enum ModuleType {
  Validator = 1,
  Executor = 2,
  Fallback = 3,
  Hook = 4,
  StatelessValidator = 7,
}

const encodeModeType = (callType: CallType, execType: ExecType, modeSelector: ModeSelector, modePayload: BytesLike) => {
  return [
    "0x",
    callType.substring(2),
    execType.substring(2),
    "00000000",
    modeSelector.substring(2),
    zeroPadValue(modePayload, 22).substring(2),
  ].join("");
};

const executionsParamType: ParamType = {
  name: "executions",
  type: "tuple[]",
  components: [
    // @ts-ignore
    { name: "to", type: "address" },
    // @ts-ignore
    { name: "value", type: "uint256" },
    // @ts-ignore
    { name: "data", type: "bytes" },
  ],
};

const encodeExecutionCalldata = (target: string | AddressLike, value: BigNumberish, data: string | BytesLike) => {
  return ethers.solidityPacked(["address", "uint256", "bytes"], [target, value, data]);
};

const encodeExecutions = (params: ExecuteParams[]) => {
  return ethers.AbiCoder.defaultAbiCoder().encode([executionsParamType], [params]);
};

export {
  CallType,
  ExecType,
  ModeSelector,
  ModuleType,
  encodeModeType,
  encodeExecutionCalldata,
  encodeExecutions,
  ExecuteParams,
};
