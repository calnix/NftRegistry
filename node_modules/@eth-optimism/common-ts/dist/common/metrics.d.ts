import { Server } from 'net';
import prometheus, { Registry } from 'prom-client';
import { Logger } from './logger';
export interface MetricsOptions {
    prefix?: string;
    labels?: Object;
}
export declare class LegacyMetrics {
    options: MetricsOptions;
    client: typeof prometheus;
    registry: Registry;
    constructor(options: MetricsOptions);
}
export interface MetricsServerOptions {
    logger: Logger;
    registry: Registry;
    port?: number;
    route?: string;
    hostname?: string;
}
export declare const createMetricsServer: (options: MetricsServerOptions) => Promise<Server>;
