import Foundation

extension TimeInterval: Identifiable {
    public var id: Int {
        return Int(self)
    }
    
    internal static var day: TimeInterval {
        return TimeInterval(24*60*60)
    }
    
    internal static var hour: TimeInterval {
        return TimeInterval(60*60)
    }
    
    internal static var tenMinutes: TimeInterval {
        return TimeInterval(10*60)
    }
}
