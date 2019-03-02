const slackend        = require('slackend/aws');
exports.handler       = slackend.handler;
exports.postMessage   = slackend.postMessage;
exports.postEphemeral = slackend.postEphemeral;
