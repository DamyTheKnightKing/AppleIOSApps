import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: BudgetStore

    @State private var incomeText: String = ""
    @State private var remindersEnabled: Bool = false
    @State private var reminderTime: Date = .now
    @State private var iCloudEnabled: Bool = false

    @State private var showAddRecurring = false
    @State private var showAddCategory = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Monthly Income") {
                    TextField("Income", text: $incomeText)
                        .keyboardType(.decimalPad)

                    Button("Save Income") {
                        if let income = Double(incomeText), income > 0 {
                            store.setMonthlyIncome(income)
                        }
                    }
                }

                Section("Reminders") {
                    Toggle("Enable Daily Budget Reminder", isOn: $remindersEnabled)
                    DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)

                    Button("Save Reminder") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                        store.setReminder(
                            enabled: remindersEnabled,
                            hour: components.hour ?? 20,
                            minute: components.minute ?? 0
                        )
                    }
                }

                Section("iCloud") {
                    Toggle("Sync Across Devices", isOn: $iCloudEnabled)
                        .onChange(of: iCloudEnabled) { _, newValue in
                            store.setICloudSync(newValue)
                        }
                }

                Section("Category Budgets") {
                    Button("Add Custom Category") {
                        showAddCategory = true
                    }

                    ForEach(store.categories) { category in
                        BudgetEditorRow(category: category)
                    }
                }

                Section("Recurring Expenses") {
                    Button("Add Recurring Expense") {
                        showAddRecurring = true
                    }

                    if store.recurringExpenses.isEmpty {
                        Text("No recurring expenses yet")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(store.recurringExpenses) { item in
                        RecurringExpenseRow(item: item)
                    }
                    .onDelete(perform: deleteRecurring)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showAddRecurring) {
                AddRecurringExpenseView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategorySheet()
                    .environmentObject(store)
            }
            .onAppear(perform: loadForm)
        }
    }

    private func loadForm() {
        incomeText = String(format: "%.0f", store.monthlyIncome)
        remindersEnabled = store.reminderEnabled
        iCloudEnabled = store.iCloudSyncEnabled

        var components = DateComponents()
        components.hour = store.reminderHour
        components.minute = store.reminderMinute
        reminderTime = Calendar.current.date(from: components) ?? .now
    }

    private func deleteRecurring(at offsets: IndexSet) {
        for index in offsets {
            store.deleteRecurringExpense(store.recurringExpenses[index])
        }
    }
}

private struct BudgetEditorRow: View {
    @EnvironmentObject private var store: BudgetStore
    let category: BudgetCategory

    @State private var budgetText: String = ""

    var body: some View {
        HStack {
            Label(category.name, systemImage: category.icon)
            Spacer()
            TextField("Budget", text: $budgetText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)
                .onDisappear(perform: save)
        }
        .onAppear {
            budgetText = String(format: "%.0f", category.monthlyBudget)
        }
    }

    private func save() {
        guard let value = Double(budgetText), value >= 0 else { return }
        store.updateBudget(for: category.id, monthlyBudget: value)
    }
}

private struct RecurringExpenseRow: View {
    @EnvironmentObject private var store: BudgetStore
    let item: RecurringExpense

    var body: some View {
        if let category = store.categories.first(where: { $0.id == item.categoryID }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(item.amount.asCurrency())
                        .font(.subheadline.weight(.bold))
                }

                Text(scheduleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var scheduleText: String {
        switch item.frequency {
        case .weekly:
            let weekday = item.weekday ?? 1
            return "Weekly on \(weekdayName(from: weekday))"
        case .monthly:
            let day = item.dayOfMonth ?? 1
            return "Monthly on day \(day)"
        }
    }

    private func weekdayName(from value: Int) -> String {
        let formatter = DateFormatter()
        let names = formatter.weekdaySymbols ?? []
        guard value > 0, value <= names.count else { return "Unknown" }
        return names[value - 1]
    }
}

private struct AddRecurringExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BudgetStore

    @State private var selectedCategoryID: UUID?
    @State private var amount: String = ""
    @State private var note: String = ""
    @State private var frequency: RecurringFrequency = .monthly
    @State private var weekday: Int = Calendar.current.component(.weekday, from: .now)
    @State private var dayOfMonth: Int = Calendar.current.component(.day, from: .now)

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    Picker("Category", selection: $selectedCategoryID) {
                        Text("Select Category").tag(UUID?.none)
                        ForEach(store.categories) { category in
                            Text(category.name).tag(UUID?.some(category.id))
                        }
                    }

                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)

                    TextField("Note", text: $note)
                }

                Section("Schedule") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(RecurringFrequency.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }

                    if frequency == .weekly {
                        Picker("Weekday", selection: $weekday) {
                            ForEach(1...7, id: \.self) { value in
                                Text(weekdayName(from: value)).tag(value)
                            }
                        }
                    } else {
                        Stepper("Day of Month: \(dayOfMonth)", value: $dayOfMonth, in: 1...28)
                    }
                }
            }
            .navigationTitle("New Recurring")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                selectedCategoryID = selectedCategoryID ?? store.categories.first?.id
            }
        }
    }

    private var isValid: Bool {
        selectedCategoryID != nil && (Double(amount) ?? 0) > 0
    }

    private func save() {
        guard let categoryID = selectedCategoryID,
              let parsedAmount = Double(amount),
              parsedAmount > 0 else {
            return
        }

        store.addRecurringExpense(
            categoryID: categoryID,
            amount: parsedAmount,
            note: note,
            frequency: frequency,
            weekday: frequency == .weekly ? weekday : nil,
            dayOfMonth: frequency == .monthly ? dayOfMonth : nil
        )

        dismiss()
    }

    private func weekdayName(from value: Int) -> String {
        let formatter = DateFormatter()
        let names = formatter.weekdaySymbols ?? []
        guard value > 0, value <= names.count else { return "Unknown" }
        return names[value - 1]
    }
}
