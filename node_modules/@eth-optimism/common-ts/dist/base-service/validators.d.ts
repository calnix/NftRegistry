import { str, bool, num, email, host, port, url, json } from 'envalid';
import { Provider } from '@ethersproject/abstract-provider';
import { Signer } from '@ethersproject/abstract-signer';
import { ethers } from 'ethers';
export declare const validators: {
    str: typeof str;
    bool: typeof bool;
    num: typeof num;
    email: typeof email;
    host: typeof host;
    port: typeof port;
    url: typeof url;
    json: typeof json;
    wallet: (spec?: import("envalid").Spec<Signer>) => import("envalid").ValidatorSpec<Signer>;
    provider: (spec?: import("envalid").Spec<Provider>) => import("envalid").ValidatorSpec<Provider>;
    jsonRpcProvider: (spec?: import("envalid").Spec<ethers.providers.JsonRpcProvider>) => import("envalid").ValidatorSpec<ethers.providers.JsonRpcProvider>;
    staticJsonRpcProvider: (spec?: import("envalid").Spec<ethers.providers.StaticJsonRpcProvider>) => import("envalid").ValidatorSpec<ethers.providers.StaticJsonRpcProvider>;
    logLevel: (spec?: import("envalid").Spec<"error" | "fatal" | "warn" | "info" | "debug" | "trace">) => import("envalid").ValidatorSpec<"error" | "fatal" | "warn" | "info" | "debug" | "trace">;
};
