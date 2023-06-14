import Foundation
import OSLog

extension OSLogEntryLog.Level {
    var string: String {
        switch self {
        case .notice:
            return "notice"
        case .debug:
            return "debug"
        case .info:
            return "info"
        case .error:
            return "error"
        case .fault:
            return "fault"
        case .undefined:
            return "undefined"
        default:
            return "unknown"
        }
    }
}
