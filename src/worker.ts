import {injectLambdaContext} from "@aws-lambda-powertools/logger";
import {logMetrics} from "@aws-lambda-powertools/metrics";
import {captureLambdaHandler} from "@aws-lambda-powertools/tracer";
import middy from "@middy/core";
import {APIGatewayTokenAuthorizerEvent, Context} from "aws-lambda";
import {logger, metrics, tracer} from "./powertools";

const lambdaHandler = async (event: APIGatewayTokenAuthorizerEvent, context: Context) => {
    logger.debug("Received input", {event, context});
    return {statusCode: 200, body: {message: "Hello World", event, context}};
};

const handler = middy(lambdaHandler)
    .use(captureLambdaHandler(tracer))
    .use(logMetrics(metrics, {captureColdStartMetric: true}))
    .use(injectLambdaContext(logger, {clearState: true}));

export { handler };
