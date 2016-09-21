//
//  Socket.swift
//  PhoenixWebSocket
//
//  Created by Almas Sapargali on 2/4/16.
//  Copyright © 2016 Almas Sapargali. All rights reserved.
//

import Foundation
import Starscream

// http://stackoverflow.com/a/24888789/1935440
// String's stringByAddingPercentEncodingWithAllowedCharacters doesn't encode + sign,
// which is ofter used in Phoenix tokens.
private let URLEncodingAllowedChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~/?")

private func encodePair(_ pair: (String, String)) -> String? {
    if let key = pair.0.addingPercentEncoding(withAllowedCharacters: URLEncodingAllowedChars),
        let value = pair.1.addingPercentEncoding(withAllowedCharacters: URLEncodingAllowedChars)
    { return "\(key)=\(value)" } else { return nil }
}

private func resolveUrl(_ url: URL, params: [String: String]?) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        let params = params else { return url }
    
    let queryString = params.flatMap(encodePair).joined(separator: "&")
    components.percentEncodedQuery = queryString
    return components.url ?? url
}

public enum SendError: Error {
    case notConnected
    
    case payloadSerializationFailed(String)
    
    case responseDeserializationFailed(ResponseError)
    
    case channelNotJoined
}

extension SendError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notConnected: return "Socket is not connected to the server."
        case .payloadSerializationFailed(let reason):
            return "Payload serialization failed: \(reason)"
        case .responseDeserializationFailed(let error):
            return "Response deserialization failed: \(error)"
        case .channelNotJoined: return "Channel not joined."
        }
    }
}

public enum MessageResponse {
    case success(Response)
    
    /// Note that errors received from server will be in Success case.
    /// This case for client side errors.
    case error(SendError)
}

public final class Socket {
    public typealias MessageCallback = (MessageResponse) -> ()
    
    fileprivate static let HearbeatRefPrefix = "heartbeat-"
    
    fileprivate let socket: WebSocket
    
    fileprivate var reconnectTimer: Timer?
    fileprivate var heartbeatTimer: Timer?
    
    public var enableLogging: Bool = true
    
    public var onConnect: (() -> ())?
    public var onDisconnect: ((NSError?) -> ())?
    
    // ref as key, for triggering callback when phx_reply event comes in
    fileprivate var sentMessages = [String: MessageCallback]()
    
    fileprivate var channels = Set<Channel>()
    
    // data may become stale on this
    fileprivate var connectedChannels = Set<Channel>()
    
    /// **Warning:** Please don't forget to disconnect when you're done to prevent memory leak
    public init(url: URL, params: [String: String]? = nil, disableSSLCertValidation: Bool = false) {
        socket = WebSocket(url: resolveUrl(url, params: params))
        socket.disableSSLCertValidation = disableSSLCertValidation
        socket.delegate = self
    }
    
