# Phase 4: Trip Planning
**Duration:** 1.5-2 weeks | **Timeline:** Week 12-13
**Goal:** A→B routing with real-time overlay, map visualization

---

## Overview
- Trip planner API (NSW API proxy for MVP)
- Routing service (origin/destination → itineraries)
- iOS trip planner UI (search, results, details)
- MapKit integration (route polylines, stop markers)

---

## User Instructions
None (all backend-side, uses existing NSW API key)

---

## Implementation Checklist

### Backend

**1. Trip Planner Service (app/services/trip_planner_service.py)**
```python
import requests
from app.config import settings

async def plan_trip(origin, destination, time, modes):
    """Proxy to NSW Trip Planner API (cache 10 min)."""
    url = "https://api.transport.nsw.gov.au/v1/tp/trip"
    headers = {'Authorization': f'apikey {settings.NSW_API_KEY}'}
    params = {
        'origin': f"{origin['lat']},{origin['lon']}",
        'destination': f"{destination['lat']},{destination['lon']}",
        'departureTime': time,
        'outputFormat': 'rapidJSON'
    }
    response = requests.get(url, headers=headers, params=params, timeout=10)
    response.raise_for_status()
    return response.json()
```

**2. Trips API (app/api/v1/trips.py)**
```python
@router.post("/trips/plan")
async def plan_trip_endpoint(request: TripPlanRequest):
    """Plan multi-modal trip."""
    # Proxy to NSW API
    result = await plan_trip(
        origin=request.origin,
        destination=request.destination,
        time=request.time,
        modes=request.modes
    )

    # Transform NSW response → our format (see INTEGRATION_CONTRACTS.md)
    itineraries = transform_nsw_response(result)

    # Merge real-time delays (from Redis TripUpdates)
    itineraries = overlay_realtime(itineraries)

    return SuccessResponse(data={'itineraries': itineraries})
```

---

### iOS

**3. Trip Planner View (Features/TripPlanner/TripPlannerView.swift)**
```swift
struct TripPlannerView: View {
    @State private var origin = ""
    @State private var destination = ""
    @State private var results: [Itinerary] = []

    var body: some View {
        VStack {
            TextField("From", text: $origin)
                .textFieldStyle(.roundedBorder)
            TextField("To", text: $destination)
                .textFieldStyle(.roundedBorder)

            Button("Plan Trip") {
                Task { await planTrip() }
            }

            List(results, id: \.id) { itinerary in
                NavigationLink(value: itinerary) {
                    ItineraryRow(itinerary: itinerary)
                }
            }
        }
        .padding()
        .navigationTitle("Trip Planner")
    }

    func planTrip() async {
        // Call /trips/plan API
        // Parse results
    }
}
```

**4. Map View (Features/TripPlanner/TripMapView.swift)**
```swift
import MapKit

struct TripMapView: View {
    let itinerary: Itinerary

    var body: some View {
        Map {
            // Route polyline
            MapPolyline(coordinates: itinerary.polylineCoordinates)
                .stroke(.blue, lineWidth: 3)

            // Stop markers
            ForEach(itinerary.stops) { stop in
                Marker(stop.name, coordinate: stop.coordinate)
            }
        }
        .navigationTitle("Route Map")
    }
}
```

---

## Acceptance Criteria

**Backend:**
- [ ] `/trips/plan` returns 3+ itineraries
- [ ] Real-time delays reflected in arrival times
- [ ] Response <2s (cached)

**iOS:**
- [ ] Search origin/destination works
- [ ] Results list shows duration, transfers
- [ ] Map displays route polyline + stops
- [ ] Tap leg → navigate to stop details

---

## Next Phase: Alerts (Week 14-16)

**End of PHASE_4_TRIP_PLANNING.md**
