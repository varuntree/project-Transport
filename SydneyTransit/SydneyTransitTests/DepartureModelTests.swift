import XCTest
import SwiftUI
@testable import SydneyTransit

final class DepartureModelTests: XCTestCase {
    func testOccupancyIconMapping() throws {
        let mappings: [(status: Int, symbol: String, label: String)] = [
            (0, "figure.stand", "Low occupancy"),
            (1, "figure.stand", "Low occupancy"),
            (2, "figure.stand.line.dotted.figure.stand", "Moderate occupancy"),
            (3, "figure.stand.line.dotted.figure.stand", "High occupancy"),
            (4, "figure.stand.line.dotted.figure.stand", "High occupancy"),
            (5, "figure.stand.line.dotted.figure.stand", "Very crowded"),
            (6, "figure.stand.line.dotted.figure.stand", "Very crowded")
        ]

        for mapping in mappings {
            let departure = Departure(
                tripId: "T1",
                routeShortName: "T1",
                headsign: "Test",
                scheduledTimeSecs: 0,
                realtimeTimeSecs: 0,
                minutesUntil: 0,
                delayS: 0,
                realtime: false,
                platform: nil,
                wheelchairAccessible: 0,
                occupancy_status: mapping.status,
                stopSequence: 0
            )

            let icon = try XCTUnwrap(departure.occupancyIcon, "Expected occupancy icon for status \(mapping.status)")
            XCTAssertEqual(icon.symbolName, mapping.symbol)
            XCTAssertEqual(icon.label, mapping.label)
        }
    }
}
