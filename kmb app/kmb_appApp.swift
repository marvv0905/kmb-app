import SwiftUI

@main
struct kmb_appApp: App {

    init() {
        applyBrutalistTheme()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(BrutalTheme.accent)
                .preferredColorScheme(.light)
        }
    }

    private func applyBrutalistTheme() {
        let barColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = barColor
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.black,
            .font: UIFont.systemFont(ofSize: 17, weight: .black)
        ]
        navAppearance.shadowColor = .black
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        UITableView.appearance().backgroundColor = barColor
        UITableViewCell.appearance().backgroundColor = barColor
        UICollectionView.appearance().backgroundColor = barColor
        UITableView.appearance().separatorColor = .black
    }
}

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            TabContentView(selectedTab: selectedTab)
                .frame(maxHeight: .infinity)

            BrutalDivider()
            TabBar(selectedTab: $selectedTab)
        }
        .background(BrutalTheme.bg.ignoresSafeArea())
    }
}

struct TabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                label: "NEARBY",
                icon: selectedTab == 0 ? "location.fill" : "location",
                isSelected: selectedTab == 0
            ) { selectedTab = 0 }

            TabBarButton(
                label: "SEARCH",
                icon: "magnifyingglass",
                isSelected: selectedTab == 1
            ) { selectedTab = 1 }

            TabBarButton(
                label: "SETTINGS",
                icon: "gearshape",
                isSelected: selectedTab == 2
            ) { selectedTab = 2 }
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(BrutalTheme.bg)
    }
}

struct TabContentView: View {
    let selectedTab: Int

    var body: some View {
        Group {
            switch selectedTab {
            case 0: HomeView()
            case 1: SearchView()
            case 2: SettingsView()
            default: HomeView()
            }
        }
    }
}

struct TabBarButton: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .black))

                Text(label)
                    .font(.brutalTab)
            }
            .foregroundStyle(isSelected ? BrutalTheme.accent : BrutalTheme.text)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
