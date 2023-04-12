import { Logger } from "@aws-lambda-powertools/logger";
import { Metrics } from "@aws-lambda-powertools/metrics";
import { Tracer } from "@aws-lambda-powertools/tracer";

export const logger = new Logger({
    persistentLogAttributes: {
        aws_region: process.env.AWS_REGION || "N/A",
    },
});

export const metrics = new Metrics({
    namespace: process.env.POWERTOOLS_METRICS_NAMESPACE || "rdc-local",
    defaultDimensions: {
        aws_region: process.env.AWS_REGION || "N/A",
    },
});

export const tracer = new Tracer();
