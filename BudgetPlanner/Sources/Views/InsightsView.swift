import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject private var store: BudgetStore

    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var exportError: String?

    private var trendSeries: [MonthlySpendPoint] {
        store.monthlySpendSeries(months: 6)
    }

    private var monthSummary: MonthComparisonSummary {
        store.currentVsPreviousMonthSummary()
    }

    private var categoryComparison: [CategoryComparisonPoint] {
        store.categoryComparisonCurrentVsPrevious()
    }

    private var forecast: Double {
        store.forecastNextMonthSpend()
    }

    private var topSavings: Double {
        store.savingsTips().prefix(3).reduce(0) { $0 + $1.potentialMonthlySavings }
    }

    private var monthlySuggestions: [String] {
        store.monthlySuggestions()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("6-Month Spending Trend")
                        .font(.headline)

                    Chart {
                        ForEach(trendSeries) { point in
                            LineMark(
                                x: .value("Month", point.monthStart),
                                y: .value("Spent", point.amount)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.blue)

                            PointMark(
                                x: .value("Month", point.monthStart),
                                y: .value("Spent", point.amount)
                            )
                            .foregroundStyle(.blue)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 6)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                        }
                    }
                    .frame(height: 220)

                    HStack(spacing: 10) {
                        SummaryCard(
                            title: "This vs Last Month",
                            value: monthSummary.delta.asCurrency(),
                            subtitle: monthDeltaSubtitle,
                            tint: monthSummary.delta <= 0 ? .green : .red
                        )

                        SummaryCard(
                            title: "Next Month Forecast",
                            value: forecast.asCurrency(),
                            subtitle: "Trend + recurring baseline",
                            tint: .orange
                        )
                    }

                    Text("Spending Breakdown")
                        .font(.headline)

                    Chart {
                        ForEach(store.sortedCategoriesBySpend(), id: \.category.id) { item in
                            BarMark(
                                x: .value("Category", item.category.name),
                                y: .value("Spent", item.spent)
                            )
                            .foregroundStyle(item.category.color)
                        }
                    }
                    .frame(height: 220)

                    if !categoryComparison.isEmpty {
                        Text("Category Change (vs last month)")
                            .font(.headline)

                        ForEach(categoryComparison.prefix(5)) { item in
                            HStack {
                                Text(item.categoryName)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(deltaText(item.delta))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(item.delta <= 0 ? .green : .red)
                                    Text(percentText(item.percentChange))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Export CSV") {
                            exportCSV()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Export PDF") {
                            exportPDF()
                        }
                        .buttonStyle(.bordered)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monthly Suggestions")
                            .font(.headline)

                        ForEach(Array(monthlySuggestions.enumerated()), id: \.offset) { index, tip in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1).")
                                    .font(.subheadline.weight(.bold))
                                Text(tip)
                                    .font(.footnote)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Savings Opportunities")
                            .font(.headline)

                        ForEach(store.savingsTips()) { tip in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(tip.title)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(tip.potentialMonthlySavings.asCurrency())
                                        .font(.subheadline.weight(.bold))
                                }
                                Text(tip.message)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    SummaryCard(
                        title: "Potential Monthly Savings",
                        value: topSavings.asCurrency(),
                        subtitle: "Based on top 3 recommendations",
                        tint: .green
                    )
                }
                .padding()
            }
            .navigationTitle("Insights")
            .sheet(isPresented: $showShareSheet) {
                if let exportURL {
                    ShareSheet(items: [exportURL])
                }
            }
            .alert("Export Failed", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportError ?? "Unknown error")
            }
        }
    }

    private var monthDeltaSubtitle: String {
        let pct = percentText(monthSummary.percentChange)
        if monthSummary.delta <= 0 {
            return "Saved vs last month: \(pct)"
        }
        return "Increase vs last month: \(pct)"
    }

    private func deltaText(_ value: Double) -> String {
        if value == 0 {
            return value.asCurrency()
        }
        return value > 0 ? "+\(value.asCurrency())" : "-\(abs(value).asCurrency())"
    }

    private func percentText(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        if value == 0 { return "0%" }
        let formatted = String(format: "%.1f", value)
        return value > 0 ? "+\(formatted)%" : "\(formatted)%"
    }

    private func exportCSV() {
        do {
            exportURL = try store.exportCSVCurrentMonth()
            showShareSheet = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func exportPDF() {
        do {
            exportURL = try store.exportPDFCurrentMonth()
            showShareSheet = true
        } catch {
            exportError = error.localizedDescription
        }
    }
}
