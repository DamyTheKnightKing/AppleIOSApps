import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: BudgetStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        SummaryCard(
                            title: "Spent This Month",
                            value: store.spentThisMonth().asCurrency(),
                            subtitle: "Budget usage: \(String(format: "%.0f", store.budgetUsagePercent()))%",
                            tint: .red
                        )

                        SummaryCard(
                            title: "Estimated Savings",
                            value: store.monthlySavingsEstimate().asCurrency(),
                            subtitle: "Income: \(store.monthlyIncome.asCurrency())",
                            tint: .green
                        )
                    }

                    Text("Budget by Category")
                        .font(.headline)
                        .padding(.top, 6)

                    ForEach(store.sortedCategoriesBySpend(), id: \.category.id) { item in
                        CategoryProgressRow(category: item.category, spent: item.spent)
                    }

                    Text("Recent Expenses")
                        .font(.headline)
                        .padding(.top, 8)

                    ForEach(store.expensesForCurrentMonth().prefix(8)) { expense in
                        if let category = store.categories.first(where: { $0.id == expense.categoryID }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(category.name)
                                            .font(.subheadline.weight(.semibold))
                                        if expense.recurringExpenseID != nil {
                                            Text("Recurring")
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.15), in: Capsule())
                                        }
                                    }
                                    if !expense.note.isEmpty {
                                        Text(expense.note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(expense.amount.asCurrency())
                                    .font(.subheadline.weight(.bold))
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Budget Planner")
        }
    }
}
