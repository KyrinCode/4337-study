import axios from "axios";
import { Addressable } from "ethers";

const oklink = axios.create({
  baseURL: "https://www.oklink.com/",
});

const getInternalTx = async (chainShortName: string = "XLAYER", address: string | Addressable) => {
  const { data } = await oklink.get(`/api/v5/explorer/address/internal-transaction-list`, {
    params: {
      chainShortName,
      address,
    },
    headers: {
      "Ok-Access-Key": process.env.OKLINK_API_KEY,
    },
  });
  return data;
};

const getNormalTx = async (chainShortName: string = "XLAYER", address: string | Addressable) => {
  const { data } = await oklink.get(`/api/v5/explorer/address/normal-transaction-list`, {
    params: {
      chainShortName,
      address,
    },
    headers: {
      "Ok-Access-Key": process.env.OKLINK_API_KEY,
    },
  });
  return data;
};

const getAddressSummary = async (chainShortName: string = "XLAYER", address: string | Addressable) => {
  const { data } = await oklink.get(`/api/v5/explorer/address/address-summary`, {
    params: {
      chainShortName,
      address,
    },
    headers: {
      "Ok-Access-Key": process.env.OKLINK_API_KEY,
    },
  });
  return data;
};

const getTxDetail = async (chainShortName: string = "XLAYER", txid: string) => {
  const { data } = await oklink.get(`/api/v5/explorer/transaction/transaction-fills`, {
    params: {
      chainShortName,
      txid,
    },
    headers: {
      "Ok-Access-Key": process.env.OKLINK_API_KEY,
    },
  });
  return data;
};

export { getInternalTx, getNormalTx, getAddressSummary, getTxDetail };
