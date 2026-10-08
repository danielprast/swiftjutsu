import OSLog


public func dlog(
  _ key: String,
  _ value: Any,
  type: DLogType = .info,
  subsystem: String = "module",
  file: String = #fileID,
  function: String = #function,
  line: Int = #line
) {
  if #available(iOS 17.0, tvOS 17.0, *) {
    dshout(
      "\(type.emojiIcon) \(key)",
      value,
      type: type,
      subsystem: subsystem,
      file: file,
      function: function,
      line: line
    )
    return
  }
  shout("\n\(type.emojiIcon) \(key)", "\(value)\n-- ⌘")
}


public func dlogTest(
  _ key: String,
  _ value: Any,
  domain: String = "",
  type: DLogType = .info
) {
  let domainLabel = domain.isEmpty ? "" : "\(domain) ≈ "
  shout("\(domainLabel)\(type.emojiIcon) \(key)", value)
}


internal func dshout(
  _ key: String,
  _ value: Any,
  type: DLogType = .info,
  subsystem: String = "module",
  file: String = #fileID,
  function: String = #function,
  line: Int = #line
) {
  let category = "\(function) :: line \(line) :: at \(file)"
  
  switch type {
  case .error:
    Logger(
      subsystem: subsystem,
      category: category
    ).critical("\(key) : \(String(describing: value))")
  
  case .warning:
    Logger(
      subsystem: subsystem,
      category: category
    ).warning("\(key) : \(String(describing: value))")
  
  case .info:
    Logger(
      subsystem: subsystem,
      category: category
    ).info("\(key) : \(String(describing: value))")
  
  }
}


internal func shout(_ key: String, _ value: Any) {
  print("\(key): \(value)")
}


public enum DLogType {
  case error
  case warning
  case info
  
  var emojiIcon: String {
    switch self {
    case .error:
      "📛"
    case .warning:
      "⚠️"
    case .info:
      "😎"
    }
  }
  
}
