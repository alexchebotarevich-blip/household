import SwiftUI

struct RootTabView: View {
    private enum Tab: Hashable {
        case home
        case tasks
        case shopping
        case profile

        var title: String {
            switch self {
            case .home: return "Home"
            case .tasks: return "Tasks"
            case .shopping: return "Shopping"
            case .profile: return "Profile"
            }
        }

        var systemImage: String {
            switch self {
            case .home: return "house.fill"
            case .tasks: return "checkmark.circle"
            case .shopping: return "cart.fill"
            case .profile: return "person.crop.circle"
            }
        }
    }

    @State private var selectedTab: Tab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label(Tab.home.title, systemImage: Tab.home.systemImage) }
                .tag(Tab.home)

            TasksView()
                .tabItem { Label(Tab.tasks.title, systemImage: Tab.tasks.systemImage) }
                .tag(Tab.tasks)

            ShoppingView()
                .tabItem { Label(Tab.shopping.title, systemImage: Tab.shopping.systemImage) }
                .tag(Tab.shopping)

            ProfileView()
                .tabItem { Label(Tab.profile.title, systemImage: Tab.profile.systemImage) }
                .tag(Tab.profile)
        }
        .tint(Color.accentColor)
    }
}

#Preview {
    RootTabView()
        .environment(\.appTheme, AppTheme.default)
        .environmentObject(AppEnvironment())
}
