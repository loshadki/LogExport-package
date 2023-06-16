import SwiftUI
import OSLog
import LogExport

struct ContentView: View {
    static var log: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: ContentView.self))
    
    var body: some View {
        VStack {
            Button {
                Self.log.info("button is pressed")
            } label: {
                Text("Press Me")
            }
            
            LogExportButton()
        }
        .onAppear {
            Self.log.info("view appear")
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 640, height: 480)
    }
}
