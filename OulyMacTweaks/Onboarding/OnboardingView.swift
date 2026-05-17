import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                welcomePage
                    .opacity(page == 0 ? 1 : 0)
                    .allowsHitTesting(page == 0)
                permissionsPage
                    .opacity(page == 1 ? 1 : 0)
                    .allowsHitTesting(page == 1)
                donePage
                    .opacity(page == 2 ? 1 : 0)
                    .allowsHitTesting(page == 2)
            }
            .animation(.easeInOut(duration: 0.35), value: page)
            .frame(width: 520, height: 380)

            pageIndicator
                .padding(.bottom, 24)
        }
        .frame(width: 520)
        .background(.regularMaterial)
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppColors.brandBlue)
                .shadow(color: AppColors.brandBlue.opacity(0.4), radius: 12)
            Text("OulyMac Tweaks")
                .font(.largeTitle.weight(.bold))
            Text("Your Mac. Faster. Smarter.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("Get Started") { withAnimation { page = 1 } }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.brandBlue)
                .controlSize(.large)
        }
        .padding(40)
    }

    private var permissionsPage: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 52))
                .foregroundStyle(AppColors.brandBlue)
            Text("One Permission")
                .font(.title2.weight(.bold))
            Text("OulyMac Tweaks needs **Full Disk Access** to analyze your storage. No data ever leaves your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Skip for now") { withAnimation { page = 2 } }
                    .buttonStyle(.bordered)
                Button("Open System Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                    )
                    withAnimation { page = 2 }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.brandBlue)
            }
        }
        .padding(40)
    }

    private var donePage: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppColors.success)
            Text("You're all set!")
                .font(.largeTitle.weight(.bold))
            Text("Your Mac is ready to be optimized.")
                .foregroundStyle(.secondary)
            Button("Open Dashboard") { isPresented = false }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.success)
                .controlSize(.large)
        }
        .padding(40)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i == page ? AppColors.brandBlue : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut, value: page)
            }
        }
    }
}
