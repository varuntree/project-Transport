# **FEATURE SPECIFICATION: Three-Layer Architecture**

**Platform:** iOS only (Swift/SwiftUI native)
**Geographic Scope:** Sydney, Melbourne, Brisbane
**Strategy:** Fundamentals first, AI later

**Build Phases:**
- **Phase 1 (MVP):** Layer 1 + core Layer 2 - match/exceed TripView + Transit reliability
- **Phase 2:** AI orchestration layer
- **Phase 3:** Voice/accessibility features

This document structures features into three layers:
1. **Layer 1: Fundamentals** (Must-haves - table stakes for any transit app)
2. **Layer 2: Multimodal Intelligence** (Journey orchestration - our immediate differentiation)
3. **Layer 3: AI Core** (Future phase - implement AFTER core is proven)

---

## **LAYER 1: FUNDAMENTALS** 
*Non-negotiable. Every transit app must nail these.*

### **1.1 Real-Time Data Display**

**Core Requirements:**
- ✅ Live vehicle positions (bus, train, ferry, light rail, metro)
- ✅ Countdown timers (minutes until departure)
- ✅ Real-time delays/early arrivals
- ✅ Platform/stop numbers
- ✅ Service status indicators (on time, delayed, cancelled)

**Data Source Dependencies:**
- GTFS-RT feeds (Vehicle Positions, Trip Updates, Service Alerts)
- Need to verify: Which modes have real-time data in each city?
  - Sydney: Excellent (all modes)
  - Melbourne: Good (Metro, trams, some buses)
  - Brisbane: Variable

**UI Requirements:**
- Visual indicators (color codes: green=on time, yellow=delayed, red=cancelled)
- "Real-time" badge/icon when live data available
- Graceful fallback to schedule when real-time unavailable

---

### **1.2 Service Alerts & Disruptions**

**Must Include:**
- ✅ System-wide alerts (track work, signal failures)
- ✅ Line-specific alerts
- ✅ Stop-specific alerts
- ✅ Planned disruptions (advance notice)
- ✅ Real-time incidents

**Notification Types:**
- Push notifications (user-controlled)
- In-app banners
- Alert icons on affected lines/stops
- Historical alerts (so users can see "what happened yesterday")

**Gap You Might Have Missed:**
- **Alert severity levels** (Critical/High/Medium/Low)
- **Alternative route suggestions** when disruption occurs
- **Subscribe to specific lines** for alerts only

---

### **1.3 Offline Capability**

**What Must Work Offline:**
- ✅ Static timetables (all lines, all stops)
- ✅ Stop locations and maps
- ✅ Saved trips
- ✅ Trip history
- ✅ Basic trip planning (schedule-based, not real-time)

**What Requires Connection:**
- Real-time updates
- Live vehicle tracking
- Service alerts
- Weather data
- AI features (initially - can optimize later)

**Architecture Note:**
- Use local SQLite database for GTFS static data
- Update weekly (automatic background sync)
- Cache last 24h of real-time data for offline resilience

---

### **1.4 Location Services**

**Core Features:**
- ✅ Auto-detect nearest stops (GPS-based)
- ✅ "Show nearby lines" from any location
- ✅ Distance to stops (meters/minutes walk)
- ✅ Sort stops by proximity

**Gap You Might Have Missed:**
- **Geofencing:** Trigger notifications when approaching stop
- **Background location:** Update "nearest stops" automatically
- **Location permissions:** Graceful degradation if denied
- **Indoor positioning:** Station/platform level (if supported by venue)

---

### **1.5 Favorites & Personalization**

**Save & Organize:**
- ✅ Favorite stops (unlimited)
- ✅ Favorite lines
- ✅ Saved trips (full journeys, not just legs)
- ✅ Frequent destinations
- ✅ Home/Work quick access

**Gap You Might Have Missed:**
- **Folders/Tags:** Organize trips ("Work commute", "Weekend", "Kids school")
- **Smart favorites:** Auto-suggest based on usage patterns
- **Sync across devices:** iCloud/Google account sync
- **Share trips:** Send trip to friend/family

---

### **1.6 Maps & Visualization**

