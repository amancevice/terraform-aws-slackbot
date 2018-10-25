'use strict';
const awsServerlessExpress = require('aws-serverless-express');
const slackend = require('slackend');
const baseUrl = process.env.SLACKEND_BASE_URL || '/';

slackend.app.set('fetchEnv', () => {
  const AWS = require('aws-sdk');
  const secretsmanager = new AWS.SecretsManager();
  const secret = process.env.AWS_SECRET;
  return secretsmanager.getSecretValue({
    SecretId: secret,
  }).promise().then((data) => {
    const secrets = JSON.parse(data.SecretString);
    Object.keys(secrets).forEach((key) => {
      process.env[key] = secrets[key];
    });
    return process.env;
  });
});

slackend.app.set('publish', (payload, topic) => {
  const AWS = require('aws-sdk');
  const SNS = new AWS.SNS();
  const msg = Buffer.from(JSON.stringify(payload)).toString('base64');
  const opt = {Message: msg, TopicArn: topic};
  console.log(`PUBLISH ${JSON.stringify(opt)}`);
  return SNS.publish(opt).promise();
});

slackend.app.use(baseUrl, slackend.router);
const server = awsServerlessExpress.createServer(slackend.app);
exports.handler = (event, context) => {
  console.log(`EVENT ${JSON.stringify(event)}`);
  return awsServerlessExpress.proxy(server, event, context);
};
