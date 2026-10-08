//
//  DIContainer.swift
//

import Foundation


public typealias ServiceFactory = (DIC) -> AnyObject


public protocol DICProtocol {
  func register<Service>(
    type: Service.Type,
    factoryClosure: @escaping ServiceFactory
  )
  func resolve<Service>(type: Service.Type) async -> Service?
  var isEmptyContainer: Bool { get async }
}


@MainActor public class DIC: @preconcurrency DICProtocol {

  var services = Dictionary<String, ServiceFactory>()

  public static let shared: DICProtocol = DIC()

  private init() {}

  public var isEmptyContainer: Bool {
    services.isEmpty
  }

  public func register<Service>(
    type: Service.Type,
    factoryClosure: @escaping ServiceFactory
  ) {
    services["\(type)"] = factoryClosure
  }

  public func resolve<Service>(type: Service.Type) -> Service? {
    return services["\(type)"]?(self) as? Service
  }

}