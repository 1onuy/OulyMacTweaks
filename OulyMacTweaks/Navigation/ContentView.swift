import SwiftUI

struct ContentView: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var selection: NavDestination? = .dashboard
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .frame(minWidth: 200, maxWidth: 200)
        } detail: {
            ZStack {
                SnowBackgroundView()
                detailView(for: selection)
            }
        }
        .onAppear {
            if !hasOnboarded { showOnboarding = true }
            monitor.startPolling()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .onDisappear { hasOnboarded = true }
        }
    }

    @ViewBuilder
    private func detailView(for dest: NavDestination?) -> some View {
        switch dest {
        case .dashboard, .none:    DashboardView()
        case .optimize:            OptimizeStubView()
        case .gaming:              GamingStubView()
        case .softwareManager:     SoftwareManagerStubView()
        case .aiAdvisor:           AIAdvisorStubView()
        case .settings:            SettingsStubView()
        }
    }
}
