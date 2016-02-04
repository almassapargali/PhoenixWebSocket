//
//  Message.swift
//  PhoenixWebSocket
//
//  Created by Almas Sapargali on 2/4/16.
//  Copyright © 2016 Almas Sapargali. All rights reserved.
//

import Foundation

public struct Message {
    public typealias Payload = [String: AnyObject]
    
    public let topic: String
    
    public let event: String
    public let payload: [String: AnyObject]
    
    let ref: String
    
    func toJson() throws -> NSData {
        let dic = ["topic": topic, "event": event, "payload": payload, "ref": ref]
        return try NSJSONSerialization.dataWithJSONObject(dic, options: NSJSONWritingOptions())
    }
    
    init(_ event: String, topic: String, payload: Payload, ref: String = NSUUID().UUIDString) {
        (self.topic, self.event, self.payload, self.ref) = (topic, event, payload, ref)
    }
    
    init?(data: NSData) {
        let jsonObject = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions())
        guard let json = jsonObject as? Payload,
            topic = json["topic"] as? String, event = json["event"] as? String,
            payload = json["payload"] as? Payload, ref = json["ref"] as? String
            else { return nil }
        (self.topic, self.event, self.payload, self.ref) = (topic, event, payload, ref)
    }
}