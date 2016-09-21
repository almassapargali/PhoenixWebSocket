//
//  Response.swift
//  PhoenixWebSocket
//
//  Created by Almas Sapargali on 2/6/16.
//  Copyright © 2016 Almas Sapargali. All rights reserved.
//

import Foundation

public enum ResponseError: Error {
    /// `status` or `response` key is missing.
    case invalidFormat
    
    /// Missing `reason` key on error response.
    case missingReason
}

extension ResponseError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidFormat: return "Invalid response format."
        case .missingReason: return "Error response is missing reason."
        }
    }
}

public enum Response {
    case ok(Message.JSON)
    /// Error responses assumed to have `reason` key with `String` value
    ///
    /// Tuple containing of `reason` value and `response` dic
    case error(String, Message.JSON)
    
    public static func fromPayload(_ payload: Message.JSON) throws -> Response {
        guard let status = payload["status"] as? String, ["ok", "error"].contains(status),
            let response = payload["response"] as? Message.JSON else {
                throw ResponseError.invalidFormat
        }
        
        if status == "ok" { return .ok(response) }
        
        // only error statuses pass here
        if let reason = response["reason"] as? String {
            return .error(reason, response)
        } else {
            throw ResponseError.missingReason
        }
    }
}

extension Response: CustomStringConvertible {
    public var description: String {
        switch self {
        case .ok(let response): return "Response.Ok: \(response)"
        case .error(_, let response): return "Response.Error: \(response)"
        }
    }
}
