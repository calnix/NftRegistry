import pino from 'pino';
import { Streams } from 'pino-multi-stream';
import { NodeOptions } from '@sentry/node';
export declare const logLevels: readonly ["trace", "debug", "info", "warn", "error", "fatal"];
export type LogLevel = typeof logLevels[number];
export interface LoggerOptions {
    name: string;
    level?: LogLevel;
    sentryOptions?: NodeOptions;
    streams?: Streams;
}
export declare class Logger {
    options: LoggerOptions;
    inner: pino.Logger;
    constructor(options: LoggerOptions);
    child(bindings: pino.Bindings): Logger;
    trace(msg: string, o?: object, ...args: any[]): void;
    debug(msg: string, o?: object, ...args: any[]): void;
    info(msg: string, o?: object, ...args: any[]): void;
    warn(msg: string, o?: object, ...args: any[]): void;
    warning(msg: string, o?: object, ...args: any[]): void;
    error(msg: string, o?: object, ...args: any[]): void;
    fatal(msg: string, o?: object, ...args: any[]): void;
}
