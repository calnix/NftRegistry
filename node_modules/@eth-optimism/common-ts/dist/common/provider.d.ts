import { Provider } from '@ethersproject/abstract-provider';
import { Logger } from './logger';
export declare const waitForProvider: (provider: Provider, opts?: {
    logger?: Logger;
    intervalMs?: number;
    name?: string;
}) => Promise<void>;
