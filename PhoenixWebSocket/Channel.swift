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
    
    private var onStatus: (Status -> ())?
    
    /// Payload to send when joining channel.
    public var joinPayload: Message.JSON?
    
    private var bindings = [Binding]()
    
    public init(topic: String, onStatusChange: (Status -> ())? = nil) {
        self.topic = topic
        onStatus = onStatusChange
        status = .Disconnected(nil)
    }
    
    /// This will override any previous `onStatusChange` calls
    /// or callback given to initializer.
    public func onStatusChange(callback: Status -> ()) -> Self {
        onStatus = callback
        return self
    }
    
    public func on(event: String, callback: Message -> ()) -> Self {
        bindings.append(Binding(event: event, callback: callback))
        return self
    }
    
    // call this when message recieved for this channel
    func recieved(message: Message) {
        // just in case, should never happen
        guard message.topic == topic else { return }
        
        bindings.filter { $0.event == message.event }
            .forEach { $0.callback(message) }
    }
    
    struct Binding {
        let event: String
        let callback: Message -> ()
    }
    
    public enum Status {
        case Joining
        
        /// When channel successfully joined, contains server response.
        case Joined(Message.JSON)
        
        /// When joining rejected by server (i.e. server replied with `{:error, response}`),
        /// contains error reason and response dic.
        case Rejected(String, Message.JSON)
        
        /// Joining failed by transport related errors.
        case JoinFailed(SendError)
        
        /// Disconnected from server, contains error if any.
        case Disconnected(NSError?)
        
        func isJoined() -> Bool {
            switch self {
            case .Joined(_): return true
            default: return false
            }
        }
    }
}

extension Channel: Equatable { }

@warn_unused_result
public func ==(lhs: Channel, rhs: Channel) -> Bool {
    return lhs.topic == rhs.topic
}

extension Channel: Hashable {
    public var hashValue: Int { return topic.hashValue }
}