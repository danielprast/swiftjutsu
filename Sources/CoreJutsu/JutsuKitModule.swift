//
// JutsuKit Module
//

public internal(set) var jutsuLogEnabled = true

nonisolated public func toggleJutsuLog(enabled: Bool) {
  jutsuLogEnabled = enabled
}