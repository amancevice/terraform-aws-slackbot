const slackend = require('slackend/aws');
const lambda = slackend();
exports.handler       = lambda.handler;
exports.postMessage   = lambda.postMessage;
exports.postEphemeral = lambda.postEphemeral;
