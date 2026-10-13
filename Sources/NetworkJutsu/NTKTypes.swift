//
//  NTKModels.swift
//

import Foundation
import Alamofire


public enum NTKEncoding: Equatable, Sendable {
  case url, json, queryString, httpBody

  public var parameterEncoding: ParameterEncoding {
    switch self {
    case .url: return URLEncoding.default
    case .json: return JSONEncoding.default
    case .queryString: return URLEncoding.queryString
    case .httpBody: return URLEncoding.httpBody
    }
  }
}


public enum NTKRequestMethod: Equatable, Sendable {
  case get, post, put, delete

  public var httpMethod: HTTPMethod {
    switch self {
    case .get: return HTTPMethod.get
    case .post: return HTTPMethod.post
    case .put: return HTTPMethod.put
    case .delete: return HTTPMethod.delete
    }
  }
}