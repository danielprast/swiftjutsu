//
//  NetworkConnectionChecker.swift
//

import Foundation
import Network
import SystemConfiguration
import CoreJutsu


public actor NetworkConnectionChecker {

  // MARK: - Configuration

  private enum Config {
    /// Maximum age of a cached result before a fresh probe is required.
    static let cacheTTL: TimeInterval = 3.0
    /// Timeout for each individual HTTP probe request.
    static let probeTimeout: TimeInterval = 5.0
    /// Probe URLs tried in parallel; the first success wins.
    static let probeURLs: [URL] = [
      URL(string: "http://captive.apple.com/hotspot-detect.html")!,
      URL(string: "https://dns.google")!
    ]
  }

  // MARK: - State

  private let pathMonitor = NWPathMonitor()
  private let monitorQueue = DispatchQueue(label: "jutsu.NetworkConnectionChecker.monitor", qos: .utility)
  
  private var isMonitoringStarted = false
  private var cachedResult: Bool = false
  private var lastCheckedAt: Date = .distantPast

  // MARK: - Init / Deinit

  public init() {
    Task { await startPathMonitor() }
  }

  deinit {
    pathMonitor.cancel()
    print("💥 \(Self.self) • destroyed")
  }

  // MARK: - NetworkConnectionChecker

  public var isConnected: Bool {
    get async { await resolve() }
  }

  // MARK: - Private — Core

  /// Returns a fresh or cached connectivity result.
  private func resolve() async -> Bool {
    // 1. Fast-fail: if NWPathMonitor says the path is unsatisfied there is no
    //    point in doing any further work.
    let path = pathMonitor.currentPath
    guard path.status == .satisfied else {
      clog("", "œ path unsatisfied → offline")
      updateCache(false)
      return false
    }

    // 2. Return cached result if it is still fresh.
    if isCacheValid {
      clog("", "œ returning cached result → \(cachedResult)")
      return cachedResult
    }

    // 3. Full reachability check.
    let result = await performFullCheck()
    updateCache(result)
    return result
  }

  /// Runs SCNetworkReachability flags check followed by an HTTP probe.
  private func performFullCheck() async -> Bool {
    // SCNetworkReachability – cheap kernel check.
    guard checkSystemConfigurator() else {
      clog("", "œ SCNetworkReachability → offline")
      return false
    }

    // HTTP probe – the only true end-to-end verification.
    let reachable = await probeEndpoints()
    clog("", "œ HTTP probe → \(reachable ? "online" : "offline")")
    return reachable
  }

  // MARK: - Private — SCNetworkReachability

  private func checkSystemConfigurator() -> Bool {
    var zeroAddress = sockaddr_in()
    zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    zeroAddress.sin_family = sa_family_t(AF_INET)

    guard let reachability = withUnsafePointer(to: &zeroAddress, {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        SCNetworkReachabilityCreateWithAddress(nil, $0)
      }
    }) else {
      return false
    }

    var flags: SCNetworkReachabilityFlags = []
    guard SCNetworkReachabilityGetFlags(reachability, &flags) else {
      return false
    }

    let isReachable = flags.contains(.reachable)
    let needsConnection = flags.contains(.connectionRequired)
    let canConnect = flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic)
    let isInterventionRequired = flags.contains(.interventionRequired)

    // Reachable without needing a connection → definitely online.
    if isReachable && !needsConnection { return true }

    // Reachable with an automatic (non-interactive) connection → probably online.
    if isReachable && canConnect && !isInterventionRequired { return true }

    return false
  }

  // MARK: - Private — HTTP Probe

  /// Fires probes to all configured URLs concurrently and returns `true` as
  /// soon as any one of them succeeds. Returns `false` only when every probe
  /// fails or times out.
  private func probeEndpoints() async -> Bool {
    await withTaskGroup(of: Bool.self) { group in
      for url in Config.probeURLs {
        group.addTask { await self.probe(url: url) }
      }

      for await result in group {
        if result {
          group.cancelAll()
          return true
        }
      }
      return false
    }
  }

  /// Performs a lightweight HEAD/GET to `url`, treating any HTTP response
  /// (regardless of status code) as evidence of internet connectivity.
  private func probe(url: URL) async -> Bool {
    let config = URLSessionConfiguration.ephemeral
    config.urlCache = nil
    config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    config.timeoutIntervalForRequest = Config.probeTimeout
    config.timeoutIntervalForResource = Config.probeTimeout

    var request = URLRequest(url: url, timeoutInterval: Config.probeTimeout)
    request.httpMethod = "HEAD"
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")

    do {
      let (_, response) = try await URLSession(configuration: config).data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
      let success = statusCode > 0
      clog("", "œ probe [\(url.host ?? url.absoluteString)] → \(statusCode)")
      return success
    } catch {
      clog("", "œ probe [\(url.host ?? url.absoluteString)] failed → \(error.localizedDescription)", type: .warning)
      return false
    }
  }

  // MARK: - Private — Cache

  private var isCacheValid: Bool {
    Date().timeIntervalSince(lastCheckedAt) < Config.cacheTTL
  }

  private func updateCache(_ result: Bool) {
    cachedResult = result
    lastCheckedAt = Date()
  }

  // MARK: - Private — NWPathMonitor

  private func startPathMonitor() async {
    guard !isMonitoringStarted else { return }
    isMonitoringStarted = true

    pathMonitor.pathUpdateHandler = { [weak self] path in
      guard let self else { return }
      Task {
        // Invalidate cache on every path change so the next `isConnected`
        // call performs a fresh check rather than returning stale data.
        await self.invalidateCache()
        self.clog("", "œ path updated → \(path.status)")
      }
    }
    pathMonitor.start(queue: monitorQueue)
    clog("🚀 NWPathMonitor started", "")
  }

  private func invalidateCache() {
    lastCheckedAt = .distantPast
  }
  
  // MARK: - •
  
  nonisolated public func clog(
    _ key: String,
    _ value: Any,
    type: DLogType = .info,
    subsystem: String = "module",
    file: String = #fileID,
    function: String = #function,
    line: Int = #line
  ) {
    guard jutsuLogEnabled else { return }
    dlog(
      "\(Self.self) ≈ \(key)",
      value,
      type: type,
      subsystem: subsystem,
      file: file,
      function: function,
      line: line
    )
  }
  
}