**Map Features:**
- ✅ Interactive map with all stops
- ✅ Real-time vehicle positions on map
- ✅ Route lines overlaid
- ✅ Station facilities icons (elevator, parking, bathrooms)
- ✅ Switch map/satellite view

**Gap You Might Have Missed:**
- **Route preview:** Show full route line when selecting trip
- **Stop clusters:** Group nearby stops visually
- **3D buildings:** Context for navigation (especially at major stations)
- **Offline maps:** Download city maps for offline use
- **Accessibility layer:** Show accessible routes/elevators

---

### **1.7 Schedule & Timetable Access**

**Lookup Features:**
- ✅ Full timetables for any line
- ✅ Filter by direction
- ✅ Filter by time of day (peak/off-peak)
- ✅ Weekday/weekend/holiday schedules
- ✅ Future dates (plan weeks ahead)

**Gap You Might Have Missed:**
- **First/last service times:** Critical for late night planning
- **Frequency visualization:** "Every 10 mins" vs timetable
- **Express vs all-stops:** Show skip-stop services clearly
- **PDF export:** For offline printing (elderly users)

---

### **1.8 Additional Data Points (If API Provides)**

**Passenger Information:**
- ✅ Passenger load (crowding indicator)
- ✅ Seat availability estimates
- ✅ Wheelchair accessibility

**Vehicle Information:**
- ✅ Vehicle type (train carriages, bus type)
- ✅ Fleet number/ID (for enthusiasts/staff)
- ✅ Facilities on vehicle (bike racks, AC, toilets on trains)

**Station/Stop Information:**
- ✅ Platform facilities
- ✅ School bus information
- ✅ Interchange information
- ✅ Nearby amenities (cafes, ATMs if data available)

**Gap You Might Have Missed:**
- **Bike parking availability** at stations
- **Park & Ride** capacity
- **Kiss & Ride** zones
- **Taxi rank** locations

---

### **1.9 Notifications & Alarms**

**Types:**
- ✅ Service alerts
- ✅ Departure reminders ("Leave in 10 mins")
- ✅ Arrival alarms ("Your stop in 2 stops")
- ✅ Delay notifications

**Controls:**
- Per-line subscriptions
- Quiet hours
- Notification preferences (sound/vibrate/silent)
- Emergency alerts (always push through)

**Gap You Might Have Missed:**
- **Smart snooze:** "Remind me about next service"
- **Contact notifications:** "Tell me AND my wife when train delayed"
- **Recurring alarms:** "Every weekday at 8am"

---

### **1.10 Widgets & Extensions**

**iOS:**
- ✅ Home Screen widgets (small/medium/large)
- ✅ Lock Screen widgets
- ✅ Apple Watch complications
- ✅ Siri Shortcuts
- ✅ Live Activities (iOS 16.1+): Live countdown on lock screen
- ✅ Dynamic Island (iPhone 14 Pro+): Persistent trip tracking

**Gap You Might Have Missed:**
- **Today View widget:** Quick glance at next departure
- **Interactive widgets:** Tap to refresh, quick actions
- **Smart Stack integration:** Context-aware widget suggestions

---

## **LAYER 2: MULTIMODAL INTELLIGENCE**
*Journey orchestration - this is where you start differentiating*

### **2.1 Intelligent Trip Planning**

**Core Capability:**
```
Input: "Get me to Sydney University"
Output: Complete journey chain with all connections
- Walk 5 min to bus stop
- Bus 123 for 3 stops
- Transfer to train
- Train to Central
- Walk 8 min to campus
```

**Key Requirements:**
- ✅ **Single destination input** (not leg-by-leg)
- ✅ **Multi-modal routing** (walk + bus + train + ferry + bike)
- ✅ **Multiple route options** (fastest, least walking, least transfers)
- ✅ **Time-based planning** ("Arrive by 9am" or "Leave now")
- ✅ **Real-time-aware:** Factor in current delays

**Gap You Might Have Missed:**
- **Route preferences:**
  - Minimize walking
  - Prefer certain modes (no ferries, only trains)
  - Avoid specific lines/stops
  - Accessible routes only
  - Prefer express services
