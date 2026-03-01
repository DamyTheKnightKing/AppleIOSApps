import SwiftUI

struct AddExpenseView: View {
    @EnvironmentObject private var store: BudgetStore

    @State private var selectedCategoryID: UUID?
    @State private var amount: String = ""
    @State private var note: String = ""
    @State private var date: Date = .now
    @State private var showConfirmation = false
    @State private var showAddCategory = false
    private let quickAmounts: [Double] = [10, 25, 50, 100]

    private var recentNotes: [String] {
        Array(
            Set(
                store.expenses
                    .map(\.note)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
        .prefix(6)
        .map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("New Expense") {
                    Picker("Category", selection: $selectedCategoryID) {
                        Text("Select Category").tag(UUID?.none)
                        ForEach(store.categories) { category in
                            Text(category.name).tag(UUID?.some(category.id))
                        }
                    }

                    Button("Add New Category") {
                        showAddCategory = true
                    }

                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickAmounts, id: \.self) { value in
                                Button(value.asCurrency()) {
                                    amount = String(format: "%.2f", value)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    TextField("Note (optional)", text: $note)
                }

                if !recentNotes.isEmpty {
                    Section("Recent Notes") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recentNotes, id: \.self) { item in
                                    Button(item) {
                                        note = item
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section {
                    Button("Add Expense") {
                        addExpense()
                    }
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Add Expense")
            .alert("Saved", isPresented: $showConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Expense added successfully.")
            }
            .onAppear {
                selectedCategoryID = selectedCategoryID ?? store.categories.first?.id
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategorySheet { newCategoryID in
                    selectedCategoryID = newCategoryID
                }
                .environmentObject(store)
            }
        }
    }

    private var isFormValid: Bool {
        selectedCategoryID != nil && (Double(amount) ?? 0) > 0
    }

    private func addExpense() {
        guard let categoryID = selectedCategoryID,
              let parsedAmount = Double(amount),
              parsedAmount > 0 else {
            return
        }

        store.addExpense(categoryID: categoryID, amount: parsedAmount, date: date, note: note)
        amount = ""
        note = ""
        date = .now
        showConfirmation = true
    }
}
