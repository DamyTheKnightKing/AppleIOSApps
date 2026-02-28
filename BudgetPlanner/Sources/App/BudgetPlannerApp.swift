import SwiftUI

@main
struct BudgetPlannerApp: App {
    @StateObject private var store = BudgetStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
        }
    }
}
