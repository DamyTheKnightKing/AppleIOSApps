import XCTest
@testable import BudgetPlanner

final class BudgetStoreAnalyticsTests: XCTestCase {
    private var store: BudgetStore!
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }

    override func setUp() {
        super.setUp()
        store = BudgetStore(usePersistence: false)

        let foodID = UUID()
        let rentID = UUID()
        store.categories = [
            BudgetCategory(id: foodID, name: "Food", icon: "fork.knife", colorHex: "#EF4444", monthlyBudget: 500),
            BudgetCategory(id: rentID, name: "Rent", icon: "house.fill", colorHex: "#10B981", monthlyBudget: 1500)
        ]

        store.recurringExpenses = [
            RecurringExpense(categoryID: rentID, amount: 1200, note: "Rent", frequency: .monthly, dayOfMonth: 1, isActive: true),
            RecurringExpense(categoryID: foodID, amount: 50, note: "Weekly groceries", frequency: .weekly, weekday: 2, isActive: true)
        ]

        store.expenses = [
            Expense(categoryID: foodID, amount: 100, date: date(2026, 1, 5), note: "Food Jan"),
            Expense(categoryID: rentID, amount: 1200, date: date(2026, 1, 1), note: "Rent Jan"),
            Expense(categoryID: foodID, amount: 150, date: date(2026, 2, 5), note: "Food Feb"),
            Expense(categoryID: rentID, amount: 1200, date: date(2026, 2, 1), note: "Rent Feb")
        ]
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    func testCurrentVsPreviousMonthSummary_UsesReferenceDate() {
        let summary = store.currentVsPreviousMonthSummary(referenceDate: date(2026, 2, 20))

        XCTAssertEqual(summary.current, 1350, accuracy: 0.001)
        XCTAssertEqual(summary.previous, 1300, accuracy: 0.001)
        XCTAssertEqual(summary.delta, 50, accuracy: 0.001)
        XCTAssertEqual(summary.percentChange ?? 0, (50.0 / 1300.0) * 100.0, accuracy: 0.001)
    }

    func testCategoryComparisonCurrentVsPrevious_SortsByLargestChange() {
        let comparison = store.categoryComparisonCurrentVsPrevious(referenceDate: date(2026, 2, 20))

        XCTAssertEqual(comparison.count, 2)
        XCTAssertEqual(comparison.first?.categoryName, "Food")
        XCTAssertEqual(comparison.first?.delta ?? 0, 50, accuracy: 0.001)

        XCTAssertEqual(comparison.last?.categoryName, "Rent")
        XCTAssertEqual(comparison.last?.delta ?? 0, 0, accuracy: 0.001)
    }

    func testMonthlySpendSeries_ReturnsChronologicalPoints() {
        let series = store.monthlySpendSeries(months: 2, referenceDate: date(2026, 2, 20))

        XCTAssertEqual(series.count, 2)
        XCTAssertEqual(series[0].amount, 1300, accuracy: 0.001)
        XCTAssertEqual(series[1].amount, 1350, accuracy: 0.001)
        XCTAssertLessThan(series[0].monthStart, series[1].monthStart)
    }

    func testForecastNextMonthSpend_CombinesTrendAndRecurringBaseline() {
        let forecast = store.forecastNextMonthSpend(referenceDate: date(2026, 2, 20))

        // Trend (3-month average): Jan=1300, Feb=1350, Dec=0 => 883.333...
        // Recurring baseline: monthly 1200 + weekly 50*4.33 = 1416.5
        // Forecast = 0.6*883.333... + 0.4*1416.5 = 1096.6
        XCTAssertEqual(forecast, 1096.6, accuracy: 0.2)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        // Midday avoids month-boundary drift across time zones in simulator CI.
        let components = DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12,
            minute: 0
        )
        return calendar.date(from: components) ?? .distantPast
    }
}
