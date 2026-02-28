import Foundation

struct MonthlySpendPoint: Identifiable, Hashable {
    var id: Date { monthStart }
    let monthStart: Date
    let label: String
    let amount: Double
}

struct CategoryComparisonPoint: Identifiable, Hashable {
    let id: UUID
    let categoryName: String
    let current: Double
    let previous: Double

    var delta: Double {
        current - previous
    }

    var percentChange: Double? {
        guard previous > 0 else { return nil }
        return (delta / previous) * 100
    }
}

struct MonthComparisonSummary: Hashable {
    let current: Double
    let previous: Double

    var delta: Double {
        current - previous
    }

    var percentChange: Double? {
        guard previous > 0 else { return nil }
        return (delta / previous) * 100
    }
}