    /// Connects socket to server, if socket is already connected to server, makes sure 
    /// all timers are in place. This may be usefull to ensure connection when app comes 
    /// from background, since all timers invalidated when app goes background.
    public func connect(_ reconnectOnError: Bool = true, reconnectInterval: TimeInterval = 5) {
        // if everything is on place
        if let heartbeatTimer = heartbeatTimer,
            socket.isConnected && heartbeatTimer.isValid { return }
        
        if reconnectOnError {
            // let's invalidate old timer if any
            reconnectTimer?.invalidate()
            reconnectTimer = Timer.scheduledTimer(timeInterval: reconnectInterval,
                target: self, selector: #selector(Socket.retry), userInfo: nil, repeats: true)
        }
        
        if socket.isConnected { // just restart heartbeat timer
            // send one now attempting to not to timeout on server
            sendHeartbeat()
            // setup new timer
            heartbeatTimer?.invalidate()
            heartbeatTimer = Timer.scheduledTimer(timeInterval: 30,
                target: self, selector: #selector(Socket.sendHeartbeat), userInfo: nil, repeats: true)
        } else {
            log("Connecting to", socket.currentURL)
            channels.forEach { $0.status = .joining }
            socket.connect()
        }
    }
    
    @objc func retry() {
        guard !socket.isConnected else { return }
        log("Retrying connect to", socket.currentURL)
        channels.forEach { $0.status = .joining }
        socket.connect()
    }
    
    /// See Starscream.WebSocket.disconnect() for forceTimeout argument's doc
    public func disconnect(_ forceTimeout: TimeInterval? = nil) {
        heartbeatTimer?.invalidate()
        reconnectTimer?.invalidate()
        if socket.isConnected {
            log("Disconnecting from", socket.currentURL)
            socket.disconnect(forceTimeout: forceTimeout)
        }
    }
    
    public func send(_ channel: Channel, event: String, payload: Message.JSON = [:], callback: MessageCallback? = nil) {
        guard socket.isConnected else {
            callback?(.error(.notConnected))
            log("Attempt to send message while not connected:", event, payload)
            return
        }
        guard channels.contains(channel) && channel.status.isJoined() else {
            callback?(.error(.channelNotJoined))
            log("Attempt to send message to not joined channel:", channel.topic, event, payload)
            return
        }
        sendMessage(Message(event, topic: channel.topic, payload: payload), callback: callback)
    }
    
    public func join(_ channel: Channel) {
        channels.insert(channel)
        if socket.isConnected { // check for setting status here.
            channel.status = .joining
            sendJoinEvent(channel)
        }
    }
    
    fileprivate func sendJoinEvent(_ channel: Channel) {
        // if socket isn't connected, we join this channel right after connection
        guard socket.isConnected else { return }
        
        log("Joining channel:", channel.topic)
        let payload = channel.joinPayload ?? [:]
        // Use send message to skip channel joined check
        sendMessage(Message(Event.Join, topic: channel.topic, payload: payload)) { [weak self] result in
            switch result {
            case .success(let joinResponse):
                switch joinResponse {
                case .ok(let response):
                    self?.log("Joined channel, payload:", response)
                    self?.connectedChannels.insert(channel)
                    channel.status = .joined(response)
                case let .error(reason, response):
                    self?.log("Rejected from channel, payload:", response)
                    channel.status = .rejected(reason, response)
                }
            case .error(let error):
                self?.log("Failed to join channel:", error)
                channel.status = .joinFailed(error)
            }
        }
    }
    
    public func leave(_ channel: Channel) {
        // before guard so it won't be rejoined on next connection
        channels.remove(channel)
        
        // we simply won't rejoin after connection
        guard socket.isConnected else { return }
        
        log("Leaving channel:", channel.topic)
        sendMessage(Message(Event.Leave, topic: channel.topic, payload: [:])) { [weak self] result in
            switch result {
            case .success(let response):
                self?.log("Left channel, payload:", response)
                _ = self?.connectedChannels.remove(channel)
                channel.status = .disconnected(nil)
            case .error(let error): // how is this possible?
                self?.log("Failed to leave channel:", error)
            }
        }
    }
    
    func sendMessage(_ message: Message, callback: MessageCallback? = nil) {
        do {
            let data = try message.toJson()
            log("Sending", message)
            // force unwrap because:
            // 0. if ref is missing, then something is going wrong
            // 1. this func isn't public
            sentMessages[message.ref!] = callback
            socket.write(data: data)
        } catch let error as NSError {
            log("Failed to send message:", error)
            callback?(.error(.payloadSerializationFailed(error.localizedDescription)))
        }
    }
    
    @objc func sendHeartbeat() {
        guard socket.isConnected else { return }
        // so we can skip logging them, less noisy
        let ref = Socket.HearbeatRefPrefix + UUID().uuidString
        sendMessage(Message(Event.Heartbeat, topic: "phoenix", payload: [:], ref: ref))
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

extension Socket: WebSocketDelegate {
    public func websocketDidConnect(socket: Starscream.WebSocket) {
        log("Connected to:", socket.currentURL)
        onConnect?()
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(timeInterval: 30,
            target: self, selector: #selector(Socket.sendHeartbeat), userInfo: nil, repeats: true)
        // statuses set when we were connecting socket
        channels.forEach(sendJoinEvent)
    }
    
    public func websocketDidDisconnect(socket: Starscream.WebSocket, error: NSError?) {
        log("Disconnected from:", socket.currentURL, error)
        // we don't worry about reconnecting, since we've started reconnectTime when connecting
        onDisconnect?(error)
        heartbeatTimer?.invalidate()
        channels.forEach { channel in
            switch channel.status {
            case .joined(_), .joining: channel.status = .disconnected(error)
            default: break
            }
        }
        connectedChannels.removeAll()
        
        // I don't think we'll recive their responses
        sentMessages.removeAll()
    }
    
    public func websocketDidReceiveMessage(socket: Starscream.WebSocket, text: String) {
        guard let data = text.data(using: String.Encoding.utf8), let message = Message(data: data)
            else { log("Couldn't parse message from text:", text); return }
        
        // don't log if hearbeat reply
        if let ref = message.ref , ref.hasPrefix(Socket.HearbeatRefPrefix) { }
        else { log("Received:", message) }
        
        // Replied message
        if let ref = message.ref, let callback = sentMessages.removeValue(forKey: ref) {
            do {
                callback(.success(try Response.fromPayload(message.payload)))
            } catch let error as ResponseError {
                callback(.error(.responseDeserializationFailed(error)))
            } catch {
                fatalError("Response.fromPayload throw unknown error")
            }
        }
        channels.filter { $0.topic == message.topic }
            .forEach { $0.recieved(message) }
    }
    
    public func websocketDidReceiveData(socket: Starscream.WebSocket, data: Data) {
        log("Received data:", data)
    }
}

extension Socket {
    fileprivate func log(_ items: Any...) {
        if enableLogging { print(items) }
    }
}
