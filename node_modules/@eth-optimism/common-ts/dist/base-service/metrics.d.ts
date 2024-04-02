import { Gauge as PGauge, Counter as PCounter, Histogram as PHistogram, Summary as PSummary } from 'prom-client';
import { OptionsSpec } from './options';
export declare class Gauge extends PGauge<string> {
}
export declare class Counter extends PCounter<string> {
}
export declare class Histogram extends PHistogram<string> {
}
export declare class Summary extends PSummary<string> {
}
export type Metric = Gauge | Counter | Histogram | Summary;
export type Metrics = Record<any, Metric>;
export type MetricsSpec<TMetrics extends Metrics> = {
    [P in keyof Required<TMetrics>]: {
        type: new (configuration: any) => TMetrics[P];
        desc: string;
        labels?: string[];
    };
};
export type StandardMetrics = {
    metadata: Gauge;
    unhandledErrors: Counter;
};
export declare const makeStdMetricsSpec: (optionsSpec: OptionsSpec<any>) => MetricsSpec<StandardMetrics>;
