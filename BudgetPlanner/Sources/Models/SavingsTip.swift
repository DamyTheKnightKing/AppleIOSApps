import Foundation

struct SavingsTip: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let message: String
    let potentialMonthlySavings: Double
}
