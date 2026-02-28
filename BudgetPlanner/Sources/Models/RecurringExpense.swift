import Foundation

enum RecurringFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        }
    }
}

struct RecurringExpense: Identifiable, Codable, Hashable {
    let id: UUID
    var categoryID: UUID
    var amount: Double
    var note: String
    var frequency: RecurringFrequency
    var weekday: Int?
    var dayOfMonth: Int?
    var isActive: Bool

    init(
        id: UUID = UUID(),
        categoryID: UUID,
        amount: Double,
        note: String,
        frequency: RecurringFrequency,
        weekday: Int? = nil,
        dayOfMonth: Int? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.categoryID = categoryID
        self.amount = amount
        self.note = note
        self.frequency = frequency
        self.weekday = weekday
        self.dayOfMonth = dayOfMonth
        self.isActive = isActive
    }

    func isDue(on date: Date, calendar: Calendar = .current) -> Bool {
        guard isActive else { return false }

        switch frequency {
        case .weekly:
            guard let weekday else { return false }
            return calendar.component(.weekday, from: date) == weekday
        case .monthly:
            guard let dayOfMonth else { return false }
            return calendar.component(.day, from: date) == dayOfMonth
        }
    }
}
