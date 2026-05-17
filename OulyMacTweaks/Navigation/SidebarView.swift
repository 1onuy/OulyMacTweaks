import SwiftUI

struct SidebarView: View {
    @Binding var selection: NavDestination?

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(NavDestination.allCases.filter { $0 != .settings }) { dest in
                    navRow(dest)
                }
            }
            Section {
                navRow(.settings)
                upgradeRow
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) { header }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.circle.fill")
                .font(.title2)
                .foregroundStyle(AppColors.brandBlue)
                .shadow(color: AppColors.brandBlue.opacity(0.5), radius: 6)
            Text("OulyMac Tweaks")
                .font(AppFonts.sectionHeader)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func navRow(_ dest: NavDestination) -> some View {
        Label(dest.rawValue, systemImage: dest.icon)
            .tag(dest)
    }

    private var upgradeRow: some View {
        Label("Upgrade to Pro", systemImage: "star.fill")
            .foregroundStyle(AppColors.brandPurple)
    }
}
