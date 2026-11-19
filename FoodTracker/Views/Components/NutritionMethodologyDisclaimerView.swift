import SwiftUI

/// Official scientific and public-health references backing FoodTracker's calculations (App Store Guideline 1.4.1).
enum MedicalCitation: String, CaseIterable, Identifiable {
    case bmrAndTdee
    case bmi
    case dietaryGuidelines
    case micronutrients
    case intermittentFasting

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .bmrAndTdee: return "Mifflin-St Jeor (BMR/TDEE)"
        case .bmi: return "WHO BMI Classification"
        case .dietaryGuidelines: return "USDA Dietary Guidelines"
        case .micronutrients: return "NIH Micronutrient RDAs"
        case .intermittentFasting: return "NEJM Fasting Review"
        }
    }

    var url: URL {
        switch self {
        case .bmrAndTdee:
            return URL(string: "https://pubmed.ncbi.nlm.nih.gov/2305711/")!
        case .bmi:
            return URL(string: "https://www.who.int/news-room/fact-sheets/detail/obesity-and-overweight")!
        case .dietaryGuidelines:
            return URL(string: "https://www.dietaryguidelines.gov/")!
        case .micronutrients:
            return URL(string: "https://ods.od.nih.gov/HealthInformation/nutrientrecommendations.aspx")!
        case .intermittentFasting:
            return URL(string: "https://pubmed.ncbi.nlm.nih.gov/31881139/")!
        }
    }
}

/// Reusable medical disclaimer and clickable citation footer required for health/nutrition apps (Guideline 1.4.1).
struct NutritionMethodologyDisclaimerView: View {
    enum Style {
        case standard
        case darkOnboarding
    }

    let citations: [MedicalCitation]
    var style: Style = .standard
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(iconColor)
                    .padding(.top, 1)

                Text("Estimates are for informational and educational purposes only and are not medical advice. Consult a healthcare professional before starting any diet or fasting protocol.")
                    .font(.system(size: compact ? 10.5 : 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(textColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !citations.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sources & Methodology")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(secondaryColor)
                        .textCase(.uppercase)

                    FlowLayoutCitations(citations: citations, style: style)
                }
            }
        }
        .padding(compact ? 12 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundFill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var iconColor: Color {
        style == .darkOnboarding ? .white.opacity(0.65) : .secondary
    }

    private var textColor: Color {
        style == .darkOnboarding ? .white.opacity(0.68) : .secondary
    }

    private var secondaryColor: Color {
        style == .darkOnboarding ? .white.opacity(0.5) : .secondary.opacity(0.85)
    }

    private var backgroundFill: Color {
        style == .darkOnboarding ? Color.white.opacity(0.06) : Color(.secondarySystemGroupedBackground).opacity(0.85)
    }

    private var borderColor: Color {
        style == .darkOnboarding ? Color.white.opacity(0.12) : Color.primary.opacity(0.06)
    }
}

private struct FlowLayoutCitations: View {
    let citations: [MedicalCitation]
    let style: NutritionMethodologyDisclaimerView.Style

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(citations) { citation in
                    Link(destination: citation.url) {
                        HStack(spacing: 4) {
                            Text(citation.titleKey)
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(style == .darkOnboarding ? Color.white : Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(style == .darkOnboarding ? Color.white.opacity(0.1) : Color.accentColor.opacity(0.1))
                        )
                    }
                }
            }
        }
    }
}
