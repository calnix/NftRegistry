import { ValidatorSpec, Spec } from 'envalid';
import { LogLevel } from '../common/logger';
export type Options = {
    [key: string]: any;
};
export type OptionsSpec<TOptions extends Options> = {
    [P in keyof Required<TOptions>]: {
        validator: (spec?: Spec<TOptions[P]>) => ValidatorSpec<TOptions[P]>;
        desc: string;
        default?: TOptions[P];
        public?: boolean;
    };
};
export type StandardOptions = {
    loopIntervalMs?: number;
    port?: number;
    hostname?: string;
    logLevel?: LogLevel;
    useEnv?: boolean;
    useArgv?: boolean;
};
export declare const stdOptionsSpec: OptionsSpec<StandardOptions>;
export declare const getPublicOptions: (optionsSpec: OptionsSpec<Options>) => string[];
