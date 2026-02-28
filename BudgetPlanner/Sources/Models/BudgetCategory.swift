import Foundation
import SwiftUI

struct BudgetCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var monthlyBudget: Double

    init(id: UUID = UUID(), name: String, icon: String, colorHex: String, monthlyBudget: Double) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.monthlyBudget = monthlyBudget
    }

    var color: Color {
        Color(hex: colorHex)
    }
}
