import Foundation

final class BudgetStore: NSObject, ObservableObject {
    @Published var categories: [BudgetCategory] = []
    @Published var expenses: [Expense] = []
    @Published var recurringExpenses: [RecurringExpense] = []

    @Published var monthlyIncome: Double = 5000
    @Published var reminderEnabled: Bool = false
    @Published var reminderHour: Int = 20
    @Published var reminderMinute: Int = 0
    @Published var iCloudSyncEnabled: Bool = false

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private lazy var cloudStore = NSUbiquitousKeyValueStore.default
    private let usePersistence: Bool
    private var isObservingICloud = false

    private let categoriesFile = "categories.json"
    private let expensesFile = "expenses.json"
    private let recurringFile = "recurring-expenses.json"
    private let profileFile = "profile.json"

    private let cloudCategoriesKey = "cloud.categories"
    private let cloudExpensesKey = "cloud.expenses"
    private let cloudRecurringKey = "cloud.recurring"
    private let cloudProfileKey = "cloud.profile"

    struct Profile: Codable {
        var monthlyIncome: Double
        var reminderEnabled: Bool
        var reminderHour: Int
        var reminderMinute: Int
        var iCloudSyncEnabled: Bool
        var lastRecurringRunDate: Date?
    }

    private var profile = Profile(
        monthlyIncome: 5000,
        reminderEnabled: false,
        reminderHour: 20,
        reminderMinute: 0,
        iCloudSyncEnabled: false,
        lastRecurringRunDate: nil
    )

    init(usePersistence: Bool = true) {
        self.usePersistence = usePersistence
        super.init()
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601

        if usePersistence {
            loadData()
            if iCloudSyncEnabled {
                setupICloudObserverIfNeeded()
                pullFromICloudIfAvailable()
            }
            generateRecurringExpensesIfNeeded()
        } else {
            categories = []
            expenses = []
            recurringExpenses = []
            hydrateProfile()
        }

        applyReminderSettings()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func addExpense(categoryID: UUID, amount: Double, date: Date, note: String, recurringExpenseID: UUID? = nil) {
        let expense = Expense(
            categoryID: categoryID,
            recurringExpenseID: recurringExpenseID,
            amount: amount,
            date: date,
            note: note
        )
        expenses.insert(expense, at: 0)
        saveExpenses()
    }

    func deleteExpense(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        saveExpenses()
    }

    func addCategory(name: String, icon: String, colorHex: String, monthlyBudget: Double) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        guard !categories.contains(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) else { return }

        categories.append(
            BudgetCategory(
                name: cleanName,
                icon: icon,
                colorHex: colorHex,
                monthlyBudget: monthlyBudget
            )
        )
        saveCategories()
    }

    func addRecurringExpense(
        categoryID: UUID,
        amount: Double,
        note: String,
        frequency: RecurringFrequency,
        weekday: Int?,
        dayOfMonth: Int?
    ) {
        let item = RecurringExpense(
            categoryID: categoryID,
            amount: amount,
            note: note,
            frequency: frequency,
            weekday: weekday,
            dayOfMonth: dayOfMonth,
            isActive: true
        )
        recurringExpenses.append(item)
        saveRecurringExpenses()
        generateRecurringExpensesIfNeeded()
    }

    func deleteRecurringExpense(_ item: RecurringExpense) {
        recurringExpenses.removeAll { $0.id == item.id }
        saveRecurringExpenses()
    }

    func updateBudget(for categoryID: UUID, monthlyBudget: Double) {
        guard let index = categories.firstIndex(where: { $0.id == categoryID }) else {
            return
        }
        categories[index].monthlyBudget = monthlyBudget
        saveCategories()
    }

    func setMonthlyIncome(_ income: Double) {
        monthlyIncome = income
        profile.monthlyIncome = income
        saveProfile()
    }

    func setReminder(enabled: Bool, hour: Int, minute: Int) {
        reminderEnabled = enabled
        reminderHour = hour
        reminderMinute = minute

        profile.reminderEnabled = enabled
        profile.reminderHour = hour
        profile.reminderMinute = minute

        applyReminderSettings()
        saveProfile()
    }

