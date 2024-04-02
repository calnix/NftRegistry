"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.makeStdMetricsSpec = exports.Summary = exports.Histogram = exports.Counter = exports.Gauge = void 0;
const prom_client_1 = require("prom-client");
const options_1 = require("./options");
class Gauge extends prom_client_1.Gauge {
}
exports.Gauge = Gauge;
class Counter extends prom_client_1.Counter {
}
exports.Counter = Counter;
class Histogram extends prom_client_1.Histogram {
}
exports.Histogram = Histogram;
class Summary extends prom_client_1.Summary {
}
exports.Summary = Summary;
const makeStdMetricsSpec = (optionsSpec) => {
    return {
        metadata: {
            type: Gauge,
            desc: 'Service metadata',
            labels: ['name', 'version'].concat((0, options_1.getPublicOptions)(optionsSpec)),
        },
        unhandledErrors: {
            type: Counter,
            desc: 'Unhandled errors',
        },
    };
};
exports.makeStdMetricsSpec = makeStdMetricsSpec;
//# sourceMappingURL=metrics.js.map