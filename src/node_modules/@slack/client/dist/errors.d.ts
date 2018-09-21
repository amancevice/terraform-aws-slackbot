/// <reference types="node" />
import { WebAPICallResult, RTMCallResult } from '.';
/**
 * All errors produced by this package adhere to this interface
 */
export interface CodedError extends NodeJS.ErrnoException {
    code: ErrorCode;
    data?: WebAPICallResult | RTMCallResult;
}
/**
 * A dictionary of codes for errors produced by this package
 */
export declare enum ErrorCode {
    TestError = "slackclient_test",
    RequestError = "slackclient_request_error",
    ReadError = "slackclient_read_error",
    HTTPError = "slackclient_http_error",
    PlatformError = "slackclient_platform_error",
    RateLimitedError = "slackclient_rate_limited_error",
    RefreshFailedError = "slackclient_refresh_failed_error",
    RTMSendWhileDisconnectedError = "slackclient_rtmclient_send_while_disconnected_error",
    RTMSendWhileNotReadyError = "slackclient_rtmclient_send_while_not_ready_error",
    RTMSendMessagePlatformError = "slackclient_rtmclient_send_message_platform_error",
    RTMWebsocketError = "slackclient_rtmclient_websocket_error",
    RTMNoReplyReceivedError = "slackclient_rtmclient_no_reply_received_error",
    KeepAliveConfigError = "slackclient_keepalive_config_error",
    KeepAliveClientNotConnected = "slackclient_keepalive_client_not_connected",
    KeepAliveInconsistentState = "slackclient_keepalive_inconsistent_state",
    IncomingWebhookRequestError = "slackclient_incomingwebhook_request_error",
    IncomingWebhookReadError = "slackclient_incomingwebhook_read_error",
    IncomingWebhookHTTPError = "slackclient_incomingwebhook_http_error"
}
/**
 * Factory for producing a {@link CodedError} from a generic error
 */
export declare function errorWithCode(error: Error, code: ErrorCode): CodedError;
