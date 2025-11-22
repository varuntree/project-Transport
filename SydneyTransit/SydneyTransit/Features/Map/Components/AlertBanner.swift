//
//  AlertBanner.swift
//  SydneyTransit
//
//  Created by Claude Code on 2025-11-22.
//  Phase 2.2 RT Feature Completion - Checkpoint 3
//

import SwiftUI

/// Visual banner displaying service alert with severity color, icon, and accessibility
struct AlertBanner: View {
    let alert: ServiceAlert

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Icon based on effect type
                Image(systemName: effectIcon)
                    .foregroundColor(effectColor)
                    .font(.title3)

                Text(alert.headerText)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()
            }

            if let description = alert.descriptionText {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            if let effect = alert.effect {
                Text(effectLabel(effect))
                    .font(.caption)
                    .foregroundColor(effectColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(effectColor.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(effectColor.opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Computed Properties

    private var effectIcon: String {
        switch alert.effect {
        case "NO_SERVICE":
            return "exclamationmark.triangle.fill"
        case "REDUCED_SERVICE":
            return "exclamationmark.circle.fill"
        case "SIGNIFICANT_DELAYS", "DELAYS":
            return "clock.fill"
        case "DETOUR":
            return "arrow.triangle.branch"
        default:
            return "info.circle.fill"
        }
    }

    private var effectColor: Color {
        switch alert.effect {
        case "NO_SERVICE":
            return .red
        case "REDUCED_SERVICE":
            return .orange
        case "SIGNIFICANT_DELAYS", "DELAYS":
            return .yellow
        default:
            return .blue
        }
    }

    private func effectLabel(_ effect: String) -> String {
        // Convert UPPERCASE_SNAKE to Title Case
        effect.split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private var accessibilityText: String {
        var text = "Service alert: \(alert.headerText)"

        if let description = alert.descriptionText {
            text += ". \(description)"
        }

        if let effect = alert.effect {
            text += ". Severity: \(effectLabel(effect))"
        }

        return text
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        AlertBanner(alert: ServiceAlert(
            id: "1",
            headerText: "Buses not stopping at Central",
            descriptionText: "Due to construction work, all bus services will skip Central Station until 5pm.",
            effect: "NO_SERVICE",
            cause: "CONSTRUCTION",
            activePeriod: [],
            informedEntity: [],
            severityLevel: "SEVERE"
        ))

        AlertBanner(alert: ServiceAlert(
            id: "2",
            headerText: "Delays on T1 North Shore Line",
            descriptionText: "Expect delays of up to 10 minutes due to signal failure.",
            effect: "SIGNIFICANT_DELAYS",
            cause: "TECHNICAL_PROBLEM",
            activePeriod: [],
            informedEntity: [],
            severityLevel: "WARNING"
        ))
    }
    .padding()
}
