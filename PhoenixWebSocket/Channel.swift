//
//  Channel.swift
//  PhoenixWebSocket
//
//  Created by Almas Sapargali on 2/4/16.
//  Copyright © 2016 Almas Sapargali. All rights reserved.
//

import Foundation

public class Channel {
    public let topic: String
    
    public internal(set) var status: Status {
        didSet { onStatus?(status) }
    }
    
    fileprivate var onStatus: ((Status) -> ())?
    
    /// Payload to send when joining channel.
    public var joinPayload: Message.JSON?
    
    fileprivate var bindings = [Binding]()
    
    public init(topic: String, onStatusChange: ((Status) -> ())? = nil) {
        self.topic = topic
        onStatus = onStatusChange
        status = .disconnected(nil)
    }
    
    /// This will override any previous `onStatusChange` calls
    /// or callback given to initializer.
    public func onStatusChange(_ callback: @escaping (Status) -> ()) -> Self {
        onStatus = callback
        return self
    }
    
    public func on(_ event: String, callback: @escaping (Message) -> ()) -> Self {
        bindings.append(Binding(event: event, callback: callback))
        return self
    }
    
    // call this when message recieved for this channel
    func recieved(_ message: Message) {
        // just in case, should never happen
        guard message.topic == topic else { return }
        
        bindings.filter { $0.event == message.event }
            .forEach { $0.callback(message) }
    }
    
    struct Binding {
        let event: String
        let callback: (Message) -> ()
    }
    
    public enum Status {
        case joining
        
        /// When channel successfully joined, contains server response.
        case joined(Message.JSON)
        
        /// When joining rejected by server (i.e. server replied with `{:error, response}`),
        /// contains error reason and response dic.
        case rejected(String, Message.JSON)
        
        /// Joining failed by transport related errors.
        case joinFailed(SendError)
        
        /// Disconnected from server, contains error if any.
        case disconnected(NSError?)
        
        func isJoined() -> Bool {
            switch self {
            case .joined(_): return true
            default: return false
            }
        }
    }
}

extension Channel: Equatable { }


public func ==(lhs: Channel, rhs: Channel) -> Bool {
    return lhs.topic == rhs.topic
}

extension Channel: Hashable {
    public var hashValue: Int { return topic.hashValue }
}
