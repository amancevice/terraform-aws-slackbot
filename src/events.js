const AWS = require('aws-sdk');

const encrypted_verificaton_token = process.env.ENCRYPTED_VERIFICATION_TOKEN;
const sns_topic_prefix = process.env.SNS_TOPIC_PREFIX;

let verification_token;

/**
 * Process Slack interactive event..
 *
 * @param {object} event AWS Lambda event.
 * @param {function} callback AWS Lambda callback function.
 */
function processEvent(event, callback) {
  console.log(`BODY ${event.body}`);
  const params = JSON.parse(event.body);
  console.log(`PARAMS ${JSON.stringify(params)}`);
  if (params.token !== verification_token) {
    console.error(`Request token (${params.token}) does not match expected`);
    return callback('Invalid request token');
  }

  else if (params.type === 'url_verification') {
    const challenge = {challenge: params.challenge};
    console.log(`CHALLENGE ${JSON.stringify(challenge)}`);
    callback(null, challenge);
  }

  else if (params.type === 'event_callback') {
    const SNS = new AWS.SNS();
    const topic = `${sns_topic_prefix}:slack_event_${params.event.type}`;
    console.log(`TOPIC ${topic}`);
    SNS.publish({
        Message: Buffer.from(JSON.stringify(payload)).toString('base64'),
        TopicArn: topic
      }, (err, data) => {
        if (err) {
          console.log('SNS error:', err);
          return callback(err);
        }
        callback();
      });
  }
}

/**
 * Responds to any HTTP request that can provide a "message" field in the body.
 *
 * @param {object} event AWS Lambda event.
 * @param {object} context AWS Lambda context.
 * @param {function} callback AWS Lambda callback function.
 */
exports.handler = (event, context, callback) => {
  const done = (err, res) => callback(null, {
      statusCode: err ? '400' : '200',
      body: err ? (err.message || err) : JSON.stringify(res),
      headers: {
          'Content-Type': 'application/json',
      }
    });

  // Container reuse, simply process the event with the key in memory
  if (verification_token) {
    processEvent(event, done);
  }

  // Encrypted token not set
  else if (!encrypted_verificaton_token || encrypted_verificaton_token === '<kms-encrypted-slack-verification-token>') {
    done('Verification token has not been set.');
  }

  // Decrypt the token and process
  else {
    const verification_ciphertext = { CiphertextBlob: new Buffer(encrypted_verificaton_token, 'base64') };
    const kms = new AWS.KMS();
    kms.decrypt(verification_ciphertext, (err, data) => {
        if (err) {
          console.log('Decrypt error: ', err);
          return done(err);
        }
        verification_token = data.Plaintext.toString('ascii');
        processEvent(event, done);
      });
  }
};
