import SwiftUI

public struct LogExportButton: View {
    @State private var exportLogs = false
    @State private var exportLogFileDocument: LogFileDocument? = nil
    
    public var label: Label = Label("Export logs...", systemImage: "square.and.arrow.up")
    
    public var body: some View {
        Button {
            if !self.exportLogs {
                self.exportLogs.toggle()
            }
        } label: {
            self.label
        }
        .sheet(
            isPresented: self.$exportLogs,
            onDismiss: {
                self.exportLogs = false
            }
        ) {
            LogExportSheet()
        }
    }
    
    
}

struct ExportLogsButtonView_Previews: PreviewProvider {
    static var previews: some View {
        LogExportButton()
            .frame(width: 320, height: 240)
    }
}
