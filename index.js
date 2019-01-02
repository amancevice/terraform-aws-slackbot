'use strict';
const awsServerlessExpress = require('aws-serverless-express');
const slackend = require('slackend');
const baseUrl = process.env.SLACKEND_BASE_URL || '/';

let env;

function fetchEnv () {
  const AWS = require('aws-sdk');
  const secretsmanager = new AWS.SecretsManager();
  const secret = process.env.SLACK_SECRET;
  return secretsmanager.getSecretValue({
    SecretId: secret,
  }).promise().then((data) => {
    const secrets = JSON.parse(data.SecretString);
    Object.keys(secrets).forEach((key) => {
      process.env[key] = secrets[key];
    });
    return process.env;
  });
}

function getEnv () {
  if (env) {
    console.log(`CACHED ENV`);
    return Promise.resolve(env);
  } else {
    console.log(`FETCH ENV`);
    return fetchEnv().then((res) => {
      env = res;
      return env;
    });
  }
}

function publish (payload, topic) {
  const AWS = require('aws-sdk');
  const SNS = new AWS.SNS();
  const msg = Buffer.from(JSON.stringify(payload)).toString('base64');
  const opt = {Message: msg, TopicArn: topic};
  console.log(`PUBLISH ${JSON.stringify(opt)}`);
  return SNS.publish(opt).promise();
}

async function postMessage (event) {
  await getEnv();
  const { WebClient } = require('@slack/client');
  const slack = new WebClient(env.BOT_TOKEN);
  await Promise.all(event.Records.map((record) => {
    const msg = JSON.parse(record.Sns.Message);
    console.log(`POST ${JSON.stringify(msg)}`);
    return slack.chat.postMessage(msg);
  }));
}

async function postEphemeral (event) {
  await getEnv();
  const { WebClient } = require('@slack/client');
  const slack = new WebClient(env.BOT_TOKEN);
  await Promise.all(event.Records.map((record) => {
    const msg = JSON.parse(record.Sns.Message);
    console.log(`POST ${JSON.stringify(msg)}`);
    return slack.chat.postEphemeral(msg);
  }));
}

slackend.app.set('fetchEnv', fetchEnv);
slackend.app.set('getEnv', getEnv);
slackend.app.set('publish', publish);
slackend.app.use(baseUrl, slackend.router);
const server = awsServerlessExpress.createServer(slackend.app);
exports.postMessage = postMessage;
exports.postEphemeral = postEphemeral;
exports.handler = (event, context) => {
  console.log(`EVENT ${JSON.stringify(event)}`);
  return awsServerlessExpress.proxy(server, event, context);
};
