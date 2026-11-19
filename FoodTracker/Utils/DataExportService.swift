import Foundation

final class DataExportService {
    
    enum ExportError: Error {
        case fileCreationError
    }
    
    static func escapeCSVField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    static func generateCSV(from summaries: [DailySummary]) throws -> URL {
        var csvString = "Date,Total Calories (kcal),Total Protein (g),Total Carbs (g),Total Fat (g),Total Meals Logged\n"
        
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        
        for summary in summaries.sorted(by: { $0.date > $1.date }) {
            let dateStr = escapeCSVField(formatter.string(from: summary.date))
            let line = "\(dateStr),\(summary.totalCalories),\(Int(summary.totalProtein)),\(Int(summary.totalCarbs)),\(Int(summary.totalFats)),\((summary.meals ?? []).count)\n"
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
