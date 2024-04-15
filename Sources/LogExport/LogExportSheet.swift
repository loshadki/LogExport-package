import SwiftUI
import OSLog

public struct LogExportSheet: View {
    @Environment(\.dismiss) var dismiss
    
    @State var includeSystemLogs: Bool = false
    @State var interval: TimeInterval = .tenMinutes
    
    @State private var isProgress: Bool = false
    @State private var error: LogExportError? = nil
    
    @State private var presentLogFileDocumentExport = false
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
            
            #if os(iOS) || os(visionOS)
            Section {
                self.buttonExportToClipboard
                self.buttonExportToFile
            }
            #endif
        }
        .navigationTitle("Export logs")
        .interactiveDismissDisabled()
        .opacity(self.isProgress ? 0.6 : 1)
        .disabled(self.isProgress)
        .overlay {
            if self.isProgress {
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
            isPresented: self.$presentLogFileDocumentExport,
            document: self.logFileDocument,
            contentType: LogFileDocument.readableContentTypes.first!,
            defaultFilename: "\(ProcessInfo.processInfo.processName)-\(Date().timeIntervalSince1970).log"
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
            
            #if os(macOS)
            ToolbarItemGroup {
                self.buttonExportToClipboard
                self.buttonExportToFile
            }
            #endif
        }
#if os(macOS)
        .frame(height: 200)
        .formStyle(.grouped)
#endif
    }
    
    @ViewBuilder
    public var buttonExportToClipboard: some View {
        Button {
            Task.detached(priority: .userInitiated) {
                let (includeSystemLogs, since) = await self.onStartExport()
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
            Label("Copy to clipboard", systemImage: "arrow.up.doc.on.clipboard")
        }
        .disabled(self.isProgress)
    }
    
    @ViewBuilder
    public var buttonExportToFile: some View {
        Button {
            guard self.logFileDocument == nil else {
                self.presentLogFileDocumentExport.toggle()
                return
            }
            
            Task.detached(priority: .userInitiated) {
                let (includeSystemLogs, since) = await self.onStartExport()
                do {
                    let file = try await self.exportToFile(
                        since: since,
                        includeSystemLogs: includeSystemLogs
                    )
                    await MainActor.run {
                        self.logFileDocument = LogFileDocument(file: file)
                        self.presentLogFileDocumentExport.toggle()
                    }
                    await self.setInProgress(false)
                } catch {
                    await self.onStopExport(error: error)
                }
            }
        } label: {
            Label("Export to file...", systemImage: "arrow.up.doc")
        }
        .disabled(self.isProgress)
    }
    
    @MainActor
    private func onStartExport() -> (Bool, Date) {
        self.isProgress = true
        return (self.includeSystemLogs, Date().advanced(by: -self.interval))
    }
    
    @MainActor
    private func onStopExport(error: Error? = nil) {
        self.isProgress = false
        if let error {
            if let logExportError = error as? LogExportError {
                self.error = logExportError
            } else {
                if let localizedError = error as? LocalizedError {
                    self.error = LogExportError(localizedError.errorDescription ?? localizedError.localizedDescription)
                } else {
                    self.error = LogExportError(error.localizedDescription)
                }
            }
        } else {
            if let file = self.logFileDocument?.file {
                try? FileManager.default.removeItem(at: file)
            }
            self.dismiss()
        }
    }
    
    private func exportToPasteboard(since: Date? = nil, includeSystemLogs: Bool) async throws {
        try await Task.detached {
            let result = try await self.exportToFile(since: since, includeSystemLogs: includeSystemLogs)
            
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
        let url = URL.temporaryDirectory.appending(path: "\(ProcessInfo.processInfo.processName)-\(Date().timeIntervalSince1970).log", directoryHint: .notDirectory)
       
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
                    !includeSystemLogs,
                    let bundleIdentifier = Bundle.main.bundleIdentifier
                {
                    predicate = NSPredicate(format: "subsystem BEGINSWITH %@", bundleIdentifier)
                }
                    
                for entry in try logStore.getEntries(at: osLogPosition, matching: predicate) {
                    if let log = entry as? OSLogEntryLog {
                        if let data = "\(entry.date.ISO8601Format()) - [\(log.level.string)] - \(log.subsystem) - \(log.category) - \(log.composedMessage)\n".data(using: .utf8) {
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
    private func setInProgress(_ value: Bool) {
        self.isProgress = value
    }
    
    @MainActor
    private func setToPasteBoard(_ string: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(string, forType: .string)
        #elseif os(iOS) || os(visionOS)
        UIPasteboard.general.string = string
        #endif
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
