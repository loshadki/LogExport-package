import Foundation
import SwiftUI
import UniformTypeIdentifiers

internal final class LogFileDocument: FileDocument {
    static var readableContentTypes: [UTType] = [UTType.log]

    public let file: URL
    
    init(file: URL) {
        self.file = file
    }
    
    required init(configuration: ReadConfiguration) throws {
        fatalError()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return try FileWrapper(url: self.file)
    }
}
