import {injectLambdaContext} from "@aws-lambda-powertools/logger";
import {logMetrics} from "@aws-lambda-powertools/metrics";
import {captureLambdaHandler} from "@aws-lambda-powertools/tracer";
import middy from "@middy/core";
import {APIGatewayTokenAuthorizerEvent, Context} from "aws-lambda";
import {logger, metrics, tracer} from "./powertools";

const lambdaHandler = async (event: APIGatewayTokenAuthorizerEvent, context: Context) => {
    logger.debug("Received input", {event, context});
    return {
        principalId: event.authorizationToken,
        policyDocument: {
            Version: "2012-10-17",
            Statement: [{Action: "execute-api:Invoke", Effect: "Allow", Resource: event.methodArn}],
        },
    };
};

const handler = middy(lambdaHandler)
    .use(captureLambdaHandler(tracer))
    .use(logMetrics(metrics, {captureColdStartMetric: true}))
    .use(injectLambdaContext(logger, {clearState: true}));

export {handler};
