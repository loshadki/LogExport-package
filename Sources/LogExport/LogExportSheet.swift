import SwiftUI
import OSLog

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

public struct LogExportSheet: View {
    @Environment(\.dismiss) var dismiss
    
    @State var includeSystemLogs: Bool = false
    @State var interval: TimeInterval = .tenMinutes
    
    @State private var exporting: Bool = false
    @State private var error: LogExportError? = nil
    
    @State private var logFileDocument: LogFileDocument? = nil
    
    private let intervals: [TimeInterval] = [.day, .hour, .tenMinutes]
    private let timeIntervalFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .spellOut
        formatter.allowedUnits = [.minute, .hour, .day]
        return formatter
    }()
    
    public var body: some View {
        Form {
            Section {
                Picker(selection: self.$interval) {
                    ForEach(self.intervals) { interval in
                        Text(timeIntervalFormatter.string(from: interval) ?? "Unknown")
                            .tag(interval)
                    }
                } label: {
                    Text("Last")
                }

                Toggle("Include system logs", isOn: self.$includeSystemLogs)
            } header: {
                Text("Filter")
            }
        }
        .interactiveDismissDisabled()
        .opacity(self.exporting ? 0.6 : 1)
        .disabled(self.exporting)
        .overlay {
            if self.exporting {
                ProgressView()
            }
        }
        .alert(
            isPresented: Binding<Bool>(
                get: {
                    self.error != nil
                }, set: { value in
                    if !value {
                        self.error = nil
                    }
                }
            ),
            error: self.error,
            actions: {}
        )
        .fileExporter(
            isPresented: Binding<Bool>(
                get: {
                    self.logFileDocument != nil
                }, set: { value in
                    if !value {
                        self.logFileDocument = nil
                    }
                }
            ),
            document: self.logFileDocument,
            contentType: LogFileDocument.readableContentTypes.first!,
            defaultFilename: "\(ProcessInfo.processInfo.processName)-\(Date().ISO8601Format()).log"
        ) { result in
            switch result {
            case .failure(let error):
                self.onStopExport(error: error)
            case .success:
                self.onStopExport()
            }
            self.logFileDocument = nil
        }
        .toolbar {
            ToolbarItemGroup(placement: .cancellationAction) {
                Button {
                    self.dismiss()
                } label: {
                    Text("Cancel")
                }
            }
            
            ToolbarItemGroup(placement: .confirmationAction) {
                Button {
                    let (includeSystemLogs, since) = self.onStartExport()
                    Task.detached(priority: .userInitiated) {
                        do {
                            try await self.exportToPasteboard(
                                since: since,
                                includeSystemLogs: includeSystemLogs
                            )
                            await self.onStopExport()
                        } catch {
                            await self.onStopExport(error: error)
                        }
                    }
                } label: {
                    Text("Copy to clipboard")
                }
            }
            
            ToolbarItemGroup(placement: .confirmationAction) {
                Button {
                    let (includeSystemLogs, since) = self.onStartExport()
                    Task.detached(priority: .userInitiated) {
                        do {
                            let file = try await self.exportToFile(
                                since: since,
                                includeSystemLogs: includeSystemLogs
                            )
                            self.logFileDocument = LogFileDocument(file: file)
                        } catch {
                            await self.onStopExport(error: error)
                        }
                    }
                } label: {
                    Text("Export to file")
                }
            }
        }
        .padding()
    }
    
    @MainActor
    private func onStartExport() -> (Bool, Date) {
        self.exporting = true
        return (self.includeSystemLogs, Date().advanced(by: -self.interval))
    }
    
    @MainActor
    private func onStopExport(error: Error? = nil) {
        if let error {
            if let logExportError = error as? LogExportError {
                self.error = logExportError
            } else {
                self.error = LogExportError(error.localizedDescription)
            }
        }
        self.exporting = false
    }
    
    private func exportToPasteboard(since: Date? = nil, includeSystemLogs: Bool) async throws {
        try await Task.detached {
            let result = try await self.exportToFile(since: since, includeSystemLogs: false)
            
            defer {
                try? FileManager.default.removeItem(at: result)
            }
            
            if let data = FileManager.default.contents(atPath: result.path(percentEncoded: false)) {
                if let str = String(data: data, encoding: .utf8) {
                    await self.setToPasteBoard(str)
                    return
                }
            }
            
            throw LogExportError("cannot access logs")
        }.value
    }
    
    private func exportToFile(since: Date?, includeSystemLogs: Bool) async throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(ProcessInfo.processInfo.processName)-\(UUID().uuidString).log", directoryHint: .notDirectory)
       
        try await Task.detached {
            if FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: nil) {
                let fileHandle = try FileHandle(forWritingTo: url)
                let logStore = try OSLogStore(scope: .currentProcessIdentifier)
                
                var osLogPosition: OSLogPosition? = nil
                if let since {
                    osLogPosition = logStore.position(date: since)
                }
                
                var predicate: NSPredicate? = nil
                if
                    includeSystemLogs,
                    let bundleIdentifier = Bundle.main.bundleIdentifier
                {
                    predicate = NSPredicate(format: "subsytem BEGINSWITH %@", bundleIdentifier)
                }
                    
                for entry in try logStore.getEntries(at: osLogPosition, matching: predicate) {
                    if let log = entry as? OSLogEntryLog {
                        if let data = "\(entry.date.ISO8601Format(.iso8601)) - [\(log.level.string)] - \(log.subsystem) - \(log.category) - \(log.composedMessage)\n".data(using: .utf8) {
                            fileHandle.write(data)
                        }
                    }
                }
                
                try fileHandle.close()
            } else {
                throw LogExportError("failed to create a temporary file at \(url.path(percentEncoded: false))")
            }
        }.value
        
        return url
    }
    
    @MainActor
    private func setToPasteBoard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(string, forType: .string)
    }
}

struct LogExportSheet_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LogExportSheet()
        }
        .frame(width: 640, height: 480)
    }
}
