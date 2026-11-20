import Foundation

final class DataExportService {
    
    enum ExportError: LocalizedError {
        case fileCreationError

        var errorDescription: String? {
            switch self {
            case .fileCreationError:
                return String(localized: "Could not create CSV export file.")
            }
        }
    }
    
    static func escapeCSVField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    static func generateCSV(from summaries: [DailySummary], weightLogs: [WeightLog] = []) throws -> URL {
        var csvString = "Date,Total Calories (kcal),Total Protein (g),Total Carbs (g),Total Fat (g),Total Meals Logged,Hydration (L),Fiber (g),Sugar (g),Active Burned (kcal),Steps,Weight (kg)\n"
        
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let calendar = Calendar(identifier: .gregorian)
        var weightByDay: [Date: Double] = [:]
        for log in weightLogs.sorted(by: { $0.date < $1.date }) {
            let dayStart = calendar.startOfDay(for: log.date)
            if log.weight > 0 {
                weightByDay[dayStart] = log.weight
            }
        }
        
        for summary in summaries.sorted(by: { $0.date > $1.date }) {
            let dayStart = calendar.startOfDay(for: summary.date)
            let resolvedWeight = summary.weight ?? weightByDay[dayStart]
            let weightText = resolvedWeight.map { String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), $0) } ?? ""
            let dateStr = escapeCSVField(formatter.string(from: summary.date))
            let hydrationStr = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), summary.totalPureWaterLiters)
            let fiberStr = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), summary.totalFiber)
            let sugarStr = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), summary.totalSugar)
            let line = "\(dateStr),\(summary.totalCalories),\(Int(summary.totalProtein)),\(Int(summary.totalCarbs)),\(Int(summary.totalFats)),\((summary.meals ?? []).count),\(hydrationStr),\(fiberStr),\(sugarStr),\(summary.activeCaloriesBurned),\(summary.stepsCount),\(escapeCSVField(weightText))\n"
            csvString.append(line)
        }
        
        let fileName = "FoodTracker_Export_\(formatter.string(from: Date())).csv"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            throw ExportError.fileCreationError
        }
    }
}
