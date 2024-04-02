import { Logger } from '../common/logger';
import { LegacyMetrics } from '../common/metrics';
type OptionSettings<TOptions> = {
    [P in keyof TOptions]?: {
        default?: TOptions[P];
        validate?: (val: any) => boolean;
    };
};
type BaseServiceOptions<T> = T & {
    logger?: Logger;
    metrics?: LegacyMetrics;
};
export declare class BaseService<T> {
    protected name: string;
    protected options: T;
    protected logger: Logger;
    protected metrics: LegacyMetrics;
    protected initialized: boolean;
    protected running: boolean;
    constructor(name: string, options: BaseServiceOptions<T>, optionSettings: OptionSettings<T>);
    init(): Promise<void>;
    start(): Promise<void>;
    stop(): Promise<void>;
    protected _init(): Promise<void>;
    protected _start(): Promise<void>;
    protected _stop(): Promise<void>;
}
export {};
