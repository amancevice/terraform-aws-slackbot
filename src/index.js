const crypto = require('crypto');
const secret = process.env.SECRET;
const sns_topic_prefix = process.env.SNS_TOPIC_PREFIX;
const oauth_redirect = process.env.OAUTH_REDIRECT;

let secrets;

/**
 * Get Slack tokens from memory or AWS SecretsManager.
 */
function getSecrets() {
  return new Promise((resolve, reject) => {
    if (secrets) {
      console.log(`SECRET ${secret}`);
      resolve(secrets);
    } else {
      console.log(`FETCH ${secret}`);
      const AWS = require('aws-sdk');
      const secretsmanager = new AWS.SecretsManager();
      secretsmanager.getSecretValue({SecretId: secret}, (err, data) => {
        if (err) {
          reject(err);
        } else {
          secrets = JSON.parse(data.SecretString);
          console.log(`SECRET ${secret}`);
          resolve(secrets);
        }
      });
    }
  });
}

/**
 * Verify request signature.
 *
 * @param {object} event AWS API Gateway event.
 */
function verifyRequest(event) {
  return new Promise((resolve, reject) => {
    const ts = event.headers['X-Slack-Request-Timestamp'];
    const req = event.headers['X-Slack-Signature'];
    const hmac = crypto.createHmac('sha256', secrets.SIGNING_SECRET);
    const data = `${secrets.SIGNING_VERSION}:${event.headers['X-Slack-Request-Timestamp']}:${event.body}`;
    const sig = `${secrets.SIGNING_VERSION}=${hmac.update(data).digest('hex')}`;
    const delta = Math.abs(new Date()/1000 - ts);
    console.log(`SIGNATURES ${JSON.stringify({request: req, calculated: sig})}`);
    if (delta > 60 * 5) {
      reject('Request too old');
    } else if (req !== sig) {
      reject('Signatures do not match');
    } else {
      resolve(event.body);
    }
  });
}

/**
 * Process Slack callback.
 *
 * @param {object} body Parsed Slack request body.
 */
function processCallback(body) {
  return Promise.resolve(body).then((res) => {
    const qs = require('querystring');
    const params = qs.parse(body);
    return JSON.parse(params.payload);
  }).then((res) => {
    return publishPayload(res, res.callback_id);
  });
}

/**
 * Process Slack event.
 *
 * @param {object} body Parsed Slack request body.
 */
function processEvent(body) {
  return Promise.resolve(body).then((res) => {
    return JSON.parse(body);
  }).then((res) => {
    if (res.type === 'url_verification') {
      const challenge = {challenge: res.challenge};
      console.log(`CHALLENGE ${JSON.stringify(challenge)}`);
      return challenge;
    } else {
      return publishPayload(res, res.event.type);
    }
  });
}

/**
 * Process Slack .
 *
 * @param {object} body Parsed Slack request body.
 */
function processOAuth(event) {
  const { WebClient } = require('@slack/client');
  const slack = new WebClient(secrets.BOT_ACCESS_TOKEN);
  const options = {
    code: event.queryStringParameters.code,
    client_id: secrets.CLIENT_ID,
    client_secret: secrets.CLIENT_SECRET
  };
  return slack.oauth.access(options).then((res) => {
    console.log(`ACCESS ${JSON.stringify(res)}`);
    return slack.team.info({team: res.team_id}).then((res) => {
      return `https://${res.team.domain}.slack.com/`;
    });
  });
}

/**
 * Process SNS message.
 *
 * @param {object} payload Slack payload.
 */
function publishPayload(payload, sns_topic_suffix) {
  return new Promise((resolve, reject) => {
    console.log(`PAYLOAD ${JSON.stringify(payload)}`);
    const AWS = require('aws-sdk');
    const SNS = new AWS.SNS();
    const topic = `${sns_topic_prefix}${sns_topic_suffix}`;
    console.log(`TOPIC ${topic}`);
    SNS.publish({
      Message: JSON.stringify(payload),
      TopicArn: topic
    }, (err, data) => {
      if (err) {
        reject(err);
      } else {
        resolve(data);
      }
    });
  });
}

/**
 * AWS Lambda handler for callbacks.
 *
 * @param {object} event SNS event object.
 * @param {object} context SNS event context.
 * @param {function} callback Lambda callback function.
 */
function callbacks(event, context, callback) {
  console.log(`EVENT ${JSON.stringify(event)}`);
  return getSecrets().then((res) => {
    return verifyRequest(event);
  }).then((res) => {
    return processCallback(res);
  }).then((res) => {
    callback(null, {statusCode: '201', body: ''});
  }).catch((err) => {
    console.error(`ERROR ${JSON.stringify(err)}`);
    callback(err, {statusCode: '400', body: err.message});
  });
}

/**
 * AWS Lambda handler for events.
 *
 * @param {object} event SNS event object.
 * @param {object} context SNS event context.
 * @param {function} callback Lambda callback function.
 */
function events(event, context, callback) {
  console.log(`EVENT ${JSON.stringify(event)}`);
  return getSecrets().then((res) => {
    return verifyRequest(event);
  }).then((res) => {
    return processEvent(res);
  }).then((res) => {
    callback(null, {
      statusCode: '200',
      body: JSON.stringify(res),
      headers: {'Content-Type': 'application/json'}
    });
  }).catch((err) => {
    console.error(`ERROR ${JSON.stringify(err)}`);
    callback(err, {statusCode: '400', body: err.message});
  });
}

/**
 * AWS Lambda handler for OAuth.
 *
 * @param {object} event SNS event object.
 * @param {object} context SNS event context.
 * @param {function} callback Lambda callback function.
 */
function oauth(event, context, callback) {
  console.log(`EVENT ${JSON.stringify(event)}`);
  return getSecrets().then((res) => {
    return processOAuth(event);
  }).then((redirect) => {
    callback(null, {
      statusCode: '301',
      body: null,
      headers: {
        'Content-Type': 'application/json',
        'Location': oauth_redirect || redirect
      }
    });
  }).catch((err) => {
    console.error(`ERROR ${JSON.stringify(err)}`);
    callback(err, {statusCode: '400', body: err.message});
  });
}

exports.callbacks = callbacks;
exports.events = events;
exports.oauth = oauth;
