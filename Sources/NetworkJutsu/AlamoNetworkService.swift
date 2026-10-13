//
//  AlamoNetworkService.swift
//

import Foundation
import CoreJutsu
import Alamofire


public actor AlamoNetworkService {

  private let session: Session

  public init(urlSessionConfiguration: URLSessionConfiguration = .default) {
    self.session = Session(configuration: urlSessionConfiguration)
  }
  
  private let defaultErrorMessage = "Something went wrong."

  public func performRequest<T>(
    decodable: T.Type,
    url: URL,
    method: NTKRequestMethod,
    headers: [String : String]? = nil,
    parameters: [String : Any & Sendable]? = nil,
    encoding: NTKEncoding
  ) async throws -> T where T: Decodable {
    do {
      let responseData = try await performRequestData(
        url: url,
        method: method,
        headers: headers,
        parameters: parameters,
        encoding: encoding
      )

      guard let responseModel = try? JSONDecoder().decode(
        T.self,
        from: responseData
      ) else {
        throw JutsuError.parsingError
      }

      return responseModel
    } catch {
      throw (error as! JutsuError)
    }
  }

  public func performRequestData(
    url: URL,
    method: NTKRequestMethod,
    headers: [String : String]? = nil,
    parameters: [String : Any & Sendable]? = nil,
    encoding: NTKEncoding,
    timeout second: TimeInterval = 10,
    responseValidation: ((Data?, HTTPURLResponse) throws -> Data)? = nil
  ) async throws -> Data {
    let httpHeaders = HTTPHeaders.init(headers ?? [:])

    let response = await session.request(
      url,
      method: method.httpMethod,
      parameters: parameters,
      encoding: encoding.parameterEncoding,
      headers: httpHeaders.isEmpty ? nil : httpHeaders,
      requestModifier: { $0.timeoutInterval = second }
    ).serializingData().response

    inspectResponse(response)

    if let sessionError = response.error {
      guard
        let urlError = sessionError.underlyingError as? URLError,
        urlError.code == .timedOut
      else {
        clog("≈• went wrong", "\(sessionError)")
        if sessionError.isResponseSerializationError {
          throw JutsuError.parsingError
        }
        throw JutsuError.invalidResponse
      }
      throw JutsuError.timeoutRequest
    }

    guard let httpResponse = response.response
    else {
      clog("≈•• went wrong", "!!!")
      throw JutsuError.invalidResponse
    }
    
    guard let responseValidation else {
      return try validateNetworkResponse(
        data: response.data,
        httpResponse: httpResponse
      )
    }
    
    return try responseValidation(response.data, httpResponse)
  }

  private func validateNetworkResponse(
    data: Data?,
    httpResponse: HTTPURLResponse
  ) throws -> Data {
    switch httpResponse.statusCode {
    
    case 200...299:
      guard let data else {
        clog("2xx", "went wrong")
        throw JutsuError.invalidResponse
      }
      return data
    
    case 400:
      guard let data else { throw JutsuError.custom(defaultErrorMessage) }
      let message = parseErrorResponse(data: data) ?? defaultErrorMessage
      clog("400 error", message)
      throw JutsuError.custom(message)
    
    case 401:
      throw JutsuError.unauthorized
    
    case 403:
      guard let data else { throw JutsuError.custom("Forbidden") }
      clog("403 error data", String.init(data: data, encoding: .utf8) as Any)
      throw JutsuError.errorDataBody(data)
    
    case 404:
      guard let data else { throw JutsuError.custom("Not found") }
      let message = parseErrorResponse(data: data) ?? "Not found"
      clog("404 error", message)
      throw JutsuError.custom(message)
    
    case 422:
      guard let data else { throw JutsuError.custom(defaultErrorMessage) }
      let message = parseErrorResponse(data: data) ?? defaultErrorMessage
      clog("422 error", message)
      throw JutsuError.custom(message)
    
    case 500...599:
      throw JutsuError.internalServerError
    
    default:
      throw JutsuError.invalidResponse
    }
  }

  public func parseErrorResponse(data: Data) -> String? {
    let jsonObject = JsonResolver.parseDataToJson(data)

    if jsonObject.isEmpty {
      return nil
    }

    guard let messagesData = jsonObject["message"] as? String else {
      return parseErrorsResponse(data: data)
    }

    return messagesData
  }

  public func parseErrorsResponse(data: Data) -> String? {
    let jsonObject = JsonResolver.parseDataToJson(data)

    if jsonObject.isEmpty {
      return nil
    }

    guard
      let errorObject = jsonObject["error"] as? [String:Any],
      let messages = errorObject["message"] as? [String] else {
      return nil
    }

    if messages.count > 1 {
      return messages.joined(separator: "\n")
    }

    return messages.first
  }

}


public func inspectResponse(_ afResponse: AFDataResponse<Data>) {
  clog("• Network request", "--- •")
  if networkJutsuLogEnabled {
    debugPrint(afResponse)
  }
  clog("• End network Request Response", "----------------------------------------\n")
}


nonisolated public func debugRequest(
  request: URLRequest?,
  response: HTTPURLResponse?,
  data: Data?
) -> String {
  var str = "\n"
  str += "• URL: \(String(describing: request?.url?.absoluteString.removingPercentEncoding)) \n"
  str += "• StatusCode: \(String(describing: response?.statusCode)) \n"
  str += "• Headers: \(String(describing: request?.allHTTPHeaderFields)) \n"

  if let body = request?.httpBody {
    if let bodyString = "\(String(decoding: body, as: UTF8.self))".removingPercentEncoding {
      str += "• Parameters: \(bodyString) \n"
    } else {
      str += "• Parameters: \(String(decoding: body, as: UTF8.self)) \n"
    }
  }

  if let mData = data,
     let jsonStr = String(data: mData, encoding: .utf8) {
    str += "• Response: \(jsonStr.replacingOccurrences(of: "\\", with: "")) \n"
  }
  
  return str
}


public internal(set) var networkJutsuLogEnabled = true


nonisolated public func toggleNetworkJutsuLog(enabled: Bool) {
  networkJutsuLogEnabled = enabled
}


nonisolated fileprivate func clog(
  _ key: String,
  _ value: Any,
  type: DLogType = .info,
  subsystem: String = "module",
  file: String = #fileID,
  function: String = #function,
  line: Int = #line
) {
  guard networkJutsuLogEnabled else { return }
  dlog(
    "NetworkJutsu ≈ \(key)",
    value,
    type: type,
    subsystem: subsystem,
    file: file,
    function: function,
    line: line
  )
}
