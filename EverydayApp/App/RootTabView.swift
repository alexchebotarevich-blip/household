import SwiftUI

private extension AppTab {
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

struct RootTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
                .tag(AppTab.home)

            TasksView()
                .tabItem { Label(AppTab.tasks.title, systemImage: AppTab.tasks.systemImage) }
                .tag(AppTab.tasks)

            ShoppingView()
                .tabItem { Label(AppTab.shopping.title, systemImage: AppTab.shopping.systemImage) }
                .tag(AppTab.shopping)

            ProfileView()
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage) }
                .tag(AppTab.profile)
        }
        .tint(Color.accentColor)
    }
}

#Preview {
    RootTabView()
        .environment(\.appTheme, AppTheme.default)
        .environmentObject(AppRouter())
        .environmentObject(AppEnvironment())
        .environmentObject(FamilyRoleStore())
}