- **Cost comparison:** Show fare for each route option
- **Environmental impact:** CO2 saved vs driving
- **Alternative modes:** Show Uber/taxi cost/time comparison

---

### **2.2 Auto-Rerouting**

**Trigger Conditions:**
- ✅ Missed connection
- ✅ Service cancellation
- ✅ Major delay
- ✅ User deviates from planned route

**Behavior:**
- Automatically calculate next best option
- Push notification: "Missed connection. Taking next train at 9:15am"
- Update trip view in real-time
- No user intervention required (but allow manual override)

**Gap You Might Have Missed:**
- **Threshold settings:** How much delay before reroute? (user configurable)
- **Fallback modes:** If no good transit option, suggest Uber/taxi
- **Historical data:** "This connection is often missed - plan for next one?"
- **Manual reroute trigger:** "I'm running late, update my trip"

---

### **2.3 Connection Intelligence**

**Smart Connection Handling:**
- ✅ Realistic transfer times (not just schedule)
- ✅ Platform-to-platform walking time
- ✅ Buffer for delays ("Train running late, but connection waits")
- ✅ Alert if connection at risk

**Gap You Might Have Missed:**
- **Learn from users:** Crowdsource actual transfer times
- **Accessibility transfers:** Longer time if using elevator
- **Peak hour buffering:** Add extra time during rush hour
- **Station complexity:** Major stations (Central, Flinders St) need more time
- **"Guaranteed connections":** Highlight services that wait for delayed trains

---

### **2.4 Weather Integration**

**Phase 1 (MVP):**
- ✅ Current weather display at top of app
- ✅ Weather icon + temperature
- ✅ Basic alerts ("Raining - bring umbrella")

**Phase 2 (Post-MVP):**
- ✅ **Weather-aware routing:**
  - Prefer covered walkways when raining
  - Suggest underground paths
  - Avoid open-air stations in extreme heat
- ✅ **Delay predictions:** "Heavy rain - expect 5-10 min delays"
- ✅ **Wardrobe suggestions:** "Cold morning, 15°C"

**Gap You Might Have Missed:**
- **UV index:** Important in Australia (sun protection)
- **Severe weather alerts:** Storms, extreme heat, flash flooding
- **Pollen count:** For allergy sufferers
- **Air quality index:** Pollution/smoke (bushfire season)

**Data Source:**
- Bureau of Meteorology (BOM) API (free for Australia)
- OpenWeather API (backup/global)

---

### **2.5 GO Mode (Your Core Feature)**

**Concept:** Hands-free journey guidance from door to door

**Phases of Journey:**

**Pre-Departure:**
- "Leave in 12 minutes" notification
- Walking directions to first stop
- Real-time updates if service status changes

**At Stop:**
- "Your bus arrives in 3 minutes"
- Live vehicle tracking on map
- "Board at front door" or "Use Opal card"

**On Vehicle:**
- "You're on the right bus" confirmation
- "Your stop is 5 stops away"
- Progress indicator
- "Get ready to alight"

**Transfer:**
- "Get off now"
- Walking directions to next platform
- "Next train in 7 minutes, Platform 3"

**Arrival:**
- "Get off at next stop"
- Walking directions to final destination
- "You've arrived!"

**Technical Requirements:**
- GPS + motion activity detection (walking/stationary/on vehicle)
- Background location (with user permission)
- Low battery usage (<5% for 30 min trip)
- Works with lock screen notifications
- Voice announcements (optional)

**Gap You Might Have Missed:**
- **Confidence scoring:** "80% confident you're on correct bus"
- **Error recovery:** "Seems like wrong bus - checking..."
- **Pause/resume:** "Hold GO - bathroom break"
- **Share trip:** Live link for family to track your journey
- **Emergency button:** Quick contact if something goes wrong

---

### **2.6 Saved Multi-Leg Trips**

**Requirement:** Save entire journey as ONE trip, not individual legs

**Example:**
```
Trip name: "To Work"
- Home (address) to bus stop 3421 (walk)
- Bus 394 to Town Hall Station
- Train to Central
- Walk to office
```

**Features:**
- One-tap to start trip
- Smart triggers: "It's Monday 8am - start Work trip?"
- Reverse trip: Auto-create return journey
- Time variants: Save "To Work (Early)" and "To Work (Late)"

