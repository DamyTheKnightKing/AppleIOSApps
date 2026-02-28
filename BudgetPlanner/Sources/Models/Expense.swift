import Foundation

struct Expense: Identifiable, Codable, Hashable {
    let id: UUID
    let categoryID: UUID
    let recurringExpenseID: UUID?
    var amount: Double
    var date: Date
    var note: String

    init(
        id: UUID = UUID(),
        categoryID: UUID,
        recurringExpenseID: UUID? = nil,
        amount: Double,
        date: Date = .now,
        note: String = ""
    ) {
        self.id = id
        self.categoryID = categoryID
        self.recurringExpenseID = recurringExpenseID
        self.amount = amount
        self.date = date
        self.note = note
    }
}
