import { RTMClient } from './';
import EventEmitter = require('eventemitter3');
import { LogLevel, LoggingFunc } from './logger';
export interface KeepAliveOptions {
    logger?: LoggingFunc;
    logLevel?: LogLevel;
    clientPingTimeout?: number;
    serverPongTimeout?: number;
}
/**
 * An object that monitors activity in an RTMClient and generates ping events in an effort to keep its websocket
 * connection alive. In cases where the websocket connection seems unresponsive, this object emits a
 * `recommend_reconnect` event. That event should be handled by tearing down the websocket connection and
 * opening a new one.
 */
export declare class KeepAlive extends EventEmitter {
    /**
     * The amount of time in milliseconds to wait after the last outgoing message from the client to generate a ping
     * message.
     */
    private clientPingTimeout;
    /**
     * The amount of time in milliseconds to wait after a ping message for the server to respond with a message that
     * replies to that ping (a pong) or some message after that.
     */
    private serverPongTimeout;
    /**
     * The RTMClient to monitor.
     */
    private client?;
    /**
     * A timer for when to send the next ping if no other outgoing message is sent.
     */
    private pingTimer?;
    /**
     * A timer for when to stop listening for an incoming event that acknowledges the ping (counts as a pong)
     */
    private pongTimer?;
    /**
     * The message ID of the latest ping sent, or undefined is there hasn't been one sent.
     */
    private lastPing?;
    /**
     * The name used to prefix all logging generated from this object
     */
    private static loggerName;
    /**
     * This object's logger instance
     */
    private logger;
    /**
     * Flag that indicates whether this object is still monitoring.
     */
    isMonitoring: boolean;
    /**
     * Flag that indicates whether recommend_reconnect event has been emitted and stop() has not been called.
     */
    recommendReconnect: boolean;
    constructor({ clientPingTimeout, serverPongTimeout, logger, logLevel, }?: KeepAliveOptions);
    /**
     * Start monitoring the RTMClient. This method should only be called after the client's websocket is already open.
     */
    start(client: RTMClient): void;
    /**
     * Stop monitoring the RTMClient. This method should be called after the `recommend_reconnect` event is emitted and
     * the client's weboscket is closed. In order to start monitoring the client again, start() needs to be called again
     * after that.
     */
    stop(): void;
    /**
     * Clears the ping timer if its set, otherwise this is a noop.
     */
    private clearPreviousPingTimer;
    /**
     * Sets the ping timer (including clearing any previous one).
     */
    private setPingTimer;
    /**
     * Sends a ping and manages the timer to wait for a pong.
     */
    private sendPing;
    /**
     * Clears the pong timer if its set, otherwise this is a noop.
     */
    private clearPreviousPongTimer;
    /**
     * Determines if a giving incoming event can be treated as an acknowledgement for the outstanding ping, and then
     * clears the ping if so.
     * @param event any incoming slack event
     */
    private attemptAcknowledgePong;
}