**Gap You Might Have Missed:**
- **Trip templates:** "Commute", "School run", "Airport", "Weekend"
- **Trip sharing:** Export trip to family member
- **Trip history:** "You've done this trip 47 times"
- **Trip analytics:** "Average journey time: 42 mins"
- **Conditional trips:** "If train delayed >10 mins, take bus instead"

---

### **2.7 Schedule Planning Ahead**

**Use Cases:**
- "What time should I leave on Saturday to arrive by 3pm?"
- "Plan my trip for next Tuesday 9am"
- "Show me all services to airport tomorrow"

**Requirements:**
- Access future timetables (weeks ahead)
- Account for weekend/holiday schedules
- Save planned trips for future dates

**Gap You Might Have Missed:**
- **Calendar integration:** Import events, suggest departure times
- **Recurring trips:** "Every Monday at 9am" auto-plan
- **Travel time estimates:** Based on historical data
- **Peak vs off-peak:** Show price differences

---

## **LAYER 3: AI CORE**
*Future phase - implement AFTER Layer 1 & 2 are production-ready*

**IMPORTANT:** This layer is NOT part of Phase 1 MVP. Build architecture to support it, but implement only after core transit features are rock-solid and proven in production.

### **3.1 Architecture Overview**

**Core Concept:** LLM as Central Orchestrator

```
User Input (Voice/Text)
       ↓
   LLM Core (On-device or API)
       ↓
   Tool Layer (Functions the LLM can call)
       ↓
   Data Layer (GTFS, User data, Context)
       ↓
   UI Layer (Dynamic rendering based on AI decisions)
```

**Critical Decisions:**

**Decision 1: On-Device vs API-Based LLM?**

| Option | Pros | Cons |
|--------|------|------|
| **On-Device (Apple Intelligence)** | • Free<br>• Privacy<br>• Low latency<br>• Works offline | • Limited capability<br>• No voice synthesis<br>• iOS 18+ only |
| **API-Based (GPT-4, Gemini)** | • Powerful reasoning<br>• Voice I/O<br>• Multi-language | • Cost per call<br>• Requires internet<br>• Latency<br>• Privacy concerns |
| **Hybrid** | • Best of both<br>• On-device for simple<br>• API for complex | • Complex architecture<br>• More code to maintain |

**Recommendation:** Start with **Hybrid**
- On-device LLM for:
  - Simple queries ("When is next bus?")
  - UI suggestions ("Show this differently")
  - Local data processing
- API-based for:
  - Voice conversations (multilingual)
  - Complex reasoning ("Plan my entire day")
  - Learning user preferences

---

### **3.2 Tool Layer (LLM Functions)**

**What Tools Will the LLM Have Access To?**

**Transit Data Tools:**
```typescript
// Pseudo-code for LLM tools

1. get_next_departures(stop_id, line_filter?, limit?)
   → Returns next N departures from a stop

2. search_stops(query, lat, lon, radius)
   → Find stops by name or proximity

3. plan_trip(origin, destination, time?, preferences?)
   → Generate multi-modal route

4. get_service_alerts(line?, severity?)
   → Fetch current disruptions

5. get_vehicle_position(vehicle_id)
   → Live tracking of specific vehicle

6. get_stop_facilities(stop_id)
   → Accessibility, amenities info

7. search_address(query)
   → Geocode address to coordinates
```

**User Context Tools:**
```typescript
8. get_user_location()
   → Current GPS position

9. get_saved_trips()
   → User's favorite journeys

10. get_trip_history()
    → Past journeys for pattern learning

11. get_user_preferences()
    → Walk speed, mode preferences, accessibility needs

12. get_calendar_events()
    → Upcoming appointments (with permission)

13. set_reminder(time, message)
    → Schedule notification
```

**External Tools:**
```typescript
14. get_weather(location, time?)
    → Current/forecast weather

15. calculate_uber_estimate(origin, destination)
    → Alternative transport cost

16. get_time()
    → Current time/date
```

---

### **3.3 AI Interaction Modes**

**Mode 1: Conversational Interface**