    func setICloudSync(_ enabled: Bool) {
        iCloudSyncEnabled = enabled
        profile.iCloudSyncEnabled = enabled
        saveProfile()

        if enabled {
            setupICloudObserverIfNeeded()
            syncToICloud()
        }
    }

    func expensesForCurrentMonth() -> [Expense] {
        let cal = Calendar.current
        return expenses.filter { cal.isDate($0.date, equalTo: .now, toGranularity: .month) }
    }

    func spentThisMonth() -> Double {
        expensesForCurrentMonth().reduce(0) { $0 + $1.amount }
    }

    func totalBudget() -> Double {
        categories.reduce(0) { $0 + $1.monthlyBudget }
    }

    func budgetUsagePercent() -> Double {
        let budget = totalBudget()
        guard budget > 0 else { return 0 }
        return (spentThisMonth() / budget) * 100
    }

    func categorySpent(_ categoryID: UUID) -> Double {
        expensesForCurrentMonth()
            .filter { $0.categoryID == categoryID }
            .reduce(0) { $0 + $1.amount }
    }

    func remainingBudget(for categoryID: UUID) -> Double {
        guard let category = categories.first(where: { $0.id == categoryID }) else { return 0 }
        return category.monthlyBudget - categorySpent(categoryID)
    }

    func sortedCategoriesBySpend() -> [(category: BudgetCategory, spent: Double)] {
        categories
            .map { ($0, categorySpent($0.id)) }
            .sorted { $0.1 > $1.1 }
    }

    func monthlySavingsEstimate() -> Double {
        max(0, monthlyIncome - spentThisMonth())
    }

    func savingsTips() -> [SavingsTip] {
        var tips: [SavingsTip] = []

        for category in categories {
            let spent = categorySpent(category.id)
            if category.monthlyBudget == 0 { continue }

            let usage = spent / category.monthlyBudget
            if usage > 1.0 {
                let overspend = spent - category.monthlyBudget
                tips.append(
                    SavingsTip(
                        title: "Reduce \(category.name)",
                        message: "You are over budget in \(category.name). Cap this by planning a weekly limit.",
                        potentialMonthlySavings: overspend
                    )
                )
            } else if usage > 0.8 {
                let potential = category.monthlyBudget * 0.1
                tips.append(
                    SavingsTip(
                        title: "Optimize \(category.name)",
                        message: "\(category.name) is nearing limit. A 10% cut can keep you in control.",
                        potentialMonthlySavings: potential
                    )
                )
            }
        }

        if tips.isEmpty {
            tips.append(
                SavingsTip(
                    title: "Great control this month",
                    message: "Your category spending is healthy. Keep tracking daily to maintain this trend.",
                    potentialMonthlySavings: 0
                )
            )
        }

        return tips.sorted { $0.potentialMonthlySavings > $1.potentialMonthlySavings }
    }

