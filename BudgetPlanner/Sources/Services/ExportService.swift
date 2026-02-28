import Foundation
import UIKit

enum ExportService {
    static func createCSV(expenses: [Expense], categories: [BudgetCategory]) throws -> URL {
        let formatter = ISO8601DateFormatter()
        let categoryName = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })

        var rows: [String] = ["date,category,amount,note,source"]
        for item in expenses.sorted(by: { $0.date > $1.date }) {
            let date = formatter.string(from: item.date)
            let category = categoryName[item.categoryID, default: "Unknown"]
            let note = csvEscaped(item.note)
            let source = item.recurringExpenseID == nil ? "manual" : "recurring"
            rows.append("\(date),\(csvEscaped(category)),\(item.amount),\(note),\(source)")
        }

        let url = temporaryFileURL(ext: "csv")
        try rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func createPDF(expenses: [Expense], categories: [BudgetCategory], monthLabel: String) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let categoryName = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })

        let data = renderer.pdfData { context in
            context.beginPage()

            let title = "Budget Planner - \(monthLabel)"
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20)
            ]
            title.draw(at: CGPoint(x: 30, y: 30), withAttributes: titleAttrs)

            var y: CGFloat = 70
            let total = expenses.reduce(0) { $0 + $1.amount }
            let totalLine = "Total Spent: \(total.asCurrency())"
            totalLine.draw(at: CGPoint(x: 30, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
            y += 28

            for item in expenses.sorted(by: { $0.date > $1.date }).prefix(28) {
                let date = DateFormatter.localizedString(from: item.date, dateStyle: .short, timeStyle: .none)
                let category = categoryName[item.categoryID, default: "Unknown"]
                let text = "\(date)  |  \(category)  |  \(item.amount.asCurrency())  |  \(item.note)"
                text.draw(at: CGPoint(x: 30, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 11)])
                y += 20
                if y > 790 {
                    context.beginPage()
                    y = 30
                }
            }
        }

        let url = temporaryFileURL(ext: "pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func temporaryFileURL(ext: String) -> URL {
        let file = "budget-export-\(Int(Date().timeIntervalSince1970)).\(ext)"
        return FileManager.default.temporaryDirectory.appendingPathComponent(file)
    }

    private static func csvEscaped(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