User can talk naturally:
- "Get me home before 6pm"
- "What's the fastest way to Circular Quay?"
- "My train is delayed, what should I do?"
- "Napisan burun kısılığına iyi gelir" (Elderly person speaking Turkish)

**Technical Requirements:**
- Speech-to-text (STT)
- LLM processing with tools
- Text-to-speech (TTS) - multilingual
- Conversation memory (multi-turn)

**Gap You Might Have Missed:**
- **Interrupt handling:** User cuts off AI mid-sentence
- **Clarification:** "Did you mean Central Station or Central Park?"
- **Confirmation:** "I'll plan your trip to Sydney Uni, okay?"
- **Error recovery:** "Sorry, I didn't understand. Can you repeat?"

---

**Mode 2: Proactive Assistant**

AI suggests actions WITHOUT being asked:

**Examples:**
- 8am Monday: "Time to leave for work in 10 minutes"
- Meeting in calendar: "Your 2pm meeting is at Parramatta. Leave by 1:15pm"
- Weather change: "It's going to rain this afternoon. Take umbrella for your trip home"
- Service alert: "Your usual train line has delays. Alternative route available?"

**Technical Requirements:**
- Background processing
- Context awareness (time, location, calendar)
- Smart notification timing (not spam)
- User permission model

**Gap You Might Have Missed:**
- **Learning loop:** If user ignores suggestion, adjust future behavior
- **Confidence thresholds:** Only suggest when AI is confident
- **Snooze options:** "Remind me in 5 minutes"
- **Opt-out:** Easy to disable proactive mode

---

**Mode 3: UI Intelligence**

AI dynamically changes interface based on context:

**Examples:**
- User frequently checks bus 394 → Surface it at top automatically
- User always takes train instead of bus → Prioritize train routes
- User struggles with map → Switch to list view
- Peak commute time → Show "Crowding: High" warning

**Technical Requirements:**
- UI component system (React Native/SwiftUI)
- AI can trigger UI state changes
- A/B testing to validate AI decisions
- Manual override (user can adjust)

**Gap You Might Have Missed:**
- **Personalization privacy:** Clear about what AI learns
- **Reset option:** "Forget my preferences"
- **Explain mode:** "Why are you showing this?"
- **Manual tuning:** User can adjust AI behavior

---

### **3.4 Voice AI for Accessibility**

**Primary Users:**
- Elderly (not tech-savvy)
- Immigrants (non-English speakers)
- Visually impaired
- Children (guided mode)

**Key Features:**
- Multilingual voice I/O (40+ languages via Gemini/GPT)
- Simplified interface (large buttons, high contrast)
- Voice-only mode (no screen needed)
- Step-by-step guided mode
- Emergency contact integration

**Example Flow (Elderly User):**
```
User: "I need to go to the doctor" (in Greek)
AI: "Okay, where is your doctor?" (in Greek)
User: "Randwick hospital"
AI: "I'll plan your trip. You need to leave in 15 minutes. 
     I'll tell you when to walk to the bus stop."
[15 minutes later]
AI: "Time to leave. Walk out your front door and turn left..."
```

**Technical Challenges:**
- Voice models are expensive ($0.01-0.10 per minute)
- Latency must be low (<2 seconds)
- Multilingual support needs testing
- Must work offline (fallback to on-device voice)

**Cost Management:**
- Free for elderly/accessibility users (social good + PR)
- Premium feature for everyone else ($4.99/month)
- On-device voice for simple commands (free)
- API voice for conversations (paid)

---

### **3.5 AI Architecture Risks & Mitigations**

**Risk 1: AI Hallucinations**
- **Problem:** LLM makes up departure times or routes
- **Mitigation:** 
  - ALWAYS validate LLM output against real data
  - If LLM suggests something not in GTFS data, reject it
  - Show confidence scores
  - Manual override always available

**Risk 2: Cost Explosion**
- **Problem:** API calls for voice/LLM get expensive fast
- **Mitigation:**
  - Hybrid on-device/API approach
  - Cache frequent queries
  - Batch API calls where possible
  - Usage limits for free tier
  - Monitor cost per user per month

