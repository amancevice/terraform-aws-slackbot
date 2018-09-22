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
 * Process SNS message.
 *
 * @param {object} payload SNS payload.
 */
function publishPayload(payload, sns_topic_suffix) {
  return new Promise((resolve, reject) => {
    console.log(`PAYLOAD ${JSON.stringify(payload)}`);
    const AWS = require('aws-sdk');
    const SNS = new AWS.SNS();
    const topic = `${sns_topic_prefix}${sns_topic_suffix}`;
    const message = Buffer.from(JSON.stringify(payload)).toString('base64');
    const options = {Message: message, TopicArn: topic};
    console.log(`PUBLISH ${JSON.stringify(options)}`);
    SNS.publish(options, (err, data) => {
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
 * @param {object} event Event object.
 */
function handleCallback(event) {
  return Promise.resolve(event.body).then((res) => {
    const qs = require('querystring');
    const params = qs.parse(res);
    return JSON.parse(params.payload);
  }).then((res) => {
    return publishPayload(res, `callback_${res.callback_id}`);
  }).then((res) => {
    return {
      statusCode: '204',
    };
  });
}

/**
 * AWS Lambda handler for events.
 *
 * @param {object} event Event object.
 */
function handleEvent(event) {
  return Promise.resolve(event.body).then((res) => {
    return JSON.parse(res);
  }).then((res) => {
    if (res.type === 'url_verification') {
      const challenge = {challenge: res.challenge};
      console.log(`CHALLENGE ${JSON.stringify(challenge)}`);
      return challenge;
    } else {
      return publishPayload(res, `event_${res.event.type}`);
    }
  }).then((res) => {
    return {
      statusCode: '200',
      body: JSON.stringify(res),
      headers: {'Content-Type': 'application/json'},
    };
  });
}

/**
 * AWS Lambda handler for slash commands.
 *
 * @param {object} event Event object.
 */
function handleSlashCommand(event) {
  return Promise.resolve(event.body).then((res) => {
    const qs = require('querystring');
    return qs.parse(res);
  }).then((res) => {
    return publishPayload(res, res.command.replace(/^\//, 'slash_'));
  }).then((res) => {
    return {
      statusCode: '204',
    };
  });
}

/**
 * AWS Lambda handler for OAuth.
 *
 * @param {object} event Event object.
 */
function handleOAuth(event) {
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
  }).then((res) => {
    return {
      statusCode: '301',
      headers: {'Location': oauth_redirect || res},
    };
  });
}

/**
 * AWS API Gateway router.
 *
 * @param {object} event Event object.
 * @param {object} context Event context.
 * @param {function} callback Lambda callback function.
 */
function handler(event, context, callback) {
  console.log(`EVENT ${JSON.stringify(event)}`);
  getSecrets().then((res) => {
    return verifyRequest(event);
  }).then((res) => {
    return {
      'GET': {
        '/oauth': handleOAuth,
      },
      'POST': {
        '/callbacks': handleCallback,
        '/events': handleEvent,
        '/slash-commands': handleSlashCommand,
      }
    }[event.httpMethod][event.path](event);
  }).then((res) => {
    callback(null, res);
  }).catch((err) => {
    console.error(`ERROR ${JSON.stringify(err)}`);
    callback(err, {statusCode: '400', body: 'Bad request'});
  });
}

exports.handler = handler;
