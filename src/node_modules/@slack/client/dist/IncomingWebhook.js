"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const got = require("got"); // tslint:disable-line:no-require-imports
const errors_1 = require("./errors");
const util_1 = require("./util");
/**
 * A client for Slack's Incoming Webhooks
 */
class IncomingWebhook {
    constructor(url, defaults = {}) {
        if (url === undefined) {
            throw new Error('Incoming webhook URL is required');
        }
        this.url = url;
        this.defaults = defaults;
    }
    send(message, callback) {
        // NOTE: no support for proxy
        // NOTE: no support for TLS config
        let payload = Object.assign({}, this.defaults);
        if (typeof message === 'string') {
            payload.text = message;
        }
        else {
            payload = Object.assign(payload, message);
        }
        const implementation = () => got.post(this.url, {
            body: JSON.stringify(payload),
            retries: 0,
        })
            .catch((error) => {
            // Wrap errors in this packages own error types (abstract the implementation details' types)
            switch (error.name) {
                case 'RequestError':
                    throw requestErrorWithOriginal(error);
                case 'ReadError':
                    throw readErrorWithOriginal(error);
                case 'HTTPError':
                    throw httpErrorWithOriginal(error);
                default:
                    throw error;
            }
        })
            .then((response) => {
            return this.buildResult(response);
        });
        if (callback !== undefined) {
            util_1.callbackify(implementation)(callback);
            return;
        }
        return implementation();
    }
    /**
     * Processes an HTTP response into an IncomingWebhookResult.
     * @param response
     */
    buildResult(response) {
        return {
            text: response.body,
        };
    }
}
exports.IncomingWebhook = IncomingWebhook;
/*
 * Helpers
 */
/**
 * A factory to create IncomingWebhookRequestError objects
 * @param original The original error
 */
function requestErrorWithOriginal(original) {
    const error = errors_1.errorWithCode(
    // `any` cast is used because the got definition file doesn't export the got.RequestError type
    new Error(`A request error occurred: ${original.code}`), errors_1.ErrorCode.IncomingWebhookRequestError);
    error.original = original;
    return error;
}
/**
 * A factory to create IncomingWebhookReadError objects
 * @param original The original error
 */
function readErrorWithOriginal(original) {
    const error = errors_1.errorWithCode(new Error('A response read error occurred'), errors_1.ErrorCode.IncomingWebhookReadError);
    error.original = original;
    return error;
}
/**
 * A factory to create IncomingWebhookHTTPError objects
 * @param original The original error
 */
function httpErrorWithOriginal(original) {
    const error = errors_1.errorWithCode(
    // `any` cast is used because the got definition file doesn't export the got.HTTPError type
    new Error(`An HTTP protocol error occurred: statusCode = ${original.statusCode}`), errors_1.ErrorCode.IncomingWebhookHTTPError);
    error.original = original;
    return error;
}
//# sourceMappingURL=IncomingWebhook.js.map