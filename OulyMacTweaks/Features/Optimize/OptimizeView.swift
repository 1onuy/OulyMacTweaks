import SwiftUI

struct OptimizeView: View {
    @Environment(OptimizationEngine.self) private var engine

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                content
            }
            .padding(24)
        }
        .animation(.easeOut(duration: 0.18), value: stateTag)
    }

    // MARK: - State routing

    @ViewBuilder
    private var content: some View {
        switch engine.state {
        case .idle:
            idleView
        case .scanning:
            scanningView
        case let .results(ram, cache):
            resultsView(ram: ram, cache: cache)
        case let .optimizing(ram, cache):
            optimizingView(ram: ram, cache: cache)
        case let .done(ramFreed, cacheFreed):
            doneView(ramFreed: ramFreed, cacheFreed: cacheFreed)
        }
    }

    private var stateTag: String {
        switch engine.state {
        case .idle:       return "idle"
        case .scanning:   return "scanning"
        case .results:    return "results"
        case .optimizing: return "optimizing"
        case .done:       return "done"
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 48)
            Image(systemName: "bolt.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(AppColors.brandBlue)
            Text("Optimize Your Mac")
                .font(.title2.weight(.bold))
            Text("Scan to see how much memory and\ndisk space can be recovered.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 8)
            OptimizeButton(style: .scan, label: "Scan Now") {
                engine.scan()
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 80)
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
                .tint(AppColors.brandBlue)
            Text("Scanning…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Results

    private func resultsView(ram: UInt64, cache: UInt64) -> some View {
        VStack(spacing: 12) {
            ScanResultCard(icon: "memorychip",
                           title: "RAM Pressure",
                           status: .pending(bytes: ram))
                .transition(.move(edge: .bottom).combined(with: .opacity))

            ScanResultCard(icon: "trash.fill",
                           title: "User Caches",
                           status: .pending(bytes: cache))
                .transition(.move(edge: .bottom).combined(with: .opacity))

            ScanResultCard(icon: "lock.fill",
                           title: "Startup Items",
                           status: .locked(message: "Available after signing"))
                .transition(.move(edge: .bottom).combined(with: .opacity))

            Spacer().frame(height: 8)

            OptimizeButton(style: .optimize, label: "Optimize Now") {
                engine.optimize()
            }
        }
    }

    // MARK: - Optimizing

    private func optimizingView(ram: UInt64, cache: UInt64) -> some View {
        VStack(spacing: 12) {
            ScanResultCard(icon: "memorychip",
                           title: "RAM Pressure",
                           status: .active)

            ScanResultCard(icon: "trash.fill",
                           title: "User Caches",
                           status: .active)

            ScanResultCard(icon: "lock.fill",
                           title: "Startup Items",
                           status: .locked(message: "Available after signing"))

            Spacer().frame(height: 8)

            OptimizeButton(style: .running, label: "Optimizing…") { }
        }
    }

    // MARK: - Done

    private func doneView(ramFreed: UInt64, cacheFreed: UInt64) -> some View {
        VStack(spacing: 12) {
            ScanResultCard(icon: "checkmark.circle.fill",
                           title: "RAM Pressure",
                           status: .done(freed: ramFreed))

            ScanResultCard(icon: "checkmark.circle.fill",
                           title: "User Caches",
                           status: .done(freed: cacheFreed))

            ScanResultCard(icon: "lock.fill",
                           title: "Startup Items",
                           status: .locked(message: "Available after signing"))

            VStack(spacing: 4) {
                Text(formatBytes(ramFreed + cacheFreed) + " freed")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppColors.brandBlue)
                Text("Your Mac is running better.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            OptimizeButton(style: .scanAgain, label: "Scan Again") {
                engine.reset()
            }
        }
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 0.1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.0f MB", mb) }
        return "< 1 MB"
    }
}
