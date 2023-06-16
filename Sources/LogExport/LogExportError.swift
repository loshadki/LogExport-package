import Foundation

public final class LogExportError: LocalizedError {
    let errorStr: String
    
    init(_ errorStr: String) {
        self.errorStr = errorStr
    }
    
    var localizedDescription: String {
        return self.errorStr
    }
    
    public var errorDescription: String? {
        return self.errorStr
    }
}
