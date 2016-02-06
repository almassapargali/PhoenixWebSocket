//
//  WebsocketClient.swift
//  PhoenixWebSocket
//
//  Created by Almas Sapargali on 2/4/16.
//  Copyright © 2016 Almas Sapargali. All rights reserved.
//

import Foundation
import Starscream

private func resolveUrl(url: NSURL, params: [String: String]?) -> NSURL {
    guard let components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false),
        params = params else { return url }
    
    let queryItems = params.map { str, val in NSURLQueryItem(name: str, value: val) }
    components.queryItems = components.queryItems.flatMap { $0 + queryItems } ?? queryItems
    return components.URL ?? url
}

public enum SendError: ErrorType {
    case NotConnected
    
    case PayloadSerializationFailed(String)
    
    case ResponseDeserializationFailed(ResponseError)
}

extension SendError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .NotConnected: return "Socket is not connected to the server."
        case .PayloadSerializationFailed(let reason):
            return "Payload serialization failed: \(reason)"
        case .ResponseDeserializationFailed(let error):
            return "Response deserialization failed: \(error)"
        }
    }
}

public enum MessageResponse {
    case Success(Response)
    
    /// Note that errors received from server will be in Success case.
    /// This case for client side errors.
    case Error(SendError)
}

public final class WebsocketClient {
    public typealias MessageCallback = MessageResponse -> ()
    
    private let socket: WebSocket
    
    private var reconnectTimer: NSTimer?
    private var heartbeatTimer: NSTimer?
    
    public var enableLogging: Bool = true
    
    public var onConnect: (() -> ())?
    public var onDisconnect: (NSError? -> ())?
    
    // ref as key, for triggering callback when phx_reply event comes in
    private var sentMessages = [String: MessageCallback]()
    
    private var channels = Set<Channel>()
    
    // data may become stale on this
    private var connectedChannels = Set<Channel>()
    
    /// **Warning:** Please don't forget to disconnect when you're done to prevent memory leak
    public init(url: NSURL, params: [String: String]? = nil, selfSignedSSL: Bool = false) {
        socket = WebSocket(url: resolveUrl(url, params: params))
        socket.selfSignedSSL = selfSignedSSL
        socket.delegate = self
    }
    
    public func connect(reconnectOnError: Bool = true, reconnectInterval: NSTimeInterval = 5) {
        guard !socket.isConnected else { return }
        
        if reconnectOnError {
            reconnectTimer = NSTimer.scheduledTimerWithTimeInterval(reconnectInterval,
                target: self, selector: "retry", userInfo: nil, repeats: true)
        }
        log("Connecting to", socket.currentURL)
        socket.connect()
    }
    
    @objc func retry() {
        guard !socket.isConnected else { return }
        log("Retrying connect to", socket.currentURL)
        socket.connect()
    }
    
    /// See Starscream.WebSocket.disconnect() for forceTimeout argument's doc
    public func disconnect(forceTimeout: NSTimeInterval? = nil) {
        heartbeatTimer?.invalidate()
        reconnectTimer?.invalidate()
        if socket.isConnected {
            log("Disconnecting from", socket.currentURL)
            socket.disconnect(forceTimeout: forceTimeout)
        }
    }
    
    public func send(channel: Channel, event: String, payload: Message.JSON = [:], callback: MessageCallback? = nil) {
        let message = Message(event, topic: channel.topic, payload: payload)
        send(message, callback: callback)
    }
    
    public func join(channel: Channel) {
        channels.insert(channel)
        sendJoinEvent(channel)
    }
    
    private func sendJoinEvent(channel: Channel) {
        // if socket isn't connected, we join this channel right after connection
        guard socket.isConnected else { return }
        
        log("Joining channel:", channel.topic)
        let payload = channel.joinPayload ?? [:]
        send(channel, event: Event.Join, payload: payload) { [weak self] result in
            switch result {
            case .Success(let response):
                self?.log("Joined channel, payload:", response)
                self?.connectedChannels.insert(channel)
                channel.onConnect?(response)
            case .Error(let error):
                self?.log("Failed to join channel:", error)
                channel.onJoinError?(error)
            }
        }
    }
    
    public func leave(channel: Channel) {
        // before guard so it won't be rejoined on next connection
        channels.remove(channel)
        
        // we simply won't rejoin after connection
        guard socket.isConnected else { return }
        
        log("Leaving channel:", channel.topic)
        send(channel, event: Event.Leave) { [weak self] result in
            switch result {
            case .Success(let response):
                self?.log("Left channel, payload:", response)
                self?.connectedChannels.remove(channel)
                channel.onDisconnect?(nil)
            case .Error(let error): // how is this possible?
                self?.log("Failed to leave channel:", error)
            }
        }
    }
    
    func send(message: Message, callback: MessageCallback? = nil) {
        guard socket.isConnected else {
            callback?(.Error(.NotConnected))
            log("Attempt to send message while not connected:", message)
            return
        }
        do {
            let data = try message.toJson()
            log("Sending", message)
            // force unwrap because:
            // 0. if ref is missing, then something is going wrong
            // 1. this func isn't public
            sentMessages[message.ref!] = callback
            socket.writeData(data)
        } catch let error as NSError {
            log("Failed to send message:", error)
            callback?(.Error(.PayloadSerializationFailed(error.localizedDescription)))
        }
    }
    
    @objc func sendHeartbeat() {
        send(Message(Event.Heartbeat, topic: "phoenix", payload: [:]))
    }
    
    // Phoenix related events
    struct Event {
        static let Heartbeat = "heartbeat"
        static let Join = "phx_join"
        static let Leave = "phx_leave"
        static let Reply = "phx_reply"
        static let Error = "phx_error"
        static let Close = "phx_close"
    }
}

extension WebsocketClient: WebSocketDelegate {
    public func websocketDidConnect(socket: Starscream.WebSocket) {
        log("Connected to:", socket.currentURL)
        onConnect?()
        heartbeatTimer?.invalidate()
        heartbeatTimer = NSTimer.scheduledTimerWithTimeInterval(30,
            target: self, selector: "sendHeartbeat", userInfo: nil, repeats: true)
        channels.forEach(sendJoinEvent)
    }
    
    public func websocketDidDisconnect(socket: Starscream.WebSocket, error: NSError?) {
        log("Disconnected from:", socket.currentURL, error)
        // we don't worry about reconnecting, since we've started reconnectTime when connecting
        onDisconnect?(error)
        heartbeatTimer?.invalidate()
        connectedChannels.forEach { $0.onDisconnect?(error) }
        connectedChannels.removeAll()
        
        // I don't think we'll recive their responses
        sentMessages.removeAll()
    }
    
    public func websocketDidReceiveMessage(socket: Starscream.WebSocket, text: String) {
        log("Received text:", text)
        if let data = text.dataUsingEncoding(NSUTF8StringEncoding), message = Message(data: data) {
            if let ref = message.ref, callback = sentMessages.removeValueForKey(ref) {
                do {
                    callback(.Success(try Response.fromPayload(message.payload)))
                } catch let error as ResponseError {
                    callback(.Error(.ResponseDeserializationFailed(error)))
                } catch {
                    fatalError("Response.fromPayload throw unknown error")
                }
            }
            channels.filter { $0.topic == message.topic }
                .forEach { $0.recieved(message) }
        } else {
            log("Couldn't parse message from text:", text)
        }
    }
    
    public func websocketDidReceiveData(socket: Starscream.WebSocket, data: NSData) {
        log("Received data:", data)
    }
}

extension WebsocketClient {
    private func log(items: Any...) {
        if enableLogging { print(items) }
    }
}
