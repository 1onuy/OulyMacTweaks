import SwiftUI

@main
struct OulyMacTweaksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var monitor = SystemMonitor()
    @State private var engine  = OptimizationEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(monitor)
                .environment(engine)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    appDelegate.connect(monitor: monitor)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
