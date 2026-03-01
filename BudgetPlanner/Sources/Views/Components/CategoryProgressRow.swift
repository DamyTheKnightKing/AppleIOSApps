import SwiftUI

struct CategoryProgressRow: View {
    let category: BudgetCategory
    let spent: Double

    var usage: Double {
        guard category.monthlyBudget > 0 else { return 0 }
        return spent / category.monthlyBudget
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(category.name, systemImage: category.icon)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(spent.asCurrency()) / \(category.monthlyBudget.asCurrency())")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: min(max(usage, 0), 1.0))
                .tint(usage > 1 ? .red : category.color)

            if usage > 1 {
                Text("Over by \((spent - category.monthlyBudget).asCurrency())")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
