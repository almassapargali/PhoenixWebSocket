//
//  Message.swift
//  PhoenixWebSocket
//
//  Created by Almas Sapargali on 2/4/16.
//  Copyright © 2016 Almas Sapargali. All rights reserved.
//

import Foundation

public enum Response {
    case Ok(Message.JSON)
    case Error(ErrorType)
    
    public static func fromPayload(payload: Message.JSON) throws -> Response {
        guard let status = payload["status"] as? String where ["ok", "error"].contains(status),
            let response = payload["response"] as? Message.JSON else {
                throw makeError("Couldn't read response from payload.")
        }
        
        if status == "ok" { return .Ok(response) }
        
        // only error statuses pass here
        if let reason = response["reason"] as? String {
            return .Error(makeError(reason, domain: "WebsocketServer"))
        }
        throw makeError("Couldn't read response from payload.")
    }
}

extension Response: CustomStringConvertible {
    public var description: String {
        switch self {
        case .Ok(let response): return "Response.Ok: \(response)"
        case .Error(let error): return "Response.Error: \(error)"
        }
    }
}

public struct Message {
    public typealias JSON = [String: AnyObject]
    
    public let topic: String
    
    public let event: String
    public let payload: [String: AnyObject]
    
    let ref: String
    
    func toJson() throws -> NSData {
        let dic = ["topic": topic, "event": event, "payload": payload, "ref": ref]
        return try NSJSONSerialization.dataWithJSONObject(dic, options: NSJSONWritingOptions())
    }
    
    init(_ event: String, topic: String, payload: JSON) {
        (self.topic, self.event, self.payload, self.ref) = (topic, event, payload, NSUUID().UUIDString)
    }
    
    init?(data: NSData) {
        let jsonObject = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions())
        guard let json = jsonObject as? JSON,
            topic = json["topic"] as? String, event = json["event"] as? String,
            payload = json["payload"] as? JSON, ref = json["ref"] as? String
            else { return nil }
        (self.topic, self.event, self.payload, self.ref) = (topic, event, payload, ref)
    }
}

extension Message: CustomStringConvertible {
    public var description: String {
        return "Message[topic: \(topic), event: \(event), ref: \(ref), payload: \(payload)]"
    }
}