    func monthlySpendSeries(months: Int = 6, referenceDate: Date = .now) -> [MonthlySpendPoint] {
        let calendar = Calendar.current
        let safeMonths = max(2, months)
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)) else {
            return []
        }

        var points: [MonthlySpendPoint] = []
        for offset in stride(from: safeMonths - 1, through: 0, by: -1) {
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: currentMonthStart) else {
                continue
            }
            points.append(
                MonthlySpendPoint(
                    monthStart: monthStart,
                    label: monthLabel(monthStart),
                    amount: spend(forMonthStart: monthStart, calendar: calendar)
                )
            )
        }
        return points
    }

    func currentVsPreviousMonthSummary(referenceDate: Date = .now) -> MonthComparisonSummary {
        let calendar = Calendar.current
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)),
              let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) else {
            return MonthComparisonSummary(current: 0, previous: 0)
        }

        return MonthComparisonSummary(
            current: spend(forMonthStart: currentMonthStart, calendar: calendar),
            previous: spend(forMonthStart: previousMonthStart, calendar: calendar)
        )
    }

    func categoryComparisonCurrentVsPrevious(referenceDate: Date = .now) -> [CategoryComparisonPoint] {
        let calendar = Calendar.current
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)),
              let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) else {
            return []
        }

        let currentTotals = categoryTotals(forMonthStart: currentMonthStart, calendar: calendar)
        let previousTotals = categoryTotals(forMonthStart: previousMonthStart, calendar: calendar)

        return categories
            .map { category in
                CategoryComparisonPoint(
                    id: category.id,
                    categoryName: category.name,
                    current: currentTotals[category.id, default: 0],
                    previous: previousTotals[category.id, default: 0]
                )
            }
            .filter { $0.current > 0 || $0.previous > 0 }
            .sorted { abs($0.delta) > abs($1.delta) }
    }

    func forecastNextMonthSpend(referenceDate: Date = .now) -> Double {
        let trendSeries = monthlySpendSeries(months: 3, referenceDate: referenceDate)
        let trailingAverage = trendSeries.isEmpty ? 0 : trendSeries.reduce(0) { $0 + $1.amount } / Double(trendSeries.count)
        let recurringBaseline = monthlyRecurringBaseline()
        return (trailingAverage * 0.6) + (recurringBaseline * 0.4)
    }

    func monthlySuggestions(referenceDate: Date = .now) -> [String] {
        var suggestions: [String] = []

        let summary = currentVsPreviousMonthSummary(referenceDate: referenceDate)
        if summary.delta > 0 {
            suggestions.append("Spending is up \(String(format: "%.1f", summary.percentChange ?? 0))% vs last month. Set tighter weekly limits this month.")
        } else if summary.delta < 0 {
            suggestions.append("Great progress. You reduced spending by \(abs(summary.delta).asCurrency()) compared with last month.")
        }

        var overBudget: [(category: BudgetCategory, spent: Double)] = []
        for category in categories where category.monthlyBudget > 0 {
            let spent = categorySpent(category.id)
            if spent > category.monthlyBudget {
                overBudget.append((category: category, spent: spent))
            }
        }
        overBudget.sort { (lhs, rhs) in
            (lhs.spent - lhs.category.monthlyBudget) > (rhs.spent - rhs.category.monthlyBudget)
        }

        if let topOver = overBudget.first {
            let overspend = topOver.spent - topOver.category.monthlyBudget
            suggestions.append("You're over budget in \(topOver.category.name) by \(overspend.asCurrency()). Add a hard cap for this category.")
        }

        if let highestRise = categoryComparisonCurrentVsPrevious(referenceDate: referenceDate).first(where: { $0.delta > 0 }) {
            suggestions.append("\(highestRise.categoryName) increased most this month (\(deltaText(highestRise.delta))). Review these transactions first.")
        }

        let forecast = forecastNextMonthSpend(referenceDate: referenceDate)
        if forecast > monthlyIncome {
            suggestions.append("Forecasted spend (\(forecast.asCurrency())) is above income. Reduce discretionary categories by at least \((forecast - monthlyIncome).asCurrency()).")
        } else {
            suggestions.append("Forecasted spend is \(forecast.asCurrency()). You can target savings of \(max(0, monthlyIncome - forecast).asCurrency()) next month.")
        }

        return Array(suggestions.prefix(4))
    }

    func exportCSVCurrentMonth() throws -> URL {
        try ExportService.createCSV(expenses: expensesForCurrentMonth(), categories: categories)
    }

    func exportPDFCurrentMonth() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let month = formatter.string(from: .now)
        return try ExportService.createPDF(expenses: expensesForCurrentMonth(), categories: categories, monthLabel: month)
    }

    func generateRecurringExpensesIfNeeded(referenceDate: Date = .now) {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: referenceDate)
        let maxBackfillDays = 120

        let startDate: Date
        if let last = profile.lastRecurringRunDate {
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)) else {
                return
            }
            startDate = nextDate
        } else {
            startDate = endDate
        }

        guard startDate <= endDate else { return }

        // Safety cap to prevent long startup blocks if prior sync data is stale.
        let cappedStartDate: Date
        if let minimumStart = calendar.date(byAdding: .day, value: -maxBackfillDays, to: endDate) {
            cappedStartDate = max(startDate, minimumStart)
        } else {
            cappedStartDate = startDate
        }

        var generated: [Expense] = []
        var cursor = cappedStartDate
        while cursor <= endDate {
            for recurring in recurringExpenses where recurring.isDue(on: cursor, calendar: calendar) {
                let alreadyExists = expenses.contains {
                    $0.recurringExpenseID == recurring.id && calendar.isDate($0.date, inSameDayAs: cursor)
                }
                if !alreadyExists {
                    generated.append(
                        Expense(
                        categoryID: recurring.categoryID,
                        recurringExpenseID: recurring.id,
                        amount: recurring.amount,
                        date: cursor,
                        note: recurring.note
                        )
                    )
                }
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        if !generated.isEmpty {
            expenses.insert(contentsOf: generated.sorted(by: { $0.date > $1.date }), at: 0)
            saveExpenses()
        }

        profile.lastRecurringRunDate = endDate
        saveProfile()
    }

    private func applyReminderSettings() {
        NotificationManager.configureBudgetReminder(
            enabled: reminderEnabled,
            hour: reminderHour,
            minute: reminderMinute
        )
    }

    private func spend(forMonthStart monthStart: Date, calendar: Calendar) -> Double {
        guard let interval = calendar.dateInterval(of: .month, for: monthStart) else {
            return 0
        }
        return expenses
            .filter { interval.contains($0.date) }
            .reduce(0) { $0 + $1.amount }
    }

    private func categoryTotals(forMonthStart monthStart: Date, calendar: Calendar) -> [UUID: Double] {
        guard let interval = calendar.dateInterval(of: .month, for: monthStart) else {
            return [:]
        }

        return expenses
            .filter { interval.contains($0.date) }
            .reduce(into: [UUID: Double]()) { partial, item in
                partial[item.categoryID, default: 0] += item.amount
            }
    }

    private func monthLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func monthlyRecurringBaseline() -> Double {
        recurringExpenses
            .filter(\.isActive)
            .reduce(0) { partial, item in
                switch item.frequency {
                case .monthly:
                    return partial + item.amount
                case .weekly:
                    return partial + (item.amount * 4.33)
                }
            }
    }

    private func deltaText(_ value: Double) -> String {
        if value >= 0 {
            return "+\(value.asCurrency())"
        }
        return "-\(abs(value).asCurrency())"
    }

    private func setupICloudObserverIfNeeded() {
        guard usePersistence, !isObservingICloud else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )
        isObservingICloud = true
    }

    @objc private func iCloudDidChange() {
        guard iCloudSyncEnabled else { return }
        pullFromICloudIfAvailable()
    }

    private func loadData() {
        guard usePersistence else {
            seedDefaults()
            return
        }

        let localCategories: [BudgetCategory]? = load(type: [BudgetCategory].self, filename: categoriesFile)
        let localExpenses: [Expense]? = load(type: [Expense].self, filename: expensesFile)
        let localRecurring: [RecurringExpense]? = load(type: [RecurringExpense].self, filename: recurringFile)
        let localProfile: Profile? = load(type: Profile.self, filename: profileFile)

        if let localCategories,
           let localExpenses,
           let localRecurring,
           let localProfile {
            categories = localCategories
            expenses = localExpenses
            recurringExpenses = localRecurring
            profile = localProfile
            hydrateProfile()
            return
        }

        seedDefaults()
    }

    private func hydrateProfile() {
        monthlyIncome = profile.monthlyIncome
        reminderEnabled = profile.reminderEnabled
        reminderHour = profile.reminderHour
        reminderMinute = profile.reminderMinute
        iCloudSyncEnabled = profile.iCloudSyncEnabled
    }

    private func seedDefaults() {
        categories = [
            BudgetCategory(name: "Food", icon: "fork.knife", colorHex: "#EF4444", monthlyBudget: 600),
            BudgetCategory(name: "Transport", icon: "car.fill", colorHex: "#3B82F6", monthlyBudget: 350),
            BudgetCategory(name: "Rent", icon: "house.fill", colorHex: "#10B981", monthlyBudget: 1700),
            BudgetCategory(name: "Shopping", icon: "bag.fill", colorHex: "#F59E0B", monthlyBudget: 400),
            BudgetCategory(name: "Health", icon: "heart.fill", colorHex: "#8B5CF6", monthlyBudget: 250),
            BudgetCategory(name: "Entertainment", icon: "tv.fill", colorHex: "#06B6D4", monthlyBudget: 300)
        ]

        if let food = categories.first,
           let rent = categories.first(where: { $0.name == "Rent" }),
           let transport = categories.first(where: { $0.name == "Transport" }) {
            expenses = [
                Expense(categoryID: food.id, amount: 28.5, date: .now, note: "Lunch"),
                Expense(categoryID: transport.id, amount: 14.2, date: .now, note: "Taxi"),
                Expense(categoryID: rent.id, amount: 1700, date: .now, note: "Monthly rent")
            ]

            recurringExpenses = [
                RecurringExpense(
                    categoryID: rent.id,
                    amount: 1700,
                    note: "Rent",
                    frequency: .monthly,
                    dayOfMonth: 1,
                    isActive: true
                )
            ]
        }

        profile = Profile(
            monthlyIncome: 5000,
            reminderEnabled: false,
            reminderHour: 20,
            reminderMinute: 0,
            iCloudSyncEnabled: false,
            lastRecurringRunDate: nil
        )
        hydrateProfile()
        saveAll()
    }

    private func saveAll() {
        saveCategories()
        saveExpenses()
        saveRecurringExpenses()
        saveProfile()
    }

    private func saveCategories() {
        save(categories, filename: categoriesFile)
        syncToICloudIfEnabled(key: cloudCategoriesKey, value: categories)
    }

    private func saveExpenses() {
        save(expenses, filename: expensesFile)
        syncToICloudIfEnabled(key: cloudExpensesKey, value: expenses)
    }

    private func saveRecurringExpenses() {
        save(recurringExpenses, filename: recurringFile)
        syncToICloudIfEnabled(key: cloudRecurringKey, value: recurringExpenses)
    }

    private func saveProfile() {
        save(profile, filename: profileFile)
        syncToICloudIfEnabled(key: cloudProfileKey, value: profile)
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func save<T: Encodable>(_ value: T, filename: String) {
        guard usePersistence else { return }
        do {
            let data = try encoder.encode(value)
            let url = documentsDirectory().appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save \(filename): \(error)")
        }
    }

    private func load<T: Decodable>(type: T.Type, filename: String) -> T? {
        guard usePersistence else { return nil }
        do {
            let url = documentsDirectory().appendingPathComponent(filename)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Failed to load \(filename): \(error)")
            return nil
        }
    }

    private func syncToICloudIfEnabled<T: Encodable>(key: String, value: T) {
        guard usePersistence, iCloudSyncEnabled else { return }
        do {
            let data = try encoder.encode(value)
            cloudStore.set(data.base64EncodedString(), forKey: key)
            cloudStore.synchronize()
        } catch {
            print("Failed to push iCloud key \(key): \(error)")
        }
    }

    private func syncToICloud() {
        syncToICloudIfEnabled(key: cloudCategoriesKey, value: categories)
        syncToICloudIfEnabled(key: cloudExpensesKey, value: expenses)
        syncToICloudIfEnabled(key: cloudRecurringKey, value: recurringExpenses)
        syncToICloudIfEnabled(key: cloudProfileKey, value: profile)
    }

    private func pullFromICloudIfAvailable() {
        guard usePersistence else { return }
        guard let categories: [BudgetCategory] = decodeCloudValue(forKey: cloudCategoriesKey, as: [BudgetCategory].self),
              let expenses: [Expense] = decodeCloudValue(forKey: cloudExpensesKey, as: [Expense].self),
              let recurring: [RecurringExpense] = decodeCloudValue(forKey: cloudRecurringKey, as: [RecurringExpense].self),
              let profile: Profile = decodeCloudValue(forKey: cloudProfileKey, as: Profile.self) else {
            return
        }

        self.categories = categories
        self.expenses = expenses
        self.recurringExpenses = recurring
        self.profile = profile
        hydrateProfile()

        save(categories, filename: categoriesFile)
        save(expenses, filename: expensesFile)
        save(recurring, filename: recurringFile)
        save(profile, filename: profileFile)
    }

    private func decodeCloudValue<T: Decodable>(forKey key: String, as _: T.Type) -> T? {
        guard let base64 = cloudStore.string(forKey: key),
              let data = Data(base64Encoded: base64) else {
            return nil
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Failed to decode iCloud key \(key): \(error)")
            return nil
        }
    }
}
