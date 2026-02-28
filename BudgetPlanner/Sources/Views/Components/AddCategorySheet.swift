import SwiftUI

struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BudgetStore

    let onCreated: ((UUID) -> Void)?

    @State private var name: String = ""
    @State private var budget: String = ""
    @State private var icon: String = "wifi"
    @State private var colorHex: String = "#3B82F6"

    private let iconOptions = [
        "wifi", "phone.fill", "airplane", "bed.double.fill", "car.fill",
        "fork.knife", "house.fill", "bag.fill", "heart.fill", "tv.fill", "creditcard.fill"
    ]

    private let colorOptions = ["#3B82F6", "#EF4444", "#10B981", "#F59E0B", "#8B5CF6", "#06B6D4"]

    init(onCreated: ((UUID) -> Void)? = nil) {
        self.onCreated = onCreated
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Name (e.g. Internet, Flight Ticket)", text: $name)

                    TextField("Monthly Budget", text: $budget)
                        .keyboardType(.decimalPad)
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(iconOptions, id: \.self) { item in
                            Button {
                                icon = item
                            } label: {
                                Image(systemName: item)
                                    .font(.headline)
                                    .frame(width: 36, height: 36)
                                    .background(icon == item ? Color.blue.opacity(0.2) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Color") {
                    HStack(spacing: 12) {
                        ForEach(colorOptions, id: \.self) { item in
                            Circle()
                                .fill(Color(hex: item))
                                .frame(width: 26, height: 26)
                                .overlay {
                                    if colorHex == item {
                                        Image(systemName: "checkmark")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture {
                                    colorHex = item
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Category")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (Double(budget) ?? 0) >= 0
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsedBudget = Double(budget), !trimmed.isEmpty else { return }

        let before = Set(store.categories.map(\.id))
        store.addCategory(name: trimmed, icon: icon, colorHex: colorHex, monthlyBudget: parsedBudget)
        let after = Set(store.categories.map(\.id))

        if let id = after.subtracting(before).first {
            onCreated?(id)
        }

        dismiss()
    }
}
