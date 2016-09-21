//
//  Message.swift
//  PhoenixWebSocket
//
//  Created by Almas Sapargali on 2/4/16.
//  Copyright © 2016 Almas Sapargali. All rights reserved.
//

import Foundation

public struct Message {
    public typealias JSON = [String: AnyObject]
    
    public let topic: String

    public let event: String
    public let payload: [String: AnyObject]

    // broadcasted messages doesn't have ref
    let ref: String?

    func toJson() throws -> Data {
        let dic = ["topic": topic, "event": event, "payload": payload, "ref": ref ?? ""] as [String : Any]
        return try JSONSerialization.data(withJSONObject: dic, options: JSONSerialization.WritingOptions())
    }
    
    init(_ event: String, topic: String, payload: JSON, ref: String = UUID().uuidString) {
        (self.topic, self.event, self.payload, self.ref) = (topic, event, payload, ref)
    }
    
    init?(data: Data) {
        let jsonObject = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions())
        guard let json = jsonObject as? JSON,
            let topic = json["topic"] as? String,
            let event = json["event"] as? String,
            let payload = json["payload"] as? JSON
            else { return nil }
        (self.topic, self.event, self.payload) = (topic, event, payload)
        ref = json["ref"] as? String
    }
}

extension Message: CustomStringConvertible {
    public var description: String {
        let type = ref == nil ? "Broadcast" : "Reply"
        return "\(type) Message[topic: \(topic), event: \(event), payload: \(payload)]"
    }
}