**Risk 3: Privacy**
- **Problem:** Sending location/calendar data to AI APIs
- **Mitigation:**
  - Local processing where possible
  - Anonymize data sent to APIs
  - Clear privacy policy
  - User controls what data AI can access
  - GDPR/privacy law compliance

**Risk 4: Latency**
- **Problem:** API calls take 2-5 seconds, feels slow
- **Mitigation:**
  - Optimistic UI updates
  - Streaming responses (show partial results)
  - Precompute common queries
  - On-device LLM for instant responses

**Risk 5: Reliability**
- **Problem:** API down = app broken
- **Mitigation:**
  - Graceful degradation (app works without AI)
  - Fallback to rule-based logic
  - Cache AI responses
  - Multiple API providers (failover)

---

## **SUMMARY: Feature Priority Matrix**

**Platform:** iOS only (Swift/SwiftUI)
**Geographic Scope:** Sydney, Melbourne, Brisbane
**Phase 1 Goal:** Match/exceed TripView + Transit core features

| Feature | Priority | Complexity | Launch Phase |
|---------|----------|------------|--------------|
| **LAYER 1: Fundamentals** |
| Real-time departures | P0 | Low | Phase 1 MVP |
| Service alerts | P0 | Low | Phase 1 MVP |
| Offline schedules | P0 | Medium | Phase 1 MVP |
| Location awareness | P0 | Low | Phase 1 MVP |
| Favorites | P0 | Low | Phase 1 MVP |
| Maps + stops | P0 | Medium | Phase 1 MVP |
| Push notifications | P0 | Medium | Phase 1 MVP |
| Widgets | P1 | Medium | Phase 1 Post-launch |
| Live Activities | P1 | Medium | Phase 1 Post-launch |
| **LAYER 2: Multimodal** |
| Trip planning | P0 | High | Phase 1 MVP |
| Multi-modal routing | P0 | High | Phase 1 MVP |
| Saved multi-leg trips | P0 | Medium | Phase 1 MVP |
| GO mode (basic) | P1 | High | Phase 1 Post-launch |
| Weather display | P1 | Low | Phase 1 MVP |
| Auto-rerouting | P1 | High | Phase 1 Post-launch |
| GO mode (advanced) | P2 | High | Phase 2 |
| Weather routing | P2 | Medium | Phase 2 |
| **LAYER 3: AI Core** (Phase 2+) |
| Architecture prep | P1 | Medium | Phase 1 (design only) |
| On-device LLM integration | P0 | High | Phase 2 |
| Text-based AI assistant | P0 | High | Phase 2 |
| Proactive suggestions | P1 | High | Phase 2 |
| Voice AI (English) | P1 | Very High | Phase 3 |
| Voice AI (multilingual) | P1 | Very High | Phase 3 |
| UI intelligence | P2 | High | Phase 3 |

---

## **NEXT STEPS**

**Before Phase 1 development:**

1. **API Data Audit** (CRITICAL)
   - Audit Sydney/Melbourne/Brisbane GTFS feeds
   - Real-time availability by mode/city
   - Update frequencies and reliability
   - Identify gaps/workarounds needed
   - Validate all 3 cities are feasible

2. **Phase 1 MVP Scope Lock**
   - Lock P0 features for first release (Layer 1 + core Layer 2)
   - Define free vs premium tiers
   - Identify "wow" differentiator that doesn't require AI

3. **Technical Architecture Document**
   - iOS app architecture (Swift/SwiftUI)
   - Backend design (modular, serves iOS + marketing site)
   - Database schema (GTFS + user data, offline-first)
   - API layer design
   - Future AI layer architecture (design only, implement Phase 2+)

4. **Financial Model**
   - Infrastructure costs (backend, hosting, data storage)
   - Development timeline estimate
   - Pricing strategy validation
   - Break-even analysis

5. **iOS Technical Decisions**
   - Minimum iOS version (15+ vs 17+)
   - Key frameworks and dependencies
   - Offline data strategy
   - Backend tech stack

**Platform Clarifications:**
- iOS only (Swift/SwiftUI native)
- Web application: 2026+ for government/agency analytics dashboards (separate use case)
- Backend: Modular system serving iOS app + marketing site