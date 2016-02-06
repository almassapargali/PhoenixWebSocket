//
//  Response.swift
//  PhoenixWebSocket
//
//  Created by Almas Sapargali on 2/6/16.
//  Copyright © 2016 Almas Sapargali. All rights reserved.
//

import Foundation

public enum ResponseError: ErrorType {
    /// `status` or `response` key is missing.
    case InvalidFormat
    
    /// Missing `reason` key on error response.
    case MissingReason
}

extension ResponseError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .InvalidFormat: return "Invalid response format."
        case .MissingReason: return "Error response is missing reason."
        }
    }
}

public enum Response {
    case Ok(Message.JSON)
    /// Error responses assumed to have `reason` key with `String` value
    ///
    /// Tuple containing of `reason` value and `response` dic
    case Error(String, Message.JSON)
    
    public static func fromPayload(payload: Message.JSON) throws -> Response {
        guard let status = payload["status"] as? String where ["ok", "error"].contains(status),
            let response = payload["response"] as? Message.JSON else {
                throw ResponseError.InvalidFormat
        }
        
        if status == "ok" { return .Ok(response) }
        
        // only error statuses pass here
        if let reason = response["reason"] as? String {
            return .Error(reason, response)
        } else {
            throw ResponseError.MissingReason
        }
    }
}

extension Response: CustomStringConvertible {
    public var description: String {
        switch self {
        case .Ok(let response): return "Response.Ok: \(response)"
        case .Error(_, let response): return "Response.Error: \(response)"
        }
    }
}