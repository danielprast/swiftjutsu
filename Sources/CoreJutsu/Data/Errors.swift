//
//  Errors.swift
//

import Foundation


public enum JutsuError: LocalizedError, Equatable, Hashable {
  
  case custom(String)
  case errorDataBody(Data)
  case parsingError
  case invalidResponse
  case connectionProblem
  case timeoutRequest
  case unauthorized
  case internalServerError
  
  public static func ==(lhs: JutsuError, rhs: JutsuError) -> Bool {
    switch (lhs, rhs) {
    case (custom(let lhsMessage), custom(let rhsMessage)):
      lhsMessage == rhsMessage
      
    case (errorDataBody(let lhsData), errorDataBody(let rhsData)):
      String(data: lhsData, encoding: .utf8) == String(data: rhsData, encoding: .utf8)
      
    case (parsingError, parsingError):
      true
    
    case (invalidResponse, invalidResponse):
      true
    
    case (connectionProblem, connectionProblem):
      true
    
    case (timeoutRequest, timeoutRequest):
      true
      
    case (unauthorized, unauthorized):
      true
      
    case (internalServerError, internalServerError):
      true
     
    default:
      false
    }
  }
  
}