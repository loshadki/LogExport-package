import SwiftUI

public struct LogExportButton: View {
    @State private var exportLogs = false
    @State private var exportLogFileDocument: LogFileDocument? = nil
    
    public init() {
        self.label = Label("Export logs...", systemImage: "square.and.arrow.up")
    }
    
    public init(
        label: Label<Text, Image>
    ) {
        self.label = label
    }
    
    public var label: Label<Text, Image>
    
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
            NavigationStack {
                LogExportSheet()
            }
        }
    }
}

struct ExportLogsButtonView_Previews: PreviewProvider {
    static var previews: some View {
        LogExportButton()
            .frame(width: 320, height: 240)
    }
}
