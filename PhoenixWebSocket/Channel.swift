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
    
    public var onConnect: (Response -> ())?
    public var onJoinError: (SendError -> ())?
    public var onDisconnect: (NSError? -> ())?
    
    public var joinPayload: Message.JSON?
    
    private var bindings = [Binding]()
    
    public init(topic: String) {
        self.topic = topic
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
}

extension Channel: Equatable { }

@warn_unused_result
public func ==(lhs: Channel, rhs: Channel) -> Bool {
    return lhs.topic == rhs.topic
}

extension Channel: Hashable {
    public var hashValue: Int { return topic.hashValue }
}