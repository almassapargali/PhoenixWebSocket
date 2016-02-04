//
//  WebsocketClient.swift
//  PhoenixWebSocket
//
//  Created by Almas Sapargali on 2/4/16.
//  Copyright © 2016 Almas Sapargali. All rights reserved.
//

import Foundation
import Starscream

private func makeError(description: String, code: Int = 0) -> NSError {
    return NSError(domain: "com.almassapargali.PhoenixWebSocket", code: code,
        userInfo: [NSLocalizedDescriptionKey: description])
}

public enum MessageResult {
    case Success(Message)
    case Error(ErrorType)
}

public final class WebsocketClient {
    public typealias MessageCallback = MessageResult -> ()
    
    private let socket: WebSocket
    
    private var reconnectTimer: NSTimer?
    private var heartbeatTimer: NSTimer?
    
    private var sentMessages = [String: MessageCallback]()
    
    private var channels = Set<Channel>()
    
    // date may become stale on this
    private var connectedChannels = Set<Channel>()
    
    deinit {
        if socket.isConnected {
            socket.disconnect()
        }
    }
    
    public init(url: NSURL, params: [String: String]? = nil, selfSignedSSL: Bool = false) {
        socket = WebSocket(url: WebsocketClient.resolveUrl(url, params: params))
        socket.selfSignedSSL = selfSignedSSL
    }
    
    @objc public func connect(reconnectOnError: Bool = true, reconnectInterval: NSTimeInterval = 5) {
        guard !socket.isConnected else { return }
        
        if reconnectOnError {
            reconnectTimer = NSTimer.scheduledTimerWithTimeInterval(reconnectInterval,
                target: self, selector: "connect", userInfo: nil, repeats: true)
        }
        socket.connect()
    }
    
    /// See Starscream.WebSocket.disconnect() doc
    public func disconnect(forceTimeout: NSTimeInterval? = nil) {
        heartbeatTimer?.invalidate()
        reconnectTimer?.invalidate()
        if socket.isConnected {
            socket.disconnect(forceTimeout: forceTimeout)
        }
    }
    
    public func send(channel: Channel, event: String, payload: Message.Payload = [:], callback: MessageCallback? = nil) {
        let message = Message(event, topic: channel.topic, payload: payload)
        send(message, callback: callback)
    }
    
    public func join(channel: Channel) {
        channels.insert(channel)
        sendJoinEvent(channel)
    }
    
    private func sendJoinEvent(channel: Channel) {
        guard socket.isConnected else { return }
        send(channel, event: Event.Join) { [weak self] result in
            switch result {
            case .Success(let message):
                self?.connectedChannels.insert(channel)
                channel.onConnect?(message)
            case .Error(let error):
                print("Couldn't join channel: \(error)")
            }
        }
    }
    
    public func leave(channel: Channel) {
        channels.remove(channel)
        guard socket.isConnected else { return }
        send(channel, event: Event.Leave) { [weak self] result in
            switch result {
            case .Success(_):
                self?.connectedChannels.remove(channel)
                channel.onDisconnect?(nil)
            case .Error(let error):
                print("Couldn't leave channel: \(error)")
            }
        }
    }
    
    func send(message: Message, callback: MessageCallback? = nil) {
        guard socket.isConnected else {
            callback?(.Error(makeError("Not connected to the server.")))
            return
        }
        do {
            let data = try message.toJson()
            sentMessages[message.ref] = callback
            socket.writeData(data)
        } catch {
            callback?(.Error(error))
        }
    }
    
    @objc func sendHeartbeat() throws {
        send(Message(Event.Heartbeat, topic: "phoenix", payload: ["status": "heartbeat"]))
    }
    
    private class func resolveUrl(url: NSURL, params: [String: String]?) -> NSURL {
        guard let components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false),
            params = params else { return url }
        
        let queryItems = params.map { str, val in NSURLQueryItem(name: str, value: val) }
        components.queryItems = components.queryItems.flatMap { $0 + queryItems } ?? queryItems
        return components.URL ?? url
    }
    
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
        heartbeatTimer?.invalidate()
        heartbeatTimer = NSTimer.scheduledTimerWithTimeInterval( 30,
            target: self, selector: "sendHeartbeat", userInfo: nil, repeats: true)
        channels.forEach(sendJoinEvent)
    }
    
    public func websocketDidDisconnect(socket: Starscream.WebSocket, error: NSError?) {
        print(error)
        heartbeatTimer?.invalidate()
        connectedChannels.forEach { $0.onDisconnect?(error) }
        connectedChannels.removeAll()
    }
    
    public func websocketDidReceiveMessage(socket: Starscream.WebSocket, text: String) {
        print("Text ", text)
    }
    
    public func websocketDidReceiveData(socket: Starscream.WebSocket, data: NSData) {
        print("Data ", NSString(data: data, encoding: NSUTF8StringEncoding))
    }
}
