const crypto = require('crypto');
const secret = process.env.SECRET;
const signing_version = 'v0';
const sns_topic_prefix = process.env.SNS_TOPIC_PREFIX;

let signing_secret;

/**
 * Get Slack tokens from memory or AWS SecretsManager.
 */
function getSigningSecret() {
  return new Promise((resolve, reject) => {
    if (signing_secret) {
      resolve(signing_secret);
    } else {
      console.log(`FETCH ${secret}`);
      const AWS = require('aws-sdk');
      const secrets = new AWS.SecretsManager();
      secrets.getSecretValue({SecretId: secret}, (err, data) => {
        if (err) {
          reject(err);
        } else {
          signing_secret = JSON.parse(data.SecretString).SIGNING_SECRET;
          console.log(`RECEIVED SIGNING SECRET`);
          resolve(signing_secret);
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
    const ts = event.headers['X-Slack-Request-Timestamp']
    const req = event.headers['X-Slack-Signature'];
    const hmac = crypto.createHmac('sha256', signing_secret);
    const data = `${signing_version}:${event.headers['X-Slack-Request-Timestamp']}:${event.body}`;
    const sig = `${signing_version}=${hmac.update(data).digest('hex')}`;
    console.log(`SIGNATURES ${JSON.stringify({request: req, calculated: sig})}`);
    if (Math.abs(new Date()/1000 - ts) > 60 * 5) {
      reject('Request too old');
    } else if (req !== sig) {
      reject('Signatures do not match');
    } else {
      console.log(`EVENT ${JSON.stringify(event)}`);
      resolve(event.body);
    }
  });
}

/**
 * Process Slack .
 *
 * @param {object} body Parsed Slack request body.
 */
function processCallback(body) {
  return Promise.resolve(body).then((res) => {
    const qs = require('querystring');
    const params = qs.parse(body);
    return JSON.parse(params.payload);
  }).then((res) => {
    return publishPayload(res);
  });
}

/**
 * Process Slack .
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
      return publishPayload(res);
    }
  });
}

/**
 * Process SNS message.
 *
 * @param {object} payload Slack payload.
 */
function publishPayload(payload) {
  return new Promise((resolve, reject) => {
    console.log(`PAYLOAD ${JSON.stringify(payload)}`);
    const AWS = require('aws-sdk');
    const SNS = new AWS.SNS();
    const topic = `${sns_topic_prefix}${payload.callback_id}`;
    console.log(`TOPIC ${topic}`);
    SNS.publish({
      Message: Buffer.from(JSON.stringify(payload)).toString('base64'),
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
  return getSigningSecret().then((res) => {
    return verifyRequest(event);
  }).then((res) => {
    return processCallback(res);
  }).then((res) => {
    callback(null, {statusCode: '201', body: ''});
  }).catch((err) => {
    console.error(`ERROR ${err}`);
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
  return getSigningSecret().then((res) => {
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
    console.error(`ERROR ${err}`);
    callback(err, {statusCode: '400', body: err.message});
  });
}

exports.callbacks = callbacks;
exports.events = events;
