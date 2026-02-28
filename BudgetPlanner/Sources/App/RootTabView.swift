import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: BudgetStore

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            AddExpenseView()
                .tabItem {
                    Label("Add", systemImage: "plus.circle")
                }

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            store.generateRecurringExpensesIfNeeded()
        }
    }
}
