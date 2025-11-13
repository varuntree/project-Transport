# Transit App - Complete Project Documentation
**Last Updated:** October 30, 2025
**Project:** Best-in-class Australian Transit App (Sydney MVP → National Expansion)

---

## 📑 Table of Contents

### Part 1: Project Overview & Strategy
1. **Project Context** - Vision, market validation, competitive landscape, strategic decisions
2. **Feature Specification** - 3-layer architecture (Fundamentals, Multimodal, AI)
3. **Phase 1 Feature Map** - Sydney MVP implementation plan

### Part 2: Technical Research
4. **Government Transit APIs** - Sydney/Melbourne/Brisbane GTFS data sources
5. **iOS Native Capabilities** - MapKit, WeatherKit, CoreLocation, WidgetKit, ActivityKit
6. **GTFS Standards** - Specification, data structures, routing algorithms
7. **Swift Transit Libraries** - GTFS parsers, frameworks, open source apps
8. **Offline Data Strategy** - SQLite implementation, storage optimization
9. **Routing Solutions** - OpenTripPlanner, cloud APIs, build vs buy analysis
10. **Competitor Architecture** - TripView, Transit, NextThere technical insights
11. **Backend Patterns** - Modular monolith, REST API, hosting, cost analysis

---

## Strategic Summary

**What We're Building:**
- iOS transit app for Sydney (Phase 1) → Melbourne/Brisbane (Phase 2+)
- TripView reliability + Transit features + modern iOS UX
- Offline-first, privacy-focused, <50MB app size
- Freemium model ($4.99/mo premium)

**Key Decisions:**
- Platform: iOS only (Swift/SwiftUI), iOS 16+ minimum
- Backend: FastAPI (Python), PostgreSQL, Redis, Next.js (static) for marketing
- Data: NSW GTFS (227MB) + NSW Trip Planner API
- Timeline: 14-18 weeks to Phase 1 MVP
- Cost: $25-50/mo infrastructure initially

**Differentiation:**
- Phase 1: Match TripView reliability, exceed Transit features
- Phase 2+: AI orchestration layer (voice, proactive suggestions)
- Phase 3: Accessibility features (multilingual voice)

---

# Project Context Document
## Transit AI Application - Session Continuation Guide

---

## 🎯 PROJECT VISION

**Building:** The best public transit app in Australia - reliability-first, then enhanced with AI capabilities.

**Platform:** iOS application (primary), Web application (2026 - government/agency analytics dashboards)

**Not building:** Another timetable lookup app with gimmicks before nailing fundamentals

**Mission:** Be the definitive transit app in Australia - start with Sydney, expand nationwide, nail core functionality first, layer intelligence after.

---

## 📊 MARKET VALIDATION (Completed)

### Market Size
- **6.4M regular transit users** across Sydney, Melbourne, Brisbane
- **11.87M Australians** use public transport at least quarterly (54.6% of population)
- **87% smartphone penetration** in Australia (23M+ users)
- **Peak usage during commute hours** - perfect timing for app adoption

### Existing Market Evidence
- **TripView** (main competitor): 500K-1M active users, $7.99 one-time payment
  - Android: ~460K paid downloads, ~2.8M free downloads
  - 197K ratings, 4.8/5 stars (exceptional satisfaction)
  - Estimated $2.5M+ revenue from one-time purchases
  - **Problem:** Dated UI, no recurring revenue model, limited innovation

### Willingness to Pay
- **Proven demand:** 460K+ paid for TripView despite limited features
- **Market trend:** Premium transit app subscriptions grew 34% in 2022
- **User behavior:** Australians spend average $15/month on app subscriptions
- **Comparable success:** Transit app maintains 70% retention over 6 months with freemium model

### Decision: **STRONG GO** (8.5/10 validation score)
- ✅ Massive proven market
- ✅ Incumbent stagnant (TripView hasn't innovated in years)
- ✅ Strong willingness to pay
- ✅ Perfect timing (on-device AI just became accessible)
- ✅ Clear differentiation opportunities

---

## 🏢 COMPETITIVE LANDSCAPE (Deep Research Completed)

### Competitor 1: **NextThere**
- **Philosophy:** Extreme simplicity - "platform indicator in palm of your hand"
- **Rating:** 4.6/5 stars
- **Pricing:** $0.99/month or $3.99/year (NextThere Pro)
- **Coverage:** All major Australian cities + NZ + limited US
- **Key Feature:** Auto-shows next 3 services from nearest saved stop
- **Limitation:** Only 3 saved stops in free version, basic features, no trip planning
- **Strength:** Perfect for regular commuters with fixed routes, very fast

### Competitor 2: **TripView / TripView Lite**
- **Philosophy:** Reliability and offline-first
- **Rating:** 4.8/5 stars (197K ratings)
- **Pricing:** $7.99 iOS / $5.49 Android (one-time) | Free (Lite with ads)
- **Coverage:** Sydney, Melbourne, Brisbane only
- **Key Feature:** All timetables stored locally, works fully offline
- **Limitation:** 
  - Can't save trips in free version (major frustration)
  - Dated UI (looks like 2015 app)
  - "Overly complicated" trip creation - can't add routes by map/address
  - Users complain: "Real-time data unavailable all the time, GPS signal lost"
- **Strength:** Extremely reliable, high user loyalty, privacy-focused

### Competitor 3: **Transit**
- **Philosophy:** Comprehensive, community-driven, storytelling-focused
- **Rating:** 4.4/5 stars
- **Pricing:** Free + Transit Royale (~$4.99/month)
- **Coverage:** 600+ cities globally
- **Revolutionary Feature: GO Mode**
  - Personal public transport companion
  - Step-by-step guidance from door to door
  - Notifications: "Leave now!", "Hurry up!", "Your stop is X stops away", "Time to get off!"
  - Uses GPS + motion detection to know if walking/waiting/on-bus
  - Auto-switches if you miss connection
  - Lock screen Live Activities / Dynamic Island integration
  - Crowdsourcing: shares your location to improve data for others
  - Gamification: leaderboards, Rate-My-Ride
  - ~5% battery for 20-min trip, <100kb data
- **Other Features:**
  - Multi-modal integration (bus+bike, scooter+metro, ride-shares)
  - Offline schedules + maps
  - Real-time tracking
  - Service alerts
- **Limitations:**
  - Recent update complaints: "harder to tell which bus", "notifications after stop not before"
  - Paywall frustration: Free shows only 4 nearby lines, rest behind Royale paywall
  - GO doesn't work with multi-modal trips
  - Can't save favorite routes (only locations)
- **Strength:** Most comprehensive features, modern engaging design, global reach

### Key Insight
**Table Stakes** (everyone does this):
- Real-time departures with countdown
- Service alerts
- Offline schedules
- Map integration
- Location awareness
- Save favorites

**Innovation Gaps** (our opportunities):
1. **Proactive guidance:** Only Transit has GO, but incomplete
2. **Voice AI:** NO ONE has conversational voice assistance
3. **Life integration:** NO ONE connects calendar, weather, contacts
4. **Accessibility:** Only basic support - huge gap for elderly/immigrants/non-English speakers
5. **Predictive AI:** NO ONE anticipates needs before asking
6. **Generous free tier:** All have annoying restrictions

---

## 💡 KEY STRATEGIC INSIGHTS & DECISIONS

### Technology Timing is Perfect
- **On-device LLMs** now available (Apple Intelligence, Android AI)
- **Voice AI APIs** accessible (Gemini, GPT live audio models)
- **Government data FREE** (GTFS APIs from Transport NSW, PTV, TransLink)
- **No data acquisition costs** - all transit data is open

### Breakthrough Ideas Identified

**1. Voice AI for Accessibility**
- Live voice AI models can speak ANY language
- Proactive voice guidance instead of just alerts
- **Target:** Elderly, immigrants, children who struggle with complex apps
- **Business model:** Free for elderly/accessibility use cases, but majority will have family willing to pay

**2. Autopilot Mode Concept**
- User wakes up → app knows morning meeting at 9am
- 7:43am notification: "Leave in 12 minutes. Train in 15 minutes. It's raining, take umbrella."
- Zero cognitive load - AI orchestrates everything
- **This is what Transit GO tried to be but didn't execute fully**

**3. Life Orchestration vs Timetables**
Core insight: "Users don't just need timetables - they need a proactive AI companion that orchestrates their entire day around an unpredictable transit system"

### User Strategy
**Target:** All Australians using public transit - no demographic segmentation
- **Everyone gets the SAME app:** Best-in-class transit functionality for all users
- **Core must be exceptional:** Reliability, accuracy, speed - match/exceed TripView/Transit
- **AI layer comes later:** After fundamentals are rock-solid

### Build Philosophy Established
1. **iOS only** - focused platform, no Android
2. **Fundamentals first** - nail core transit features before AI/voice
3. **Sydney-first** - perfect one city (NSW) before expanding to Melbourne/Brisbane
4. **Modular architecture** - easy to add cities later, backend serves iOS app + marketing site
5. **FastAPI backend** - Python for API + background workers, Next.js (static) for marketing site
6. **Low app size** - aggressive optimization, smart caching (<50MB initial download)
7. **Match then exceed competitors** - TripView reliability + Transit features + better UX
8. **Generous free tier** - learn from competitors' paywall mistakes
9. **Web later** (2026) - government/agency analytics dashboards, not user-facing transit app

---

## 🏗️ CURRENT STATE & PROGRESS

### Completed
1. ✅ **Market validation** (6.4M TAM, proven willingness to pay)
2. ✅ **Competitor deep-dive** (NextThere, TripView, Transit analyzed)
3. ✅ **Strategic positioning** identified (fundamentals-first, AI later)
4. ✅ **Revenue model** conceptualized (freemium, $4.99/month premium tier)
5. ✅ **Technology landscape** mapped (GTFS APIs, on-device AI, voice APIs)
6. ✅ **Differentiation strategy** defined (TripView reliability + Transit features + iOS polish)
7. ✅ **Feature specification document** (3-layer architecture defined)
8. ✅ **Comprehensive research** (8 technical documentation files created):
   - Government APIs (Sydney/Melbourne/Brisbane GTFS schemas)
   - iOS native capabilities assessment
   - GTFS standards & routing algorithms
   - Swift transit libraries catalog
   - Offline data strategy
   - Routing solutions analysis
   - Competitor architecture insights
   - Backend architecture patterns

### In Progress
- Strategic decisions finalized (Sydney-first, FastAPI backend, low app size)
- High-level architecture planning

### Not Yet Started
- Technical architecture specification (detailed)
- Financial model (unit economics, cost structure)
- Development roadmap with timelines
- UI/UX design

---

## 🎯 STRATEGIC POSITIONING

**Phase 1 Goal:** Best transit app in Australia (core functionality)
**Phase 2 Goal:** Add AI/voice layer competitors don't have

**Immediate Differentiators (Phase 1):**
1. **TripView reliability** + Transit features + modern UX
2. **Generous free tier** (don't artificially limit core features)
3. **Sydney perfection** - nail one city completely before expanding
4. **iOS-focused polish** (better than cross-platform competitors)
5. **Ultra-lightweight** - <50MB app vs competitors' 100-200MB bloat
6. **Modular architecture** (future-ready for AI layer + city expansion)

**Future Differentiators (Phase 2+):**
1. Voice AI assistant (multilingual, accessible)
2. Proactive autopilot mode (calendar integration, weather-aware)
3. Life orchestration layer

**Positioning vs competitors:**
- **vs NextThere:** More comprehensive features, same simplicity
- **vs TripView:** Modern UX, same reliability, better trip planning
- **vs Transit:** iOS-focused polish, more generous free tier

---

## 📈 REVENUE OPPORTUNITY

### Conservative Model
- **Target:** 5% market share = 320,000 users
- **Pricing:** $4.99/month or $39.99/year
- **Revenue:** $12.8M - $15.4M annually

### Moderate Model  
- **Target:** 10% market share = 640,000 users
- **Revenue:** $25.6M - $30.7M annually

### Cost Considerations
- Voice AI APIs are expensive (need cost optimization strategy)
- Plan: Use on-device AI for simple tasks, API for complex conversations
- Subsidize elderly/accessibility users (good PR, social impact)

---

## 🛠️ TECHNOLOGY FOUNDATIONS

### Data Sources (Free & Available)
- **Sydney:** Transport NSW Open Data Hub (GTFS feeds, Trip Planner APIs)
- **Melbourne:** Public Transport Victoria APIs (GTFS + real-time feeds)
- **Brisbane:** TransLink Queensland (GTFS + GTFS-RT feeds)

### AI Capabilities (Future Phases)
- **On-device AI:** iOS 18+ (Apple Intelligence)
- **Voice AI APIs:** Gemini live audio, GPT-4o real-time audio
- **Standard APIs:** Calendar, Weather, Location, Notifications

### Architecture Principles
1. **Platform:** iOS only (Swift/SwiftUI), iOS 16+ minimum
2. **Backend:** FastAPI (Python) for API + background workers, Next.js (static) for marketing site
3. **Geographic:** Sydney/NSW first, modular for Melbourne/Brisbane later
4. **Storage:** SQLite + GRDB (227MB NSW GTFS optimized to ~300MB on-device)
5. **Routing:** NSW Trip Planner API (60K free calls/day) + local caching
6. **Native-first:** MapKit, WeatherKit, CloudKit, Live Activities
7. **Libraries:** Minimal (GRDB, SwiftDate, SwiftProtobuf only)
8. **App size:** <50MB initial, optional offline data download
9. **Future AI layer:** Pluggable, modular (Phase 2+)

---

## 🎬 NEXT STEPS (Where We Continue)

### Immediate (Next Session)
1. **Finalize feature specification**
   - Core features (what everyone needs)
   - AI features (our differentiation)
   - Free vs Premium tier boundaries
   - Accessibility features

2. **Define technical architecture**
   - System components and modules
   - Data flow diagrams
   - API integration strategy
   - AI orchestration approach

3. **Create financial model**
   - Unit economics
   - Cost structure (especially voice AI costs)
   - Pricing strategy validation
   - Break-even analysis

4. **Develop competitive moat strategy**
   - What makes us defensible?
   - Network effects plan
   - Data advantages
   - Brand positioning

### Near-term
- UI/UX wireframes
- Development roadmap
- Technology stack decisions
- Team requirements

---

## 🧠 CRITICAL CONTEXT FOR CONTINUATION

### Philosophy Reminders
- **Best transit app first** - nail fundamentals before AI features
- **iOS only** - focused, polished, native
- **Everyone deserves simplicity** - no demographic segmentation, all users get same app
- **All 3 cities** - Sydney, Melbourne, Brisbane from launch
- **Generous free tier** - competition's paywalls are opportunity
- **Future vision:** AI/voice layer after core is proven

### Self-Funded Reality
- Must be financially sustainable (bootstrapped, no VC)
- Cost-effective architecture (modular backend, native iOS)
- Freemium model with generous free tier

### Vision Beyond Phase 1
- **Phase 1:** Best transit app in Australia (core features)
- **Phase 2:** Add AI orchestration layer
- **Phase 3:** Voice/accessibility features
- **Future:** Gov/agency analytics web platform (2026+)

### Build Right, Not Fast
- Modular architecture allows AI evolution
- Don't rush - TripView took years to reach 500K users
- Quality > Speed (reliability is table stakes)

---

## ✅ STRATEGIC DECISIONS LOCKED

**Geographic Scope:** Sydney/NSW only for Phase 1
- NSW has best API (227MB GTFS, daily updates, 5 req/s, all modes real-time)
- Modular architecture for easy Melbourne/Brisbane expansion
- Perfect one city before multi-city complexity

**Backend Stack:** FastAPI (Python) + Next.js (static)
- FastAPI for REST API + background workers (GTFS polling, alerts, APNs)
- Next.js (SSG) for marketing site only
- Hosting: Railway/Fly.io (backend), Vercel (marketing site)
- PostgreSQL + Redis for data/caching

**App Size Priority:** Must be low (<50MB initial download)
- Challenge: 227MB NSW GTFS data
- Solution: Optional offline data, aggressive caching, smart compression
- Learn from TripView (5.44MB) not Transit (196MB bloat)

**iOS Version:** iOS 16+ (96% market coverage)
- Gets: WeatherKit, Live Activities, Lock widgets
- Native capabilities: MapKit, CloudKit, CoreLocation

**Libraries:** Minimal dependencies
- GRDB (SQLite wrapper)
- SwiftDate (timezone handling)
- SwiftProtobuf (GTFS-RT parsing)

## 📋 QUESTIONS STILL TO ANSWER

1. **MVP scope cutline?**
   - Which Layer 1 features are P0 for first release?
   - Which can be P1 (post-launch)?

2. **Routing approach?**
   - NSW Trip Planner API only (simplest, 60K free/day)?
   - Build custom routing (more control, 10-16 weeks)?
   - Hybrid (API + local fallback)?

3. **Phase 1 "wow" feature?**
   - Live Activities for trip tracking?
   - Weather-aware suggestions?
   - GO mode basics?

4. **Revenue timeline?**
   - Need revenue in 6 months → focus premium early
   - Can wait 12 months → focus user growth first

5. **Offline strategy?**
   - Full offline (227MB download, TripView model)?
   - Cloud-first with caching (lighter app)?
   - Hybrid (WiFi background download)?

---

## 📁 COMPANION DOCUMENTS

This context file should be read alongside:
- **Feature Specification Document** (created at end of last session)
- **Competitor Analysis** (detailed in this context, full version available)
- **Market Validation Report** (summarized above)

---

**Status:** Ready to continue with feature specification finalization and move to technical architecture definition.

**Last Updated:** End of Session 1  
**Next Session Goal:** Finalize features, begin technical architecture# **FEATURE SPECIFICATION: Three-Layer Architecture**

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
- Backend: Modular system serving iOS app + marketing site# Phase 1 Feature Map - Sydney MVP
**Target:** Best transit app in Sydney - TripView reliability + Transit features + iOS polish

---

## 🎯 Strategic Focus

**Geographic:** Sydney/NSW only
**Platform:** iOS 16+, Swift/SwiftUI
**Backend:** FastAPI (Python), PostgreSQL, Redis, Next.js (static) for marketing
**Data:** NSW GTFS (227MB) + NSW Trip Planner API
**App Size:** <50MB initial download, optional offline data

---

## Core Features (P0 - Must Have for Launch)

### 1. Real-Time Departures
**What:** Live countdown timers for all Sydney transit modes
- Sydney Trains, Metro, Buses, Ferries, Light Rail
- Next 3-5 departures per stop/platform
- Real-time delays/cancellations (NSW GTFS-RT, 10-15s updates)
- Accessibility info (wheelchair accessible vehicles)

**UI:**
- Clean list view with countdown
- Color-coded by mode (train/bus/ferry)
- Tap for trip details

**Data Source:** NSW GTFS-RT vehicle positions + trip updates

---

### 2. Stop/Station Search & Nearby
**What:** Find stops quickly by name or location
- Search by stop name/number
- "Nearby" view showing closest stops (geofenced radius)
- Map view with stop pins

**Native:**
- CoreLocation for user position
- MapKit for map display

**Data Source:** NSW GTFS stops.txt (local SQLite)

---

### 3. Service Alerts
**What:** Real-time disruption notifications
- System-wide alerts (track work, cancellations)
- Mode-specific filtering (show only trains)
- Push notifications for favorites

**UI:**
- Alert banner at top
- Dedicated alerts tab
- Affected lines highlighted

**Data Source:** NSW GTFS alerts feed

---

### 4. Favorites & Quick Access
**What:** Save frequently used stops/routes
- Tap to favorite any stop
- Home screen shows favorited stops with next departures
- Swipe to reorder

**Sync:** CloudKit for cross-device favorites

---

### 5. Trip Planning
**What:** Multi-modal journey planning door-to-door
- Enter origin + destination (address, stop, landmark)
- Multiple route options (fastest, least walking, accessible)
- Walk + transit combinations
- Real-time-aware (accounts for delays)

**Data Source:** NSW Trip Planner API (60K free calls/day)
**Fallback:** Local GTFS routing if API unavailable

---

### 6. Maps & Route Visualization
**What:** See routes on map
- Live vehicle positions (buses, trains, ferries)
- Route shapes visualization
- Stop locations

**Native:** MapKit for base maps

---

### 7. Push Notifications
**What:** Proactive alerts
- Service disruptions affecting favorites
- Departure reminders (optional)
- Time-sensitive notifications (iOS priority)

**Native:** APNs

---

## Enhanced Features (P1 - Post-Launch)

### 8. Widgets
- Home screen widgets (small/medium/large)
- Lock screen widgets (iOS 16+)
- Next departure for favorite stop

### 9. Live Activities
- Trip tracking with countdown (iOS 16.1+)
- Dynamic Island integration (iPhone 14 Pro+)
- "2 stops away" notifications

### 10. Saved Trips
- Save common journeys (home → work)
- One-tap to view next departure times

### 11. GO Mode (Basic)
- Step-by-step guidance during journey
- Notifications: "Board now", "2 stops away", "Next stop"
- GPS-based position tracking

### 12. Weather Integration
- Display current weather
- Rain warnings for walking portions

**Native:** WeatherKit (iOS 16+)

### 13. Offline Schedules
- Optional: Download full NSW GTFS (~300MB optimized SQLite)
- Works without internet (schedules only, no real-time)
- WiFi background download via Background Assets

---

## Feature Comparison vs Competitors

| Feature | Our App | TripView | Transit | NextThere |
|---------|---------|----------|---------|-----------|
| Real-time departures | ✅ All modes | ✅ All modes | ✅ All modes | ✅ Limited |
| Service alerts | ✅ Push + in-app | ✅ In-app only | ✅ Push + in-app | ❌ |
| Trip planning | ✅ Multi-modal | ✅ Basic | ✅ Advanced | ❌ |
| Offline mode | 🟡 Optional | ✅ Full | ✅ Partial | ❌ |
| Live Activities | ✅ iOS 16+ | ❌ | ✅ | ❌ |
| Widgets | ✅ All types | ✅ Basic | ✅ Advanced | ✅ Basic |
| GO mode | 🟡 P1 | ❌ | ✅ | ❌ |
| App size | <50MB | 5.44MB | 196MB | 119MB |
| Free tier | Generous | Limited | Restricted | 3 stops only |

---

## Free vs Premium Tiers

### Free (Generous)
✅ Real-time departures (unlimited stops)
✅ Service alerts
✅ Trip planning (unlimited)
✅ Maps & live vehicles
✅ Favorites (unlimited)
✅ Basic widgets
✅ Push notifications

### Premium ($4.99/month or $39.99/year)
✨ Live Activities & Dynamic Island
✨ GO mode (step-by-step guidance)
✨ Offline mode (full GTFS download)
✨ Weather-aware suggestions
✨ Advanced widgets (lock screen, interactive)
✨ Trip history & analytics
✨ Priority support

**Philosophy:** Don't paywall core features (learn from Transit's mistake)

---

## Technical Implementation

### iOS App Architecture
```
/SenseTransit (iOS App)
  /Core
    /Models       # GTFS data models (Stop, Route, Trip)
    /Services     # API clients (NSW API, GTFS-RT)
    /Database     # GRDB/SQLite layer
  /Features
    /Departures   # Real-time departure views
    /Search       # Stop search & nearby
    /TripPlanner  # Journey planning
    /Favorites    # Saved stops
    /Alerts       # Service alerts
    /Maps         # MapKit integration
  /Shared
    /UI           # Reusable components
    /Extensions   # Swift extensions
    /Utils        # Helpers
  /Widgets        # WidgetKit extensions
  /LiveActivities # ActivityKit
```

### Backend Architecture (FastAPI)
```
/app
  /api
    /gtfs         # GTFS data sync & parsing endpoints
    /realtime     # GTFS-RT proxy/cache endpoints
    /trips        # Trip planning (NSW API wrapper)
    /alerts       # Alert aggregation endpoints
    /users        # Auth (Apple Sign-In)
    /favorites    # User data sync (if not using CloudKit)
    /push         # APNs notification delivery
  /workers
    /gtfs_poller  # Background job: GTFS-RT polling (Celery)
    /alert_engine # Background job: Alert matching
    /apns_worker  # Background job: Push notification delivery
  /models         # SQLAlchemy database models
  /schemas        # Pydantic request/response schemas
  /services       # Business logic layer
  /utils          # Helpers, Redis abstractions
```

### Data Flow
1. **Static GTFS:** Daily sync from NSW → PostgreSQL → SQLite export for iOS
2. **Real-time:** iOS polls FastAPI → FastAPI caches NSW GTFS-RT (Redis, 15s TTL via Celery worker)
3. **Trip planning:** iOS → FastAPI → NSW Trip Planner API → Cache → iOS
4. **Favorites:** CloudKit sync (no backend needed)

---

## App Size Optimization Strategy

**Target:** <50MB initial download

### How:
1. **No bundled GTFS data** - download on-demand
2. **Minimal dependencies** (GRDB, SwiftDate, SwiftProtobuf only)
3. **Asset catalog optimization** - compress images
4. **On-demand resources** - download rarely used assets
5. **Aggressive code stripping** - remove unused symbols

**Optional Offline Data:**
- User opts in to download NSW GTFS
- Background download via WiFi (Background Assets framework)
- ~300MB optimized SQLite database
- "Low Storage Mode" - skip shapes, reduce indexes (~40% savings)

---

## Phase 1 Timeline Estimate

| Milestone | Duration | Deliverable |
|-----------|----------|-------------|
| Architecture setup | 1-2 weeks | iOS project structure, FastAPI scaffold, Celery workers |
| GTFS data pipeline | 2-3 weeks | Daily NSW GTFS sync, SQLite generation |
| Real-time departures | 2 weeks | NSW GTFS-RT integration, departure UI |
| Stop search & nearby | 1 week | Search, geolocation, map view |
| Trip planning | 2-3 weeks | NSW API integration, multi-route display |
| Service alerts | 1 week | Alert feed parsing, UI |
| Favorites | 1 week | CloudKit sync, UI |
| Push notifications | 1 week | APNs setup, alert routing |
| Basic widgets | 1-2 weeks | Home screen widgets |
| Testing & polish | 2-3 weeks | Bug fixes, performance, UX refinement |
| **Total** | **14-18 weeks** | **Phase 1 MVP launch** |

Post-launch (P1 features): 6-8 additional weeks

---

## Success Metrics

**Phase 1 Goals (6 months):**
- 5,000 active users
- 4.5+ App Store rating
- <1% crash rate
- <100ms departure query time
- 95% uptime for real-time data

**User Satisfaction:**
- Match TripView reliability (users trust it)
- Exceed Transit UX (modern, intuitive)
- Beat NextThere simplicity (one tap to info)

---

## Risk Mitigation

### Risk: NSW API rate limits (5 req/s)
**Mitigation:** Aggressive Redis caching (15s TTL), batch requests

### Risk: Large GTFS download (227MB)
**Mitigation:** Optional offline mode, WiFi-only, background download

### Risk: Real-time data outages
**Mitigation:** Graceful degradation to schedules, clear status indicator

### Risk: Trip Planner API downtime
**Mitigation:** Local RAPTOR routing fallback (implement Phase 1.5)

### Risk: App size bloat
**Mitigation:** Strict dependency review, code size audits, asset optimization

---

## Next Steps

1. **Finalize MVP scope** - Lock P0 features, cut anything non-essential
2. **Design technical architecture spec** - Detailed system design doc
3. **Create development roadmap** - Sprint planning, milestones
4. **Design core UI flows** - Wireframes for key screens
5. **Set up development environment** - Xcode project, FastAPI scaffold, Celery setup, GitHub repo
6. **Begin Phase 1 development** - Start with GTFS data pipeline

---

**Status:** Feature map complete - ready for architecture specification phase
# Australian Government Transit Data APIs
**Comprehensive Documentation for Sydney, Melbourne, and Brisbane**

Last Updated: October 2025

---

## Executive Summary

### Key Findings

**Best Overall Coverage:** Transport NSW (Sydney) offers most comprehensive real-time coverage across all transport modes with separate endpoints per mode.

**Best Documentation:** Transport NSW has most mature developer portal with GTFS Studio v2, active forums, detailed specifications.

**Simplest Access:** TransLink Queensland requires no authentication for GTFS-RT feeds - completely open access.

**Most Restrictive:** PTV Victoria has strictest rate limits (24 calls/60 seconds) and requires email-based API key request.

### Red Flags

- **NSW:** Large file sizes (227MB+ for complete GTFS), binary response format requires .proto files, inconsistent data across feeds
- **PTV:** Manual API key process via email, older data (updated 2023), migration issues from legacy platform
- **TransLink:** Limited to vehicles with tracking equipment, deprecated v1.0 caused decoding errors, annual updates only

### Opportunities

- **NSW:** GTFS Pathways extension for accessibility, active developer community, custom extensions (Notes file)
- **PTV:** Creative Commons license allows commercial use, comprehensive metro coverage
- **TransLink:** No authentication barriers, multiple regional feeds beyond SEQ, v2.0 protobuf format

---

## Sydney - Transport NSW Open Data Hub

### Overview

Transport NSW operates the most comprehensive open data program of the three cities, with extensive GTFS static and real-time coverage across all transport modes.

**Portal:** https://opendata.transport.nsw.gov.au/

### GTFS Static Feed

#### Access URLs
- **Complete GTFS Dataset:** Available via download button on portal
- **Base URL Pattern:** `https://api.transport.nsw.gov.au/v1/`
- Must download via portal or cURL - API explorer doesn't work due to large file size

#### File Specifications
- **Format:** ZIP file containing CSV files
- **Size:** ~227 MB (zipped) - historically noted as very large
- **Update Frequency:** Daily for Sydney Trains, Bus, Ferries, Light Rail, Rural and Regional GTFS feeds
- **Last Updated:** October 29, 2025

#### Coverage
- Sydney Trains
- NSW TrainLink (regional trains)
- Metro (Sydney Metro)
- Buses (contract-based feeds)
- Ferries
- Light Rail
- Regional services
- On-demand services
- Trackwork and transport routes

#### Schema & Extensions
- **Standard:** GTFS specification compliant
- **Custom Extensions:**
  - **Notes.txt:** TfNSW-defined extension for irregularities, special conditions
  - **GTFS Pathways:** Released June 2, 2023 - provides step-by-step navigation within stations including traversal time, signposts, accessibility info
  - **trip_note field:** Custom field in trips.txt for operator notes
  - **stop_note field:** Custom field in stop_times.txt

### GTFS-RT Real-Time Feeds

#### Feed Types & Endpoints

**1. Vehicle Positions**
- **Endpoint Pattern:** `https://api.transport.nsw.gov.au/v1/gtfs/vehiclepos/[mode]`
- **Modes:** buses, ferries, lightrail, nswtrains, sydneytrains, metro, regionalbuses

**2. Trip Updates**
- **Endpoint Pattern:** `https://api.transport.nsw.gov.au/v1/gtfs/realtime/[mode]`
- **Modes:** buses, ferries, lightrail, nswtrains, sydneytrains, metro, regionalbuses

**3. Service Alerts**
- **Dataset:** Public Transport - Realtime - Alerts - v2
- **Endpoint:** `https://api.transport.nsw.gov.au/v1/gtfs/alerts/[mode]`
- **Coverage:** All modes - Bus, Train, Ferry, Light Rail, Metro, Coaches

#### Real-Time Coverage by Mode
- ✅ Sydney Trains - Full coverage
- ✅ Metro - Full coverage
- ✅ NSW Trains (Intercity/Regional) - Full coverage
- ✅ Buses - Full coverage (regional + urban)
- ✅ Ferries - Full coverage
- ✅ Light Rail - Full coverage

#### Update Frequencies
- **Real-time files/APIs:** Updated every 10-15 seconds
- **Recommended polling interval:** Every 15 seconds
- **Response format:** Binary (Protocol Buffer) - requires .proto file for decoding

### Authentication

#### Registration Process
1. Register free account at https://opendata.transport.nsw.gov.au/
2. Activate account via email
3. Create application and generate API key
4. Key provided once - store securely (cannot be viewed again)
5. View/manage keys on Applications page

#### API Key Usage
- **Header Name:** `Authorization`
- **Format:** `apikey [your-key]`
- **Protocol:** HTTPS on port 443
- **Recommendation:** Separate API key per application
- **Security:** Keep keys private, avoid exposing in URLs or markup

### Rate Limits

#### Default Bronze Plan
- **Daily Quota:** 60,000 requests per day
- **Throttle Rate:** 5 requests per second
- **Upgrades:** Contact OpenDataProgram@transport.nsw.gov.au to increase limits

#### Error Responses
- **HTTP 401:** Missing/invalid API key
- **HTTP 403:** Rate limit or quota exceeded
- **HTTP 503:** API quota exceeded (intermittent)
- **HTTP 200:** Success

### Terms of Service

#### License
- **Type:** Creative Commons Attribution 4.0 International
- **Commercial Use:** Allowed
- **Caching:** Permitted
- **Redistribution:** Allowed with attribution

#### Attribution Requirements
- Must credit "Transport for NSW"
- Use official Transport logo for attribution
- Do not modify brand elements (colors, format)
- Do not imply endorsement without written consent
- **Contact:** OpenDataProgram@transport.nsw.gov.au

#### Branding Guidelines
- Mode symbols/pictograms copyrighted by Transport
- Only use logos to attribute data source
- Official color palette provided for WCAG 2.0 AA compliance
- Assets not available for third-party advertising without written consent

### Known Limitations & Issues

#### Data Quality Issues
- Inconsistent real-time data - sometimes in NSW Trains feed, sometimes Sydney Trains, sometimes both
- Future projections may not match between GTFS static and real-time (different systems)
- Real-time data affected by connectivity and GPS issues
- API explorer unavailable due to large file sizes

#### Reported Problems (from developer forums)
- **2018:** GTFS bundle version number changes daily but downloads same old file
- **2019:** Inconsistent API responses
- **May 2025:** HTTP 500 Internal Server Error from Vehicle Positions API
- Download problems with complete GTFS bundle

#### Technical Challenges
- Large file sizes (20MB+ for some feeds)
- Binary response format requires protocol buffer decoding
- Complex authentication compared to competitors

### Documentation Quality

**Rating: Excellent**

- Comprehensive developer portal with user guides
- Active developer forum at https://opendataforum.transport.nsw.gov.au/
- GTFS Studio v2 for managing/querying data
- Detailed implementation specification (v1.0.3)
- Troubleshooting guide available
- Email support: OpenDataHelp@transport.nsw.gov.au

### Example API Call

```bash
curl -X GET \
  'https://api.transport.nsw.gov.au/v1/gtfs/vehiclepos/buses' \
  -H 'Authorization: apikey YOUR_API_KEY_HERE'
```

**Response:** Binary Protocol Buffer format requiring .proto file decoding

---

## Melbourne - Public Transport Victoria (PTV)

### Overview

PTV provides both a REST API (PTV Timetable API v3) and GTFS datasets. Real-time data transitioned from Data Exchange Platform (DEP) to Transport Victoria Open Data Portal in 2025.

**Portal:** https://opendata.transport.vic.gov.au/

### GTFS Static Feed

#### Access URLs
- **Portal:** Transport Victoria Open Data Portal
- **Alternative:** Victorian Government Data Directory (discover.data.vic.gov.au)
- **Format:** ZIP file download

#### File Specifications
- **Format:** Standard GTFS text files
- **Size:** Not publicly specified (too large for GitHub hosting per community reports)
- **Update Frequency:** Weekly or as needed
- **Data Range:** Rolling 30 days from export date
- **Last Updated:** November 14, 2023 (as of search date)
- **Maintenance Note:** Publication may be delayed during scheduled maintenance

#### Coverage
- Metro trains (Melbourne suburban network)
- Yarra Trams
- Metro buses (Melbourne urban)
- Regional buses (progressive rollout)
- V/Line trains (regional)
- **Note:** Some route information may not be complete for entire 30-day period

#### Schema
- **Standard:** GTFS specification compliant
- **Extensions:** No custom extensions documented
- **Shapes Data:** Included for map routing

### GTFS-RT Real-Time Feeds

#### Feed Types & Modes

**Trip Updates:**
- Metro Train: Near real-time updates
- Yarra Trams: Every 60 seconds
- Metro & Regional Bus: Near real-time
- V/Line: Available

**Vehicle Positions:**
- Metro Train: Near real-time
- (Trams, buses, V/Line not specified in available documentation)

**Service Alerts:**
- Metro Train: Available
- Yarra Trams: Available
- (Other modes not specified)

#### Real-Time Coverage by Mode
- ✅ Metro trains - Full coverage
- ✅ Trams - Full coverage
- ✅ Metropolitan buses - Full coverage
- ⚠️ Regional buses - Partial/progressive rollout
- ✅ V/Line trains - Available (launched October 2023)

#### Update Frequencies
- **Metro Train:** Near real-time
- **Yarra Trams:** 60 seconds
- **Metro Bus:** Near real-time
- **Cache Time:** 30 seconds

#### Response Format
- **Format:** Protocol Buffer (binary, not human-readable)
- **Specification:** GTFS Realtime v2.0
- **API Format:** OpenAPI JSON (2.06 KB - 2.46 KB per feed spec)

### Authentication

#### GTFS-RT Feeds
- **API Key Required:** Yes
- **Header Name:** `KeyID`
- **Obtainment:** Sign up via Data Exchange Platform

#### Registration Process (PTV Timetable API v3)
1. Email APIKeyRequest@ptv.vic.gov.au
2. Subject line: "PTV Timetable API – request for key"
3. PTV returns developer ID (devid) and API key (128-bit GUID) via email
4. Email address added to API mailing list for updates
5. **Note:** PTV does not provide technical support for the API

#### Migration Note
- **Deadline:** September 29, 2025 - DEP decommissioned
- All API access moved to Transport Victoria Open Data Portal
- API keys from DEP no longer work after deadline
- Two-month transition period provided (August-September 2025)

### Rate Limits

#### GTFS-RT Feeds
- **Rate Limit:** 24 calls per 60 seconds
- **Applies to:** Metro Train, Tram, and Bus uniformly
- **Alternative Limit Noted:** 20-27 calls per minute (varies by data size)

#### PTV Timetable API v3
- **Rate Limits:** Not publicly documented
- **Guidance:** "Don't hammer our servers"
- **Advice:** Don't make multiple requests for large data sets in short periods
- **Design:** Works best when used dynamically within apps, not for bulk downloads

### Terms of Service

#### License
- **Type:** Creative Commons Attribution 4.0 International
- **Commercial Use:** Allowed
- **Redistribution:** Allowed with attribution

#### Attribution Requirements
- **Required Text:** "Source: Licensed from Public Transport Victoria under a Creative Commons Attribution 4.0 International Licence"
- Do not pretend to be PTV
- Do not claim PTV endorsement without written consent

### Known Limitations & Issues

#### Platform Migration Issues
- DEP decommissioned September 30, 2025
- Required developer action to migrate API keys
- Two-month transition period

#### API Limitations
- PTV Timetable API doesn't support all features from legacy EFA interface
- Only allows viewing "a little bit of data at a time"
- Ties developers to specific access method
- Limited technical support from PTV

#### Data Freshness
- Static GTFS data last updated November 2023 (as of search)
- Rolling 30-day window may have incomplete route information

#### Technical Challenges
- Email-based API key request (not instant)
- Manual approval process
- May experience delays with high request volumes
- Separate authentication systems for GTFS-RT vs REST API

### Documentation Quality

**Rating: Good**

- Official FAQ page available
- Swagger documentation at timetableapi.ptv.vic.gov.au/swagger/ui/index
- Transport Victoria Open Data Portal provides dataset descriptions
- API mailing list for updates
- Limited technical support offered
- Community-maintained documentation (e.g., stevage.github.io/PTV-API-doc/)

### Reliability & Uptime

- Systems up 99.9% of time (claimed)
- **Recent Outage:** October 7, 2025 (detected by StatusGator)
- **Planned Maintenance:** Periodic 1-hour windows (e.g., March 22, 2025, 1-5 PM CET)
- No major reliability issues reported 2024-2025

### Example API Call

```bash
# GTFS-RT Feed Example
curl -X GET \
  'https://opendata.transport.vic.gov.au/api/[endpoint]' \
  -H 'KeyID: YOUR_API_KEY'
```

**Response:** Binary Protocol Buffer format

---

## Brisbane - TransLink Queensland

### Overview

TransLink provides open GTFS static and real-time data for South East Queensland and regional services through Queensland Government Open Data Portal.

**Portal:** https://www.data.qld.gov.au/

**Developer Portal:** https://translink.com.au/about-translink/open-data

### GTFS Static Feed

#### Access URLs
- **Base URL:** `https://gtfsrt.api.translink.com.au/GTFS/`
- **SEQ Feed:** SEQ_GTFS.zip
- **Regional Feeds:** CNS_GTFS.zip, TWB_GTFS.zip, TSV_GTFS.zip, etc.

#### File Specifications
- **Format:** ZIP files containing GTFS text files
- **Specification Version:** GTFS v1.12
- **Update Frequency:** Annually
- **Last Updated:** November 14, 2023

#### Coverage

**South East Queensland (SEQ):**
- Bus
- Rail
- Light Rail (G:link)
- Ferry

**Regional Services (18+ networks):**
- Cairns (989 KiB)
- Townsville (335 KiB)
- Toowoomba (422 KiB)
- Bundaberg
- Mackay
- Rockhampton-Yeppoon
- Fraser Coast
- Warwick (18 KiB)
- Bowen
- Innisfail
- Various island services

#### Schema
- **Standard:** GTFS v1.12 compliant
- **Extensions:** No custom extensions documented
- **Files:** stops, routes, trips, schedules (standard GTFS structure)

#### Special Datasets
- **School Services:** Pilot SEQ GTFS dataset incorporating school services
- **Warning:** Pilot release - file structure may change or be withdrawn

### GTFS-RT Real-Time Feeds

#### Base URL Pattern
`https://gtfsrt.api.translink.com.au/api/realtime/[REGION]/[DATA_TYPE]`

#### Regions
- **SEQ** - South East Queensland
- **CNS** - Cairns
- **NSI** - Not specified in detail
- **MHB** - Not specified in detail
- **BOW** - Bowen
- **INN** - Innisfail

#### Feed Types by Region

**For Each Region:**
1. **Trip Updates**
   - General: `/TripUpdates`
   - By mode: `/Bus/TripUpdates`, `/Rail/TripUpdates`, `/Tram/TripUpdates`, `/Ferry/TripUpdates`

2. **Vehicle Positions**
   - General: `/VehiclePositions`
   - By mode: `/Bus/VehiclePositions`, `/Rail/VehiclePositions`, `/Tram/VehiclePositions`, `/Ferry/VehiclePositions`

3. **Service Alerts**
   - General: `/Alerts`

#### Real-Time Coverage by Mode
- ✅ Bus - Full coverage
- ✅ Rail - Full coverage
- ✅ Tram/Light Rail - Full coverage
- ✅ Ferry - Full coverage

**Important Limitation:** Only vehicles equipped with real-time tracking technology are included - not comprehensive across all services

#### Update Frequencies
- **Frequency:** Near real-time
- **Specific timing:** Not publicly documented

#### Response Format
- **Format:** Protocol Buffer (Protobuf)
- **Specification:** GTFS Realtime v2.0
- **Proto Definition:** Available on TransLink website (`gtfs-realtime.proto`)

### Authentication

#### GTFS-RT Feeds
- **API Key Required:** NO
- **Authentication:** None required
- **Access:** Completely open

#### GTFS Static Feeds
- **Authentication:** None required
- **Access:** Public download links

### Rate Limits

**No rate limits documented or enforced**

TransLink does not specify rate limits or throttling restrictions for either static or real-time feeds.

### Terms of Service

#### License
- **Type:** Creative Commons Attribution 4.0 (CC-BY)
- **Commercial Use:** Allowed with attribution
- **Redistribution:** Allowed

#### Attribution Requirements
- Must credit TransLink as source
- Attribution required under CC BY 4.0 terms
- **Contact:** opendata@translink.com.au

#### Community Support
- **TransLink Australia Google Group:** Available for developer discussions
- **Email Support:** opendata@translink.com.au

### Known Limitations & Issues

#### Version Compatibility
- **Major Issue:** v1.0 feed deprecated, caused decoding errors
- **Error:** "Illegal value for Message.Field .transit_realtime.TripDescriptor.schedule_relationship: 5"
- **Resolution:** Migrated to GTFS-RT v2.0
- **Impact:** Developers using v1.0 libraries experienced breakage

#### Data Coverage
- Limited to vehicles with tracking equipment
- Not all services have real-time data
- Some routes may lack coverage

#### Update Frequency
- **Static GTFS:** Only annual updates
- Less frequent than Sydney (daily) or Melbourne (weekly)
- May not reflect recent service changes

#### Pilot Datasets
- School services dataset may be unstable
- File structure subject to change
- May be withdrawn without notice

### Documentation Quality

**Rating: Good**

- Official TransLink Open Data page provides overview
- Queensland Government Open Data Portal has dataset descriptions
- API documentation includes proto definition
- TransLink Australia Google Group for community support
- Clear endpoint structure
- Email support available

### Reliability

- No major outages documented in search results
- Uptime statistics not publicly available
- Community feedback generally positive regarding availability

### Example API Calls

```bash
# No authentication required

# SEQ Vehicle Positions
curl 'https://gtfsrt.api.translink.com.au/api/realtime/SEQ/VehiclePositions'

# SEQ Trip Updates - Bus Only
curl 'https://gtfsrt.api.translink.com.au/api/realtime/SEQ/Bus/TripUpdates'

# Cairns Service Alerts
curl 'https://gtfsrt.api.translink.com.au/api/realtime/CNS/Alerts'

# Static GTFS Download
curl -O 'https://gtfsrt.api.translink.com.au/GTFS/SEQ_GTFS.zip'
```

**Response:** Binary Protocol Buffer format

---

## Cross-City Comparison

### Data Quality Matrix

| Aspect | Sydney (NSW) | Melbourne (PTV) | Brisbane (TransLink) |
|--------|-------------|----------------|---------------------|
| **Static Update Freq** | Daily | Weekly | Annually |
| **RT Update Freq** | 10-15 sec | 30-60 sec | Near real-time (unspecified) |
| **Static File Size** | ~227 MB | Unknown (large) | 18 KiB - 989 KiB (regional) |
| **RT Coverage** | All modes | Most modes | All modes (with equipment) |
| **Data Freshness** | Oct 2025 | Nov 2023 | Nov 2023 |
| **Documentation** | Excellent | Good | Good |
| **Community Support** | Active forums | Moderate | Google Group |

### Schema Consistency

**Standard Compliance:**
- ✅ All three cities use standard GTFS format
- ✅ All use GTFS-RT v2.0 Protocol Buffer format
- ✅ All provide Trip Updates, Vehicle Positions, Service Alerts

**Custom Extensions:**
- **Sydney:** Custom Notes.txt file, GTFS Pathways, custom fields
- **Melbourne:** No custom extensions
- **Brisbane:** No custom extensions

**Verdict:** Sydney has most extensive customization; Melbourne and Brisbane stick to standard spec.

### Authentication & Access

| City | GTFS Static | GTFS-RT | API Key Process | Complexity |
|------|------------|---------|----------------|-----------|
| Sydney | API key required | API key required | Instant online signup | Medium |
| Melbourne | No auth | API key required | Email-based approval | High |
| Brisbane | No auth | No auth | None | Lowest |

**Winner:** TransLink Queensland - completely open, no barriers

### Rate Limits Comparison

| City | Daily Quota | Per-Second/Minute Limit | Upgrade Path |
|------|------------|------------------------|--------------|
| Sydney | 60,000 req/day | 5 req/sec | Contact for increase |
| Melbourne | Not specified | 24 calls/60 sec | Not specified |
| Brisbane | Unlimited | None | N/A |

**Winner:** TransLink Queensland - no limits

**Most Restrictive:** PTV Melbourne - lowest throughput rate

### Real-Time Coverage Quality

**Best Coverage:**
1. **Sydney** - All modes, separate endpoints, most granular
2. **Brisbane** - All modes (equipment-dependent)
3. **Melbourne** - Most modes, regional buses still rolling out

**Update Frequency:**
1. **Sydney** - 10-15 seconds (fastest)
2. **Melbourne** - 30-60 seconds
3. **Brisbane** - Near real-time (unspecified, likely similar to others)

### License & Commercial Use

**All three cities:**
- Creative Commons Attribution 4.0
- Commercial use allowed
- Attribution required
- Redistribution permitted

**Winner:** Tie - all equally permissive

### API Response Format

**All three cities:**
- Static: ZIP with CSV files
- Real-time: Protocol Buffer (binary)
- Require .proto file for decoding

**Consistency:** High - all use same GTFS/GTFS-RT standards

### Developer Experience

#### Ease of Getting Started
1. **Brisbane** - No signup, start immediately
2. **Sydney** - Quick online signup, instant API key
3. **Melbourne** - Email request, manual approval, potential delays

#### Best Documentation
1. **Sydney** - GTFS Studio, active forums, comprehensive guides, troubleshooting
2. **Melbourne** - Swagger docs, FAQs, community docs
3. **Brisbane** - Basic documentation, Google Group

#### Most Developer-Friendly
**Brisbane** - No authentication, no rate limits, simple URLs
- **But:** Less frequent static updates (annual vs daily)

#### Most Feature-Rich
**Sydney** - Pathways extension, custom fields, most frequent updates, granular mode separation
- **But:** Large file sizes, complex authentication, binary responses

### Historical Uptime/Reliability

**Sydney:**
- Issues reported: 503 errors (rate limiting), 500 errors (May 2025), inconsistent responses
- File versioning problems (2018)
- Generally stable but occasional API issues

**Melbourne:**
- 99.9% uptime claimed
- October 2025 outage detected
- Platform migration caused disruption (DEP → Transport Victoria)
- Legacy API limitations

**Brisbane:**
- No major outages documented
- v1.0 → v2.0 migration caused decoding issues
- Generally stable

**Verdict:** All three cities maintain reasonable uptime; Sydney most transparent about issues via active forums.

### Community-Reported Issues Summary

**Sydney:**
- Large file sizes problematic
- Inconsistent data across feeds
- Binary format adds complexity
- Active community identifies and reports issues quickly

**Melbourne:**
- Limited API functionality vs legacy system
- Email-based key request delays
- Platform migration disruptions
- Less community feedback available

**Brisbane:**
- Version compatibility issues during v1.0 deprecation
- Limited documentation for troubleshooting
- Coverage gaps due to equipment dependency
- Smaller developer community

---

## Recommendations for Implementation

### For Maximum Reliability
**Choose Sydney (Transport NSW)**
- Most frequent updates (daily)
- Most comprehensive real-time coverage
- Active support forums and responsive team
- Despite complexity, most mature platform

### For Fastest Setup
**Choose Brisbane (TransLink)**
- No authentication barriers
- No rate limits
- Start development immediately
- Simplest API calls

### For Best Documentation
**Choose Sydney (Transport NSW)**
- GTFS Studio v2 visualization tool
- Detailed implementation specs
- Active developer community
- Comprehensive troubleshooting guides

### Technical Recommendations

#### Data Refresh Strategy
1. **Static GTFS:**
   - Sydney: Update daily (lightweight delta updates if available)
   - Melbourne: Update weekly
   - Brisbane: Update monthly (check for version changes)

2. **Real-Time GTFS-RT:**
   - Sydney: Poll every 15 seconds (recommended by provider)
   - Melbourne: Poll every 30-60 seconds (cache time)
   - Brisbane: Poll every 30 seconds (conservative estimate)

#### Caching Strategy
- Cache static GTFS locally
- Use ETags/If-Modified-Since headers to avoid unnecessary downloads
- Cache real-time responses for 15-30 seconds client-side
- Implement exponential backoff for API errors

#### Error Handling
```python
# Pseudocode for robust API calls

def fetch_gtfs_rt(city, endpoint, api_key=None):
    max_retries = 3
    backoff = 1  # seconds

    for attempt in range(max_retries):
        try:
            headers = {}
            if city == "sydney":
                headers["Authorization"] = f"apikey {api_key}"
            elif city == "melbourne":
                headers["KeyID"] = api_key
            # Brisbane needs no headers

            response = requests.get(endpoint, headers=headers, timeout=10)

            if response.status_code == 200:
                return decode_protobuf(response.content)
            elif response.status_code == 429:  # Rate limit
                sleep(backoff * 2)
                backoff *= 2
            elif response.status_code == 503:  # Service unavailable
                sleep(backoff)
                backoff *= 2
            else:
                log_error(f"HTTP {response.status_code}")
                return None

        except requests.exceptions.Timeout:
            sleep(backoff)
            backoff *= 2
        except Exception as e:
            log_error(f"Exception: {e}")
            return None

    return None  # All retries failed
```

#### Multi-City Support Architecture

If building app supporting all three cities:

1. **Abstraction Layer:** Create unified interface abstracting city-specific differences
2. **Configuration:** Store city-specific endpoints, auth methods, rate limits in config
3. **Adapter Pattern:** Implement city-specific adapters for authentication and data parsing
4. **Fallback Strategy:** If one city's API fails, gracefully handle without affecting others

### API Key Management

**Sydney:**
- Generate separate keys per environment (dev, staging, prod)
- Rotate keys periodically
- Monitor quota usage via portal
- Request quota increase before hitting limits

**Melbourne:**
- Request multiple keys upfront for different environments
- Join API mailing list for maintenance notifications
- Plan for manual approval delays in development timeline

**Brisbane:**
- No key management needed
- Consider implementing your own rate limiting to be respectful
- Monitor for API changes via Google Group

### Cost Considerations

**All three cities: Free**

Operational costs:
- Bandwidth for downloading large GTFS files (Sydney: ~227 MB daily)
- Compute for Protocol Buffer decoding
- Storage for cached static GTFS data
- Monitoring and error logging infrastructure

### Compliance & Legal

**Attribution Requirements:**
- Display city logos when showing transit data
- Include license text in app's legal section
- Don't claim endorsement by transit agencies
- For commercial apps, ensure proper attribution in UI

**Data Usage:**
- All permit commercial use under CC-BY-4.0
- No explicit caching restrictions
- Redistribution allowed with attribution
- Check terms before reselling raw data feeds

### Monitoring & Alerts

**Key Metrics to Track:**
1. API response times
2. Error rates (401, 403, 429, 500, 503)
3. Data freshness (timestamp in feeds)
4. Feed availability (HTTP status)
5. Protocol Buffer decode success rate
6. Static GTFS version changes

**Recommended Alerting:**
- Alert if API unavailable for >5 minutes
- Alert if error rate >5% over 15 minutes
- Alert if data timestamp >30 minutes old (real-time)
- Alert if approaching rate limits (Sydney: >80% of quota)

---

## Code Examples

### Python: Decoding GTFS-RT Protocol Buffer

```python
from google.transit import gtfs_realtime_pb2
import requests

# Sydney Example
def fetch_sydney_vehicle_positions(api_key):
    url = "https://api.transport.nsw.gov.au/v1/gtfs/vehiclepos/buses"
    headers = {"Authorization": f"apikey {api_key}"}

    response = requests.get(url, headers=headers)

    if response.status_code == 200:
        feed = gtfs_realtime_pb2.FeedMessage()
        feed.ParseFromString(response.content)

        for entity in feed.entity:
            if entity.HasField('vehicle'):
                vehicle = entity.vehicle
                print(f"Vehicle {vehicle.vehicle.id}: "
                      f"Lat {vehicle.position.latitude}, "
                      f"Lon {vehicle.position.longitude}")
    else:
        print(f"Error: {response.status_code}")

# Melbourne Example
def fetch_melbourne_trip_updates(api_key):
    url = "https://data-exchange.vicroads.vic.gov.au/api/gtfs-rt/metro-train-trip-updates"
    headers = {"KeyID": api_key}

    response = requests.get(url, headers=headers)

    if response.status_code == 200:
        feed = gtfs_realtime_pb2.FeedMessage()
        feed.ParseFromString(response.content)

        for entity in feed.entity:
            if entity.HasField('trip_update'):
                trip = entity.trip_update
                print(f"Trip {trip.trip.trip_id}: {len(trip.stop_time_update)} stops")
    else:
        print(f"Error: {response.status_code}")

# Brisbane Example (No auth required)
def fetch_brisbane_alerts():
    url = "https://gtfsrt.api.translink.com.au/api/realtime/SEQ/Alerts"

    response = requests.get(url)

    if response.status_code == 200:
        feed = gtfs_realtime_pb2.FeedMessage()
        feed.ParseFromString(response.content)

        for entity in feed.entity:
            if entity.HasField('alert'):
                alert = entity.alert
                print(f"Alert: {alert.header_text.translation[0].text}")
    else:
        print(f"Error: {response.status_code}")
```

### JavaScript/Node.js: Rate Limiting

```javascript
const axios = require('axios');
const Bottleneck = require('bottleneck');

// Sydney: 5 requests per second
const sydneyLimiter = new Bottleneck({
  maxConcurrent: 1,
  minTime: 200  // 200ms between requests = 5/sec
});

// Melbourne: 24 requests per 60 seconds
const melbourneLimiter = new Bottleneck({
  reservoir: 24,
  reservoirRefreshAmount: 24,
  reservoirRefreshInterval: 60 * 1000  // 60 seconds
});

// Brisbane: No limit, but be respectful
const brisbaneLimiter = new Bottleneck({
  maxConcurrent: 5,
  minTime: 100  // 10/sec voluntary limit
});

// Wrapped API call for Sydney
const fetchSydneyData = sydneyLimiter.wrap(async (endpoint, apiKey) => {
  const response = await axios.get(endpoint, {
    headers: { 'Authorization': `apikey ${apiKey}` }
  });
  return response.data;
});

// Wrapped API call for Melbourne
const fetchMelbourneData = melbourneLimiter.wrap(async (endpoint, apiKey) => {
  const response = await axios.get(endpoint, {
    headers: { 'KeyID': apiKey }
  });
  return response.data;
});

// Wrapped API call for Brisbane
const fetchBrisbaneData = brisbaneLimiter.wrap(async (endpoint) => {
  const response = await axios.get(endpoint);
  return response.data;
});
```

### Python: Unified Multi-City Interface

```python
from abc import ABC, abstractmethod
from enum import Enum

class City(Enum):
    SYDNEY = "sydney"
    MELBOURNE = "melbourne"
    BRISBANE = "brisbane"

class TransitAPI(ABC):
    @abstractmethod
    def fetch_vehicle_positions(self, mode):
        pass

    @abstractmethod
    def fetch_trip_updates(self, mode):
        pass

    @abstractmethod
    def fetch_service_alerts(self):
        pass

class SydneyAPI(TransitAPI):
    def __init__(self, api_key):
        self.api_key = api_key
        self.base_url = "https://api.transport.nsw.gov.au/v1/gtfs"
        self.headers = {"Authorization": f"apikey {api_key}"}

    def fetch_vehicle_positions(self, mode):
        url = f"{self.base_url}/vehiclepos/{mode}"
        return self._fetch(url)

    def fetch_trip_updates(self, mode):
        url = f"{self.base_url}/realtime/{mode}"
        return self._fetch(url)

    def fetch_service_alerts(self):
        url = f"{self.base_url}/alerts"
        return self._fetch(url)

    def _fetch(self, url):
        response = requests.get(url, headers=self.headers)
        return self._decode_protobuf(response.content) if response.status_code == 200 else None

class MelbourneAPI(TransitAPI):
    def __init__(self, api_key):
        self.api_key = api_key
        self.base_url = "https://opendata.transport.vic.gov.au/api"
        self.headers = {"KeyID": api_key}

    def fetch_vehicle_positions(self, mode):
        # Melbourne GTFS-RT endpoints (simplified)
        url = f"{self.base_url}/gtfs-rt/{mode}-vehicle-positions"
        return self._fetch(url)

    def fetch_trip_updates(self, mode):
        url = f"{self.base_url}/gtfs-rt/{mode}-trip-updates"
        return self._fetch(url)

    def fetch_service_alerts(self):
        url = f"{self.base_url}/gtfs-rt/service-alerts"
        return self._fetch(url)

    def _fetch(self, url):
        response = requests.get(url, headers=self.headers)
        return self._decode_protobuf(response.content) if response.status_code == 200 else None

class BrisbaneAPI(TransitAPI):
    def __init__(self):
        self.base_url = "https://gtfsrt.api.translink.com.au/api/realtime/SEQ"

    def fetch_vehicle_positions(self, mode):
        url = f"{self.base_url}/{mode}/VehiclePositions"
        return self._fetch(url)

    def fetch_trip_updates(self, mode):
        url = f"{self.base_url}/{mode}/TripUpdates"
        return self._fetch(url)

    def fetch_service_alerts(self):
        url = f"{self.base_url}/Alerts"
        return self._fetch(url)

    def _fetch(self, url):
        response = requests.get(url)  # No auth needed
        return self._decode_protobuf(response.content) if response.status_code == 200 else None

# Factory
def get_transit_api(city: City, api_key=None):
    if city == City.SYDNEY:
        return SydneyAPI(api_key)
    elif city == City.MELBOURNE:
        return MelbourneAPI(api_key)
    elif city == City.BRISBANE:
        return BrisbaneAPI()
    else:
        raise ValueError(f"Unsupported city: {city}")

# Usage
sydney_api = get_transit_api(City.SYDNEY, api_key="your_sydney_key")
vehicles = sydney_api.fetch_vehicle_positions("buses")

brisbane_api = get_transit_api(City.BRISBANE)
alerts = brisbane_api.fetch_service_alerts()
```

---

## Additional Resources

### Official Documentation Links

**Sydney (Transport NSW):**
- Developer Portal: https://opendata.transport.nsw.gov.au/
- API Documentation: https://developer.transport.nsw.gov.au/developers/documentation
- Developer Forum: https://opendataforum.transport.nsw.gov.au/
- User Guide: https://opendata.transport.nsw.gov.au/developers/userguide
- Troubleshooting: https://opendata.transport.nsw.gov.au/troubleshooting
- GTFS Studio: https://opendata.transport.nsw.gov.au/ (Browse menu)
- Support Email: OpenDataHelp@transport.nsw.gov.au

**Melbourne (PTV):**
- Open Data Portal: https://opendata.transport.vic.gov.au/
- PTV Timetable API: https://www.ptv.vic.gov.au/footer/data-and-reporting/datasets/ptv-timetable-api/
- API FAQ: https://www.ptv.vic.gov.au/footer/data-and-reporting/datasets/ptv-timetable-api/ptv-timetable-api-faqs/
- Swagger Docs: https://timetableapi.ptv.vic.gov.au/swagger/ui/index
- API Key Request: APIKeyRequest@ptv.vic.gov.au
- Community Docs: https://stevage.github.io/PTV-API-doc/

**Brisbane (TransLink):**
- Open Data Portal: https://www.data.qld.gov.au/
- TransLink Open Data: https://translink.com.au/about-translink/open-data
- GTFS-RT Info: https://translink.com.au/about-translink/open-data/gtfs-rt
- API Base: https://gtfsrt.api.translink.com.au/
- Support Email: opendata@translink.com.au
- Google Group: TransLink Australia Google Group

### GTFS Resources
- GTFS Specification: https://gtfs.org/
- GTFS Realtime Reference: https://gtfs.org/documentation/realtime/reference/
- Protocol Buffer Documentation: https://developers.google.com/protocol-buffers
- OpenMobilityData: https://transitfeeds.com/ (GTFS feed directory)

### Third-Party Tools
- **GTFS Validators:** transitfeed, gtfs-validator
- **GTFS Visualization:** Transitland, GTFS Studio (NSW)
- **Protocol Buffer Libraries:** protobuf (Python), protobufjs (Node.js)
- **Rate Limiting:** Bottleneck (Node.js), ratelimit (Python)

---

## Changelog

**October 30, 2025:** Initial documentation created based on research of current API status

---

## License

This documentation is provided as-is for informational purposes. Transit data from each city is subject to their respective Creative Commons Attribution 4.0 licenses. Always refer to official documentation for authoritative information.

**Attribution:**
- Sydney transit data: Transport for NSW
- Melbourne transit data: Public Transport Victoria
- Brisbane transit data: TransLink Queensland

---

## Contact

For updates or corrections to this document, please contact the transit agencies directly using the support channels listed in the Additional Resources section.
# iOS Native Capabilities for Transit Apps

**Document Version:** 1.0
**Last Updated:** October 2024
**Target Platform:** iOS 16+ (recommended minimum)

---

## Executive Summary

### Native vs External Services Recommendation

**Core Recommendation:** Use a hybrid approach - maximize iOS native capabilities where they excel, supplement with external services where iOS falls short.

**Use iOS Native:**
- CoreLocation for location tracking and geofencing
- WidgetKit for home/lock screen widgets
- ActivityKit for Live Activities (iOS 16.1+)
- APNs for push notifications
- SQLite with FTS5 for GTFS data storage
- WeatherKit for weather data (iOS 16+)
- CloudKit for user preference sync (optional)

**Use External Services:**
- Google Maps/Mapbox for full transit routing (MapKit insufficient)
- Custom backend for real-time vehicle tracking
- Third-party analytics (Apple Analytics limited)

**Avoid:**
- MapKit transit routing (ETA only, no full directions)
- SwiftData (buggy, iOS 17+ only, performance issues)
- Significant-change location service (battery drain, limited updates)

---

## MapKit

### Transit Mode Support

**Available Features:**
- Transit ETA requests between two points
- Launch Apple Maps with transit directions
- Set transport type to `.transit` in MKDirectionsRequest
- Display transit stops on map
- Basic map rendering and annotations

**Critical Limitations:**
- **NO full transit routing calculations** in third-party apps
- Cannot compute step-by-step directions with transfers
- Cannot display transit route polylines programmatically
- Cannot access schedule data or stop sequences
- MKDirections returns null for transit routing requests

**What This Means:**
You can request "how long will this trip take by transit?" but NOT "show me the route with transfers and walking directions."

### Geocoding Capabilities

**Forward Geocoding:**
```swift
let geocoder = CLGeocoder()
geocoder.geocodeAddressString("Sydney Opera House") { placemarks, error in
    // Returns coordinate, name, address components
}
```

**Reverse Geocoding:**
```swift
geocoder.reverseGeocodeLocation(location) { placemarks, error in
    // Returns address from coordinates
}
```

**Limits:**
- 50 geocoding requests per minute per app
- Throttled if exceeded, returns error

### When to Use MapKit vs Alternatives

| Use Case | Recommendation | Reason |
|----------|---------------|---------|
| Basic map display | MapKit | Free, native, good performance |
| POI search | MapKit | Good coverage, free |
| Transit routing | Google Maps API | MapKit doesn't support it |
| Walking/driving | MapKit | Works well, free |
| Custom styling | Mapbox | More flexibility |
| Offline maps | Mapbox/custom | MapKit doesn't support |

### Transit Data Coverage

**Limited Coverage:** Apple Maps transit available in 300+ cities worldwide (as of 2024), primarily:
- Major US/Canadian cities
- European capitals
- 300+ Chinese cities
- Limited Australian coverage (Sydney, Melbourne)

**Australia Specific:** New map data released Dec 2021, but transit coverage limited compared to Google Transit.

### Cost: FREE

---

## WeatherKit (iOS 16+)

### Available Weather Data

**Current & Forecast:**
- Current conditions
- 10-day forecast
- Hourly forecasts
- Temperature, precipitation, wind, UV index
- iOS 18+: Snowfall/sleet totals, cloud cover %, historical comparisons

**Special Features:**
- Minute-by-minute precipitation (next hour) - select regions
- Severe weather alerts - select regions
- Hyperlocal precision

### Australian Coverage

**Status:** WeatherKit works in Australia with server infrastructure in Melbourne.

**Coverage Quality:**
- Global coverage leveraging Apple Weather service
- "Select regions" features (minute precipitation, alerts) may be limited
- No specific AU limitations documented

### Cost Structure

**Free Tier:**
- 500,000 API calls/month per Apple Developer Program membership ($99/year)
- Unused calls don't roll over

**Paid Tiers:**
- $49.99/month: 1 million calls
- Scaling up to $9,999.99/month: 200 million calls

**Cost Calculator:**
- 10,000 daily active users
- 3 weather checks/day/user
- = 900,000 calls/month
- **Cost:** $49.99/month + $99/year dev program

### WeatherKit vs Bureau of Meteorology (BOM)

| Factor | WeatherKit | BOM |
|--------|-----------|-----|
| Cost | $99/year + overage | FREE |
| API Documentation | Excellent | Reverse-engineered only |
| Reliability | Guaranteed SLA | No guarantees |
| Commercial Use | ✓ Allowed | ⚠️ Contact required |
| Integration | Native Swift + REST | Unofficial, may break |
| Coverage | Global | Australia only |
| Data Freshness | Real-time | Real-time |
| Support | Apple Developer | None |

**BOM Concerns:**
- No official API, data reverse-engineered from beta site
- "No guarantees of availability"
- "Unable to contact users of service changes"
- Commercial use requires Registered User Services
- Could break at any time

### Recommendation: **Use WeatherKit**

**Rationale:**
1. BOM's unofficial API too risky for production app
2. WeatherKit's 500K free tier sufficient for MVP
3. Native iOS integration simpler
4. Paid scaling available if needed
5. Professional support and SLA

**Exception:** If building government/public sector app with BOM partnership, official BOM feeds viable.

### Attribution Requirements

**Mandatory:**
- Display Apple Weather trademark
- Link to weather data sources
- Weather alerts must include meteorological agency names with links

### Code Example

```swift
import WeatherKit
import CoreLocation

let weatherService = WeatherService()
let location = CLLocation(latitude: -33.8688, longitude: 151.2093) // Sydney

let weather = try await weatherService.weather(for: location)

// Current
let temp = weather.currentWeather.temperature
let condition = weather.currentWeather.condition

// Hourly forecast
let hourlyForecast = weather.hourlyForecast

// Daily forecast (10-day)
let dailyForecast = weather.dailyForecast
```

**Platform Requirements:** iOS 16+, macOS 13+, watchOS 9+, tvOS 16+, visionOS 1.0+

---

## CoreLocation

### Background Location Modes

**Available Modes:**

1. **Standard Location (Recommended for Transit)**
```swift
locationManager.desiredAccuracy = kCLLocationAccuracyBest
locationManager.distanceFilter = 50 // meters
locationManager.allowsBackgroundLocationUpdates = true
locationManager.pausesLocationUpdatesAutomatically = true
locationManager.activityType = .otherNavigation
```

2. **Significant-Change Location (NOT Recommended)**
- Triggered only by cell tower changes (~500m)
- Runs continuously, can drain battery
- Throttled if combined with standard location (iOS 16.4+)

3. **Visits Location (Most Efficient)**
- Detects when user arrives/leaves locations
- Best battery efficiency
- Not suitable for real-time tracking

### Battery Impact Benchmarks

| Mode | Battery Impact | Update Frequency | Use Case |
|------|---------------|------------------|----------|
| Visits | Low (5-10%) | Arrival/departure | Station notifications |
| Significant-change | Medium (15-20%) | ~500m changes | NOT recommended |
| Standard (100m accuracy) | Medium (20-30%) | Every 100m | Transit tracking |
| Standard (Best accuracy) | High (30-40%) | Every movement | Active navigation |

**Key Findings:**
- Location services can account for 20-30% battery usage when continuous
- Intelligent management = 30% decrease in consumption
- `pausesLocationUpdatesAutomatically = true` critical for battery

### Accuracy Modes

```swift
// For transit stop detection
kCLLocationAccuracyBest // ~5m, high battery

// For route tracking
kCLLocationAccuracyNearestTenMeters // ~10m, medium battery

// For general area
kCLLocationAccuracyHundredMeters // ~100m, low battery
```

### Geofencing Capabilities

**Hard Limit:** 20 regions maximum per app

**Region Types:**
- CLCircularRegion (geofences)
- CLBeaconRegion (iBeacons)
- **Combined limit of 20 total**

**Workaround for Transit Apps:**
- Monitor only closest stops to user location
- Update monitored regions as user moves
- Implement dynamic region management

**Radius Limits:**
- Minimum: 1 meter
- Maximum: Unlimited (practical ~100km)
- Recommended for transit stops: 50-100 meters

```swift
let stopLocation = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
let region = CLCircularRegion(
    center: stopLocation,
    radius: 75, // meters
    identifier: "stop_123"
)
region.notifyOnEntry = true
region.notifyOnExit = true

locationManager.startMonitoring(for: region)
```

### Best Practices for Transit Apps

1. **Set Activity Type:**
```swift
locationManager.activityType = .otherNavigation
```

2. **Enable Auto-Pause:**
```swift
locationManager.pausesLocationUpdatesAutomatically = true
```

3. **Use Appropriate Accuracy:**
- Tracking journey: `kCLLocationAccuracyNearestTenMeters`
- Finding nearby stops: `kCLLocationAccuracyHundredMeters`

4. **Background Requirements:**
- Enable "Location updates" in Capabilities
- Add NSLocationAlwaysAndWhenInUseUsageDescription to Info.plist
- Add NSLocationWhenInUseUsageDescription to Info.plist

5. **iOS 16.4+ Warning:**
- Avoid combining `startUpdatingLocation()` + `startMonitoringSignificantLocationChanges()`
- App may suspend in background with low accuracy settings

### Background Limitations

- App can be suspended after 10 minutes to hours in background
- System decides when to suspend based on battery/activity
- Use background modes declaration to extend time
- No guaranteed continuous tracking

---

## WidgetKit

### Widget Types

**Home Screen Widgets:**
- Small: 2x2 grid
- Medium: 4x2 grid
- Large: 4x4 grid

**Lock Screen Widgets (iOS 16+):**
- Circular: Single value/icon
- Rectangular: Small horizontal widget
- Inline: Single line of text above clock

**iOS 17+:** Interactive widgets (buttons, toggles) - home screen only

### Lock Screen Widgets

**Design Philosophy:** Glanceable, non-interactive (tap launches app)

**Privacy:** Can hide sensitive info when device locked

**Image Size Limits:**
- Lock screen: Max ~120x120px
- Large images (1200x1200px) will fail
- Keep assets small for memory constraints

**Widget Families:**
```swift
@main
struct TransitWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextBusWidget() // Home screen
        NextBusLockScreenWidget() // Lock screen
    }
}

struct NextBusLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextBus", provider: Provider()) { entry in
            NextBusLockScreenView(entry: entry)
        }
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
```

### Data Refresh Limits

**Daily Budget:** 40-70 refreshes for frequently viewed widgets

**Doesn't Count Against Budget:**
- App in foreground
- Active audio/navigation session
- System locale changes
- Dynamic Type/Accessibility changes

**Timeline Reload Policies:**

1. **atEnd** - Refresh when last entry displayed
2. **after(Date)** - Refresh at specific time
3. **never** - Manual refresh only

### Best Practices for Transit Widgets

**Maximize Timeline Entries:**
```swift
func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
    var entries: [SimpleEntry] = []

    // Create entry for each departure in next hour
    for departureTime in nextDepartures {
        entries.append(SimpleEntry(date: departureTime, nextBus: busInfo))
    }

    // Refresh after last entry
    let timeline = Timeline(entries: entries, policy: .atEnd)
    completion(timeline)
}
```

**Recommendations:**
- Provide as many future entries as possible
- Keep entries ≥5 minutes apart
- Use `.atEnd` policy for predictable refreshes
- Avoid `.after(Date)` with <5 minute intervals
- Don't exceed 70 refreshes/day
- Pre-order data to avoid ORDER BY in timeline

**Real-Time Updates:**
- Use multiple timeline entries for departure countdowns
- Refresh every 5-15 minutes during active hours
- Reduce refresh rate during off-peak hours
- Widget shows within 1-2 seconds of scheduled time

### Size Limits

**Runtime:**
- Limited execution time
- No long-running tasks
- No network requests in widget view
- All data from timeline provider

**Storage:**
- Share data via App Groups
- Use UserDefaults or local files
- Keep data fresh from main app

---

## ActivityKit (Live Activities)

### iOS Version Requirement

**Minimum:** iOS 16.1+

**Dynamic Island:** iPhone 14 Pro and later (iOS 16.1+)

### Duration Limits

**Active in Dynamic Island:** 8 hours maximum
- After 8 hours, automatically ends
- Removed from Dynamic Island

**Lock Screen Display:** Additional 4 hours
- Remains on Lock Screen after Dynamic Island removal
- **Total maximum: 12 hours**

**Implications for Transit:**
- Perfect for trips <8 hours
- Long-haul journeys need restart mechanism
- Consider ending/restarting at transfers

### Data Update Mechanisms

**1. ActivityKit Updates (Local):**
```swift
let activityAttributes = TripAttributes(routeNumber: "333")
let initialState = TripAttributes.ContentState(
    nextStop: "Central Station",
    arrivalTime: Date().addingTimeInterval(300)
)

let activity = try Activity<TripAttributes>.request(
    attributes: activityAttributes,
    contentState: initialState
)

// Update later
Task {
    let updatedState = TripAttributes.ContentState(
        nextStop: "Town Hall",
        arrivalTime: Date().addingTimeInterval(180)
    )
    await activity.update(using: updatedState)
}
```

**2. ActivityKit Push Notifications:**
- Update from remote server
- Requires APNs push token
- Counts against notification budget

**3. Broadcast Push (iOS 18+):**
- Single push updates ALL Live Activities
- Perfect for transit: one update for all users on same route
- Massive efficiency gain

### Data Size Restrictions

**Hard Limit:** 4 KB combined
- Static attributes
- Dynamic content state
- ActivityKit updates
- Push notification payloads

**For Transit Apps:**
- Store route/stop IDs, not full names
- Use abbreviations
- Compress data structure
- Reference app's local database

### Network & Location Access

**Critical Limitation:** Live Activities run in isolated sandbox

**CANNOT Access:**
- Network directly
- Location updates
- Background tasks
- Main app data (except shared container)

**MUST Use:**
- ActivityKit push notifications for updates
- Shared App Group container for data
- Pre-loaded data in initial state

### Image Size Constraints

**Dynamic Island Minimal:**
- Max ~45x36.67 points
- Keep images tiny
- Use SF Symbols when possible

**Lock Screen:**
- Slightly larger allowed
- Still constrain to <100x100 points

### Push Notification Budget

**Budget Limit:** Apple restricts updates per hour (exact number undisclosed)

**Priority Levels:**
- Priority 10 (immediate): Counts against budget heavily
- Priority 5 (lower): Less impact on budget

**For Frequent Updates:**
```xml
<!-- Info.plist -->
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

**Best Practices:**
- Use priority 5 for routine updates
- Reserve priority 10 for critical alerts
- Batch updates when possible
- iOS 18+ use broadcast push

### Use Cases for Transit Tracking

**Excellent For:**
- Active trip tracking (next stop, arrival time)
- Service alerts during journey
- Platform changes
- Real-time delays

**Not Suitable For:**
- Multi-day tracking (12hr limit)
- All-day background monitoring
- Non-active journey planning

### Example: Trip Tracking

```swift
import ActivityKit

struct TripAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentStop: String
        var nextStop: String
        var stopsRemaining: Int
        var estimatedArrival: Date
        var delayMinutes: Int
    }

    var routeNumber: String
    var destination: String
}

// Start Live Activity when boarding
let attributes = TripAttributes(routeNumber: "333", destination: "Bondi")
let state = TripAttributes.ContentState(
    currentStop: "Central",
    nextStop: "Town Hall",
    stopsRemaining: 12,
    estimatedArrival: Date().addingTimeInterval(900),
    delayMinutes: 0
)

let activity = try Activity<TripAttributes>.request(
    attributes: attributes,
    contentState: state,
    pushType: .token
)

// Get push token for remote updates
for await pushToken in activity.pushTokenUpdates {
    let token = pushToken.map { String(format: "%02x", $0) }.joined()
    // Send to your server
}
```

---

## Push Notifications

### APNs Quotas and Limits

**Throughput:**
- **No caps or batch limits**
- Target: 9,000 notifications/second
- If below 9,000/sec, improve error handling

**Payload Size:**
- HTTP/2 (current): 4 KB maximum
- Legacy binary: 2 KB maximum

**Text Limits:**
- Title + subtitle: 256 characters max
- Body: 2,048 characters max

### Background Update Notifications (Silent Push)

**Severe Throttling:**
- Limited to ~2 per hour
- Treated as low priority
- May be dropped entirely if excessive

**Recommendation:** Don't rely on silent push for frequent updates

### Time-Sensitive Notifications

**Interruption Levels:**
- `passive`: No sound/banner
- `active`: Normal notification
- `time-sensitive`: Breaks through Focus
- `critical`: Breaks through mute (requires entitlement)

**For Transit Apps:**
```swift
let content = UNMutableNotificationContent()
content.title = "Bus 333 arriving in 2 minutes"
content.interruptionLevel = .timeSensitive

// Requires capability in App ID
```

**Setup:**
- Add "Time Sensitive Notifications" capability to App ID
- User can disable per-app in Settings > Notifications

### Notification Grouping

**Thread Identifier:**
```swift
content.threadIdentifier = "route_333"
```

Groups notifications by route/trip for clean notification center.

### Best Practices

1. **Use APNs for:**
   - Service alerts
   - Arrival notifications
   - Route changes
   - Live Activity updates

2. **Avoid Silent Push for:**
   - Frequent data syncs
   - Regular updates
   - Background refresh (use URLSession instead)

3. **Optimize Payload:**
   - Keep under 4 KB
   - Use notification service extension for rich content
   - Compress data, use IDs instead of full text

4. **Respect User Preferences:**
   - Allow granular notification settings
   - Don't spam
   - Use time-sensitive judiciously

---

## Data Storage

### CoreData vs SQLite vs Realm for GTFS Data

**GTFS Characteristics:**
- Large datasets (millions of stop_times records)
- Complex relational structure (routes → trips → stop_times)
- Read-heavy operations
- Spatial queries (nearby stops)
- Infrequent writes (daily/weekly updates)

| Factor | CoreData | SQLite (direct) | Realm |
|--------|----------|----------------|-------|
| **Performance** | Good with optimization | Excellent | Excellent |
| **Learning Curve** | Medium | Low (if know SQL) | Low |
| **GTFS Fit** | Good | **Best** | Good |
| **Large Datasets** | Slower without tuning | Fast with indexes | Fast |
| **Full-Text Search** | Limited | **FTS5 excellent** | Basic |
| **Spatial Queries** | Custom | **R-Tree extension** | Manual |
| **Migration** | Complex | Manual but flexible | Easier |
| **iOS Integration** | Native | Native (SQLite.framework) | Third-party |
| **Size** | Larger overhead | Minimal | Medium |
| **SwiftData** | ⚠️ Buggy (avoid) | N/A | N/A |

### Recommendation: **SQLite with FTS5**

**Rationale:**
1. **FTS5 (Full-Text Search):** Perfect for stop name/route search
2. **R-Tree:** Efficient spatial queries for nearby stops
3. **Direct SQL:** Flexibility for complex GTFS queries
4. **Performance:** Fastest for read-heavy transit data
5. **GTFS Tools:** Most GTFS libraries output SQLite
6. **Size:** Minimal overhead vs CoreData/Realm

### SQLite FTS5 Implementation

**Schema Example:**
```sql
-- Stops table with FTS
CREATE TABLE stops (
    stop_id TEXT PRIMARY KEY,
    stop_name TEXT,
    stop_lat REAL,
    stop_lon REAL,
    stop_code TEXT
);

-- FTS5 virtual table for search
CREATE VIRTUAL TABLE stops_fts USING fts5(
    stop_id UNINDEXED,
    stop_name,
    stop_code,
    content=stops,
    content_rowid=rowid
);

-- Triggers to keep FTS in sync
CREATE TRIGGER stops_ai AFTER INSERT ON stops BEGIN
    INSERT INTO stops_fts(rowid, stop_id, stop_name, stop_code)
    VALUES (new.rowid, new.stop_id, new.stop_name, new.stop_code);
END;

-- R-Tree for spatial queries
CREATE VIRTUAL TABLE stops_rtree USING rtree(
    id,
    min_lat, max_lat,
    min_lon, max_lon
);
```

**Fast Stop Name Search:**
```swift
let query = "central"
let sql = "SELECT stop_id, stop_name FROM stops_fts WHERE stops_fts MATCH ? LIMIT 20"
// Returns in milliseconds instead of seconds
```

**Nearby Stops (Spatial):**
```swift
let sql = """
SELECT s.stop_id, s.stop_name, s.stop_lat, s.stop_lon
FROM stops_rtree r
JOIN stops s ON r.id = s.rowid
WHERE r.min_lat >= ? AND r.max_lat <= ?
  AND r.min_lon >= ? AND r.max_lon <= ?
"""
```

### Performance Optimization

**Indexes:**
```sql
CREATE INDEX idx_stop_times_trip ON stop_times(trip_id);
CREATE INDEX idx_stop_times_stop ON stop_times(stop_id);
CREATE INDEX idx_trips_route ON trips(route_id);
```

**Best Practices:**
- Use LIMIT in queries (increases speed significantly)
- Avoid ORDER BY if possible (pre-order data)
- Use FTS MATCH instead of LIKE
- Keep database pre-ordered by common sort fields
- Optimize FTS index periodically:
  ```sql
  INSERT INTO stops_fts(stops_fts) VALUES('optimize');
  ```

**iOS Implementation:**
```swift
import SQLite3

class GTFSDatabase {
    var db: OpaquePointer?

    func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("gtfs.db")

        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Error opening database")
        }
    }

    func searchStops(query: String) -> [Stop] {
        let sql = "SELECT stop_id, stop_name FROM stops_fts WHERE stops_fts MATCH ? LIMIT 20"
        var statement: OpaquePointer?
        var stops: [Stop] = []

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, query, -1, nil)

            while sqlite3_step(statement) == SQLITE_ROW {
                let stopId = String(cString: sqlite3_column_text(statement, 0))
                let stopName = String(cString: sqlite3_column_text(statement, 1))
                stops.append(Stop(id: stopId, name: stopName))
            }
        }
        sqlite3_finalize(statement)
        return stops
    }
}
```

### Storage Size Limits

**App Size:**
- Total app: <4 GB (includes all assets)
- Follow-on downloads: Can exceed 4 GB

**User Data:**
- No hard limit (device storage is limit)
- Alert shown when <200 MB free
- Apps can store multiple GB locally

**Caching:**
- Use Caches directory for removable data (GTFS feeds)
- Use Documents directory for permanent data (user favorites)
- Exclude from iCloud backup:
  ```swift
  var url = fileURL
  var resourceValues = URLResourceValues()
  resourceValues.isExcludedFromBackup = true
  try url.setResourceValues(resourceValues)
  ```

### GTFS Dataset Sizes

**Typical Sizes:**
- Small city: 5-20 MB
- Large city (e.g., Sydney): 50-150 MB
- Entire state/region: 200-500 MB

**Storage Strategy:**
- Download compressed GTFS ZIP
- Extract and import to SQLite
- Delete ZIP after import
- Store in Caches (allow OS to purge if needed)

---

## CloudKit

### User Data Sync Capabilities

**What CloudKit Can Sync:**
- User favorites (saved stops, routes)
- Trip history
- Preferences (notifications, themes)
- Saved journeys

**Private vs Public Database:**
- **Private:** User's iCloud, secure, scales automatically
- **Public:** Shared app data, 1 PB storage

**Features:**
- Automatic conflict resolution
- Offline support with local caching
- Device-to-device sync via iCloud
- Built-in user authentication (iCloud account)

### Cost (Free Tier Limits)

**Baseline Free Tier:**
- 40 requests/second
- 2 GB data transfer
- 100 MB database storage
- 10 GB asset storage

**Scaling with Users:**
- Requests scale up per user
- Storage scales per user
- Example: 100K users = 50 TB assets, 500 GB database

**Overage Pricing:**
- $100 per 10 requests/sec
- $0.10/GB data transfer
- $3/GB database storage
- $0.03/GB asset storage

**Realistic Costs:**
Most apps stay within free tier for user preference syncing.

### Privacy Considerations

**Advantages:**
- Data in user's iCloud (not your servers)
- End-to-end encryption for private database
- No user authentication to implement
- GDPR compliant (user controls data)

**Disadvantages:**
- Requires iCloud account
- Users can disable iCloud sync
- Cannot access user's private data from server

### CloudKit vs Custom Backend

| Factor | CloudKit | Custom Backend |
|--------|----------|----------------|
| **Cost** | Free for most apps | Server costs |
| **Development Time** | Fast setup | Slower |
| **Privacy** | User's iCloud | Your responsibility |
| **Offline Sync** | Built-in | Build yourself |
| **User Auth** | Automatic (iCloud) | Implement yourself |
| **Flexibility** | Limited | Full control |
| **Server Access** | Only public DB | Full access |
| **Real-time** | Polling/subscriptions | WebSockets, etc. |

### Recommendation for Transit App

**Use CloudKit for:**
- Saved stops/routes
- User preferences
- Trip history
- Notification settings

**Use Custom Backend for:**
- Real-time vehicle locations
- Service alerts
- User analytics
- Features requiring server processing

**Hybrid Approach:**
- CloudKit: User preferences (syncs across devices)
- Local SQLite: GTFS data (too large for CloudKit)
- Custom backend: Real-time updates (need server push)

### Implementation Example

```swift
import CloudKit

class FavoritesManager {
    let container = CKContainer.default()
    let privateDB = CKContainer.default().privateCloudDatabase

    func saveFavoriteStop(stopId: String, stopName: String) {
        let record = CKRecord(recordType: "FavoriteStop")
        record["stopId"] = stopId as CKRecordValue
        record["stopName"] = stopName as CKRecordValue
        record["dateAdded"] = Date() as CKRecordValue

        privateDB.save(record) { record, error in
            if let error = error {
                print("Error saving: \(error)")
            } else {
                print("Favorite saved to iCloud")
            }
        }
    }

    func fetchFavorites(completion: @escaping ([FavoriteStop]) -> Void) {
        let query = CKQuery(recordType: "FavoriteStop", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]

        privateDB.perform(query, inZoneWith: nil) { records, error in
            guard let records = records else { return }
            let favorites = records.compactMap { FavoriteStop(record: $0) }
            completion(favorites)
        }
    }
}
```

**Enable iCloud:**
1. Add iCloud capability in Xcode
2. Check CloudKit
3. Create container (or use default)

---

## Background Modes

### What's Allowed for Transit Apps

**Enabled Background Modes:**

1. **Location updates** - Track user location for journey
2. **Background fetch** - Update GTFS data periodically
3. **Remote notifications** - Receive push updates
4. **Background processing** - Long-running tasks (iOS 13+)

**Declaration (Info.plist):**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>fetch</string>
    <string>remote-notification</string>
    <string>processing</string>
</array>
```

### Background Fetch Limitations

**Frequency:** System-controlled, unpredictable
- Not guaranteed
- Typically every few hours
- Depends on user behavior patterns
- Battery state affects scheduling

**Time Limit:** ~30 seconds per fetch

**Best Practices:**
```swift
import BackgroundTasks

// Register task
BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.app.gtfs-refresh", using: nil) { task in
    self.handleGTFSRefresh(task: task as! BGProcessingTask)
}

// Schedule task
let request = BGProcessingTaskRequest(identifier: "com.app.gtfs-refresh")
request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 60 * 60) // 12 hours
request.requiresNetworkConnectivity = true
request.requiresExternalPower = false

try? BGTaskScheduler.shared.submit(request)
```

**Don't Use For:**
- Real-time updates (use push notifications)
- Frequent syncs (too unreliable)

**Good For:**
- Daily GTFS feed updates
- Prefetching transit schedules
- Cache maintenance

### Background Location Requirements

**User Permission:**
- Must request "Always" location access
- System shows permission dialog after multiple "When in Use" sessions
- Explain clearly why "Always" needed

**Info.plist Keys:**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby transit stops and track your journey.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Allow "Always" to receive notifications when approaching your stop, even when app is closed.</string>
```

**Background Capability:**
```swift
locationManager.allowsBackgroundLocationUpdates = true
locationManager.pausesLocationUpdatesAutomatically = true
```

**Limitations:**
- System may suspend app after 10+ minutes
- Battery state affects background time
- No guaranteed continuous tracking
- Background location shows blue bar/icon to user

### URLSession Background Downloads

**For GTFS Updates:**
```swift
let config = URLSessionConfiguration.background(withIdentifier: "com.app.gtfs-download")
let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

let url = URL(string: "https://data.transport.nsw.gov.au/gtfs.zip")!
let task = session.downloadTask(with: url)
task.resume()
```

**Characteristics:**
- Continues even if app terminated
- System manages download
- Limit concurrent downloads (set `httpMaximumConnectionsPerHost = 1`)
- Best for large files (GTFS feeds)

**Limitations:**
- URLSessionDataTask NOT supported in background
- Only URLSessionDownloadTask and URLSessionUploadTask
- System controls scheduling
- May delay downloads to conserve battery

---

## iOS Version Decision Framework

### Feature Availability by Version

| Feature | iOS 15 | iOS 16 | iOS 17 | iOS 18 |
|---------|--------|--------|--------|--------|
| **CoreLocation** | ✓ | ✓ | ✓ | ✓ |
| **MapKit** | ✓ | ✓ | Enhanced | Enhanced |
| **WeatherKit** | ✗ | ✓ | ✓ | ✓ Enhanced |
| **Lock Screen Widgets** | ✗ | ✓ | ✓ | ✓ |
| **Live Activities** | ✗ | ✓ (16.1+) | ✓ | ✓ Broadcast |
| **Interactive Widgets** | ✗ | ✗ | ✓ | ✓ |
| **SwiftData** | ✗ | ✗ | ✓ Buggy | ✓ Better |
| **Dynamic Island** | ✗ | ✓ (Pro only) | ✓ | ✓ |

### Market Share by iOS Version

**As of October 2024:**
- iOS 18: 68% (78% on devices <4 years old)
- iOS 17: ~20%
- iOS 16: ~8%
- iOS 15: <3%
- iOS 14 and older: <1%

**January 2025 Update:**
- iOS 18: 68-82% (varying sources)
- iOS 17: 20-23%
- iOS 16+: 96%+ combined

**Adoption Rate:**
- iOS 18 reached 68% in 4 months (similar to iOS 17)
- Apple Intelligence didn't significantly boost adoption
- Users upgrade rapidly within first 6 months

### Minimum Version Recommendation

**Primary Recommendation: iOS 16+**

**Rationale:**
1. **96%+ market coverage** (iOS 16+17+18)
2. **WeatherKit available** (critical for transit UX)
3. **Lock Screen widgets** (high visibility)
4. **Live Activities** (iOS 16.1+, excellent for trip tracking)
5. **Stable platform** (iOS 16 released Sept 2022, mature)
6. **Developer consensus** (industry standard)

**Trade-offs:**

| Min Version | Coverage | Features | Maintenance |
|-------------|----------|----------|-------------|
| **iOS 16** | **96%+** | **All key features** | **Low complexity** |
| iOS 15 | 99%+ | No WeatherKit, no Lock widgets | More code paths |
| iOS 17 | 88%+ | Interactive widgets, SwiftData | Cutting edge only |

**Avoid iOS 15:**
- Loses only 3-4% of users
- Gains WeatherKit, Lock Screen widgets, Live Activities
- Significantly simplifies codebase
- iOS 15 users typically upgrade quickly

**Avoid iOS 17+:**
- Loses 12% of potential users
- Gains: Interactive widgets (nice but not essential)
- SwiftData still buggy (avoid anyway)
- Not worth the user loss

### Special Considerations

**Dynamic Island (Live Activities):**
- Only iPhone 14 Pro+ have Dynamic Island hardware
- Live Activities still work on all iOS 16.1+ devices (Lock Screen)
- Design for both Dynamic Island and standard Lock Screen

**WeatherKit:**
- If weather critical: iOS 16+ required
- If weather optional: iOS 15+ with fallback

**Interactive Widgets:**
- If widget interaction essential: iOS 17+
- For most transit apps: Lock Screen widgets (iOS 16) sufficient

### Recommendation Summary

**Build for iOS 16+**
- Set Deployment Target: iOS 16.0
- Test on iOS 16, 17, 18
- Use WeatherKit, Live Activities, Lock Screen widgets
- Adopt new iOS 18 features progressively (broadcast push)
- Re-evaluate annually as iOS 18 adoption increases

**Exceptions:**
- Enterprise/government apps: May need iOS 15 for older devices
- Cutting-edge apps: iOS 17+ for latest features
- Legacy apps: iOS 15+ during transition period

---

## Code Examples

### Complete Location Manager Setup

```swift
import CoreLocation

class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 50 // meters
        manager.pausesLocationUpdatesAutomatically = true
        manager.activityType = .otherNavigation
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
    }

    func monitorStop(stop: Stop) {
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon),
            radius: 75,
            identifier: stop.id
        )
        region.notifyOnEntry = true
        manager.startMonitoring(for: region)
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        // User approached stop
        NotificationCenter.default.post(name: .didEnterStop, object: region.identifier)
    }
}
```

### Widget with Timeline

```swift
import WidgetKit
import SwiftUI

struct NextBusEntry: TimelineEntry {
    let date: Date
    let route: String
    let destination: String
    let minutesUntilArrival: Int
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NextBusEntry {
        NextBusEntry(date: Date(), route: "333", destination: "Bondi", minutesUntilArrival: 5)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextBusEntry) -> ()) {
        let entry = NextBusEntry(date: Date(), route: "333", destination: "Bondi", minutesUntilArrival: 5)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextBusEntry>) -> ()) {
        var entries: [NextBusEntry] = []
        let currentDate = Date()

        // Fetch next departures
        let departures = fetchNextDepartures() // Your function

        // Create entry for each departure
        for departure in departures {
            let entryDate = departure.departureTime.addingTimeInterval(-60) // 1 min before
            let minutes = Int(departure.departureTime.timeIntervalSince(entryDate) / 60)

            entries.append(NextBusEntry(
                date: entryDate,
                route: departure.route,
                destination: departure.destination,
                minutesUntilArrival: minutes
            ))
        }

        // Refresh after last entry (or in 1 hour if no departures)
        let refreshDate = entries.last?.date.addingTimeInterval(60) ?? currentDate.addingTimeInterval(3600)
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }
}

struct NextBusWidgetView: View {
    var entry: NextBusEntry

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(entry.route)
                    .font(.system(size: 24, weight: .bold))
                Spacer()
                Text("\(entry.minutesUntilArrival) min")
                    .font(.system(size: 18, weight: .semibold))
            }
            Text(entry.destination)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

@main
struct NextBusWidget: Widget {
    let kind = "NextBusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NextBusWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Bus")
        .description("Shows your next bus arrival time")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
```

### Live Activity Implementation

```swift
import ActivityKit
import Foundation

struct TripAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentStop: String
        var nextStop: String
        var stopsRemaining: Int
        var estimatedArrival: Date
        var delayMinutes: Int
        var routeNumber: String
    }

    var destination: String
    var routeColor: String
}

class TripTracker {
    var currentActivity: Activity<TripAttributes>?

    func startTrip(route: String, destination: String) async {
        let attributes = TripAttributes(destination: destination, routeColor: "#FF0000")
        let initialState = TripAttributes.ContentState(
            currentStop: "Starting",
            nextStop: "First Stop",
            stopsRemaining: 10,
            estimatedArrival: Date().addingTimeInterval(600),
            delayMinutes: 0,
            routeNumber: route
        )

        do {
            currentActivity = try Activity<TripAttributes>.request(
                attributes: attributes,
                contentState: initialState,
                pushType: .token
            )

            // Get push token for server updates
            for await pushToken in currentActivity!.pushTokenUpdates {
                let token = pushToken.map { String(format: "%02x", $0) }.joined()
                await sendPushTokenToServer(token)
            }
        } catch {
            print("Error starting activity: \(error)")
        }
    }

    func updateTrip(nextStop: String, stopsRemaining: Int, delay: Int) async {
        guard let activity = currentActivity else { return }

        let updatedState = TripAttributes.ContentState(
            currentStop: activity.contentState.nextStop,
            nextStop: nextStop,
            stopsRemaining: stopsRemaining,
            estimatedArrival: Date().addingTimeInterval(Double(stopsRemaining * 120)),
            delayMinutes: delay,
            routeNumber: activity.contentState.routeNumber
        )

        await activity.update(using: updatedState)
    }

    func endTrip() async {
        guard let activity = currentActivity else { return }
        await activity.end(dismissalPolicy: .immediate)
    }

    private func sendPushTokenToServer(_ token: String) async {
        // Send to your backend for push notification updates
    }
}

// Live Activity View
struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripAttributes.self) { context in
            // Lock Screen UI
            VStack {
                HStack {
                    Text("Route \(context.state.routeNumber)")
                    Spacer()
                    Text("\(context.state.stopsRemaining) stops")
                }
                Text("Next: \(context.state.nextStop)")
                if context.state.delayMinutes > 0 {
                    Text("Delayed \(context.state.delayMinutes) min")
                        .foregroundColor(.red)
                }
            }
        } dynamicIsland: { context in
            // Dynamic Island UI (iPhone 14 Pro+)
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Route \(context.state.routeNumber)")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.stopsRemaining)")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Next: \(context.state.nextStop)")
                }
            } compactLeading: {
                Text(context.state.routeNumber)
            } compactTrailing: {
                Text("\(context.state.stopsRemaining)")
            } minimal: {
                Text(context.state.routeNumber)
            }
        }
    }
}
```

---

## Performance Recommendations

### Battery Optimization

1. **Location Tracking:**
   - Use `pausesLocationUpdatesAutomatically = true`
   - Set appropriate `activityType`
   - Reduce accuracy when precision not needed
   - Stop tracking when user completes journey

2. **Background Refresh:**
   - Schedule GTFS updates during low-usage hours
   - Use `requiresExternalPower` for large downloads
   - Minimize background fetch frequency

3. **Widgets:**
   - Stay within 40-70 refresh budget
   - Provide multiple timeline entries
   - Reduce refresh rate during off-peak

4. **Network:**
   - Cache GTFS data locally
   - Use background URLSession for large downloads
   - Compress API responses
   - Implement offline mode

### Memory Optimization

1. **GTFS Data:**
   - Load only needed routes/stops into memory
   - Use database queries instead of loading all data
   - Implement pagination for large result sets
   - Release cached data when not needed

2. **Widgets:**
   - Keep images small (<120px)
   - Limit timeline entries to reasonable number
   - Use SF Symbols instead of custom images

3. **Live Activities:**
   - Keep data under 4 KB
   - Use IDs instead of full strings
   - Share minimal data between app and activity

---

## Decision Matrix

### Quick Reference Table

| Need | iOS Solution | Alternative | Recommendation |
|------|-------------|-------------|----------------|
| **Transit Routing** | MapKit (ETA only) | Google Maps API | **Google Maps** |
| **Weather** | WeatherKit | BOM API | **WeatherKit** |
| **Location Tracking** | CoreLocation | None | **CoreLocation** |
| **GTFS Storage** | CoreData/SQLite | Realm | **SQLite + FTS5** |
| **Stop Search** | Core Spotlight | SQLite FTS | **SQLite FTS5** |
| **User Sync** | CloudKit | Custom backend | **CloudKit** |
| **Widgets** | WidgetKit | None | **WidgetKit** |
| **Trip Tracking** | Live Activities | Push notifications | **Live Activities** |
| **Background Updates** | APNs | Background fetch | **APNs** |
| **Maps Display** | MapKit | Google Maps | **MapKit** |
| **Geofencing** | CoreLocation | None | **CoreLocation** (20 limit) |

---

## Common Pitfalls

### 1. MapKit Transit Routing
**Mistake:** Assuming MapKit can provide full transit directions
**Reality:** Only provides ETA, must use external API for routing
**Solution:** Use Google Maps Directions API or build custom router

### 2. SwiftData
**Mistake:** Using SwiftData for GTFS data on iOS 17
**Reality:** Buggy, performance issues, iOS 17+ only
**Solution:** Use SQLite directly with FTS5

### 3. Significant-Change Location
**Mistake:** Using for real-time transit tracking
**Reality:** Only updates every ~500m, drains battery
**Solution:** Use standard location with appropriate accuracy

### 4. Widget Refresh Expectations
**Mistake:** Expecting real-time widget updates
**Reality:** 40-70 refreshes/day budget, not guaranteed
**Solution:** Use timeline entries, accept 5-15 minute intervals

### 5. Live Activity Duration
**Mistake:** Starting Live Activity for all-day tracking
**Reality:** 8-hour active limit, 12-hour total
**Solution:** Use for active trips only, restart at transfers if needed

### 6. Silent Push for Frequent Updates
**Mistake:** Using background push for real-time updates
**Reality:** Throttled to ~2/hour
**Solution:** Use regular push or Live Activity push

### 7. Geofencing Scale
**Mistake:** Monitoring 100+ transit stops
**Reality:** 20 region limit
**Solution:** Monitor only nearest stops, update dynamically

### 8. Background Fetch Reliability
**Mistake:** Relying on background fetch for critical updates
**Reality:** Unpredictable timing, not guaranteed
**Solution:** Use push notifications for time-sensitive updates

---

## Testing Recommendations

### Location Testing

**Xcode Simulator:**
- Debug > Location > Custom Location
- Freeway Drive, City Run for simulated movement
- GPX files for route simulation

**Device Testing:**
```swift
#if DEBUG
// Override location for testing
let testLocation = CLLocation(latitude: -33.8688, longitude: 151.2093)
#endif
```

### Widget Testing

**Timeline Debugging:**
```swift
func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
    print("Widget timeline requested at \(Date())")
    // Your code
}
```

**Force Refresh:**
- Long-press widget > Edit Widget
- Or use `WidgetCenter.shared.reloadTimelines(ofKind: "YourWidget")`

### Live Activity Testing

**Simulator:**
- Run app, start Live Activity
- Lock screen (Cmd+L) to see Lock Screen UI
- Swipe down from top-right for Dynamic Island (iPhone 14 Pro simulator)

**Update Testing:**
```swift
// In debug builds, add UI to manually trigger updates
Button("Update Activity") {
    Task {
        await tripTracker.updateTrip(nextStop: "Test Stop", stopsRemaining: 5, delay: 2)
    }
}
```

### Background Mode Testing

**Location:**
- Enable "Allow Simulated Locations" in scheme
- Use GPX file with multiple points
- Background app and observe location updates in Xcode console

**Background Fetch:**
```bash
# Trigger background fetch
xcrun simctl launch booted YourBundleID --attach
```

---

## Resources

### Apple Documentation

- [MapKit](https://developer.apple.com/documentation/mapkit)
- [WeatherKit](https://developer.apple.com/documentation/weatherkit)
- [CoreLocation](https://developer.apple.com/documentation/corelocation)
- [WidgetKit](https://developer.apple.com/documentation/widgetkit)
- [ActivityKit](https://developer.apple.com/documentation/activitykit)
- [CloudKit](https://developer.apple.com/documentation/cloudkit)

### WWDC Sessions

- WWDC15: What's New in MapKit
- WWDC16: Public Transit in Apple Maps
- WWDC22: What's New in WeatherKit
- WWDC22: What's New in MapKit
- WWDC23: Update Live Activities with push notifications
- WWDC24: Broadcast updates to your Live Activities

### Third-Party Tools

- **GTFS Processing:** [OneBusAway GTFSKit](https://github.com/OneBusAway/OBAKit)
- **SQLite GUI:** [DB Browser for SQLite](https://sqlitebrowser.org/)
- **FTS Testing:** [SQLite Online](https://sqliteonline.com/)

### Community Resources

- [Apple Developer Forums - MapKit](https://developer.apple.com/forums/tags/mapkit)
- [Apple Developer Forums - WeatherKit](https://developer.apple.com/forums/tags/weatherkit)
- [Stack Overflow - iOS Location](https://stackoverflow.com/questions/tagged/core-location)

---

## Changelog

**Version 1.0 (October 2024):**
- Initial research and documentation
- iOS 18 features included
- Market share updated to October 2024 data
- All native capability assessments completed

---

*This document compiled from Apple Developer Documentation, WWDC sessions, developer blogs, Stack Overflow, and iOS developer community resources.*
# GTFS Standards & Transit Routing Reference

## Executive Summary

### Key Concepts
- **GTFS Static**: Text-based specification defining scheduled transit data (routes, stops, schedules)
- **GTFS Realtime**: Protocol Buffer-based format for live vehicle positions, trip updates, service alerts
- **Transit Routing**: Algorithms designed for multi-criteria optimization (arrival time + transfers)
- **Complexity**: Medium-high; requires understanding time calculations, timezone handling, calendar logic, graph algorithms

### Recommended Approach for iOS App
1. **Data Storage**: SQLite with integer identifiers, denormalized data for performance
2. **Routing Algorithm**: RAPTOR (Round-based Public Transit Optimized Router) - no preprocessing, good mobile performance
3. **Realtime Integration**: Swift Protobuf with server-side parsing layer
4. **Update Strategy**: Background updates with incremental GTFS refresh

---

## GTFS Static Specification

### Overview
- **Format**: Collection of CSV text files (.txt) in single ZIP archive
- **License**: Apache 2.0
- **Current Version**: Revised July 9, 2025
- **Official Spec**: https://gtfs.org/documentation/overview/
- **GitHub**: https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md

### Required Files (Core 7)

#### 1. agency.txt
Defines transit agencies operating the services.

**Key Fields**:
- `agency_id` - Unique identifier (required if multiple agencies)
- `agency_name` - Full agency name
- `agency_url` - Agency website
- `agency_timezone` - Timezone (IANA format, e.g., "America/New_York")
- `agency_lang` - Primary language (ISO 639-1)

**Best Practice**: Maintain stable `agency_id` across feed versions

#### 2. routes.txt
Transit routes (e.g., "Bus Line 5", "Blue Line Metro")

**Key Fields**:
- `route_id` - Unique identifier
- `agency_id` - References agency.txt
- `route_short_name` - Public-facing short name (e.g., "5", "Blue")
- `route_long_name` - Full descriptive name
- `route_type` - Mode of transportation:
  - 0: Tram/Light Rail
  - 1: Subway/Metro
  - 2: Rail
  - 3: Bus
  - 4: Ferry
  - 5: Cable Car
  - 6: Gondola
  - 7: Funicular
- `route_color` - Hex color (without #)
- `route_text_color` - Text color for readability

**Best Practice**: Use Mixed Case, not ALL CAPS; branches should use distinct `route_short_name` if marketed separately, otherwise use `trip_headsign`

#### 3. trips.txt
Individual journey instances along a route.

**Key Fields**:
- `trip_id` - Unique identifier
- `route_id` - References routes.txt
- `service_id` - References calendar.txt or calendar_dates.txt
- `trip_headsign` - Destination text shown to passengers
- `direction_id` - 0 or 1 for opposite directions
- `block_id` - Groups trips where vehicle continues between them
- `shape_id` - References shapes.txt (optional)
- `wheelchair_accessible` - 0=unknown, 1=yes, 2=no

**Best Practice**: Don't include route name in headsign; never begin with "To" or "Towards"; for loop routes, use `stop_headsign` to indicate direction changes

#### 4. stops.txt
Physical locations where vehicles stop.

**Key Fields**:
- `stop_id` - Unique identifier
- `stop_name` - Name visible to passengers
- `stop_lat` - Latitude (WGS84)
- `stop_lon` - Longitude (WGS84)
- `location_type` - 0=stop/platform, 1=station, 2=entrance/exit, 3=generic node, 4=boarding area
- `parent_station` - Groups platforms under station
- `wheelchair_boarding` - 0=unknown, 1=accessible, 2=not accessible
- `platform_code` - Platform identifier for passengers
- `stop_timezone` - Overrides agency_timezone if needed

**Best Practice**: Location accuracy within 4 meters; place on correct side of street; maintain persistent `stop_id` across versions

#### 5. stop_times.txt
Arrival/departure times for each stop on each trip.

**Key Fields**:
- `trip_id` - References trips.txt
- `arrival_time` - Time in HH:MM:SS (can exceed 24:00:00)
- `departure_time` - Time in HH:MM:SS
- `stop_id` - References stops.txt
- `stop_sequence` - Order of stops (0-based or 1-based, must increase)
- `pickup_type` - 0=regular, 1=none, 2=phone ahead, 3=coordinate with driver
- `drop_off_type` - Same as pickup_type
- `timepoint` - 0=approximate, 1=exact

**Critical Implementation Details**:
- Times measured from "noon minus 12h" in `agency_timezone` (effectively midnight)
- Service day can exceed 24 hours (e.g., 25:30:00 for 1:30 AM next day)
- Always use `agency_timezone` even for trips crossing timezones
- Times must always increase throughout trip

#### 6. calendar.txt
Regular service schedules (Monday-Sunday patterns).

**Key Fields**:
- `service_id` - Unique identifier
- `monday` through `sunday` - 1=available, 0=not available
- `start_date` - YYYYMMDD format
- `end_date` - YYYYMMDD format

**Best Practice**: Include `service_name` field (non-standard but recommended) for human readability

#### 7. calendar_dates.txt
Service exceptions (holidays, special events).

**Key Fields**:
- `service_id` - References calendar.txt
- `date` - YYYYMMDD format
- `exception_type` - 1=service added, 2=service removed

**Best Practice**: Remove expired services; use GTFS-Realtime for changes within 7 days rather than updating static feed

### Optional Files (15+)

#### shapes.txt
Geographic path taken by vehicles (route visualization).

**Key Fields**:
- `shape_id` - Unique identifier
- `shape_pt_lat` - Point latitude
- `shape_pt_lon` - Point longitude
- `shape_pt_sequence` - Order of points
- `shape_dist_traveled` - Distance from first point (meters)

**Best Practice**: Route alignment within 100m of served stops; remove extraneous points; downsample for mobile apps

**Implementation Notes**:
- One route may have many shapes (different trip patterns)
- Often unnecessarily high resolution
- Can aggregate points into PostGIS LineString for efficient querying

#### frequencies.txt
Headway-based service (frequency rather than fixed schedule).

**Key Fields**:
- `trip_id` - References trips.txt
- `start_time` - Period start (HH:MM:SS)
- `end_time` - Period end
- `headway_secs` - Seconds between departures
- `exact_times` - 0=frequency-based, 1=schedule-based compressed

**Two Service Types**:
1. **Frequency-based** (`exact_times=0`): Operators maintain headways, not specific times; actual stop times ignored except intervals between stops
2. **Schedule-based compressed** (`exact_times=1`): Fixed schedule with consistent headways

**Best Practice**: Set first stop time to 00:00:00 for clarity; avoid `headway_secs` > 1200 (20 min) for frequency-based

#### transfers.txt
Transfer rules between routes/stops.

**Key Fields**:
- `from_stop_id` - Origin stop
- `to_stop_id` - Destination stop
- `transfer_type`:
  - 0: Recommended transfer point
  - 1: Timed transfer (departing vehicle waits)
  - 2: Requires min_transfer_time
  - 3: Not possible
- `min_transfer_time` - Seconds required for transfer

**Best Practice**: Include buffer for schedule variance; MBTA model: `min_transfer_time = min_walk_time + suggested_buffer_time`; typical values: 300s (5 min) for bus, 600s (10 min) for long-distance

**Buffer Strategies**:
- Consider walking distance, schedule reliability, service frequency
- More critical connections need larger buffers
- Some agencies use flat defaults per mode

#### fare_attributes.txt & fare_rules.txt
Fare pricing and application rules.

**fare_attributes.txt**:
- `fare_id` - Unique identifier
- `price` - Fare amount
- `currency_type` - ISO 4217 code
- `payment_method` - 0=on board, 1=before boarding
- `transfers` - Number allowed (empty=unlimited)
- `transfer_duration` - Validity period (seconds)

**fare_rules.txt**:
- `fare_id` - References fare_attributes.txt
- `route_id` - Specific route (optional)
- `origin_id` - Origin zone (optional)
- `destination_id` - Destination zone (optional)
- `contains_id` - Zone that must be passed through (optional)

**Common Patterns**:
1. **Flat fare**: fare_attributes without rules
2. **Route-based**: One rule per route
3. **Zone-based**: Rules match exact zone set traversed
4. **Origin-destination**: Combines origin_id + destination_id

**Best Practice**: If accuracy impossible, represent fare as more expensive to prevent underpayment

**Limitation**: GTFS-Fares v2 proposal addresses limitations of current model

#### pathways.txt & levels.txt
Indoor navigation for complex stations.

**Files**:
- `pathways.txt` - Connections between locations
- `levels.txt` - Floor/level definitions

**Key Concepts**:
- Graph representation: nodes (stops with location_type) + edges (pathways)
- `location_type` in stops.txt:
  - 0: Stop/platform
  - 1: Station (parent)
  - 2: Entrance/exit
  - 3: Generic node
  - 4: Boarding area

**pathways.txt Fields**:
- `pathway_id` - Unique identifier
- `from_stop_id` - Origin node
- `to_stop_id` - Destination node
- `pathway_mode` - 1=walkway, 2=stairs, 3=moving sidewalk, 4=escalator, 5=elevator, 6=fare gate, 7=exit gate
- `is_bidirectional` - 0=one-way, 1=two-way
- `traversal_time` - Seconds required
- `wheelchair_accessible` - 0=unknown, 1=yes, 2=no

**Best Practice**: Exhaustively define all connections within station; not for indoor mapping (use GIS/BIM); for itinerary/accessibility guidance

**Tools**: GTFS Station Builder UI, Transitland Station Editor

### GTFS Extensions
- Translations (multi-language support)
- Attribution (data source credits)
- Feed Info (publisher metadata)
- Google Ticketing Extensions (fare payment integration)
- Locations.geojson (zone boundaries)

---

## GTFS Realtime Specification

### Overview
- **Format**: Protocol Buffers (binary, compact, fast)
- **Purpose**: Live fleet updates complementing static GTFS
- **Protocol**: https://gtfs.org/documentation/realtime/proto/
- **GitHub**: https://github.com/google/transit/blob/master/gtfs-realtime/proto/gtfs-realtime.proto

### Protocol Buffers
- Language/platform-neutral serialization (like XML but smaller, faster, simpler)
- Developed by Google (2008)
- Schema defined in `.proto` file
- Code generation for Java, C++, Python, Swift, etc.

### Message Types

#### 1. Trip Updates
Conveys schedule deviations.

**Use Cases**:
- Delays/early arrivals
- Cancellations
- Route modifications
- Added trips

**Key Fields**:
- `trip_id`, `route_id`, `start_time`, `start_date` - Identifies trip
- `stop_time_update` - Array of updates:
  - `stop_sequence` or `stop_id`
  - `arrival.delay` - Seconds behind/ahead of schedule
  - `departure.delay`
  - `schedule_relationship` - SCHEDULED, SKIPPED, NO_DATA

**Update Frequency**: Whenever new data from Automatic Vehicle Location (AVL) system

#### 2. Service Alerts
Communicates disruptions.

**Use Cases**:
- Stop relocated/closed
- Unexpected incidents
- Network-wide service impacts
- Construction/maintenance

**Key Fields**:
- `informed_entity` - Affected routes/stops/trips
- `cause` - UNKNOWN_CAUSE, TECHNICAL_PROBLEM, STRIKE, DEMONSTRATION, ACCIDENT, HOLIDAY, WEATHER, MAINTENANCE, CONSTRUCTION, etc.
- `effect` - NO_SERVICE, REDUCED_SERVICE, SIGNIFICANT_DELAYS, DETOUR, ADDITIONAL_SERVICE, MODIFIED_SERVICE, STOP_MOVED, etc.
- `header_text` - Brief description (multi-language support)
- `description_text` - Detailed explanation
- `active_period` - Time range(s) when alert applies

#### 3. Vehicle Positions
Current vehicle locations and status.

**Use Cases**:
- Real-time map display
- Crowding information
- Accurate ETAs

**Key Fields**:
- `trip` - Trip descriptor
- `vehicle` - Vehicle descriptor (ID, label, license plate)
- `position` - Latitude, longitude, bearing, speed
- `current_stop_sequence` - Which stop vehicle is at/approaching
- `current_status` - INCOMING_AT, STOPPED_AT, IN_TRANSIT_TO
- `timestamp` - Measurement time
- `congestion_level` - UNKNOWN_CONGESTION_LEVEL, RUNNING_SMOOTHLY, STOP_AND_GO, CONGESTION, SEVERE_CONGESTION
- `occupancy_status` - EMPTY, MANY_SEATS_AVAILABLE, FEW_SEATS_AVAILABLE, STANDING_ROOM_ONLY, CRUSHED_STANDING_ROOM_ONLY, FULL, NOT_ACCEPTING_PASSENGERS

### Integration with Static GTFS

**Matching Realtime to Static**:
- Trip updates/vehicle positions reference `trip_id` from trips.txt
- Service alerts reference `route_id`, `stop_id`, or entire agency
- Timestamps in POSIX time (seconds since Jan 1 1970 UTC)

**Best Practices**:
- Keep static feed valid for 7+ days (ideally 30+)
- Use realtime for short-term changes (<7 days)
- Update feed regularly aligned with AVL data
- Include all three message types for comprehensive service

**Data Flow**:
1. Parse static GTFS into database
2. Fetch realtime protobuf feeds (HTTP GET)
3. Decode protobuf messages
4. Match to static data via IDs
5. Apply updates to schedule/display

---

## GTFS Best Practices

### Calendar & Service Handling

**calendar.txt vs calendar_dates.txt**:
- Use `calendar.txt` for regular weekly patterns
- Use `calendar_dates.txt` for exceptions (holidays, special events)
- Can use `calendar_dates.txt` exclusively for irregular services
- Remove expired calendars from feed

**Service Day Definition**:
- May exceed 24:00:00 (e.g., service starts one day, ends next)
- Measured from "noon minus 12h" in agency_timezone
- Varies by agency (not always calendar day)
- Support time ranges: 00:00-24:00, 01:00-25:00, 02:00-26:00, even 00:00-27:00

**Daylight Saving Time**:
- Model trips during DST switch to previous day reference point
- Keep departure times consistent with vehicle travel time
- Consumer algorithms auto-calculate correct display times
- Always specify times in `agency_timezone`

### Dataset Publishing

**Versioning**:
- Maintain persistent IDs across versions (`stop_id`, `route_id`, `agency_id`, `trip_id`)
- Publish at stable, permanent, public URL
- Configure HTTP Last-Modified headers correctly
- Merged datasets: Include current + upcoming service in single file
- Valid for 7+ days minimum, 30+ days recommended

**URL Best Practice**: https://agency.org/gtfs/gtfs.zip (not dated/versioned URLs)

### Text Formatting

**Casing**:
- Use Mixed Case for customer-facing fields
- NEVER use ALL CAPS
- Exception: Official place names that are actually capitalized

**Headsigns**:
- Don't include route name (it's shown separately)
- Never begin with "To" or "Towards"
- For branches: Use distinct `trip_headsign` if on same route
- Loop routes: Include first/last stop twice in `stop_times.txt`; use `stop_headsign` for direction changes
- Lasso routes: Use `stop_headsign` on shared segments

**Abbreviations**:
- Avoid unless official place names
- Spell out street directions (North, not N)

### Location Accuracy

**Stops**:
- Accuracy within 4 meters of actual boarding position
- Correct side of street
- For rail: Center of platform
- Use `parent_station` to group platforms

**Shapes**:
- Route alignment within 100 meters of served stops
- Remove extraneous points
- Follow actual vehicle path, not straight lines between stops

### Frequency vs Schedule-Based

**Frequency-based** (`exact_times=0`):
- Use when operators maintain headways, not fixed times
- Set first stop `arrival_time` to 00:00:00
- Only travel time intervals between stops matter
- Avoid `headway_secs` > 20 minutes (bad UX)

**Schedule-based** (`exact_times=1`):
- Use for compressed representation of consistent schedules
- Actual times matter: first departure + (n × headway)

**Block IDs**: Can be provided for frequency-based trips if vehicle continues

### Accessibility

**wheelchair_boarding** (stops.txt):
- 1 = Accessible from street AND can board vehicles
- 2 = Not accessible
- 0 or empty = Unknown
- Applies to both stop access and vehicle boarding capability

**wheelchair_accessible** (trips.txt):
- 1 = Vehicle can accommodate wheelchair
- 2 = Cannot accommodate
- 0 = Unknown
- Should have valid value for every trip

**Pathways**: If any pathways defined, must exhaustively define all station connections

### Common Pitfalls

1. **Stop times not increasing**: All times must increase throughout trip
2. **Timezone confusion**: Always use `agency_timezone` in `stop_times.txt`, even for cross-timezone trips
3. **Calendar expiry**: Old services bloat feed; remove them
4. **Missing shapes**: Improves UX significantly; worth the effort
5. **Inconsistent IDs**: Breaking ID changes across versions breaks consumer apps
6. **ALL CAPS TEXT**: Looks unprofessional; use Mixed Case
7. **Inaccurate fare modeling**: If unsure, err on higher fare to prevent underpayment
8. **Headsign route names**: Redundant and clutters display

---

## Transit Routing Algorithms

### Overview

Traditional graph algorithms (Dijkstra, A*) too slow for large transit networks. Modern algorithms designed for:
- **Multi-criteria optimization**: Minimize arrival time AND transfers simultaneously
- **Large-scale networks**: Nationwide timetables with thousands of routes
- **Dynamic updates**: Incorporate realtime delays

### Algorithm Comparison

| Algorithm | Preprocessing | Query Time | Memory | Multi-Criteria | Notes |
|-----------|---------------|------------|--------|----------------|-------|
| **Dijkstra** | None | Slow (baseline) | Low | No | Time-expanded graph; too slow for large networks |
| **A*** | None | Medium | Low | No | Heuristic-guided; still too slow for transit |
| **CSA** | None | Medium | Low | Yes | Simple, scans connections array; degrades on large networks |
| **RAPTOR** | None | Fast | Medium | Yes | Round-based; good mobile performance; Pareto-optimal results |
| **TBTR** | 30s-2min | Very Fast (70ms) | Medium | Yes | Precalculates transfers; excellent for repeated queries |
| **Transfer Patterns** | Heavy | Very Fast | High | Varies | Fastest but requires significant preprocessing |

### RAPTOR (Round-based Public Transit Optimized Router)

**Recommended for iOS App**

#### How It Works

**Core Concept**: Organizes search into rounds, where each round = one additional transfer.

**Algorithm Flow**:
1. **Round 0**: Mark initial stop with departure time
2. **Round 1**: Explore all routes from marked stops (direct trips, 0 transfers)
3. **Round 2**: Apply footpaths, explore routes again (1 transfer)
4. **Round n**: Continue until no improvements found

**Data Structures**:
- **Routes**: Grouped trips by path
- **Stops**: Track earliest arrival time per round
- **Marked stops**: Stops with improved arrival times in previous round

**Example**:
```
Origin: Stop A at 08:00
Destination: Stop D

Round 1 (0 transfers):
- Route 1 from Stop A → reaches Stop B at 08:15
- Route 2 from Stop A → reaches Stop C at 08:20

Round 2 (1 transfer):
- Walk from Stop B to Stop C (2 min) → 08:17
- Route 3 from Stop C → reaches Stop D at 08:30 (via route starting 08:20)
- Route 3 from Stop C → reaches Stop D at 08:28 (via walk+transfer at 08:17)

Best result: Stop D at 08:28 with 1 transfer
```

#### Key Features

**Multi-Criteria**: Returns Pareto-optimal journeys (each round improves arrival time OR transfer count)

**No Preprocessing**: Can handle realtime updates immediately; just update arrival/departure times

**Footpaths**: Apply previous-round arrival times when calculating walk transfers (not current round)

**Range Queries**: Extend to McRAPTOR for full departure time ranges (e.g., all options 8am-9am)

#### Performance Characteristics

- **Query Time**: Milliseconds to seconds depending on network size
- **Memory**: O(routes × stops)
- **Mobile Suitability**: Good - no preprocessing, reasonable memory, fast enough for on-device
- **Comparison**: Faster than CSA, slower than TBTR, but much simpler than Transfer Patterns

#### Implementation Considerations

**Interchange Time**: Must consistently apply minimum transfer time at stops

**Result Extraction**: Store trip-boarding-exit triples for each stop per round, then backtrack from destination

**Footpath Handling**:
- Critical bug: Use arrival times from previous round, not current
- Prevents shortcuts through impossible transfers

**Optimization**:
- rRAPTOR (partitioned) for larger networks
- HypRAPTOR (hyperpartitioned) for nationwide scale
- One-To-Many variants for location-based queries

### Connection Scan Algorithm (CSA)

#### How It Works

**Core Concept**: Scan all connections (departure-arrival pairs) once in chronological order.

**Data Model**:
```
Connection = (departure_stop, arrival_stop, departure_time, arrival_time)
```

**Algorithm**:
```
For each connection c in chronological order:
  If arrival_time[c.departure_stop] < c.departure_time:
    If c.arrival_time < arrival_time[c.arrival_stop]:
      arrival_time[c.arrival_stop] = c.arrival_time
      in_connection[c.arrival_stop] = c
```

**Backtracking**: Follow `in_connection` from destination to origin to reconstruct journey

#### Performance

- **Query Time**: Comparable to RAPTOR on small/medium networks; degrades on large networks
- **Advantage**: Extremely simple implementation
- **Disadvantage**: Must scan ALL connections before terminating; includes unnecessary transfers
- **Mobile**: Suitable for city-scale, questionable for nationwide

#### Variants

- **One-To-Many CSA**: Improved for location queries
- **Multilevel Overlay CSA**: Nationwide networks (trains + buses)
- **Profile CSA**: Range queries (all departures in time window)

### Trip-Based Public Transit Routing (TBTR)

#### How It Works

**Core Concept**: Precalculate useful transfers between trips; query as breadth-first search on trip graph.

**Preprocessing**:
- Nodes = Trips
- Edges = Transfers between trips
- Calculates which trip transfers are useful
- **Time**: 30s for city (London), 2 min for country (Germany, 8-core)

**Query**:
- Breadth-first search across trip graph
- Considers both arrival time and transfer count (bicriteria)
- **Time**: ~70ms for 24-hour profile on metropolitan network

#### Performance

- **Preprocessing**: Moderate (30s-2min)
- **Query Time**: Very fast (70ms for full profile)
- **Memory**: Medium-high (stores precalculated transfers)
- **Mobile**: Preprocessing on server, query results can be cached/downloaded

#### Advanced Variants

- **rTBTR**: Partitioned variant for improved query times
- **HypTBTR**: Hypergraph-based, 23-37% faster than TBTR
- **One-To-Many rTBTR**: 90-95% speedup for location queries
- **MHypTBTR**: Multilevel, 53% faster preprocessing
- **Arc-Flag TB**: Two orders of magnitude speedup, <1ms queries on countrywide networks

**Best Use Case**: Server-side routing with high query volume; too much preprocessing for on-device

### Transfer Patterns

#### How It Works

**Core Concept**: Precompute all optimal transfer patterns between stop pairs.

**Preprocessing**:
- Heavy computation (hours)
- Large storage (GB of patterns)

**Query**:
- Lookup: Fastest possible
- Essentially table lookup + time adjustments

**Performance**:
- **Preprocessing**: Very heavy
- **Query Time**: Extremely fast
- **Memory**: Very high
- **Mobile**: Preprocessing prohibitive; patterns could be downloaded but storage requirements high

**Use Case**: Large-scale commercial routing services with server infrastructure

### Recommendations for iOS App

**Primary: RAPTOR**
- No preprocessing: Can update with realtime data instantly
- Good performance: Fast enough for on-device (<1s queries)
- Pareto-optimal: Returns best options per transfer count
- Reasonable memory: Fits on mobile device
- Simple to implement: Clearer than TBTR/Transfer Patterns

**Alternative: CSA**
- Even simpler implementation
- Good for single-city app
- Degrades on multi-city/regional networks

**Server-Side Option: TBTR**
- Precompute on server
- Serve results via API
- Best query performance
- Allows caching common queries

**Hybrid Approach**:
1. RAPTOR on-device for quick queries
2. TBTR on server for complex/range queries
3. Cache TBTR results locally
4. Fall back to RAPTOR if offline

---

## Multi-Modal Routing

### Concept

Combining walking, cycling, bus, train, ferry, etc. in single journey.

### Transfer Types

**1. In-Seat Transfers**:
- Same vehicle continues on different route
- No physical transfer
- Modeled with `block_id` in trips.txt

**2. Timed Transfers**:
- Coordinated schedules
- Departing vehicle waits for arriving vehicle
- `transfer_type=1` in transfers.txt

**3. Walk Transfers**:
- Physical movement between stops/platforms
- `min_transfer_time` in transfers.txt
- Footpaths in routing algorithm

**4. Station Transfers**:
- Complex multi-level stations
- Modeled with pathways.txt
- Accessibility considerations

### Transfer Handling Strategies

**Minimum Transfer Time**:
```
min_transfer_time = min_walk_time + suggested_buffer_time
```

**Components**:
- **Walking distance**: Physical distance / average walk speed (1.4 m/s typical)
- **Vertical movement**: Stairs/escalators/elevators
- **Wayfinding**: Time to navigate complex stations
- **Schedule variance buffer**: Account for delays
- **Service frequency**: Lower frequency → larger buffer

**Typical Values**:
- Bus-to-bus (same stop): 0-120s
- Bus-to-bus (different stops): 300s (5 min)
- Rail-to-rail (platform change): 180-300s (3-5 min)
- Long-distance coach: 600s+ (10+ min)
- Inter-city rail: 600-900s (10-15 min)

### Connection Intelligence

**1. Transfer Reliability**:
- Consider on-time performance of connecting services
- Increase buffer for unreliable routes
- Real-time: Skip questionable connections if delay detected

**2. Time-of-Day**:
- Off-peak: Longer buffers (lower frequency makes missed connection more costly)
- Peak: Shorter acceptable (next vehicle soon)

**3. Station Complexity**:
- Simple stop: Minimal buffer
- Complex station: Account for walking, wayfinding
- Multi-level: Add vertical movement time

**4. Accessibility**:
- Wheelchair users: Longer transfer times
- Check `wheelchair_boarding` and pathway `wheelchair_accessible`
- Escalator vs stairs vs elevator

### Algorithm Extensions for Multi-Modal

**RAPTOR Multi-Modal**:
- Include footpaths between nearby stops
- Model bike/car as "routes" with specific characteristics
- Different "mode" per round

**Transfer Costs**:
- Not just time: Transfers have inherent penalty
- Users prefer fewer transfers even if slightly longer
- Typical: 2-5 minute penalty per transfer beyond time

**Multi-Criteria**:
- Minimize: Travel time, transfers, walking distance, cost
- Pareto frontier: All non-dominated solutions
- User preferences: Weight criteria differently

### Implementation Pattern

**Data Preparation**:
1. Load GTFS static data
2. Build stop proximity index (spatial search for nearby stops)
3. Calculate walk times between nearby stops
4. Parse transfers.txt for explicit transfer rules
5. Load pathways.txt for station internals

**Query Flow**:
1. Find nearby stops from origin location (walking distance)
2. Run RAPTOR/CSA with all nearby origin stops
3. Include walk transfers between rounds
4. Apply transfer time penalties
5. Find routes to nearby stops of destination
6. Add final walking leg
7. Return Pareto-optimal journeys

**Data Structures**:
```
FootPath:
  from_stop_id
  to_stop_id
  walk_time_seconds
  distance_meters
  wheelchair_accessible

NearbyStops:
  location (lat/lon)
  stops: [
    { stop_id, walk_time, distance }
  ]
```

---

## Implementation Guidance

### Database Schema Patterns

#### PostgreSQL + PostGIS (Server-Side)

**Tools**:
- `gtfs-via-postgres`: Creates tables + helpful views
- `gtfsdb`: SQLAlchemy ORM with PostGIS support
- `gtfs-schema`: Pre-built schemas for worldwide feeds

**Schema Design**:

```sql
-- Core tables (mirror GTFS files)
CREATE TABLE agency (...);
CREATE TABLE routes (...);
CREATE TABLE trips (...);
CREATE TABLE stops (
  stop_id TEXT PRIMARY KEY,
  stop_lat NUMERIC,
  stop_lon NUMERIC,
  stop_loc GEOGRAPHY(Point, 4326)  -- PostGIS
);
CREATE TABLE stop_times (...);
CREATE TABLE calendar (...);
CREATE TABLE calendar_dates (...);
CREATE TABLE shapes (
  shape_id TEXT,
  shape_pt_sequence INTEGER,
  shape_pt_lat NUMERIC,
  shape_pt_lon NUMERIC,
  shape_geom GEOGRAPHY(Point, 4326)
);

-- Foreign keys
ALTER TABLE routes ADD FOREIGN KEY (agency_id) REFERENCES agency(agency_id);
ALTER TABLE trips ADD FOREIGN KEY (route_id) REFERENCES routes(route_id);
ALTER TABLE stop_times ADD FOREIGN KEY (trip_id) REFERENCES trips(trip_id);
ALTER TABLE stop_times ADD FOREIGN KEY (stop_id) REFERENCES stops(stop_id);

-- Spatial indexes
CREATE INDEX idx_stops_loc ON stops USING GIST (stop_loc);
CREATE INDEX idx_shapes_geom ON shapes USING GIST (shape_geom);

-- Helpful views
CREATE VIEW service_days AS
  -- Applies calendar_dates to calendar
  -- Returns (service_id, date) for all operating days
  ...;

CREATE VIEW arrivals_departures AS
  -- Combines stop_times, trips, calendar
  -- Returns actual arrival/departure times for each stop
  ...;

CREATE VIEW connections AS
  -- Pairs of (departure, arrival) for routing
  SELECT
    st1.trip_id,
    st1.stop_id as from_stop,
    st2.stop_id as to_stop,
    st1.departure_time as departure,
    st2.arrival_time as arrival
  FROM stop_times st1
  JOIN stop_times st2 ON st1.trip_id = st2.trip_id
    AND st2.stop_sequence = st1.stop_sequence + 1;

CREATE VIEW shapes_aggregated AS
  -- Aggregates shape points into LineStrings
  SELECT
    shape_id,
    ST_MakeLine(shape_geom ORDER BY shape_pt_sequence) as geom
  FROM shapes
  GROUP BY shape_id;
```

**Optimization**:
- Composite indexes on `(trip_id, stop_sequence)`, `(stop_id, arrival_time)`
- Partial indexes for active service only
- Materialized views for expensive queries
- Partitioning by date for large systems

#### SQLite (Mobile App)

**Critical Optimizations for iOS**:

1. **Integer Identifiers**:
```sql
-- Don't do this (strings):
CREATE TABLE stops (
  stop_id TEXT PRIMARY KEY,
  ...
);

-- Do this (integers):
CREATE TABLE stops (
  id INTEGER PRIMARY KEY,
  stop_id TEXT UNIQUE,  -- Keep original for reference
  ...
);

CREATE TABLE stop_times (
  trip_internal_id INTEGER,
  stop_internal_id INTEGER,
  ...
  FOREIGN KEY (trip_internal_id) REFERENCES trips(id),
  FOREIGN KEY (stop_internal_id) REFERENCES stops(id)
);
```

**Benefit**: 50-70% size reduction, much faster joins

2. **Integer Times**:
```sql
-- Store times as seconds since midnight
CREATE TABLE stop_times (
  arrival_time INTEGER,  -- seconds since midnight
  departure_time INTEGER,
  ...
);

-- Handle times > 24:00:00:
-- 25:30:00 → (25 * 3600) + (30 * 60) = 91800 seconds
```

**Benefit**: Smaller storage, faster comparisons, easier math

3. **Denormalization**:
```sql
-- Instead of JOIN trips → routes → agency for every query
CREATE TABLE trips (
  id INTEGER PRIMARY KEY,
  route_internal_id INTEGER,
  route_short_name TEXT,  -- Denormalized
  route_color TEXT,       -- Denormalized
  ...
);
```

**Trade-off**: Larger database, faster queries (no joins on critical path)

4. **Exclude Unused Data**:
- If not showing detailed routes: Skip shapes.txt (can be 50%+ of feed size)
- If not handling fares: Skip fare_attributes/fare_rules
- If not showing translations: Skip translations.txt

5. **Pre-built Database**:
```
Bundle pre-processed .sqlite file in app
→ No startup time (parsing GTFS → SQLite)
→ Immediate queries
```

**Update Strategy**:
- Check for new GTFS version (HTTP HEAD, Last-Modified)
- Download new .zip in background
- Process to new .sqlite file
- Atomic swap when complete
- Keep old until new validated

6. **Indexes**:
```sql
-- Critical for query performance
CREATE INDEX idx_stop_times_trip ON stop_times(trip_internal_id, stop_sequence);
CREATE INDEX idx_stop_times_stop ON stop_times(stop_internal_id);
CREATE INDEX idx_trips_route ON trips(route_internal_id);
CREATE INDEX idx_trips_service ON trips(service_id);

-- For spatial queries (if using SpatiaLite extension)
SELECT CreateSpatialIndex('stops', 'geom');
```

**Tools**:
- `gtfs2sqlite`: Converts GTFS → SQLite
- `GTFSImporter`: iOS/Android SQLite importer
- `mobsql`: Mobility DB automatic ingestion

### Service Day Calculations

**Challenge**: Service days don't align with calendar days due to:
- Times exceeding 24:00:00
- Timezone complexities
- Daylight saving transitions

#### Implementation Pattern

**1. Determine Operating Days**:
```sql
-- For a specific date (e.g., 2025-10-30)
SELECT service_id FROM calendar
WHERE monday = 1  -- If Oct 30 is Monday
  AND start_date <= '20251030'
  AND end_date >= '20251030'
UNION
SELECT service_id FROM calendar_dates
WHERE date = '20251030' AND exception_type = 1
EXCEPT
SELECT service_id FROM calendar_dates
WHERE date = '20251030' AND exception_type = 2;
```

**2. Convert Times**:
```python
def gtfs_time_to_seconds(time_str):
    """Convert HH:MM:SS to seconds since midnight.
    Handles times > 24:00:00."""
    h, m, s = map(int, time_str.split(':'))
    return h * 3600 + m * 60 + s

def seconds_to_datetime(date_str, seconds_since_midnight, timezone_str):
    """Convert GTFS time to actual datetime."""
    import datetime
    import pytz

    # Parse service date
    service_date = datetime.datetime.strptime(date_str, '%Y%m%d')

    # Add seconds (may overflow to next day)
    dt = service_date + datetime.timedelta(seconds=seconds_since_midnight)

    # Apply timezone
    tz = pytz.timezone(timezone_str)
    dt_localized = tz.localize(dt)

    return dt_localized

# Example:
# Service date: 2025-10-30
# Departure time: 25:30:00
# Timezone: America/New_York
# Result: 2025-10-31 01:30:00 EDT
```

**3. Query for Specific Time**:
```sql
-- Find trips departing Stop A between 8:00 and 9:00 on 2025-10-30
SELECT DISTINCT t.*
FROM trips t
JOIN stop_times st ON t.id = st.trip_internal_id
WHERE st.stop_internal_id = (SELECT id FROM stops WHERE stop_id = 'A')
  AND st.departure_time >= 28800  -- 08:00:00
  AND st.departure_time < 32400   -- 09:00:00
  AND t.service_id IN (
    -- Active services on 2025-10-30
    ...
  );
```

**4. Handle Daylight Saving**:
- GTFS times always in standard agency_timezone
- DST transitions: Service day reference point shifts
- Algorithm auto-adjusts; no special handling needed in most cases
- Edge case: 2am-3am during "spring forward" (hour doesn't exist)
  - Model as previous day if needed
  - Ensure travel time consistency

### Timezone Complexities

**Rule**: ALL times in stop_times.txt use `agency_timezone`, even for trips crossing timezones.

**Example**:
```
Agency: Amtrak (America/New_York)
Trip: Boston → Chicago (crosses 1 timezone)

Stop A (Boston): Depart 08:00 (Eastern)
Stop B (Buffalo): Arrive 12:00 (still measured in Eastern)
Stop C (Cleveland): Arrive 15:00 (still measured in Eastern, even though Cleveland is Central)
Stop D (Chicago): Arrive 18:00 (measured in Eastern; local time is 17:00 Central)
```

**Why**: Ensures times always increase throughout trip.

**Display to User**:
```python
def display_time(stop_id, gtfs_time_seconds, service_date, agency_timezone):
    """Convert GTFS time to local time at stop."""
    # Get stop's local timezone (if stop_timezone provided)
    stop_tz = get_stop_timezone(stop_id) or agency_timezone

    # Convert GTFS time (agency TZ) to UTC
    dt_agency = seconds_to_datetime(service_date, gtfs_time_seconds, agency_timezone)
    dt_utc = dt_agency.astimezone(pytz.UTC)

    # Convert to stop's local time
    dt_local = dt_utc.astimezone(pytz.timezone(stop_tz))

    return dt_local
```

### Real-Time Integration Patterns

#### Pattern 1: In-Memory Update

**Flow**:
1. Load static GTFS into database/memory
2. Periodically fetch GTFS-RT protobuf (30-60s intervals)
3. Parse protobuf messages
4. Apply updates to in-memory schedule
5. Run routing on updated schedule

**Advantages**:
- Simple
- Always current
- No database writes

**Disadvantages**:
- Lost on app restart
- High memory if caching many updates

**Code (Swift)**:
```swift
import SwiftProtobuf

struct RealtimeUpdater {
    var tripUpdates: [String: TripUpdate] = [:]  // trip_id → update
    var vehiclePositions: [String: VehiclePosition] = [:]

    func fetchAndApply(url: URL) async throws {
        let data = try await URLSession.shared.data(from: url).0
        let feed = try TransitRealtime_FeedMessage(serializedData: data)

        for entity in feed.entity {
            if entity.hasTripUpdate {
                tripUpdates[entity.tripUpdate.trip.tripID] = entity.tripUpdate
            }
            if entity.hasVehicle {
                vehiclePositions[entity.vehicle.trip.tripID] = entity.vehicle
            }
        }
    }

    func getAdjustedArrival(tripId: String, stopSequence: Int, scheduledArrival: Int) -> Int {
        guard let update = tripUpdates[tripId],
              let stopUpdate = update.stopTimeUpdate.first(where: { $0.stopSequence == stopSequence }),
              stopUpdate.hasArrival else {
            return scheduledArrival
        }
        return scheduledArrival + Int(stopUpdate.arrival.delay)
    }
}
```

#### Pattern 2: Database Update

**Flow**:
1. Static GTFS in SQLite
2. Fetch GTFS-RT protobuf
3. Write updates to separate tables
4. JOIN static + realtime in queries

**Schema**:
```sql
CREATE TABLE realtime_trip_updates (
  trip_id TEXT,
  stop_sequence INTEGER,
  arrival_delay INTEGER,
  departure_delay INTEGER,
  schedule_relationship TEXT,
  timestamp INTEGER,
  PRIMARY KEY (trip_id, stop_sequence)
);

CREATE TABLE realtime_vehicle_positions (
  vehicle_id TEXT PRIMARY KEY,
  trip_id TEXT,
  latitude REAL,
  longitude REAL,
  bearing REAL,
  timestamp INTEGER
);

-- Query with realtime
SELECT
  st.stop_id,
  st.arrival_time + COALESCE(rtu.arrival_delay, 0) as actual_arrival
FROM stop_times st
LEFT JOIN realtime_trip_updates rtu
  ON st.trip_id = rtu.trip_id AND st.stop_sequence = rtu.stop_sequence
WHERE st.trip_id = ?;
```

**Advantages**:
- Persists across restarts
- Can query historical RT data
- Works with existing SQL queries

**Disadvantages**:
- Database writes (performance)
- Need cleanup of old data

#### Pattern 3: Server-Side Processing

**Flow**:
1. Server fetches GTFS-RT feeds
2. Server parses protobuf
3. Server exposes simplified JSON API
4. iOS app fetches JSON
5. Apply to in-memory schedule

**Advantages**:
- Offload protobuf parsing
- Server can aggregate multiple feeds
- Simpler iOS code
- Can add value (predictions, filtering)

**Disadvantages**:
- Requires server infrastructure
- Network dependency
- Latency

**API Example**:
```json
GET /api/trips/trip_123/realtime

{
  "trip_id": "trip_123",
  "vehicle": {
    "id": "vehicle_456",
    "lat": 42.3601,
    "lon": -71.0589,
    "bearing": 180,
    "speed": 12.5,
    "timestamp": 1730303400
  },
  "stop_updates": [
    {
      "stop_id": "stop_A",
      "stop_sequence": 5,
      "arrival_delay": 120,
      "departure_delay": 90,
      "relationship": "SCHEDULED"
    }
  ]
}
```

### Query Optimization Strategies

**1. Index Everything Used in WHERE/JOIN**:
```sql
-- Slow:
SELECT * FROM stop_times WHERE trip_id = 'ABC' ORDER BY stop_sequence;

-- Fast (with index):
CREATE INDEX idx_st_trip_seq ON stop_times(trip_id, stop_sequence);
```

**2. Use Covering Indexes**:
```sql
-- Query only needs trip_id, stop_id, arrival_time
CREATE INDEX idx_st_covering ON stop_times(trip_id, stop_sequence, stop_id, arrival_time);
-- Now query doesn't need to access table, just index
```

**3. Limit Result Sets**:
```sql
-- Don't fetch all trips, filter early
SELECT t.* FROM trips t
WHERE t.service_id IN (...)  -- Active today
  AND t.route_id = ?
LIMIT 50;
```

**4. Prepared Statements**:
```swift
let stmt = try db.prepare(
    "SELECT * FROM stop_times WHERE trip_id = ? ORDER BY stop_sequence"
)
// Reuse for many queries
```

**5. Spatial Queries (Nearby Stops)**:
```sql
-- With SpatiaLite or manual calculation
SELECT
  stop_id,
  (6371 * acos(cos(radians(?1)) * cos(radians(stop_lat)) *
   cos(radians(stop_lon) - radians(?2)) + sin(radians(?1)) *
   sin(radians(stop_lat)))) AS distance_km
FROM stops
WHERE stop_lat BETWEEN ?1 - 0.01 AND ?1 + 0.01  -- Bounding box
  AND stop_lon BETWEEN ?2 - 0.01 AND ?2 + 0.01
HAVING distance_km < 0.5
ORDER BY distance_km
LIMIT 10;
```

**6. Denormalize for Read Performance**:
```sql
-- Instead of 3 JOINs every query
SELECT
  st.arrival_time,
  s.stop_name,
  t.trip_headsign,
  r.route_short_name
FROM stop_times st
JOIN stops s ON st.stop_id = s.stop_id
JOIN trips t ON st.trip_id = t.trip_id
JOIN routes r ON t.route_id = r.route_id;

-- Store trip_headsign, route_short_name in stop_times table
-- No JOINs needed
```

**7. Cache Common Queries**:
- "Nearby stops" for fixed locations (home, work)
- Active service IDs for today
- Popular routes

---

## iOS-Specific Recommendations

### Architecture

**Layer 1: Data Layer**
- SQLite database (bundled + updatable)
- GTFS-RT protobuf parser
- Update manager

**Layer 2: Routing Engine**
- RAPTOR implementation in Swift
- Multi-modal support (walk + transit)
- Realtime-aware

**Layer 3: Presentation**
- MapKit for maps
- List views for schedules
- Realtime updates via Combine

### Libraries & Tools

**GTFS Parsing**:
- `emma-k-alexandra/GTFS`: Swift structures for GTFS & GTFS-RT
- `richwolf/transit`: Swift library for GTFS static datasets
- Note: GTFS initialization slow; do server-side or background processing

**Protobuf**:
- `apple/swift-protobuf`: Official Apple library
- Generate Swift classes: `protoc --swift_out=. gtfs-realtime.proto`

**Database**:
- SQLite.swift: Type-safe SQLite wrapper
- GRDB: Advanced SQLite toolkit
- SpatiaLite: If spatial queries needed

**Networking**:
- URLSession for GTFS-RT fetches
- Background URLSession for feed updates

### Performance Tips

**1. Preprocess on Server**:
- Parse GTFS → SQLite on server
- Download .sqlite file (smaller than .zip)
- Immediate startup

**2. Incremental Updates**:
- Don't re-download entire feed daily
- Diff changes, apply incrementally
- Only full refresh when major version change

**3. Background Processing**:
```swift
import BackgroundTasks

func scheduleGTFSUpdate() {
    let request = BGProcessingTaskRequest(identifier: "com.app.gtfs-update")
    request.requiresNetworkConnectivity = true
    try? BGTaskScheduler.shared.submit(request)
}
```

**4. Lazy Loading**:
- Don't load entire database into memory
- Fetch trips/stops on-demand
- Cache recent queries

**5. Spatial Indexing**:
- Use R-tree for stops (SpatiaLite or custom)
- Quick "nearby stops" queries
- Critical for user location → transit

**6. Memory Management**:
- GTFS data can be large (100MB+)
- Use autoreleasepool in tight loops
- Monitor memory, purge caches under pressure

### Data Update Strategy

**Scenario 1: Daily/Weekly Updates (Small Changes)**
1. Background task checks for new GTFS version
2. Download new .zip
3. Diff with current version (compare checksums)
4. Apply changes incrementally to SQLite
5. Swap databases when complete

**Scenario 2: Major Changes (New Routes, Schedule Overhaul)**
1. Full re-download and re-process
2. Prepare new .sqlite in temporary location
3. Validate (ensure queries work)
4. Atomic swap (rename files)
5. Delete old database

**Scenario 3: Realtime Updates (Continuous)**
1. Every 30-60s: Fetch GTFS-RT protobuf
2. Parse in background queue
3. Update in-memory structures
4. Notify UI via Combine/NotificationCenter
5. Don't persist (ephemeral data)

### User Experience

**Loading States**:
- Show skeleton/placeholder while routing
- Target: <1s for simple queries, <3s for complex

**Offline Support**:
- Bundled GTFS for initial use
- Cached routes
- Graceful degradation (no realtime)

**Accessibility**:
- VoiceOver for `wheelchair_accessible` routes
- Filter by accessibility in UI
- Show accessible transfer paths

**Localization**:
- Use GTFS translations.txt if available
- Fall back to system language
- Time/date formatting per locale

---

## Code Examples

### RAPTOR Implementation (Swift Pseudocode)

```swift
struct Route {
    let id: String
    let stops: [StopTime]  // Ordered stop times
}

struct StopTime {
    let stopId: String
    let arrivalTime: Int  // Seconds since midnight
    let departureTime: Int
}

struct Journey {
    let arrivalTime: Int
    let transfers: Int
    let legs: [Leg]
}

struct Leg {
    let route: Route
    let fromStop: String
    let toStop: String
    let boardTime: Int
    let alightTime: Int
}

class RAPTOR {
    let routes: [Route]
    let stops: Set<String>
    let routesByStop: [String: [Route]]  // Stop → routes serving it

    func search(from: String, to: String, departureTime: Int, maxTransfers: Int = 5) -> [Journey] {
        var bestArrivalTime: [String: [Int]] = [:]  // Stop → arrival time per round
        var markedStops: Set<String> = [from]
        var journeys: [Journey] = []

        // Initialize
        for stop in stops {
            bestArrivalTime[stop] = Array(repeating: Int.max, count: maxTransfers + 1)
        }
        bestArrivalTime[from]![0] = departureTime

        // Rounds (k = number of transfers)
        for k in 0...maxTransfers {
            var markedStopsNextRound: Set<String> = []

            // Scan routes
            for route in routes where route.stops.contains(where: { markedStops.contains($0.stopId) }) {
                var boarded = false
                var boardTime = 0
                var boardStopIdx = 0

                for (idx, stopTime) in route.stops.enumerated() {
                    // Can we board here?
                    if markedStops.contains(stopTime.stopId) &&
                       stopTime.departureTime >= bestArrivalTime[stopTime.stopId]![k] {
                        if !boarded || stopTime.departureTime < boardTime {
                            boarded = true
                            boardTime = stopTime.departureTime
                            boardStopIdx = idx
                        }
                    }

                    // Can we alight here?
                    if boarded && stopTime.arrivalTime < bestArrivalTime[stopTime.stopId]![k + 1] {
                        bestArrivalTime[stopTime.stopId]![k + 1] = stopTime.arrivalTime
                        markedStopsNextRound.insert(stopTime.stopId)

                        // Track journey
                        if stopTime.stopId == to {
                            // Construct journey...
                        }
                    }
                }
            }

            // Apply footpaths (walk transfers)
            for stop in markedStopsNextRound {
                for (nearbyStop, walkTime) in getFootpaths(stop) {
                    let arrivalViaWalk = bestArrivalTime[stop]![k + 1] + walkTime
                    if arrivalViaWalk < bestArrivalTime[nearbyStop]![k + 1] {
                        bestArrivalTime[nearbyStop]![k + 1] = arrivalViaWalk
                        markedStopsNextRound.insert(nearbyStop)
                    }
                }
            }

            markedStops = markedStopsNextRound

            if markedStops.isEmpty {
                break  // No improvements possible
            }
        }

        // Extract Pareto-optimal journeys
        for k in 0...maxTransfers {
            if let arrival = bestArrivalTime[to]?[k], arrival < Int.max {
                // Reconstruct journey from metadata (omitted for brevity)
                // journeys.append(reconstructedJourney)
            }
        }

        return journeys
    }

    func getFootpaths(_ stopId: String) -> [(String, Int)] {
        // Returns nearby stops and walk times
        // Could use spatial index, transfers.txt, or simple distance calc
        return []
    }
}
```

### SQLite Query Patterns (Swift)

```swift
import SQLite

let db = try Connection("path/to/gtfs.sqlite")

// Find active services for a date
func activeServices(for date: Date) -> [String] {
    let calendar = Table("calendar")
    let serviceId = Expression<String>("service_id")
    let monday = Expression<Int>("monday")
    let startDate = Expression<String>("start_date")
    let endDate = Expression<String>("end_date")

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd"
    let dateStr = dateFormatter.string(from: date)
    let weekday = Calendar.current.component(.weekday, from: date)  // 1=Sun, 2=Mon, ...

    var services: [String] = []

    // From calendar.txt
    let query = calendar
        .select(serviceId)
        .filter(startDate <= dateStr && endDate >= dateStr)
    // Filter by weekday (simplified; need to check correct weekday column)

    for row in try! db.prepare(query) {
        services.append(row[serviceId])
    }

    // TODO: Apply calendar_dates.txt additions/exceptions

    return services
}

// Find next departures from a stop
func nextDepartures(stopId: String, departureTime: Int, limit: Int = 10) -> [(tripId: String, routeName: String, headsign: String, time: Int)] {
    let stopTimes = Table("stop_times")
    let trips = Table("trips")

    let query = """
        SELECT
            st.trip_id,
            t.route_short_name,
            t.trip_headsign,
            st.departure_time
        FROM stop_times st
        JOIN trips t ON st.trip_internal_id = t.id
        WHERE st.stop_internal_id = (SELECT id FROM stops WHERE stop_id = ?)
          AND st.departure_time >= ?
          AND t.service_id IN (?)
        ORDER BY st.departure_time
        LIMIT ?
    """

    let services = activeServices(for: Date())  // Today
    var results: [(String, String, String, Int)] = []

    for row in try! db.prepare(query, stopId, departureTime, services.joined(separator: ","), limit) {
        results.append((
            tripId: row[0] as! String,
            routeName: row[1] as! String,
            headsign: row[2] as! String,
            time: row[3] as! Int
        ))
    }

    return results
}

// Nearby stops
func nearbyStops(lat: Double, lon: Double, radiusKm: Double = 0.5) -> [(stopId: String, name: String, distance: Double)] {
    let query = """
        SELECT
            stop_id,
            stop_name,
            (6371 * acos(cos(radians(?)) * cos(radians(stop_lat)) *
             cos(radians(stop_lon) - radians(?)) + sin(radians(?)) *
             sin(radians(stop_lat)))) AS distance
        FROM stops
        WHERE stop_lat BETWEEN ? AND ?
          AND stop_lon BETWEEN ? AND ?
        HAVING distance < ?
        ORDER BY distance
        LIMIT 20
    """

    let latDelta = 0.01  // Rough bounding box
    let lonDelta = 0.01

    var results: [(String, String, Double)] = []

    for row in try! db.prepare(query, lat, lon, lat,
                                lat - latDelta, lat + latDelta,
                                lon - lonDelta, lon + lonDelta,
                                radiusKm) {
        results.append((
            stopId: row[0] as! String,
            name: row[1] as! String,
            distance: row[2] as! Double
        ))
    }

    return results
}
```

### GTFS-RT Parsing (Swift)

```swift
import SwiftProtobuf

struct GTFSRealtime {
    func fetchTripUpdates(url: URL) async throws -> [TransitRealtime_TripUpdate] {
        let (data, _) = try await URLSession.shared.data(from: url)
        let feed = try TransitRealtime_FeedMessage(serializedData: data)

        return feed.entity.compactMap { $0.hasTripUpdate ? $0.tripUpdate : nil }
    }

    func fetchVehiclePositions(url: URL) async throws -> [TransitRealtime_VehiclePosition] {
        let (data, _) = try await URLSession.shared.data(from: url)
        let feed = try TransitRealtime_FeedMessage(serializedData: data)

        return feed.entity.compactMap { $0.hasVehicle ? $0.vehicle : nil }
    }

    func fetchServiceAlerts(url: URL) async throws -> [TransitRealtime_Alert] {
        let (data, _) = try await URLSession.shared.data(from: url)
        let feed = try TransitRealtime_FeedMessage(serializedData: data)

        return feed.entity.compactMap { $0.hasAlert ? $0.alert : nil }
    }
}

// Usage
let rt = GTFSRealtime()

// Fetch trip updates every 30s
Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
    Task {
        do {
            let updates = try await rt.fetchTripUpdates(url: URL(string: "https://agency.com/gtfs-rt/trip-updates")!)

            for update in updates {
                let tripId = update.trip.tripID

                for stopUpdate in update.stopTimeUpdate {
                    if stopUpdate.hasArrival {
                        let delay = stopUpdate.arrival.delay  // Seconds
                        print("\(tripId) at stop \(stopUpdate.stopSequence): +\(delay)s")
                    }
                }
            }
        } catch {
            print("GTFS-RT fetch error: \(error)")
        }
    }
}
```

---

## Summary & Quick Reference

### GTFS Static Core Files
1. **agency.txt**: Transit agencies (timezone critical)
2. **routes.txt**: Bus/rail lines (route_type for mode)
3. **trips.txt**: Individual journey instances (headsign, direction)
4. **stops.txt**: Physical locations (lat/lon, wheelchair_boarding)
5. **stop_times.txt**: Schedule (times in HH:MM:SS, can exceed 24:00)
6. **calendar.txt**: Weekly patterns
7. **calendar_dates.txt**: Exceptions (holidays)

### GTFS Static Optional (High Value)
- **shapes.txt**: Route visualization
- **transfers.txt**: Connection rules, transfer times
- **frequencies.txt**: Headway-based service
- **pathways.txt**: Station navigation

### GTFS Realtime Messages
1. **Trip Updates**: Delays, cancellations
2. **Service Alerts**: Disruptions, closures
3. **Vehicle Positions**: Live locations, crowding

### Routing Algorithm Selection
- **On-Device Mobile**: RAPTOR (no preprocessing, good performance)
- **Server-Side API**: TBTR (fast queries after preprocessing)
- **Simple City App**: CSA (easiest to implement)
- **Commercial Scale**: Transfer Patterns (fastest, heavy preprocessing)

### iOS Database Schema
- **Use integers** for IDs (not strings)
- **Denormalize** frequently joined data
- **Index** all WHERE/JOIN columns
- **Exclude** unused files (shapes if not displaying routes)
- **Bundle** pre-built .sqlite file

### Time Handling
- All times in **agency_timezone**
- Times can **exceed 24:00:00** (service day, not calendar day)
- Store as **seconds since midnight** (integer)
- DST: No special handling (algorithm adjusts)

### Transfer Time Formula
```
min_transfer_time = walk_time + buffer_time

Typical buffers:
- Bus-to-bus (same stop): 0-2 min
- Bus-to-bus (different stops): 5 min
- Rail platform change: 3-5 min
- Long-distance: 10+ min
```

### Best Practices Checklist
- [ ] Stop locations within 4m accuracy
- [ ] Persistent IDs across versions
- [ ] Mixed Case text (not ALL CAPS)
- [ ] Headsigns without "To" prefix
- [ ] Shapes within 100m of stops
- [ ] Feed valid for 7+ days
- [ ] Remove expired services
- [ ] Wheelchair accessibility populated
- [ ] Transfer times include buffer
- [ ] Published at stable URL

### Key URLs
- **Specification**: https://gtfs.org/
- **GitHub**: https://github.com/google/transit
- **Best Practices**: https://gtfs.org/documentation/schedule/schedule-best-practices/
- **Realtime Proto**: https://gtfs.org/documentation/realtime/proto/
- **Validator**: https://github.com/MobilityData/gtfs-validator

---

## Complexity Assessment

**Low Complexity**:
- Parsing GTFS files (CSV parsing)
- Displaying static routes/stops
- Basic schedule lookup

**Medium Complexity**:
- Service day calculations (calendar logic)
- Timezone handling (cross-timezone trips)
- Transfer time modeling
- Database schema design

**High Complexity**:
- Multi-criteria routing algorithms (RAPTOR, TBTR)
- Realtime integration (protobuf parsing, updates)
- Multi-modal routing (walk + transit)
- Performance optimization (large datasets)
- Pareto-optimal result sets

**Very High Complexity**:
- Preprocessing-based algorithms (TBTR, Transfer Patterns)
- Nationwide/multi-agency federation
- Custom GTFS extensions
- Real-time predictions (beyond simple delays)

**Estimated Development Time (iOS App)**:
- Basic viewer (routes, stops, schedules): 2-4 weeks
- Add trip planning (RAPTOR): +3-5 weeks
- Add realtime updates: +2-3 weeks
- Polish, optimization, edge cases: +3-4 weeks
- **Total**: 10-16 weeks for comprehensive transit app

**Recommended Approach**:
1. **Phase 1**: Static GTFS display (stops, routes, schedules)
2. **Phase 2**: Basic routing (RAPTOR, single mode)
3. **Phase 3**: Multi-modal (walk + transit)
4. **Phase 4**: Realtime integration
5. **Phase 5**: Polish (offline, accessibility, performance)

---

*Document Version: 1.0*
*Last Updated: 2025-10-30*
*Based on GTFS Specification revised 2025-07-09*
# Swift/iOS Transit App Development Libraries & Resources

## Executive Summary

**Recommended Approach:** Hybrid - Use established libraries for core functionality, build custom components where needed.

**Key Recommendations:**
- **GTFS Parsing:** Use `emma-k-alexandra/GTFS` or build custom parser with SwiftProtobuf
- **Database:** GRDB for complex queries, CoreData for standard CRUD operations
- **Networking:** URLSession (native) for simple needs, Alamofire for rapid development
- **Geospatial:** CoreLocation + MapKit (native), add GEOSwift for complex polygon operations
- **Date/Time:** SwiftDate for timezone/calendar complexity
- **Architecture:** Learn from OneBusAway's OBAKit framework architecture

**Build vs. Buy Decision:**
- ✅ **Use libraries:** GTFS parsing, geospatial calculations, date/time handling
- ⚠️ **Evaluate carefully:** Database layer (depends on complexity), networking (native may suffice)
- 🔨 **Build custom:** UI/UX, business logic, transit-specific features

---

## GTFS Parsing Libraries

### 1. emma-k-alexandra/GTFS
**GitHub:** https://github.com/emma-k-alexandra/GTFS
**Stars:** Not specified in search results
**License:** Not specified
**Maintenance:** Active (available on Swift Package Registry)

**Features:**
- Supports both GTFS static and GTFS-RT (real-time) data
- Uses Apple's SwiftProtobuf for GTFS-RT structures
- Available via Swift Package Manager

**Pros:**
- Comprehensive coverage of both static and real-time specs
- Uses official SwiftProtobuf implementation
- Modern Swift Package Manager distribution

**Cons:**
- Performance warning: Initializing GTFS object can be slow
- Not recommended for on-device parsing of large datasets
- Better suited for server-side or preprocessed data

**Integration Complexity:** Medium
**Recommendation:** Use for GTFS-RT parsing; consider alternatives for large static datasets

---

### 2. richwolf/transit
**GitHub:** https://github.com/richwolf/transit
**Stars:** Not specified
**Maintenance:** Active

**Features:**
- "The Swiftiest way to work with GTFS data feeds"
- Currently supports GTFS Static Specification only
- Simple API: instantiate Feed with folder contents
- Distributed as Swift Package

**Pros:**
- Idiomatic Swift API design
- Simple instantiation pattern
- Focus on developer experience

**Cons:**
- No GTFS-RT support yet
- Limited documentation in search results

**Integration Complexity:** Low
**Recommendation:** Good for static GTFS parsing with clean Swift API

---

### 3. jackwilsdon/GTFSKit
**GitHub:** https://github.com/jackwilsdon/GTFSKit
**Distribution:** CocoaPods
**Maintenance:** Unknown

**Features:**
- Swift Framework for GTFS static data only
- CocoaPods installation

**Pros:**
- Framework approach

**Cons:**
- CocoaPods only (CocoaPods entered maintenance mode Aug 2024)
- Static data only
- Unknown maintenance status

**Integration Complexity:** Medium
**Recommendation:** Avoid - prefer SPM-based alternatives

---

### 4. danramteke/SwiftGtfsSupport
**GitHub:** https://github.com/danramteke/SwiftGtfsSupport

**Features:**
- GTFS Protocol Buffer bindings for Swift
- Generated using protoc compiler

**Pros:**
- Direct protobuf bindings
- Low-level control

**Cons:**
- Lower-level API
- Requires more manual implementation

**Integration Complexity:** High
**Recommendation:** Only if you need custom protobuf handling

---

### GTFS-RT Performance Considerations

**Memory Management:**
- GTFS-RT feeds contain entire dataset in FeedMessage
- Full deserialization requires all data to fit in memory
- For constrained environments, consider event/callback-driven parsing

**Mobile Best Practices:**
- **Don't consume GTFS-RT directly on mobile devices** (too much data)
- Use intermediate server to filter/serve relevant data only
- Cache processed results locally

**Implementation Approach:**
- Use SwiftProtobuf to generate Swift classes from `gtfs-realtime.proto`
- Parse binary feeds on backend, expose filtered JSON/REST API to mobile
- Update local cache incrementally

---

## Open Source Transit Apps

### 1. OneBusAway for iOS (OBAKit)
**GitHub:** https://github.com/OneBusAway/onebusaway-ios
**Stars:** 115 stars, 52 forks
**License:** Apache 2.0 (assumed based on OBA project)
**Maintenance:** Active (Open Transit Software Foundation)

**Architecture:**
- Total rewrite in Swift
- Two-framework architecture:
  - **OBAKitCore:** Low-level networking and data modeling
  - **OBAKit:** High-level UI components
- Built as reusable frameworks for white-labeling
- Uses XcodeGen for project generation
- Swift Package Manager for dependencies

**White Label Capabilities:**
- Transit agencies can create custom-branded apps
- Apply custom name, icon, color scheme
- Ships as independent App Store app
- Maintains access to OBAKit updates/fixes
- New apps can be created in <1 day

**Code Quality:**
- Emphasizes clarity over cleverness
- Designed for easy understanding, testing, maintenance
- Modular, framework-based architecture
- Clear separation: core vs. UI layers

**Key Lessons:**
- ✅ Framework separation enables reusability
- ✅ White-label architecture allows customization without forking
- ✅ Clarity-focused code aids long-term maintenance
- ✅ Swift Package Manager for modern dependency management

**Integration Complexity:** Medium-High (can embed frameworks in your app)
**Recommendation:** Study architecture; consider embedding OBAKit if building OneBusAway-compatible app

**Documentation:** https://github.com/OneBusAway/onebusaway-ios/blob/main/Tutorials/WhiteLabel.md

---

### 2. Ithaca Transit
**GitHub:** https://github.com/cuappdev/ithaca-transit-ios
**Features:**
- TCAT bus tracking
- "Beautiful, clean interface"
- Free and open-source

**Key Lessons:**
- Reference for modern Swift UI patterns
- Real-world transit app implementation

---

### 3. TransitPal
**GitHub:** https://github.com/robbiet480/TransitPal
**Features:**
- NFC transit card reader
- Built with SwiftUI
- iOS 13+

**Key Lessons:**
- SwiftUI architecture for transit apps
- NFC integration patterns

---

### 4. TripKit (Public Transport API Library)
**GitHub:** https://github.com/alexander-albers/tripkit
**Stars:** 77 stars, 8 forks
**License:** Likely ISC/MIT (not explicit in search results)
**Swift Version:** 5.0
**Platform Support:** iOS 12.0+/watchOS 5.0+/tvOS 12.0+/macOS 10.13+

**Features:**
- Swift port of public-transport-enabler with enhancements
- Query data from various public transport providers
- Used by ÖPNV Navigator app (iOS App Store)
- Swift Package Manager installation

**Key Lessons:**
- Multi-provider abstraction layer
- Production-tested (used in App Store app)

**Recommendation:** Evaluate if you need multi-provider support

---

## Geospatial Libraries

### CoreLocation + MapKit (Native)
**Apple Frameworks - No external dependency**

**Distance Calculations:**
- `CLLocation.distance(from:)` - Great circle distance ("as the crow flies")
- Haversine algorithm built-in
- Efficient and battery-optimized

**Route Distance:**
- `MKDirectionsRequest` + `MKRoute` for driving/walking distance
- Returns distance in meters + travel time
- Matches Apple Maps routing

**Pros:**
- Native integration, no dependencies
- Battery-optimized
- Official Apple support

**Cons:**
- Limited to Apple's routing algorithms
- No advanced geospatial operations

**Battery Best Practices:**
- Use `kCLLocationAccuracyHundredMeters` or `kCLLocationAccuracyKilometer` (40-60% battery savings vs. GPS)
- `startMonitoringSignificantLocationChanges` for passive tracking (500m threshold)
- `requestLocation()` for one-time fixes (auto-stops)
- `distanceFilter` to reduce callback frequency
- Toggle accuracy based on user activity (passive vs. active navigation)

**Recommendation:** Start here; add specialized libraries only if needed

---

### GEOSwift
**GitHub:** https://github.com/GEOSwift/GEOSwift
**License:** MIT
**Maintenance:** Active

**Features:**
- Swift Geometry Engine
- Type-safe interface to OSGeo's GEOS library
- Geometric objects: points, linestrings, polygons
- Topological operations: intersections, overlapping
- Point-in-polygon detection

**Pros:**
- Industry-standard GEOS backend
- Type-safe Swift API
- Comprehensive geometry operations

**Cons:**
- Additional dependency
- Learning curve for GEOS concepts

**Use Cases:**
- Service area boundaries (polygon-based geofencing)
- Complex route proximity detection
- Spatial relationships between transit elements

**Integration Complexity:** Medium
**Recommendation:** Use when CoreLocation's simple distance calculations aren't enough

---

### Geofencing Libraries

#### StuartFarmer/Geofencing
**GitHub:** https://github.com/StuartFarmer/Geofencing

**Features:**
- Monitor CLCircularRegion or MKPolygon objects
- Block-based API
- Enter/exit callbacks

**Integration Complexity:** Low

---

#### Iccr/Geofence-Swift
**GitHub:** https://github.com/Iccr/Geofence-Swift

**Features:**
- Polygon-based region detection
- Map-based visualization

**Integration Complexity:** Low

---

#### zpg6/SwiftUIPolygonGeofence
**GitHub:** https://github.com/zpg6/SwiftUIPolygonGeofence

**Features:**
- Draw custom polygon geofences
- Photoshop pen tool-style interaction
- SwiftUI-based

**Integration Complexity:** Medium
**Recommendation:** Good for custom service area definition UI

---

## Database Libraries

### Performance Comparison Summary
(Based on "Performance Divide between CoreData, Realm and GRDB" study)

| Operation | Best Performance | Notes |
|-----------|-----------------|-------|
| **Read** | CoreData | Scales best beyond 100K objects |
| **Write** | CoreData | Lower times for large datasets |
| **Delete** | GRDB | Consistently lowest delete times |
| **Update** | CoreData | Best for <1M objects |

**Performance Hierarchy:** Direct SQLite > CoreData > SwiftData

---

### 1. GRDB.swift
**GitHub:** https://github.com/groue/GRDB.swift
**License:** MIT
**Maintenance:** Very active

**Features:**
- SQLite wrapper for Swift
- Supports plain Swift structs and value types
- Immutable database views for reads
- Exclusive write access for safety
- Excellent fetch performance
- Lightweight, flexible schema

**Concurrency:**
- Addresses multithreading difficulties of CoreData/Realm
- Immutable views prevent threading issues
- Single source of truth
- Safe for value-type models

**Pros:**
- ✅ Best delete performance
- ✅ Value types = thread-safe
- ✅ Immutability advantages
- ✅ Flexible schema for evolving GTFS data
- ✅ Direct SQL control when needed

**Cons:**
- ❌ Highest write times for large datasets
- ❌ More boilerplate than CoreData
- ❌ SQL knowledge helpful

**Transit App Use Case:**
- GTFS data with complex queries
- Multi-threaded sync operations
- Delete/refresh cycles (route updates)
- Value-type models for safety

**Integration Complexity:** Medium
**Recommendation:** Excellent choice for transit data (complex queries, safe concurrency, good delete performance)

---

### 2. CoreData
**Apple Framework - Native**

**Pros:**
- ✅ Best read performance at scale
- ✅ Best write/update performance
- ✅ Native iOS integration
- ✅ iCloud sync support
- ✅ Mature, stable

**Cons:**
- ❌ Worst delete performance
- ❌ Complex multithreading (context management)
- ❌ No single source of truth
- ❌ Opaque magic ("difficult to use properly")

**Transit App Use Case:**
- Read-heavy operations (displaying routes, stops)
- Standard CRUD without complex queries
- Need iCloud sync

**Integration Complexity:** Medium
**Recommendation:** Solid choice if you prioritize Apple ecosystem integration and read performance

---

### 3. Realm
**License:** Apache 2.0
**Maintenance:** MongoDB-backed

**Pros:**
- ✅ Object-oriented API
- ✅ Live queries
- ✅ Cross-platform (iOS, Android, etc.)

**Cons:**
- ❌ Poor read scalability (rapid degradation >100K objects)
- ❌ High write times
- ❌ Thread boundary crossing issues
- ❌ No single source of truth

**Transit App Use Case:**
- Cross-platform requirement
- Smaller datasets

**Integration Complexity:** Low-Medium
**Recommendation:** Avoid for transit apps (poor scalability, threading issues)

---

### 4. SwiftData
**Apple Framework - Native (iOS 17+)**

**Pros:**
- ✅ Modern Swift concurrency support
- ✅ SwiftUI-first design
- ✅ Simpler than CoreData

**Cons:**
- ❌ Slower than CoreData and direct SQLite
- ❌ iOS 17+ only
- ❌ Still maturing (bugs, limitations)

**Integration Complexity:** Low
**Recommendation:** Wait until more mature; iOS 17+ requirement limits audience

---

### Database Recommendation for Transit Apps

**Use GRDB if:**
- Complex queries (find all stops near location with active routes)
- Frequent updates/deletes (real-time feed processing)
- Multi-threaded sync operations
- Value-type domain models

**Use CoreData if:**
- Primarily read operations (displaying schedules)
- Need iCloud sync
- Prefer native Apple integration
- Standard CRUD patterns

**Avoid Realm** for transit (scalability issues with large stop/route datasets)

---

## MapKit Extensions & Overlays

### Native MapKit Support

**SwiftUI (iOS 17+):**
- `MapPolyline` for route overlays
- Native annotation support
- No external dependencies

**UIKit/MKMapView:**
- `MKPolyline` / `MKPolygon` overlays
- `MKAnnotation` protocol
- `MKOverlayRenderer` for custom drawing
- Animated overlays supported

**Pros:**
- No dependencies
- Official Apple support
- Good performance

**Cons:**
- SwiftUI overlays require iOS 17+
- UIKit more verbose

---

### Community Libraries

#### pauljohanneskraft/Map
**GitHub:** https://github.com/pauljohanneskraft/Map

**Features:**
- MKMapView wrapper for SwiftUI
- iOS 13+ support (pre-iOS 17)
- Easily extensible annotations/overlays
- Backward compatible with MKAnnotation/MKOverlay
- SwiftUI-style API with Identifiable

**Integration Complexity:** Medium
**Recommendation:** Use if you need SwiftUI maps with iOS 13-16 support

---

#### okhanokbay/MapViewPlus
**GitHub:** https://github.com/okhanokbay/MapViewPlus

**Features:**
- Custom callout views for annotations
- Custom annotation images
- Animation support

**Integration Complexity:** Low
**Recommendation:** Good for custom transit stop callouts

---

#### robertmryan/mapkit-animated-overlays
**GitHub:** https://github.com/robertmryan/mapkit-animated-overlays

**Features:**
- Touch recognition on overlays
- Dynamic polyline/polygon drawing
- Animations

**Integration Complexity:** Medium
**Recommendation:** Study for animated route drawing (real-time vehicle tracking)

---

**MapKit Recommendation:**
- **iOS 17+:** Use native SwiftUI Map with MapPolyline
- **iOS 13-16:** Use pauljohanneskraft/Map for SwiftUI, or native MKMapView for UIKit
- **Custom callouts:** okhanokbay/MapViewPlus
- **Animations:** Learn from robertmryan/mapkit-animated-overlays

---

## Date/Time Handling

### SwiftDate
**GitHub:** https://github.com/malcommac/SwiftDate
**Website:** http://malcommac.github.io/SwiftDate/main_concepts.html
**License:** MIT
**Maintenance:** Active

**Features:**
- Comprehensive timezone support
- Recognizes major datetime formats automatically (ISO8601, RSS, .NET, SQL, HTTP)
- Natural language date manipulation
- 140+ supported languages/locales
- `DateInRegion` class: encapsulates UTC date with region/locale/calendar
- Codable support
- 90% code coverage

**Transit-Specific Use Cases:**
- GTFS timezone handling (feed timezone vs. user timezone)
- Service calendar calculations (which trips run today?)
- Time range queries (find next 3 departures)
- DST transitions
- Multi-timezone trip planning

**Pros:**
- ✅ Solves complex timezone edge cases
- ✅ Excellent for GTFS calendar.txt and calendar_dates.txt
- ✅ Well-documented with interactive playground
- ✅ Production-ready (high test coverage)

**Cons:**
- ❌ Additional dependency (can use native Foundation if simple needs)

**Integration Complexity:** Low
**Recommendation:** Strongly recommended for transit apps (timezone/calendar complexity is high)

---

### Native Foundation (Alternative)
**Apple Framework - Native**

**Features:**
- `Calendar`, `TimeZone`, `DateComponents`
- Works but verbose for complex operations

**Recommendation:** Use SwiftDate instead unless you have minimal date/time needs

---

## Networking Libraries

### Performance & Ecosystem (2024)

**CocoaPods Status:** Entered maintenance mode August 13, 2024
**Current Standard:** Swift Package Manager (SPM)

---

### 1. URLSession (Native)
**Apple Framework - Native**

**Pros:**
- ✅ No external dependency
- ✅ Part of Foundation framework
- ✅ Fine-grained control
- ✅ Minimal overhead
- ✅ Background network sessions
- ✅ Official Apple support

**Cons:**
- ❌ More verbose
- ❌ Manual error handling
- ❌ More boilerplate for common tasks

**Use Cases:**
- Simple API calls
- Background GTFS-RT feed fetching
- Performance-critical operations
- Minimal dependency preference

**Integration Complexity:** Low
**Recommendation:** Default choice for transit apps (GTFS-RT feeds are simple HTTP requests)

---

### 2. Alamofire
**GitHub:** https://github.com/Alamofire/Alamofire
**Latest Release:** 5.10.1 (October 19, 2024)
**License:** MIT
**Maintenance:** Very active

**Features:**
- "Elegant HTTP Networking in Swift"
- Higher-level API over URLSession
- Automatic retry
- Request chaining
- JSON parsing helpers
- Reduced boilerplate

**Performance:**
- Minimal overhead vs. URLSession
- Built on top of URLSession

**Pros:**
- ✅ Rapid development
- ✅ Compact syntax (few lines for complex requests)
- ✅ Built-in features (retry, validation)
- ✅ Well-maintained

**Cons:**
- ❌ External dependency
- ❌ Slight overhead vs. URLSession
- ❌ Abstracts away low-level control

**Use Cases:**
- Complex API integrations
- Multiple backend endpoints
- Developer productivity priority

**Integration Complexity:** Low
**Recommendation:** Use if you have complex multi-endpoint API needs beyond GTFS

---

### Networking Recommendation for Transit Apps

**Use URLSession if:**
- Fetching GTFS-RT feeds (simple HTTP GET)
- Background fetch tasks
- Minimal dependencies preferred
- Simple API surface

**Use Alamofire if:**
- Multiple complex API endpoints
- Need rapid development features
- Request chaining required
- Team prefers higher-level API

**For GTFS-RT specifically:** URLSession is sufficient (binary protobuf over HTTP GET)

---

## Background Tasks & Data Refresh

### BackgroundTasks Framework (Native)
**Apple Framework - iOS 13+**

**Features:**
- SwiftUI `backgroundTask` modifier
- App refresh tasks
- Database cleaning tasks
- Swift Concurrency (async/await)
- Cooperative cancellation

**Background Network Requests:**
- Use `URLSession` with background configuration
- Long-running downloads complete when app suspended
- Additional runtime when network request completes

**Important Limitations:**
- ⚠️ System decides execution time (battery, network, priority)
- ⚠️ Cannot force immediate execution
- ⚠️ No guarantees on timing

**Best Practices:**
- Assign unique task identifiers
- Handle data persistence carefully
- Design for interrupted/failed tasks
- Test with Xcode background fetch simulation

**Transit App Use Cases:**
- Periodic GTFS-RT feed refresh
- Route/schedule updates
- Alert notifications processing

**Integration Complexity:** Medium
**Recommendation:** Use for background GTFS-RT updates; design assuming unpredictable execution

---

## Swift Package Manager vs. CocoaPods (2024)

### CocoaPods - Maintenance Mode
**Status:** Announced maintenance mode August 13, 2024

**Pros:**
- ✅ Thousands of libraries
- ✅ Established ecosystem

**Cons:**
- ❌ Slower build times (rebuilds all dependencies)
- ❌ Maintenance mode = limited future
- ❌ Podfile management overhead

**Recommendation:** Migrate away from CocoaPods

---

### Swift Package Manager (SPM) - Current Standard
**Apple's Official Package Manager**

**Pros:**
- ✅ Native Xcode integration
- ✅ Significantly faster builds (direct framework integration)
- ✅ No Podfile maintenance
- ✅ Private packages easier
- ✅ Apple's long-term investment

**Cons:**
- ❌ Smaller library selection than CocoaPods (but growing rapidly)
- ❌ Cannot update single package independently
- ❌ Bound to Xcode release schedule

**Recommendation:** Use SPM for all new projects

**Can use both together:** Yes, but avoid if possible

---

## Community Resources

### Forums

**Swift.org Forums (Official):**
- URL: https://forums.swift.org/
- Category: "Using Swift" for newcomers
- All technical/administrative Swift topics

**Apple Developer Forums:**
- URL: https://developer.apple.com/forums/
- Direct interaction with Apple engineers
- Tool-specific sections

**Reddit:**
- /r/swift
- /r/iOSProgramming
- Tutorials, discussions, news

---

### Slack Communities

**iOS Developers HQ:**
- 40,000+ members
- URL: https://ios-developers.io/

**Swift User Groups:**
- Real-time help
- Best practices discussions

---

### Discord Servers

**Apple Development Discord:**
- URL: https://discord.com/invite/vVNXQZT
- Largest Discord for Apple developers
- Objective-C, Swift, iOS, iPadOS, macOS, visionOS, tvOS

**Swift Community Discord:**
- Search Discord for "Swift" or "iOS Development" tags
- 150M+ monthly active users

---

### GitHub Organizations

**OneBusAway:**
- https://github.com/OneBusAway
- Open Transit Software Foundation
- Production transit apps

**MobilityData/awesome-transit:**
- https://github.com/MobilityData/awesome-transit
- Curated list of transit APIs, apps, datasets, research, software

---

### Transit-Specific Resources

**GTFS.org:**
- https://gtfs.org/
- Official GTFS documentation
- Using Data section: https://gtfs.org/resources/using-data/

**Open Transit Software Foundation:**
- https://opentransitsoftwarefoundation.org/
- Transit app development news
- Case studies

---

### Blogs & Tutorials

**Limited 2024 Swift+GTFS Content:**
- Most resources are GitHub libraries
- Stack Overflow for specific problems
- General iOS development blogs (SwiftLee, Hacking with Swift) for patterns

**Conference Talks:**
- Apple WWDC sessions (Core Location, MapKit, BackgroundTasks)
- WWDC 2016: Core Location Best Practices
- WWDC 2022: Background Tasks in SwiftUI

---

## Architecture Lessons from Open Source Apps

### OneBusAway (OBAKit)

**Framework Separation Pattern:**
```
OBAKitCore (networking + data)
    ↓
OBAKit (UI)
    ↓
App (branding + configuration)
```

**Lessons:**
1. ✅ **Separate network/data from UI** - enables white-labeling and testing
2. ✅ **Framework-first thinking** - forces clean API boundaries
3. ✅ **Clarity over cleverness** - long-term maintainability
4. ✅ **XcodeGen + SPM** - modern project generation
5. ✅ **Reusable components** - agencies create apps in <1 day

---

### General iOS Architecture for Transit

**Recommended Pattern:** Clean Architecture + MVVM

**Layers:**
- **Domain:** GTFS models (Route, Stop, Trip, etc.)
- **Data:** Repository pattern (network + database)
- **Presentation:** MVVM ViewModels
- **UI:** SwiftUI Views

**Example Structure:**
```
Domain/
  Models/
    Route.swift
    Stop.swift
    Trip.swift

Data/
  Network/
    GTFSAPIService.swift
    GTFSRTService.swift
  Database/
    GTFSDatabase.swift (GRDB)
  Repositories/
    RouteRepository.swift

Presentation/
  RouteList/
    RouteListViewModel.swift
    RouteListView.swift
  StopDetails/
    StopDetailsViewModel.swift
    StopDetailsView.swift

App/
  AppDelegate.swift
  Configuration.swift
```

**Key Principles:**
- Dependency injection for testing
- Protocol-oriented repositories
- Value types for domain models (Thread-safe, testable)
- Coordinator pattern for navigation
- Background tasks separated from UI

---

## Recommended Library Stack

### Minimal Dependencies (Production-Ready)

```swift
// Package.swift dependencies
dependencies: [
    // GTFS Parsing
    .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.25.0"),

    // Database
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),

    // Date/Time
    .package(url: "https://github.com/malcommac/SwiftDate.git", from: "7.0.0"),

    // Geospatial (optional - only if needed)
    .package(url: "https://github.com/GEOSwift/GEOSwift.git", from: "9.0.0"),
]
```

**Native Frameworks (No Dependencies):**
- Networking: URLSession
- Location: CoreLocation
- Maps: MapKit
- Background: BackgroundTasks
- Database (alternative): CoreData

**Total External Dependencies:** 3-4 packages

---

### Evaluation Criteria Recap

| Library | Use? | Rationale |
|---------|------|-----------|
| **GTFS Parsing** | Custom + SwiftProtobuf | Build simple parser; backend handles RT |
| **Database** | GRDB | Best for complex queries, safe concurrency |
| **Networking** | URLSession | Sufficient for GTFS-RT; no dependency |
| **Geospatial** | CoreLocation + (GEOSwift if needed) | Native first; add GEOSwift for polygons |
| **Date/Time** | SwiftDate | Transit timezone complexity = must-have |
| **MapKit** | Native (iOS 17+) or pauljohanneskraft/Map | No dependency for modern iOS |
| **Background** | BackgroundTasks | Native framework |

---

## Build vs. Buy Decision Matrix

### Build Custom:
- ✅ GTFS static parser (simple CSV parsing)
- ✅ UI/UX (transit-specific flows)
- ✅ Business logic (route planning, favorites)
- ✅ Real-time processing logic (filtering, caching)

### Use Libraries:
- ✅ GTFS-RT protobuf parsing (SwiftProtobuf)
- ✅ Complex date/time (SwiftDate)
- ✅ Database layer (GRDB)
- ✅ Geospatial operations (GEOSwift if complex)

### Evaluate Case-by-Case:
- ⚠️ Networking (URLSession likely sufficient)
- ⚠️ MapKit extensions (native iOS 17+ vs. backport)
- ⚠️ Architecture frameworks (learn from OBAKit, build custom)

---

## License Compatibility Summary

**Confirmed Open Source Licenses:**
- GRDB: MIT
- SwiftDate: MIT
- Alamofire: MIT
- GEOSwift: MIT
- OneBusAway: Apache 2.0 (assumed)
- TripKit: ISC/MIT (likely)

**All identified libraries are permissive licenses** - compatible with commercial App Store distribution.

---

## Next Steps

1. **Prototype GTFS parsing:**
   - Test `emma-k-alexandra/GTFS` or `richwolf/transit` with your GTFS feed
   - Measure parsing time for on-device vs. backend preprocessing
   - Decide: on-device parsing or backend API?

2. **Database POC:**
   - Implement GRDB schema for stops, routes, trips
   - Test query performance with full GTFS dataset
   - Compare with CoreData if needed

3. **Architecture:**
   - Study OneBusAway's OBAKit framework structure
   - Define your app's layer boundaries (Domain/Data/Presentation/UI)
   - Decide on white-label requirements

4. **Real-time:**
   - Set up SwiftProtobuf code generation from `gtfs-realtime.proto`
   - Build backend API to filter GTFS-RT for mobile
   - Implement BackgroundTasks for periodic refresh

5. **Geospatial:**
   - Map service area boundaries (do you need GEOSwift?)
   - Test CoreLocation battery impact with different accuracy settings
   - Implement "find nearest stops" algorithm

6. **Community:**
   - Join iOS Developers HQ Slack
   - Follow OneBusAway GitHub activity
   - Monitor MobilityData/awesome-transit for new tools

---

## Resources for Further Learning

**Official Documentation:**
- GTFS Spec: https://gtfs.org/
- OneBusAway Docs: https://developer.onebusaway.org/
- Apple Core Location: https://developer.apple.com/documentation/corelocation
- Apple MapKit: https://developer.apple.com/documentation/mapkit

**GitHub Repositories:**
- OneBusAway iOS: https://github.com/OneBusAway/onebusaway-ios
- Awesome Transit: https://github.com/MobilityData/awesome-transit
- GRDB: https://github.com/groue/GRDB.swift
- SwiftDate: https://github.com/malcommac/SwiftDate

**WWDC Videos:**
- Core Location Best Practices (WWDC 2016)
- Background Tasks in SwiftUI (WWDC 2022)

---

## Conclusion

**Don't reinvent the wheel for:**
- GTFS-RT parsing (use SwiftProtobuf)
- Complex date/timezone logic (use SwiftDate)
- Database abstraction (use GRDB for transit data)
- Geospatial geometry (use GEOSwift if needed)

**Do build custom:**
- GTFS static parser (simple, understand your data)
- Transit-specific UI/UX
- Real-time data filtering and caching logic
- App-specific features (favorites, notifications, trip planning)

**Learn from OneBusAway:**
- Framework-based architecture for reusability
- White-label pattern for customization
- Clarity-focused code for maintainability

**Modern Stack (2024):**
- Swift Package Manager (not CocoaPods)
- SwiftUI + UIKit where needed
- Native frameworks first (URLSession, CoreLocation, MapKit)
- Minimal, focused dependencies (3-4 packages)

This research demonstrates that while transit app development is complex, the Swift ecosystem provides mature, well-maintained libraries for the hard problems (protobuf parsing, database management, geospatial calculations, timezone handling), allowing you to focus on building great transit experiences rather than low-level infrastructure.
# Offline Data Storage Strategy for Transit App
## Sydney, Melbourne, Brisbane GTFS Implementation

---

## Executive Summary

**Recommended Approach:**
- **Storage**: SQLite with selective denormalization + R-Tree indexes for geospatial
- **Size**: ~320-520 MB compressed, ~800 MB-1.5 GB uncompressed on-device
- **Updates**: Weekly full replacement via Background Assets framework
- **Real-time Cache**: 24-hour rolling cache, separate SQLite table
- **Database**: Direct SQLite (not CoreData/Realm) for GTFS-optimized schema

**Key Decision**: Prioritize query performance over storage efficiency. Mobile devices have sufficient storage, but users need <100ms query times for stop departures.

---

## Storage Requirements

### GTFS Feed Sizes (Official Data)

| City | Compressed | Routes | Stops | Notes |
|------|-----------|--------|-------|-------|
| **Sydney (TfNSW)** | 227 MB | - | - | Complete GTFS including regional |
| **Melbourne (PTV)** | 262.3 MB | 2,623 | 27,795 | All metro/regional train, bus, tram |
| **Brisbane (Translink)** | 29.1 MB | 1,514 | 13,083 | SEQ urban bus, rail, light rail, ferry |
| **Total** | **~518 MB** | **4,137+** | **40,878+** | Combined compressed size |

### Uncompressed Estimates

```
Sydney:    227 MB → ~600 MB uncompressed (2.6x ratio)
Melbourne: 262 MB → ~700 MB uncompressed (2.7x ratio)
Brisbane:  29 MB  → ~75 MB uncompressed (2.6x ratio)
---------------------------------------------------------
Total uncompressed: ~1.4 GB raw GTFS CSV files
```

### On-Device Storage (After Import to SQLite)

**Conservative Estimate:**
- Base tables: ~800 MB (normalized)
- Denormalized views/tables: +200 MB
- Indexes (including R-Tree): +150 MB
- Real-time cache (24h): +50 MB
- **Total: ~1.2 GB**

**With Optimization:**
- Selective indexing
- Remove unused GTFS fields
- Compress shape data
- **Optimized: ~800-900 MB**

### iOS Storage Limits & Best Practices

**Official Limits:**
- App bundle: 4 GB max uncompressed
- Cellular download: 200 MB max (requires WiFi above)
- User storage: No hard limit, depends on device

**Best Practices:**
- Use iOS 16+ Background Assets framework for downloads
- Set `NSFileManager.IsExcludedFromBackupKey` to exclude from iCloud backup
- Store in app's Documents directory (persists across updates)
- Implement storage check before download: require 2 GB free space
- Provide "Download over WiFi only" setting
- Show clear storage usage in Settings screen

**User Storage Management:**
- Warn if <2 GB available before download
- Allow per-city download (Sydney only, Melbourne only, etc.)
- "Low Storage Mode": Skip shapes, reduce indexes (~40% savings)
- Clear cache option for real-time data

---

## Database Architecture

### Storage Technology: Direct SQLite (Not CoreData/Realm)

**Why SQLite over CoreData:**
- CoreData adds overhead for GTFS structure
- Need raw SQL for complex transit queries
- Better control over indexes
- Easier to import bulk CSV data
- Lower memory footprint

**Why SQLite over Realm:**
- Better R-Tree support for geospatial
- Simpler GTFS import tooling
- Smaller binary size
- More mature on iOS

### Schema Design Strategy

**Hybrid Normalization Approach:**
1. **Normalized base tables** (mirrors GTFS structure)
2. **Denormalized query tables** (optimized for common queries)
3. **Materialized views** (pre-computed joins)

#### Base Tables (Normalized)

```sql
-- Core GTFS tables (normalized for data integrity)
CREATE TABLE agency (
    agency_id TEXT PRIMARY KEY,
    agency_name TEXT NOT NULL,
    agency_url TEXT,
    agency_timezone TEXT NOT NULL
);

CREATE TABLE routes (
    route_id TEXT PRIMARY KEY,
    agency_id TEXT,
    route_short_name TEXT,
    route_long_name TEXT,
    route_type INTEGER NOT NULL,
    route_color TEXT,
    FOREIGN KEY (agency_id) REFERENCES agency(agency_id)
);

CREATE TABLE stops (
    stop_id TEXT PRIMARY KEY,
    stop_code TEXT,
    stop_name TEXT NOT NULL,
    stop_lat REAL NOT NULL,
    stop_lon REAL NOT NULL,
    location_type INTEGER DEFAULT 0,
    parent_station TEXT,
    wheelchair_boarding INTEGER
);

CREATE TABLE trips (
    trip_id TEXT PRIMARY KEY,
    route_id TEXT NOT NULL,
    service_id TEXT NOT NULL,
    trip_headsign TEXT,
    direction_id INTEGER,
    block_id TEXT,
    shape_id TEXT,
    FOREIGN KEY (route_id) REFERENCES routes(route_id),
    FOREIGN KEY (service_id) REFERENCES calendar(service_id)
);

CREATE TABLE stop_times (
    trip_id TEXT NOT NULL,
    stop_id TEXT NOT NULL,
    arrival_time INTEGER NOT NULL,  -- seconds since midnight
    departure_time INTEGER NOT NULL,
    stop_sequence INTEGER NOT NULL,
    pickup_type INTEGER DEFAULT 0,
    drop_off_type INTEGER DEFAULT 0,
    PRIMARY KEY (trip_id, stop_sequence),
    FOREIGN KEY (trip_id) REFERENCES trips(trip_id),
    FOREIGN KEY (stop_id) REFERENCES stops(stop_id)
);

CREATE TABLE calendar (
    service_id TEXT PRIMARY KEY,
    monday INTEGER NOT NULL,
    tuesday INTEGER NOT NULL,
    wednesday INTEGER NOT NULL,
    thursday INTEGER NOT NULL,
    friday INTEGER NOT NULL,
    saturday INTEGER NOT NULL,
    sunday INTEGER NOT NULL,
    start_date INTEGER NOT NULL,  -- YYYYMMDD as integer
    end_date INTEGER NOT NULL
);

CREATE TABLE calendar_dates (
    service_id TEXT NOT NULL,
    date INTEGER NOT NULL,  -- YYYYMMDD as integer
    exception_type INTEGER NOT NULL,
    PRIMARY KEY (service_id, date)
);
```

#### Denormalized Query Tables

```sql
-- Pre-computed stop departures (hot path query)
CREATE TABLE stop_departures (
    stop_id TEXT NOT NULL,
    route_id TEXT NOT NULL,
    trip_id TEXT NOT NULL,
    departure_time INTEGER NOT NULL,
    headsign TEXT,
    service_id TEXT NOT NULL,
    route_short_name TEXT,
    route_color TEXT,
    direction_id INTEGER,
    PRIMARY KEY (stop_id, trip_id, departure_time)
);

-- Pre-computed trip patterns (for trip planning)
CREATE TABLE trip_patterns (
    pattern_id TEXT PRIMARY KEY,
    route_id TEXT NOT NULL,
    stop_ids TEXT NOT NULL,  -- JSON array of stop_ids
    stop_count INTEGER NOT NULL
);

-- Nearby stops cache (for map view)
CREATE TABLE stop_clusters (
    cluster_id INTEGER PRIMARY KEY,
    center_lat REAL NOT NULL,
    center_lon REAL NOT NULL,
    stop_ids TEXT NOT NULL,  -- JSON array
    radius_meters INTEGER
);
```

### Indexing Strategy

#### Critical Indexes (Always Create)

```sql
-- Stop departures (most common query)
CREATE INDEX idx_stop_times_stop_id ON stop_times(stop_id, departure_time);
CREATE INDEX idx_stop_times_trip_id ON stop_times(trip_id);

-- Trip planning
CREATE INDEX idx_trips_route_service ON trips(route_id, service_id);
CREATE INDEX idx_routes_type ON routes(route_type);

-- Calendar lookups
CREATE INDEX idx_calendar_dates_date ON calendar_dates(date, service_id);

-- Geospatial (R-Tree for nearby stops)
CREATE VIRTUAL TABLE stops_rtree USING rtree(
    id,
    min_lat, max_lat,
    min_lon, max_lon
);
```

#### Optional Indexes (Standard Mode)

```sql
-- Covering index for stop departures
CREATE INDEX idx_stop_departures_full ON stop_departures(
    stop_id, departure_time, route_id, headsign
);

-- Headsign search
CREATE INDEX idx_trips_headsign ON trips(trip_headsign);
```

#### R-Tree Performance

**Benefits:**
- 2-5x faster for nearby stops queries
- Essential for map view performance
- Efficient bounding box queries

**Cost:**
- ~15% additional storage
- Initial bulk load: 6 seconds (3M rows)

**Implementation:**
```sql
-- Populate R-Tree from stops table
INSERT INTO stops_rtree
SELECT
    CAST(rowid AS INTEGER),
    stop_lat, stop_lat,
    stop_lon, stop_lon
FROM stops;

-- Query nearby stops (1km radius)
SELECT s.*
FROM stops s
JOIN stops_rtree r ON s.rowid = r.id
WHERE r.min_lat >= ? AND r.max_lat <= ?
  AND r.min_lon >= ? AND r.max_lon <= ?
ORDER BY
    (s.stop_lat - ?)*(s.stop_lat - ?) +
    (s.stop_lon - ?)*(s.stop_lon - ?)
LIMIT 20;
```

### Query Performance Benchmarks

**Target Performance:**
- Stop departures: <100ms
- Nearby stops: <150ms
- Trip planning: <500ms (single route)
- Route list: <50ms

**Optimization Techniques:**
1. **Pre-compute joins**: `stop_departures` table
2. **Integer time storage**: Seconds since midnight (not strings)
3. **Date as integer**: YYYYMMDD format (faster comparisons)
4. **Covering indexes**: Include all SELECT columns
5. **ANALYZE command**: Update statistics after data load

---

## Data Compression

### GTFS Compression Effectiveness

**Standard Compression (gzip):**
- Ratio: 2.5-3x (90% for GTFS-RT)
- Speed: Very fast, native support
- Use case: Network transfer

**Advanced Compression (7zip/bzip2):**
- Ratio: 17x (85 MB → 5 MB observed)
- Speed: Slower decompression
- Use case: App bundle pre-load

**Specialized (bGTFS - Transit App's format):**
- Ratio: 30-200x
- Requires custom implementation
- Not recommended (complexity vs. benefit)

### Recommended Approach

**Download:** gzip (.zip) - GTFS standard format
```
Server: GTFS .zip (~518 MB)
   ↓ Download with URLSession
iOS Device: Unzip (~1.4 GB CSV)
   ↓ Import to SQLite
SQLite DB: (~900 MB with indexes)
   ↓ Runtime
Memory: <100 MB active working set
```

**App Bundle Pre-load (Optional):**
- Ship compressed SQLite database in app bundle
- Use zlib compression (2-3x)
- Extract on first launch to Documents directory
- Reduces initial download wait

### Custom Compression Strategies

**Shape Data (Optional):**
```sql
-- Store shapes as compressed BLOB
CREATE TABLE shapes_compressed (
    shape_id TEXT PRIMARY KEY,
    points BLOB  -- zlib compressed lat/lon array
);
```

**Benefits:**
- Shapes are 40-60% of GTFS size
- Rarely accessed (only for map polylines)
- Can decompress on-demand

**Trade-offs:**
- CPU cost: ~5ms decompression per route
- Code complexity
- Negligible battery impact

---

## Update Strategies

### GTFS Schedule Update Frequency

**Static GTFS:**
- Industry standard: Weekly updates
- Processing time: 24-48 hours (for validation)
- Sydney/Melbourne/Brisbane: Weekly on Mondays (typical)

**Change Patterns:**
- Service adjustments: Monthly
- Route changes: Quarterly
- Timetable updates: Seasonal (summer/winter)
- Emergency changes: Via GTFS-RT alerts

### Recommended Update Strategy: Weekly Full Replacement

**Rationale:**
- GTFS static feeds are immutable snapshots
- No official incremental update mechanism
- Full replacement is simpler and more reliable
- Weekly update aligns with transit agency schedules

#### Implementation with Background Assets Framework

**iOS 16+ Background Assets API:**

```swift
import BackgroundAssets

class GTFSUpdateManager {
    func scheduleWeeklyUpdate() {
        let request = BAURLDownload(
            identifier: "com.app.gtfs.sydney",
            request: URLRequest(url: sydneyGTFSURL),
            applicationGroupIdentifier: nil
        )

        // Essential priority for regular updates
        request.priority = .default

        BADownloadManager.shared.scheduleDownload(request)
    }

    func handleDownloadComplete(_ download: BADownload) {
        // 1. Verify download integrity (check file size, zip validity)
        // 2. Extract to temporary directory
        // 3. Import to new SQLite database
        // 4. Run validation queries
        // 5. Atomic swap: rename new DB to active DB
        // 6. Delete old database
    }
}
```

**Benefits:**
- System manages scheduling (WiFi, battery, time)
- Survives app termination
- Background processing time
- User-configurable settings

#### Atomic Database Swap Pattern

```swift
// Ensure zero downtime during update
let oldDB = documentsPath + "gtfs.db"
let newDB = documentsPath + "gtfs_new.db"
let backupDB = documentsPath + "gtfs_backup.db"

// 1. Import to gtfs_new.db
importGTFS(to: newDB)

// 2. Validate
guard validateDatabase(newDB) else {
    // Rollback: delete new DB, keep old
    return
}

// 3. Atomic swap
try? FileManager.default.moveItem(at: oldDB, to: backupDB)
try FileManager.default.moveItem(at: newDB, to: oldDB)

// 4. Clean up backup after verification
try? FileManager.default.removeItem(at: backupDB)
```

### Update Failure Handling

**Scenarios:**
1. Download fails (network)
2. Disk full during extraction
3. SQLite import error
4. Data validation fails

**Graceful Degradation:**
```
1. Keep existing database (don't delete)
2. Show notification: "Using schedules from [date]"
3. Retry download: Exponential backoff (1h, 4h, 12h, 24h)
4. Alert if data >30 days old
5. Fallback: Manual update button in Settings
```

### Differential Updates (Future Consideration)

**Current Status:**
- GTFS-RT supports DIFFERENTIAL mode (unsupported/unspecified)
- No standard for static GTFS incremental updates

**Potential Approach (Custom):**
- Calculate diff between old/new GTFS feeds
- Generate patch file (added/modified/deleted trips)
- Apply patch to SQLite with transactions
- Risk: Complex, error-prone, limited benefit

**Verdict:** Not recommended for v1. Weekly full replacement is sufficient.

---

## Real-Time Data Caching

### Strategy: 24-Hour Rolling Cache

**Rationale:**
- GTFS-RT data must be <90 seconds fresh (per spec)
- Offline users benefit from "recent" predictions
- 24h cache provides context for delays/service changes

### Cache Schema

```sql
CREATE TABLE realtime_cache (
    trip_id TEXT NOT NULL,
    stop_id TEXT NOT NULL,
    arrival_delay INTEGER,      -- seconds
    departure_delay INTEGER,    -- seconds
    timestamp INTEGER NOT NULL, -- Unix timestamp
    schedule_relationship INTEGER, -- 0=scheduled, 1=skipped, 2=no_data
    vehicle_id TEXT,
    PRIMARY KEY (trip_id, stop_id, timestamp)
);

-- Auto-cleanup old entries
CREATE INDEX idx_realtime_timestamp ON realtime_cache(timestamp);
```

### Cache Management

**Update Frequency:**
- Online: Fetch GTFS-RT every 30 seconds (per spec)
- Offline: Serve from cache, show staleness indicator

**Storage Overhead:**
- ~50-100 MB for 24h of data (3 cities)
- Prune entries older than 24h on each update

**Cache Invalidation:**
```swift
// Prune old cache entries
let cutoff = Date().addingTimeInterval(-86400) // 24h ago
db.execute("DELETE FROM realtime_cache WHERE timestamp < ?", cutoff)

// Vacuum periodically (weekly)
db.execute("VACUUM")
```

### Offline Real-Time Merging

**Merge Logic:**
```swift
func getStopDepartures(stopId: String) -> [Departure] {
    // 1. Get scheduled times from GTFS static
    let scheduled = getScheduledDepartures(stopId)

    // 2. Apply real-time delays from cache
    if isOnline {
        let realtime = fetchRealtimeUpdates(stopId)
        return merge(scheduled, realtime)
    } else {
        let cached = getCachedRealtime(stopId)
        let age = Date().timeIntervalSince(cached.timestamp)

        if age < 3600 { // <1h old, useful
            return merge(scheduled, cached, showAge: true)
        } else {
            return scheduled // Fall back to schedule
        }
    }
}
```

**UI Indicators:**
- Green: Live real-time (<90s)
- Yellow: Cached real-time (90s-1h) "Updated 15 min ago"
- Gray: Scheduled only (no real-time available)

### Graceful Degradation

**Offline Behavior:**
1. Show scheduled times (always available)
2. Show cached delays with timestamp if <1h old
3. Hide real-time indicator if >1h stale
4. Display "Using scheduled times - connect to see live updates"

---

## Competitor Analysis

### Citymapper

**Offline Strategy:**
- Saved Trips feature: Download specific journeys
- Stores map data + scheduled times for saved trips
- Shows "next scheduled departure" when offline
- Official subway/bus maps available offline
- Detects slow connection → switches to scheduled times

**Limitations:**
- Cannot search for new locations offline
- Real-time info requires connectivity
- Per-trip download (not full city)

**Lessons:**
- Partial offline (saved trips) is useful but limiting
- Users expect search to work offline
- Clear distinction between scheduled vs. real-time

### TripView (Sydney)

**Public Information:**
- Limited official documentation on offline mode
- Appears to cache recent queries
- Focus on real-time data (less offline emphasis)

**Community Observations:**
- App size suggests partial offline data
- Strong integration with NSW transport APIs
- Real-time-first philosophy

### Transit App

**Offline Innovation:**
- Developed bGTFS (30-200x compression)
- "Worked offline" became core feature
- Full trip planning without data connection
- Pre-download cities before travel

**Key Insight:**
> "We shrank our trip planner till it didn't need data"
> - Transit App blog post

**Lessons:**
- Offline capability is a competitive differentiator
- Users need trip planning during commutes (tunnels, poor signal)
- Download city data before trips (international travelers)

### Best Practices from Community

1. **Full city download** beats selective caching
2. **Scheduled data works offline**, real-time enhances when online
3. **R-Tree indexes** are essential for map performance
4. **SQLite > Realm/CoreData** for GTFS-specific use case
5. **Show data freshness** prominently (user trust)

---

## iOS-Specific Considerations

### CoreData vs SQLite vs Realm Comparison

| Aspect | SQLite | CoreData | Realm |
|--------|---------|----------|-------|
| **GTFS Import** | Native CSV import | Complex mapping | Manual iteration |
| **Raw SQL** | Full control | Limited (NSPredicate) | None (query API) |
| **R-Tree Support** | Native | None | None |
| **File Size** | Smallest | +20-30% overhead | +10-15% overhead |
| **Performance** | Best for reads | Good for objects | Fast for simple queries |
| **Memory Usage** | Lowest | Higher (object graph) | Moderate |
| **Learning Curve** | SQL knowledge | iOS-specific | New query language |
| **Multi-threading** | WAL mode (concurrent) | NSPrivateQueueConcurrencyType | Automatic |

**Verdict: Direct SQLite**
- GTFS is already tabular (perfect fit)
- Need complex joins and geospatial queries
- Minimize overhead
- Use GRDB.swift or SQLite.swift wrapper

### Recommended Library: GRDB.swift

```swift
import GRDB

// Define Stop model
struct Stop: Codable, FetchableRecord, PersistableRecord {
    var stopId: String
    var stopName: String
    var stopLat: Double
    var stopLon: Double
}

// Query with compile-time safety
let stops = try dbQueue.read { db in
    try Stop
        .filter(Column("stopLat") > -34.0)
        .filter(Column("stopLat") < -33.8)
        .fetchAll(db)
}
```

**Benefits:**
- Type-safe queries
- Codable support (Swift-friendly)
- Connection pooling
- WAL mode by default
- Async/await support (iOS 15+)

### App Bundle vs Downloaded Data

**Hybrid Approach (Recommended):**

1. **App Bundle (~50 MB compressed):**
   - Compressed SQLite database (empty schema)
   - OR: Sydney only (most users)
   - OR: Top 100 routes (minimal subset)

2. **First Launch Download:**
   - Prompt: "Download full schedules? (800 MB)"
   - Options:
     - "All cities" (Sydney + Melbourne + Brisbane)
     - "Sydney only" (smaller)
     - "Later" (use bundle data)

3. **Background Updates:**
   - Weekly refresh via Background Assets

**Benefits:**
- App passes 200 MB cellular limit
- Immediate functionality (bundle data)
- User choice (storage conscious)
- Update without app store submission

### Background Asset Downloads Framework

**iOS 16+ API:**
```swift
import BackgroundAssets

// Schedule essential download (runs weekly automatically)
let download = BAURLDownload(
    identifier: "gtfs.sydney.2024.12.01",
    request: URLRequest(url: gtfsURL),
    essential: true  // Prioritized by system
)

BADownloadManager.shared.scheduleDownload(download)

// Monitor progress
BADownloadManager.shared.withExclusiveControl { manager, error in
    for download in try await manager.fetchCurrentDownloads() {
        print("Progress: \(download.progress.fractionCompleted)")
    }
}
```

**System Behavior:**
- Schedules during WiFi + charging + idle time
- Survives app termination
- User can control in Settings → General → Background App Refresh

### iCloud Integration (Not Recommended)

**Considerations:**
- GTFS data is public (no personal data)
- Same data for all users (not user-specific)
- Large size (consumes iCloud quota)
- Sync complexity (version conflicts)

**Verdict:** Do NOT use iCloud for GTFS data. Only use for:
- User's saved trips/favorites
- App preferences
- Custom annotations

---

## Query Optimization

### Fast Stop Departures Query

**Most Common Query:**
"Show next 10 departures from this stop"

**Optimized Query:**
```sql
-- Uses covering index idx_stop_departures_full
SELECT
    d.route_short_name,
    d.headsign,
    d.departure_time,
    d.route_color,
    d.trip_id
FROM stop_departures d
WHERE d.stop_id = ?
  AND d.departure_time >= ?  -- Current time in seconds since midnight
  AND EXISTS (
      SELECT 1 FROM calendar c
      WHERE c.service_id = d.service_id
        AND (
          (c.start_date <= ? AND c.end_date >= ?)  -- Today in YYYYMMDD
          OR EXISTS (
            SELECT 1 FROM calendar_dates cd
            WHERE cd.service_id = d.service_id
              AND cd.date = ?
              AND cd.exception_type = 1
          )
        )
  )
ORDER BY d.departure_time ASC
LIMIT 10;
```

**Performance:**
- Cold query: ~80ms
- Warm (cached): ~20ms
- Index scan only (no table access)

**Optimization Tips:**
1. Use denormalized `stop_departures` table
2. Store `departure_time` as INTEGER (seconds)
3. Store `date` as INTEGER (YYYYMMDD)
4. Use covering index (all SELECT columns in index)

### Efficient Trip Planning Offline

**Challenge:** Multi-stop routing without network

**Approach: Pre-computed Transfer Patterns**

```sql
-- Build transfer graph during import
CREATE TABLE transfers (
    from_stop_id TEXT NOT NULL,
    to_stop_id TEXT NOT NULL,
    transfer_type INTEGER NOT NULL,
    min_transfer_time INTEGER,
    distance_meters INTEGER,
    PRIMARY KEY (from_stop_id, to_stop_id)
);

-- Add walking transfers (computed from lat/lon)
INSERT INTO transfers (from_stop_id, to_stop_id, transfer_type, distance_meters)
SELECT
    s1.stop_id,
    s2.stop_id,
    2, -- Walking transfer
    CAST(6371000 * 2 * ASIN(SQRT(
        POW(SIN((s2.stop_lat - s1.stop_lat) * PI() / 360), 2) +
        COS(s1.stop_lat * PI() / 180) * COS(s2.stop_lat * PI() / 180) *
        POW(SIN((s2.stop_lon - s1.stop_lon) * PI() / 360), 2)
    )) AS INTEGER) AS distance
FROM stops s1, stops s2
WHERE s1.stop_id != s2.stop_id
  AND distance < 200  -- 200m max walking transfer
```

**Routing Algorithm:**
- Modified Dijkstra's algorithm
- Pre-computed transfer graph
- Time-dependent edge weights (schedule lookup)
- Limit: 3 transfers max

**Performance:**
- Simple route (no transfer): ~100ms
- 1 transfer: ~300ms
- 2 transfers: ~500ms

**Optimization:**
- Pre-compute common routes (save in DB)
- Limit search space (bounding box)
- Use trip patterns to group similar routes

### Nearby Stops with Geospatial Queries

**Query: Find stops within 1km of user location**

**Using R-Tree Index:**
```sql
-- Step 1: Coarse filter with R-Tree (bounding box)
WITH nearby AS (
    SELECT r.id
    FROM stops_rtree r
    WHERE r.min_lat BETWEEN ? AND ?  -- lat ± 0.009 (~1km)
      AND r.min_lon BETWEEN ? AND ?  -- lon ± 0.009
)
-- Step 2: Precise distance calculation
SELECT
    s.stop_id,
    s.stop_name,
    s.stop_lat,
    s.stop_lon,
    6371000 * 2 * ASIN(SQRT(
        POW(SIN((s.stop_lat - ?) * PI() / 360), 2) +
        COS(? * PI() / 180) * COS(s.stop_lat * PI() / 180) *
        POW(SIN((s.stop_lon - ?) * PI() / 360), 2)
    )) AS distance_meters
FROM stops s
JOIN nearby n ON s.rowid = n.id
WHERE distance_meters <= 1000
ORDER BY distance_meters ASC
LIMIT 20;
```

**Performance:**
- Without R-Tree: ~500ms (full table scan, 40k+ stops)
- With R-Tree: ~50ms (2-5x faster)

**iOS Implementation:**
```swift
import CoreLocation

func findNearbyStops(location: CLLocation, radius: CLLocationDistance) async throws -> [Stop] {
    let delta = radius / 111000 // ~111km per degree
    let minLat = location.coordinate.latitude - delta
    let maxLat = location.coordinate.latitude + delta
    let minLon = location.coordinate.longitude - delta
    let maxLon = location.coordinate.longitude + delta

    return try await db.read { db in
        try Stop
            .fetchAll(db, sql: """
                SELECT s.*, ... FROM stops s
                JOIN stops_rtree r ON s.rowid = r.id
                WHERE r.min_lat BETWEEN ? AND ?
                  AND r.min_lon BETWEEN ? AND ?
                  AND distance_meters <= ?
                ORDER BY distance_meters
                LIMIT 20
            """, arguments: [minLat, maxLat, minLon, maxLon, radius])
    }
}
```

### Real-Time Data Merging with Static Schedules

**Query: Merge scheduled + real-time delays**

```sql
-- Get scheduled departures with real-time overlay
SELECT
    st.stop_id,
    st.trip_id,
    st.departure_time AS scheduled_time,
    COALESCE(rt.departure_delay, 0) AS delay_seconds,
    st.departure_time + COALESCE(rt.departure_delay, 0) AS predicted_time,
    rt.timestamp AS realtime_updated,
    t.trip_headsign,
    r.route_short_name,
    r.route_color
FROM stop_times st
JOIN trips t ON st.trip_id = t.trip_id
JOIN routes r ON t.route_id = r.route_id
LEFT JOIN realtime_cache rt ON st.trip_id = rt.trip_id
    AND st.stop_id = rt.stop_id
    AND rt.timestamp > ?  -- Only recent real-time data
WHERE st.stop_id = ?
  AND st.departure_time >= ?
ORDER BY predicted_time ASC
LIMIT 10;
```

**Performance:**
- ~100ms with proper indexes
- LEFT JOIN allows fallback to scheduled
- COALESCE handles missing real-time data

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)

**Goal:** Basic offline storage working for Sydney only

1. **Setup SQLite + GRDB** (2 days)
   - Add GRDB.swift dependency
   - Create database connection manager
   - Implement WAL mode + connection pooling

2. **GTFS Import Pipeline** (3 days)
   - Download Sydney GTFS feed
   - Parse CSV files (use CSVReader)
   - Import to normalized tables (base schema)
   - Add basic indexes

3. **Core Query Functions** (3 days)
   - `getStopDepartures(stopId:)`
   - `getNearbyStops(location:radius:)`
   - `getRoutes()`
   - `getStopDetails(stopId:)`

4. **Testing** (2 days)
   - Unit tests for queries
   - Performance benchmarks
   - Verify data integrity

**Deliverable:** Sydney schedules working offline, basic queries <100ms

### Phase 2: Optimization (Weeks 3-4)

**Goal:** Fast queries, multi-city support

1. **Denormalization** (3 days)
   - Create `stop_departures` table
   - Pre-compute common joins
   - Migrate queries to use new tables

2. **R-Tree Indexes** (2 days)
   - Implement R-Tree for stops
   - Optimize nearby stops query
   - Add geospatial helper functions

3. **Multi-City Support** (3 days)
   - Import Melbourne + Brisbane feeds
   - Add city selector UI
   - Per-city enable/disable (storage management)

4. **Performance Tuning** (2 days)
   - Run ANALYZE command
   - Optimize slow queries (EXPLAIN QUERY PLAN)
   - Add covering indexes

**Deliverable:** All 3 cities working, queries optimized, <1 GB storage

### Phase 3: Updates & Real-Time (Weeks 5-6)

**Goal:** Automatic updates, real-time integration

1. **Background Updates** (4 days)
   - Implement Background Assets download
   - Atomic database swap logic
   - Handle update failures gracefully
   - Show data freshness in UI

2. **Real-Time Caching** (3 days)
   - Fetch GTFS-RT feeds (30s interval)
   - Store in `realtime_cache` table
   - Prune old entries (24h TTL)
   - Merge with scheduled data

3. **Offline Indicators** (2 days)
   - Show connection status
   - Display "Live" vs "Scheduled" badge
   - Age indicators for cached data

4. **Testing** (1 day)
   - Test update flow end-to-end
   - Verify real-time merging
   - Network toggle testing (airplane mode)

**Deliverable:** Auto-updating schedules, real-time overlays, offline resilience

### Phase 4: Polish & Advanced Features (Weeks 7-8)

**Goal:** Trip planning, storage management

1. **Trip Planning** (4 days)
   - Build transfer graph
   - Implement routing algorithm
   - Multi-leg journey support
   - Save favorite routes

2. **Storage Management UI** (2 days)
   - Show storage usage per city
   - Download/delete city data
   - "Low Storage Mode" option
   - Clear cache function

3. **Performance Monitoring** (2 days)
   - Add Instruments logging
   - Query performance metrics
   - Database size tracking
   - Memory profiling

4. **Polish** (2 days)
   - Loading states for long queries
   - Retry logic for failed downloads
   - User education (offline mode explanation)
   - Settings screen

**Deliverable:** Full-featured offline transit app, production-ready

### Ongoing: Maintenance

- **Weekly**: Monitor GTFS feed updates
- **Monthly**: Review query performance logs
- **Quarterly**: Database schema optimizations
- **Annually**: Re-evaluate compression strategies

---

## Risks and Mitigations

### Risk 1: Large Download Size (518 MB)

**Impact:** Users unwilling to download, cellular data concerns

**Mitigations:**
- ✓ WiFi-only download by default
- ✓ Per-city selection (Sydney only = 227 MB)
- ✓ Progressive download (start with nearby city)
- ✓ Clear storage requirements upfront
- ✓ Ship Sydney in app bundle (immediate functionality)

**Metrics:**
- Track download completion rate
- Monitor user feedback on size
- A/B test different default sizes

### Risk 2: Storage Space on Device

**Impact:** Users with low storage can't use offline mode

**Mitigations:**
- ✓ Check available space before download (require 2 GB free)
- ✓ Show storage usage in Settings
- ✓ "Low Storage Mode" (skip shapes, reduce indexes = ~40% savings)
- ✓ Delete old data on update (don't accumulate)
- ✓ Allow uninstall of specific cities

**Monitoring:**
- Storage usage analytics
- Device storage distribution (user fleet)

### Risk 3: Query Performance Degradation

**Impact:** Slow queries frustrate users, app feels sluggish

**Mitigations:**
- ✓ Set strict performance budgets (<100ms for departures)
- ✓ Performance testing in CI pipeline
- ✓ EXPLAIN QUERY PLAN analysis
- ✓ Covering indexes for hot queries
- ✓ Denormalized tables for complex joins
- ✓ R-Tree for geospatial

**Monitoring:**
- Query duration logging (95th percentile)
- Slow query alerts (>200ms)
- User-reported "app is slow"

### Risk 4: GTFS Feed Format Changes

**Impact:** App breaks when transit agencies change feed structure

**Mitigations:**
- ✓ GTFS validator on import (check required fields)
- ✓ Versioned schema (handle changes gracefully)
- ✓ Fallback to old data if new import fails
- ✓ Manual review of feed changes (subscribe to agency mailing lists)
- ✓ Unit tests with real GTFS feeds

**Monitoring:**
- Import failure alerts
- Feed validation errors
- User reports of missing data

### Risk 5: Update Failures

**Impact:** Users stuck with stale data, app shows outdated schedules

**Mitigations:**
- ✓ Keep old database until new one validates
- ✓ Retry download with exponential backoff
- ✓ Show "Using schedules from [date]" notification
- ✓ Manual update button in Settings
- ✓ Alert if data >30 days old

**Monitoring:**
- Update success rate
- Time since last successful update
- User-initiated manual updates

### Risk 6: Battery & CPU Impact

**Impact:** App drains battery during import or queries

**Mitigations:**
- ✓ Background Assets framework (system-managed)
- ✓ Import only during charging + WiFi (configurable)
- ✓ Efficient queries (avoid table scans)
- ✓ Lazy loading (don't query until needed)
- ✓ Debounce real-time fetches (max every 30s)

**Monitoring:**
- Battery usage metrics (Xcode Energy Log)
- CPU time per query
- Import duration

### Risk 7: Real-Time Data Costs

**Impact:** Frequent GTFS-RT fetches consume data plan

**Mitigations:**
- ✓ Cache aggressively (24h)
- ✓ Only fetch when app is active + screen on
- ✓ Pause updates when low power mode enabled
- ✓ User setting: "Reduce data usage"
- ✓ Protocol Buffers (efficient wire format)

**Monitoring:**
- Network usage per session
- GTFS-RT fetch frequency
- User complaints about data usage

### Risk 8: Disk Space Bloat Over Time

**Impact:** Cache and old data accumulate, wasting storage

**Mitigations:**
- ✓ Auto-delete old real-time cache (24h TTL)
- ✓ VACUUM database periodically (weekly)
- ✓ Delete old database files on update
- ✓ Clear tmp directory on launch
- ✓ Storage usage warnings

**Monitoring:**
- App storage size over time
- Cache size distribution
- VACUUM reclaimed space

---

## Appendix: Additional Resources

### GTFS Data Sources

- **Sydney (TfNSW):** https://opendata.transport.nsw.gov.au/dataset/timetables-complete-gtfs
- **Melbourne (PTV):** https://www.ptv.vic.gov.au/footer/data-and-reporting/datasets/
- **Brisbane (Translink):** https://www.data.qld.gov.au/dataset/general-transit-feed-specification-gtfs-translink

### GTFS Realtime Feeds

- **Sydney:** https://api.transport.nsw.gov.au/v1/gtfs/realtime/
- **Melbourne:** https://opendata.transport.vic.gov.au/dataset/gtfs-realtime
- **Brisbane:** https://gtfsrt.api.translink.com.au/

### Tools & Libraries

**iOS:**
- GRDB.swift: https://github.com/groue/GRDB.swift
- SQLite.swift: https://github.com/stephencelis/SQLite.swift

**GTFS Tools:**
- node-gtfs: https://github.com/BlinkTagInc/node-gtfs
- gtfs-to-sqlite: https://github.com/aytee17/gtfs-to-sqlite
- gtfs-validator: https://github.com/MobilityData/gtfs-validator

**Routing:**
- OpenTripPlanner: https://www.opentripplanner.org/
- Trip-Based Routing: https://github.com/mk-fg/trip-based-public-transit-routing-algo

### Documentation

- GTFS Specification: https://gtfs.org/
- GTFS Realtime: https://developers.google.com/transit/gtfs-realtime
- GTFS Best Practices: https://gtfs.org/best-practices/
- SQLite R-Tree: https://www.sqlite.org/rtree.html
- iOS Background Assets: https://developer.apple.com/documentation/backgroundassets

### Research Papers

- "Trip-Based Public Transit Routing" (2015): arXiv:1504.07149v2
- "GTFS-enabled dynamic transit accessibility analysis" (2017): PLOS ONE

---

## Summary: Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Storage Technology** | Direct SQLite (via GRDB.swift) | Best performance, native GTFS fit, R-Tree support |
| **Total Storage** | ~800-900 MB (3 cities) | Acceptable on modern iOS devices (64 GB+) |
| **Update Strategy** | Weekly full replacement | Simpler than differential, aligns with agency schedules |
| **Update Mechanism** | Background Assets framework | System-managed, reliable, WiFi-aware |
| **Schema Design** | Hybrid (normalized + denormalized) | Balance integrity and query performance |
| **Geospatial** | R-Tree indexes | 2-5x faster nearby stops queries |
| **Real-Time Cache** | 24-hour rolling cache | Offline resilience, graceful degradation |
| **Compression** | gzip for download, uncompressed DB | Simple, fast, native support |
| **Trip Planning** | Pre-computed transfer graph | Offline routing without complex algorithms |
| **User Storage Mgmt** | Per-city download, Low Storage Mode | User control, flexibility |

**Next Steps:**
1. Validate assumptions with prototype (Sydney only)
2. Benchmark query performance on target devices
3. User test storage requirements (acceptance)
4. Begin Phase 1 implementation
# Transit Routing Solutions Analysis

## Executive Summary

**Recommendation: Hybrid Approach - Cloud API Primary + Local Caching**

For Australian multi-modal transit app, use official state-based APIs (NSW, VIC, QLD) with intelligent local caching, avoiding custom routing engine deployment.

**Why:**
- State APIs provide accurate, real-time data with official integration
- No server infrastructure/maintenance burden
- 60K daily calls free (NSW Bronze) supports ~2K-3K active users
- Build custom routing = 6-12 months + ongoing maintenance vs weeks for API integration
- On-device routing infeasible (memory, battery, complexity)
- OTP server deployment requires 10-100GB RAM + Java infrastructure

**Risk Mitigation:**
- Implement aggressive local schedule caching (Transit app approach: compress GTFS to kilobytes)
- Pre-calculate common routes/transfer times
- Graceful degradation to offline schedule-based routing
- Multi-state support requires integration with 3+ different APIs

---

## 1. OpenTripPlanner (OTP)

### Architecture Overview

**Core Technology:**
- Java-based server application requiring JVM
- Client-server model exposing REST + GraphQL APIs
- OTP2 (current version) under active development since 2018
- **Cannot run on iOS device - server-side only**

**Deployment Model:**
```
iOS App → HTTP/GraphQL → OTP Server → GTFS + OSM data
         ↑                ↑             ↑
      OTPKit           Java VM      In-memory graph
```

### iOS Integration Approaches

**1. OTPKit (Swift Client Library)**
- Developed in Google Summer of Code 2024
- Swift Package Manager support
- Uses OTP 1.x REST API (OTP 2.x uses GraphQL)
- Client-only - still requires separate OTP server

**2. Direct API Integration**
- Make HTTP requests to self-hosted or third-party OTP instance
- GraphQL API for OTP2 (recommended)
- REST API for OTP1 (legacy)

**3. No On-Device Option**
- OTP fundamentally requires server deployment
- Memory-intensive in-memory graph structure
- Java runtime requirement incompatible with iOS

### Performance Characteristics

**Memory Requirements:**
- Depends on geographic coverage + data density
- Small city (Portland): >1GB RAM
- Finland: 12GB RAM
- Germany: 95GB RAM
- Australia states likely 5-20GB each

**CPU Requirements:**
- Single-thread performance critical for query latency
- Benefits from large CPU cache
- Multi-core scaling for concurrent requests
- Graph building requires significantly more resources than serving

**Query Performance:**
- Millisecond-range responses for typical queries
- OTP2 uses RAPTOR-based algorithm (see Algorithm Comparison)
- 10x faster than previous approaches on complex networks (London benchmark)

**Scalability:**
- Digitransit Finland uses 20+ OTP instances for capital area
- Load balancing needed for high traffic
- Build graph on powerful machine, deploy to smaller servers

### Pros

1. **Transit-Specialized**
   - Purpose-built for public transit routing
   - Excellent multi-modal support (walk/bike/transit)
   - Time-dependent routing (arrive-by, depart-at)

2. **Rich Feature Set**
   - Alternative route generation
   - Transfer optimization
   - Accessibility routing
   - Real-time GTFS-RT integration

3. **Active Community**
   - 16+ years development
   - International collaboration
   - Regular releases (v2.5.0 March 2024)
   - Active GitHub (frequent commits)

4. **Data Integration**
   - Native GTFS support
   - OpenStreetMap for walking/biking
   - GTFS Realtime for live updates
   - Elevation data support

5. **Production-Ready**
   - Used by major transit agencies globally
   - Mature codebase
   - Well-documented APIs
   - Comprehensive developer guides

### Cons

1. **Infrastructure Burden**
   - Requires dedicated server(s)
   - 10-100GB RAM for Australian coverage
   - Java runtime environment
   - DevOps expertise needed

2. **Operational Complexity**
   - Graph rebuilding for data updates
   - Load balancing for scale
   - Monitoring and maintenance
   - Server hosting costs ($50-500+/month)

3. **iOS Deployment Challenge**
   - Cannot run on device
   - Requires separate backend infrastructure
   - Network dependency for all queries
   - Latency from client-server architecture

4. **Data Management**
   - Manual GTFS feed updates
   - OSM data synchronization
   - Build process time-consuming
   - Testing graph updates

5. **Resource Intensive**
   - High memory consumption
   - CPU for graph building
   - Storage for graph files
   - Bandwidth for API traffic

### Maintenance Burden

**Ongoing Tasks:**
- Weekly/monthly GTFS feed updates
- OSM data refreshes
- Server monitoring and scaling
- Security patches for Java/dependencies
- API version management
- Graph rebuild testing

**Estimated Effort:**
- Initial setup: 2-4 weeks
- Monthly maintenance: 5-10 hours
- Requires DevOps + backend developer skills

### Community Support

**Strong Points:**
- Active mailing list and forums
- GitHub discussions and issues
- International contributor base
- Commercial support available (Conveyal, etc.)

**Documentation:**
- Comprehensive official docs
- Deployment guides
- API references
- Community tutorials

### License

**LGPL (Lesser General Public License)**

**Commercial Use: ALLOWED**
- Can use in commercial apps without open-sourcing your app
- Must allow users to replace/modify LGPL components
- Modifications to OTP itself must be open-sourced
- Dynamic linking permitted
- No restrictions on proprietary code using OTP APIs

**Implications:**
- ✅ Safe for commercial iOS app
- ✅ No revenue sharing or licensing fees
- ⚠️ Must disclose OTP usage
- ⚠️ Users must be able to point app to different OTP server

### Can It Run on iOS Device?

**NO - Server-Side Only**

**Technical Reasons:**
1. Java runtime requirement (not native iOS)
2. Memory footprint (10-100GB for graph)
3. Graph building process (hours, CPU-intensive)
4. Architecture designed for server deployment

**iOS Integration Pattern:**
```
┌─────────────┐
│  iOS App    │
│             │
│  OTPKit     │ ← Swift client library
│             │
└──────┬──────┘
       │ HTTPS
       ↓
┌─────────────┐
│ OTP Server  │
│   (Linux)   │ ← Must be separate server
│             │
│  Java VM    │
│  10-100GB   │
└─────────────┘
```

---

## 2. Alternative Routing Engines

### R5 (Conveyal)

**Overview:**
- Developed by Conveyal (same team that influenced OTP2)
- Specialized for accessibility analysis
- RAPTOR-based routing

**Strengths:**
- Faster than OTP1 for many-to-many queries
- Excellent for research and analysis
- Influenced OTP2 development

**Weaknesses:**
- Focus on analysis over passenger services
- Point-to-point routing "second-class feature"
- Less suitable for production transit apps

**Verdict:** ❌ Not recommended for passenger-facing app

---

### GraphHopper

**Overview:**
- General-purpose routing engine
- GTFS support available
- Java-based, similar to OTP

**Transit Support:**
- "Simulates" multi-modal by finding fastest route, least transfers, walk-only
- Not specialized for transit (unlike OTP)
- GTFS import supported but less mature

**iOS Support:**
- iOS fork exists with demo
- Primarily server-side like OTP
- Offline Android demo available
- iOS GTFS routing documentation sparse

**Performance:**
- Fast for car/bike routing
- Lower memory than OTP for road networks
- Transit routing less optimized

**Verdict:** ⚠️ Consider only if need car routing integration; otherwise OTP superior for transit

---

### Valhalla (Mapzen/Linux Foundation)

**Overview:**
- C++ open-source routing engine
- Used by Tesla for in-car navigation
- Multi-modal support

**Transit/GTFS Support:**
- Optional GTFS feeds
- Transit support "vestigial" until recently
- Now in beta (merged to master)
- Less mature than OTP for transit

**iOS Compatibility:**
- ✅ Written in C++ (can compile for iOS)
- ✅ Used in embedded systems
- ⚠️ Transit routing still beta
- Memory footprint unclear for transit

**Strengths:**
- Lower runtime requirements than OTP
- Flexible cost functions
- Could potentially run on-device

**Weaknesses:**
- Transit routing immature
- Limited GTFS-RT support
- Smaller transit community

**Verdict:** ⚠️ Interesting for future if transit support matures; currently OTP more proven

---

### Feature Comparison Matrix

| Feature | OTP | R5 | GraphHopper | Valhalla |
|---------|-----|----|----|----------|
| **Primary Use** | Passenger routing | Analysis | General routing | Multi-purpose |
| **Transit Focus** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| **GTFS Support** | Native, mature | Native, mature | Supported | Beta |
| **GTFS-RT Support** | Excellent | Good | Limited | Limited |
| **Multi-modal** | Walk/bike/transit | Walk/bike/transit | Car/bike/transit | Car/bike/transit |
| **iOS Client Library** | OTPKit (Swift) | None | Limited | Possible (C++) |
| **On-Device Routing** | ❌ Java, high RAM | ❌ Java, high RAM | ❌ Java, high RAM | ⚠️ Maybe (C++, beta) |
| **Memory (AU coverage)** | 10-50GB | Similar | 5-30GB | Unknown |
| **Community (Transit)** | Large | Medium | Small | Small |
| **License** | LGPL | MIT | Apache 2.0 | MIT |
| **Production Ready** | ✅ | Research/Analysis | ⚠️ For transit | ⚠️ For transit |

---

## 3. Cloud Routing APIs

### Transport NSW Trip Planner API

**Coverage:** Sydney, NSW regional

**Authentication:**
- API key via HTTP header
- Free Bronze Plan: 60,000 calls/day, 5/second rate limit
- No paid tiers mentioned

**Endpoints:**
1. Stop Finder
2. Trip Planner
3. Departures
4. Service Alerts
5. Coordinate Request

**Data Quality:**
- ✅ Official TfNSW data
- ✅ Real-time integration
- ✅ Service alerts included
- ✅ All modes (train/bus/ferry/light rail/metro)

**Pros:**
- Free for reasonable usage
- Official, accurate data
- No infrastructure to manage
- Real-time built-in
- Maintained by transport authority

**Cons:**
- Sydney/NSW only
- Rate limits (5/sec may be tight for burst traffic)
- Vendor lock-in
- No offline capability
- API changes outside your control

**Estimated Costs:**
- Free up to 60K/day = ~2-3K active daily users
- Beyond that: pricing unclear (likely need enterprise agreement)

---

### PTV Timetable API (Victoria)

**Coverage:** Melbourne, Victoria statewide

**API Type:**
- ⚠️ **Raw data access, NOT journey planner**
- Provides stops, lines, disruptions, timetables
- Real-time data included
- **Does NOT provide trip routing**

**GTFS Alternative:**
- Static GTFS dumps available on DataVic
- Can feed GTFS into OTP or build custom routing

**Journey Planner:**
- Web journey planner exists
- Uses business rules (e.g., 30min early for regional trains)
- API doesn't replicate these rules

**Verdict:**
- ⚠️ Need to build routing logic yourself OR use GTFS with OTP
- Not direct trip planning API like NSW

---

### TransLink Queensland (Brisbane)

**Coverage:** Brisbane, SEQ, regional Queensland

**API Type:**
- ⚠️ **GTFS feeds only, no trip planning API**
- GTFS Static + GTFS Realtime
- Available via Queensland Open Data Portal

**Access:**
- Join TransLink Australia Google Group
- Read terms and conditions
- Download GTFS from gtfsrt.api.translink.com.au

**Data Format:**
- GTFS Static: ZIP file
- GTFS Realtime: Protocol Buffers

**Verdict:**
- ❌ No ready-made trip planning API
- Must use GTFS with OTP or build own routing

---

### Cloud API Comparison

| Provider | Type | Coverage | Cost | Real-Time | Routing |
|----------|------|----------|------|-----------|---------|
| **TfNSW** | Trip Planner API | NSW | Free 60K/day | ✅ | ✅ Built-in |
| **PTV** | Timetable API | VIC | Free | ✅ | ❌ Raw data only |
| **TransLink** | GTFS Feeds | QLD | Free | ✅ RT feeds | ❌ GTFS only |

**Key Insight:**
- Only NSW provides ready-made routing API
- VIC + QLD require building routing layer (OTP or custom)

---

## 4. On-Device Routing

### Feasibility Assessment

**Technical Requirements:**

1. **Memory:**
   - Full GTFS graph: hundreds of MB uncompressed
   - Transit app achieved compression to ~100s of KB per city
   - Requires aggressive optimization

2. **CPU/Battery:**
   - Routing computation drains battery quickly
   - Mobile CPU 12x faster in 2000-2012, battery capacity 2x
   - Energy-aware offloading reduces consumption by 55%
   - Complex routing = battery drain

3. **Algorithm Complexity:**
   - Multi-modal routing computationally expensive
   - Time-dependent (schedules) adds complexity
   - Real-time updates require continuous processing

### Implementation Complexity

**From Scratch: VERY HIGH**

Core components needed:
1. GTFS parser and data structures
2. Graph building (stops, routes, transfers)
3. Routing algorithm (RAPTOR or CSA)
4. Walking/biking integration (need map data)
5. Real-time update handling
6. UI for route display

**Estimated Timeline:**
- Experienced team: 6-12 months
- Features comparable to OTP: 12-18 months
- Ongoing maintenance: indefinite

**Skills Required:**
- Algorithm expertise (transit routing specific)
- Mobile optimization (memory, battery)
- GTFS specification deep knowledge
- Real-time data integration
- iOS development

### Real-Time Integration Challenges

**GTFS Realtime Complexity:**
- Protocol Buffers parsing
- StopTimeUpdate processing
- Trip cancellations/modifications
- Vehicle position tracking
- Service alerts correlation

**Update Frequency:**
- Real-time feeds update every 1-30 seconds
- Battery impact of continuous polling
- Network data usage
- Cache invalidation

### Offline Routing Capabilities

**Success Stories:**

**Transit App (2019):**
- Compressed schedule data from 100s MB → 100s KB
- Pattern recognition (e.g., every 10 min)
- Pre-calculated transfer times
- Automatic cloud download + cache
- Online: real-time data; Offline: schedules
- Routing in milliseconds on-device

**Transito (Open Source):**
- Downloads GTFS feeds (~1500 available)
- On-device route calculation
- Fully offline after download

**Implementation Pattern:**
```
1. Compress GTFS (pattern recognition, delta encoding)
2. Download compressed data on WiFi
3. Build lightweight in-memory graph
4. Use efficient algorithm (RAPTOR)
5. Pre-calculate common transfers
6. Graceful degradation (online → offline)
```

**Feasibility:** ⚠️ **Possible but HIGH effort**
- Transit app: well-funded team, years of development
- Requires specialized expertise
- Ongoing maintenance as GTFS data changes

### Performance Requirements

**Acceptable Response Times:**
- Single route query: <1 second
- Multiple alternatives: <3 seconds
- Longer delays acceptable for complex multi-modal

**Battery Impact:**
- Routing computation: moderate
- Continuous GPS: high
- Network requests: moderate
- Screen-on time: high

**Memory Budget (iOS):**
- Background apps: ~50MB before termination
- Active app: depends on device (1-4GB available)
- GTFS data: must fit in reasonable footprint

### Verdict

**On-Device Routing:**
- ✅ **Technically possible** (Transit app proves it)
- ❌ **NOT recommended for MVP** (6-12 month effort)
- ⚠️ **Consider for V2** if business justifies investment

**Better Approach:**
- Start with cloud APIs
- Implement caching layer
- Add offline schedule browsing
- Evaluate on-device routing later based on traction

---

## 5. Hybrid Approaches

### Server-Side Routing + Local Caching

**Architecture:**
```
┌─────────────────────┐
│     iOS App         │
│                     │
│ ┌─────────────────┐ │
│ │ Cache Layer     │ │ ← Compressed schedules
│ │ - Schedules     │ │ ← Pre-calculated routes
│ │ - Common routes │ │ ← Transfer times
│ │ - Stops/lines   │ │
│ └─────────────────┘ │
│         ↕           │
│ ┌─────────────────┐ │
│ │ API Client      │ │
│ └─────────────────┘ │
└──────────┬──────────┘
           │ HTTPS
           ↓
┌──────────────────────┐
│ Cloud Routing APIs   │
│ - TfNSW (NSW)        │
│ - PTV + OTP (VIC)    │
│ - GTFS + OTP (QLD)   │
└──────────────────────┘
```

**Implementation:**

1. **Primary Path (Online):**
   - User requests route
   - Check cache for recent identical query
   - If miss: API call to appropriate state endpoint
   - Cache result + schedule data
   - Return to user

2. **Secondary Path (Degraded):**
   - User requests route, no network
   - Use cached schedules
   - Calculate route with simplified algorithm
   - Show "schedule-based, not real-time" warning
   - Still useful for planning

3. **Background Optimization:**
   - Pre-calculate popular routes (home→work, etc.)
   - Download compressed GTFS on WiFi
   - Update cache nightly
   - Clear stale data

**Caching Strategy (Transit App Model):**

```swift
// Pseudo-code
struct ScheduleCache {
    // Compress using pattern recognition
    func compress(gtfs: GTFS) -> CompressedSchedule {
        // "Every 10 minutes" → single rule
        // "Weekday vs weekend" → two patterns
        // Result: 100s MB → 100s KB
    }

    // Pre-calculate transfers
    func preCalculateTransfers(stops: [Stop]) -> TransferTimes {
        // Walking time between nearby stops
        // Stored locally for instant access
    }

    // Offline routing (simplified)
    func offlineRoute(from: Location, to: Location) -> [Trip] {
        // Use cached schedules (no real-time)
        // Fast RAPTOR or CSA variant
        // Return multiple options
    }
}
```

**Benefits:**
- ✅ Fast response (cache hits)
- ✅ Works offline (degraded)
- ✅ Reduces API calls (cost/rate limits)
- ✅ Better user experience
- ✅ Lower battery drain

**Complexity:**
- Medium effort (2-4 weeks)
- Cache invalidation logic
- Compression algorithms
- Offline routing implementation

---

### Fallback Strategies

**Tiered Approach:**

**Tier 1: Real-Time API (Best Quality)**
- Use state-specific APIs when online
- Real-time delays, cancellations
- Service alerts
- Most accurate

**Tier 2: Cached Recent Results (Fast)**
- Identical query within X hours
- Show cached result immediately
- Background refresh if online
- "Last updated: 10 minutes ago"

**Tier 3: Offline Schedule-Based (Basic)**
- Use compressed local GTFS
- Schedule-only (no real-time)
- Simple routing algorithm
- "Schedule-based estimate" warning

**Tier 4: Degraded Information (Fallback)**
- Show stop schedules
- Next departures (from cached timetables)
- No routing, just browse
- "Limited info - check online"

**Implementation:**
```swift
func requestRoute(from: Location, to: Location) async -> Result<Route> {
    // Tier 1: Try real-time API
    if networkAvailable {
        if let route = try? await apiClient.getRoute(from, to) {
            cache.store(route)
            return .success(route)
        }
    }

    // Tier 2: Check cache
    if let cached = cache.get(from, to, maxAge: .hours(2)) {
        return .success(cached.withStalenessWarning())
    }

    // Tier 3: Offline routing
    if let offline = offlineRouter.calculate(from, to) {
        return .success(offline.withOfflineWarning())
    }

    // Tier 4: Degraded
    return .failure(.showSchedulesOnly)
}
```

---

### Best of Both Worlds

**Recommended Hybrid Architecture:**

**Phase 1 (MVP - 4-6 weeks):**
1. Integrate TfNSW API for NSW routing
2. Basic cache layer (identical query cache)
3. Error handling and offline message
4. PTV + TransLink GTFS display (no routing yet)

**Phase 2 (3-6 months):**
1. Deploy OTP server for VIC + QLD
2. Implement GTFS compression + caching
3. Pre-calculate common transfers
4. Background data updates

**Phase 3 (6-12 months):**
1. Simple offline routing (schedule-based)
2. Route prediction (ML for common patterns)
3. Advanced caching strategies
4. Performance optimization

**Cost Estimate:**
- Phase 1: API calls free, development time only
- Phase 2: $50-200/month OTP servers
- Phase 3: No additional server costs

**Development Effort:**
- Phase 1: 1 developer, 4-6 weeks
- Phase 2: 1-2 developers, 3-6 months
- Phase 3: 1 developer, 6-12 months

**Benefits:**
- ✅ Fast time-to-market (Phase 1)
- ✅ Incremental investment
- ✅ Validate market before heavy build
- ✅ Leverage official APIs where available
- ✅ Build expertise gradually

---

## 6. Routing Requirements Analysis

### Multi-Modal Routing

**Modes Required:**
1. **Walking**
   - First/last mile
   - Transfers between stops
   - Walking-only option

2. **Bus**
   - Local routes
   - Express services
   - School buses (optional)

3. **Train**
   - Suburban rail
   - Metro
   - Regional trains

4. **Ferry**
   - Harbor services
   - River ferries

5. **Light Rail**
   - Trams (Melbourne)
   - Light rail (Sydney, Gold Coast)

6. **Future Considerations**
   - Bike/e-scooter integration
   - Ride-share integration
   - Car parks at stations

**Complexity:**
- Transfer rules between modes
- Different fare structures
- Mode preferences (avoid ferries, etc.)
- Walking distance limits

---

### Real-Time Awareness

**Data Sources:**

1. **GTFS Realtime (TripUpdates):**
   - Delays (early/late)
   - Cancellations
   - Schedule changes
   - Stop sequence modifications

2. **GTFS Realtime (ServiceAlerts):**
   - Disruptions
   - Planned work
   - Special events
   - Station closures

3. **GTFS Realtime (VehiclePositions):**
   - Live vehicle tracking
   - Crowding information
   - Real-time arrival predictions

**Integration Requirements:**
- Poll/stream GTFS-RT feeds (1-30 sec refresh)
- Parse Protocol Buffers
- Merge with static GTFS
- Update routes in real-time
- Handle conflicts (static vs realtime)

**Complexity:**
- ⭐⭐⭐⭐ High
- OTP handles this well
- Custom implementation: significant effort
- NSW API includes real-time automatically

---

### Time-Dependent Routing

**Query Types:**

1. **Leave Now**
   - Most common
   - Current time departure
   - Real-time aware

2. **Depart At**
   - User specifies departure time
   - Future planning
   - Use scheduled data (no real-time for future)

3. **Arrive By**
   - Reverse search
   - Work backwards from arrival time
   - More complex algorithm

**Algorithm Implications:**
- Time-dependent graph search
- Schedule-aware routing
- Different options for different times
- Frequency-based vs schedule-based routes

**Complexity:**
- RAPTOR algorithm handles this natively
- Core requirement for transit routing
- All serious engines support this

---

### User Preferences

**Common Preferences:**

1. **Fastest** (minimize total time)
2. **Least Walking** (minimize walk distance)
3. **Least Transfers** (minimize changes)
4. **Accessible** (wheelchair, elevator-only)
5. **Cheapest** (minimize fare)

**Advanced Preferences:**
- Prefer specific modes
- Avoid specific lines/stops
- Maximum walking distance
- Prefer express services
- Minimize waiting time

**Implementation:**
- Multi-objective optimization
- Pareto-optimal routes
- Weighting system
- RAPTOR supports multi-criteria

**Complexity:**
- ⭐⭐⭐ Medium-High
- OTP has extensive preference support
- Custom implementation: weeks of work

---

### Alternative Routes

**Requirements:**
- Show 2-5 different route options
- Different trade-offs (fast vs fewer changes)
- Different departure times
- Different mode combinations

**Algorithm Approach:**
- RAPTOR naturally generates alternatives (rounds = transfers)
- Pareto-optimal set
- Avoid dominated solutions

**UX Considerations:**
- Sort by preference
- Highlight differences
- Update alternatives when one delayed

**Complexity:**
- ⭐⭐⭐ Medium
- Core feature of transit routing
- OTP provides this out-of-box

---

### Connection Intelligence

**Advanced Features:**

1. **Guaranteed Connections**
   - Train waits for connecting bus
   - Official timetabled connections

2. **Realistic Transfers**
   - Walking time between platforms
   - Accessibility considerations
   - Buffer time (don't miss connection)

3. **Disruption Handling**
   - Reroute when service cancelled
   - Alternative if connection missed
   - Proactive notifications

4. **Pattern Recognition**
   - Learn common user routes
   - Suggest based on location/time
   - Predictive departure board

**Data Requirements:**
- Transfer times (GTFS transfers.txt)
- Station layouts
- Real-time positions
- Historical reliability

**Complexity:**
- ⭐⭐⭐⭐⭐ Very High
- Requires ML + historical data
- OTP has basic transfer support
- Advanced features need custom development

---

### Requirements Complexity Matrix

| Feature | Priority | Complexity | OTP Support | Cloud API | Build Effort |
|---------|----------|------------|-------------|-----------|--------------|
| Multi-modal | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ Full | ✅ NSW, ⚠️ VIC/QLD | 3-6 months |
| Real-time | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ GTFS-RT | ✅ NSW, ⚠️ VIC/QLD | 2-4 months |
| Time-dependent | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ Native | ✅ All | 2-3 months |
| Preferences | ⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ Extensive | ⚠️ Limited | 1-2 months |
| Alternatives | ⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ Pareto | ✅ NSW | 2-3 weeks |
| Connections | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⚠️ Basic | ❌ | 3-6 months |

**Total Build Effort (All Features from Scratch):**
- **12-18 months** with experienced team
- Ongoing maintenance indefinitely

---

## 7. Build vs Buy Decision Framework

### Complexity Assessment

**Build Custom Routing Engine:**
- Complexity: ⭐⭐⭐⭐⭐ (5/5)
- Specialized domain knowledge required
- Numerous edge cases
- Continuous GTFS spec updates
- Real-time integration challenges

**Integrate OTP:**
- Complexity: ⭐⭐⭐ (3/5)
- DevOps setup
- Server management
- API integration
- Data pipeline setup

**Use Cloud APIs:**
- Complexity: ⭐ (1/5)
- Simple HTTP requests
- Handle rate limits
- Multi-state coordination

**Hybrid (APIs + Caching):**
- Complexity: ⭐⭐ (2/5)
- API integration
- Cache implementation
- Offline logic
- Data compression

---

### Development Time Estimates

**Option 1: Build from Scratch**
- Algorithm implementation: 3-4 months
- GTFS integration: 2-3 months
- Multi-modal logic: 2-3 months
- Real-time support: 2-3 months
- UI/UX integration: 1-2 months
- Testing and debugging: 2-3 months
- **Total: 12-18 months (2-3 developers)**

**Option 2: OTP Integration**
- Server setup and configuration: 1-2 weeks
- GTFS data pipeline: 1-2 weeks
- iOS client (OTPKit): 2-3 weeks
- Testing and optimization: 2-3 weeks
- **Total: 6-10 weeks (1 developer + DevOps)**

**Option 3: Cloud APIs Only**
- NSW API integration: 1 week
- VIC/QLD basic display: 1 week
- Error handling: 1 week
- UI/UX: 2 weeks
- **Total: 5-6 weeks (1 developer)**

**Option 4: Hybrid (Recommended)**
- API integration (Phase 1): 4-6 weeks
- OTP for VIC/QLD (Phase 2): 6-8 weeks
- Caching layer: 2-3 weeks
- Offline routing (Phase 3): 6-8 weeks
- **Total: 18-25 weeks phased (1-2 developers)**

---

### Maintenance Burden

**Build Custom:**
- Ongoing: ⭐⭐⭐⭐⭐ (Very High)
- Weekly GTFS updates
- Algorithm improvements
- Bug fixes (routing edge cases numerous)
- Real-time feed monitoring
- New features development
- **Estimate: 20-40 hours/month indefinitely**

**OTP Integration:**
- Ongoing: ⭐⭐⭐ (Medium)
- Server monitoring and updates
- GTFS feed refreshes
- OTP version upgrades
- Performance tuning
- **Estimate: 10-15 hours/month**

**Cloud APIs:**
- Ongoing: ⭐ (Low)
- Monitor API status
- Handle API changes (rare)
- Update when spec changes
- **Estimate: 2-5 hours/month**

**Hybrid:**
- Ongoing: ⭐⭐ (Low-Medium)
- API monitoring
- Cache maintenance
- OTP for VIC/QLD (if deployed)
- **Estimate: 5-10 hours/month**

---

### Cost Analysis

#### Option 1: Build from Scratch

**Development Costs:**
- 2 developers × 12 months × $10,000/month = $240,000
- Or contract team: $150,000-300,000

**Ongoing Costs:**
- Maintenance developer: $3,000-5,000/month
- Server hosting (for APIs): $100-500/month
- GTFS data hosting: included
- **Annual: $36,000-60,000 + initial $150K-300K**

**ROI:** Only justified if:
- Building core IP for company
- Very specific requirements unmet by alternatives
- Long-term control critical
- Tens of thousands of users

---

#### Option 2: OTP Integration

**Development Costs:**
- 1 developer × 2.5 months × $10,000/month = $25,000
- DevOps setup: $5,000-10,000
- **Total Initial: $30,000-35,000**

**Ongoing Costs:**
- Server hosting:
  - NSW: 20GB RAM EC2 = $120/month
  - VIC: 30GB RAM EC2 = $180/month
  - QLD: 15GB RAM EC2 = $90/month
  - Total: ~$390/month servers
- Maintenance: $1,000-2,000/month
- Data transfer: $50-100/month
- **Annual: ~$22,000-30,000**

**Scaling Costs:**
- Add load balancers: +$100/month
- Increase instance sizes: +$200-500/month
- CDN for caching: +$50-200/month

---

#### Option 3: Cloud APIs Only

**Development Costs:**
- 1 developer × 1.5 months × $10,000/month = $15,000
- **Total Initial: $15,000**

**Ongoing Costs:**
- NSW API: Free (60K/day)
  - Overage: enterprise pricing (unknown, likely $0.001-0.01/call)
- VIC API: Free (but no routing, display only)
- QLD: Free (GTFS feeds)
- Maintenance: $500-1,000/month
- **Annual: $6,000-12,000**

**Scaling Costs:**
- Hit rate limits:
  - 60K/day ≈ 2-3K active users (20-30 queries/user/day)
  - Beyond: need enterprise tier (negotiate pricing)
  - Estimate: $0.001-0.01 per call = $600-6,000/month for 60K extra/day

**Risk:**
- Rate limits constrain growth
- No control over pricing changes
- VIC/QLD no routing without OTP

---

#### Option 4: Hybrid (Recommended)

**Development Costs:**
- Phase 1 (APIs): $15,000
- Phase 2 (OTP for VIC/QLD): $15,000
- Phase 3 (Caching/offline): $10,000
- **Total Initial: $40,000 (phased)**

**Ongoing Costs:**
- NSW API: Free initially
- OTP servers (VIC/QLD only): $270/month
- Maintenance: $1,000-1,500/month
- **Annual: ~$15,000-20,000**

**Scaling:**
- NSW: hit rate limits → add caching → defer overage
- VIC/QLD: scale OTP servers (+$100-300/month per instance)
- Caching reduces API calls significantly

---

### Cost Comparison Summary

| Option | Initial | Year 1 | Year 2-5/yr | Maintenance Burden |
|--------|---------|--------|-------------|-------------------|
| **Build Custom** | $150-300K | $36-60K | $36-60K | Very High ⭐⭐⭐⭐⭐ |
| **OTP Integration** | $30-35K | $22-30K | $22-30K | Medium ⭐⭐⭐ |
| **Cloud APIs** | $15K | $6-12K | $6-30K* | Low ⭐ |
| **Hybrid** | $40K | $15-20K | $15-25K | Low-Med ⭐⭐ |

*Cloud APIs: cost grows with usage (rate limits)

---

### Control vs Convenience Trade-offs

| Factor | Build | OTP | Cloud API | Hybrid |
|--------|-------|-----|-----------|--------|
| **Time to Market** | 12-18mo | 2-3mo | 1-1.5mo | 1-6mo phased |
| **Control over Routing** | Full | High | None | Medium |
| **Data Freshness** | Manual | Manual | Auto | Auto/Manual |
| **Customization** | Unlimited | Medium | None | Medium |
| **Offline Support** | Possible | Possible | ❌ | ✅ Phase 3 |
| **Real-Time Quality** | Custom | Good | Best (NSW) | Best/Good |
| **Vendor Lock-In** | None | None | High | Medium |
| **Technical Risk** | High | Medium | Low | Low-Med |
| **Innovation Ability** | High | Medium | Low | Medium |
| **Infrastructure Burden** | High | Medium | None | Low-Med |

---

### Recommendation with Rationale

## **RECOMMENDED: Hybrid Approach (Option 4)**

### Why Hybrid Wins

**1. Fast Time-to-Market**
- Phase 1 (NSW API) in 4-6 weeks
- Revenue generation starts quickly
- Validate market before heavy investment

**2. Optimal Cost Structure**
- Initial: $40K (phased, manageable)
- Ongoing: $15-20K/year
- Scales with usage, not upfront

**3. Best Data Quality**
- NSW: official API with real-time
- VIC/QLD: self-hosted OTP (control + quality)
- Avoids VIC/QLD "no routing" problem

**4. Flexibility**
- Start simple, add complexity as needed
- Can pivot based on user feedback
- Not locked into single approach

**5. Risk Mitigation**
- Fallback to offline if APIs fail
- Caching reduces dependency
- Multi-provider (not single point of failure)

**6. Technical Feasibility**
- Proven technologies (APIs + OTP)
- Manageable complexity
- Standard iOS development skills

**7. Future-Proof**
- Can add on-device routing later (Phase 4)
- Easy to integrate new modes (bike-share, etc.)
- ML/prediction layer possible (Phase 5)

---

### Implementation Roadmap

**Phase 1: MVP (Weeks 1-6)**
```
- NSW Trip Planner API integration
- Basic route display
- Simple cache (identical queries)
- VIC/QLD: show stops/schedules (no routing)
- Ship to App Store
```
**Deliverable:** Working app for Sydney users

**Phase 2: National Expansion (Weeks 7-14)**
```
- Deploy OTP servers (VIC + QLD)
- GTFS integration for both states
- GraphQL API client
- Multi-state routing
- Improved caching
```
**Deliverable:** Full Australia coverage

**Phase 3: Offline + Optimization (Weeks 15-26)**
```
- GTFS compression (Transit app model)
- Offline schedule-based routing
- Pre-calculated transfers
- Background data sync
- Performance tuning
```
**Deliverable:** Works without network

**Phase 4: Intelligence (Months 7-12) [Optional]**
```
- ML route prediction
- Historical delay analysis
- Personalized suggestions
- Advanced connection intelligence
```
**Deliverable:** Smart routing

---

### When to Reconsider

**Move to Full OTP** if:
- NSW API becomes paid/expensive
- Need deep customization of routing
- Multi-tenant (white-label) offering

**Move to Build Custom** if:
- Raising significant funding ($1M+)
- Routing is core differentiator
- Very specific unmet needs
- Long-term strategic IP

**Stick with APIs** if:
- Bootstrap/small budget
- NSW-only focus
- Low usage (<1000 DAU)
- Quick validation needed

---

## 8. Routing Algorithms Deep Dive

### RAPTOR (Round-Based Public Transit Optimized Router)

**Overview:**
- Developed by Microsoft Research
- Not Dijkstra-based (novel approach)
- Looks at each route (bus line) at most once per round
- Round = number of transfers

**How It Works:**
```
Round 0: Direct routes from origin
Round 1: Routes reachable with 1 transfer
Round 2: Routes reachable with 2 transfers
...
```

**Advantages:**
- ⭐ 10x faster than Dijkstra approaches (London test)
- ⭐ Naturally generates alternatives (different transfer counts)
- ⭐ Pareto-optimal results
- ⭐ No preprocessing needed (dynamic)
- ⭐ Parallelizable (multi-core)

**Disadvantages:**
- ⚠️ More complex to implement than Dijkstra
- ⚠️ Requires understanding of algorithm paper

**Used By:**
- OpenTripPlanner 2
- R5
- Various research implementations

**Implementation Complexity:**
- From scratch: 2-3 months (experienced developer)
- Many open-source implementations available

---

### CSA (Connection Scan Algorithm)

**Overview:**
- Scan all connections (departures) in chronological order
- Extremely simple concept
- Very fast in practice

**How It Works:**
```
1. Get all connections (departures) sorted by time
2. Scan forward from departure time
3. Mark reachable stops
4. Continue until arrival stop reached
```

**Advantages:**
- ⭐ Very simple to implement
- ⭐ Fast for single queries
- ⭐ Easy to adapt to real-time changes (timetable updates)
- ⭐ Cache-friendly (sequential access)

**Disadvantages:**
- ⚠️ Generates fewer alternatives than RAPTOR
- ⚠️ Can include unnecessary transfers
- ⚠️ Quality slightly lower than RAPTOR

**Used By:**
- Various research projects
- Some smaller routing engines
- Backend for static timetables

**Implementation Complexity:**
- From scratch: 3-6 weeks
- Simpler than RAPTOR

**When to Use:**
- Real-time timetable updates frequent
- Simplicity preferred over result quality
- Single-query optimization

---

### Algorithm Comparison

| Factor | RAPTOR | CSA | Dijkstra (baseline) |
|--------|--------|-----|---------------------|
| **Speed** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **Result Quality** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Alternatives** | ⭐⭐⭐⭐⭐ Natural | ⭐⭐⭐ Adequate | ⭐⭐ Post-process |
| **Implementation** | ⭐⭐⭐ Complex | ⭐⭐⭐⭐ Simple | ⭐⭐⭐⭐⭐ Well-known |
| **Real-Time Adapt** | ⭐⭐⭐ Good | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐ Slow |
| **Memory** | ⭐⭐⭐ Medium | ⭐⭐⭐⭐ Low | ⭐⭐ High |
| **Multi-Criteria** | ⭐⭐⭐⭐⭐ Native | ⭐⭐⭐ Possible | ⭐⭐⭐ Difficult |

---

### Recommendation: RAPTOR

**For Australian Transit App:**
- ✅ Use OTP (has RAPTOR built-in)
- ✅ If building custom: implement RAPTOR
- ⚠️ CSA acceptable for simple use case
- ❌ Avoid Dijkstra (outdated for transit)

**Open-Source RAPTOR Implementations:**
- OTP 2 (Java)
- planarnetwork/raptor (TypeScript)
- transnetlab/transit-routing (Python)

---

## 9. Implementation Patterns

### If Building Custom

**Not Recommended, but if required:**

**Technology Stack:**
```
- Language: Swift (iOS native) or Kotlin (if Android too)
- Data: SQLite for GTFS storage
- Algorithm: RAPTOR (from paper + open-source reference)
- Real-time: GTFS-RT parsing (Protocol Buffers)
- Maps: MapKit or Mapbox
```

**Architecture:**
```
┌─────────────────────────────────┐
│         iOS App                 │
│                                 │
│  ┌──────────────────────────┐   │
│  │  UI Layer                │   │
│  │  - Map view              │   │
│  │  - Route list            │   │
│  │  - Stop search           │   │
│  └──────────────────────────┘   │
│            ↕                     │
│  ┌──────────────────────────┐   │
│  │  Routing Engine          │   │
│  │  - RAPTOR implementation │   │
│  │  - Multi-modal logic     │   │
│  │  - Preference handling   │   │
│  └──────────────────────────┘   │
│            ↕                     │
│  ┌──────────────────────────┐   │
│  │  Data Layer              │   │
│  │  - GTFS SQLite           │   │
│  │  - GTFS-RT parser        │   │
│  │  - OSM data (walking)    │   │
│  └──────────────────────────┘   │
│            ↕                     │
│  ┌──────────────────────────┐   │
│  │  Network Layer           │   │
│  │  - GTFS feed downloader  │   │
│  │  - GTFS-RT poller        │   │
│  └──────────────────────────┘   │
└─────────────────────────────────┘
```

**Development Phases:**

1. **Data Foundation (4-6 weeks)**
   - GTFS parser (stops, routes, trips, stop_times, calendar)
   - SQLite schema design
   - GTFS-RT Protocol Buffer parser
   - Unit tests

2. **Core Routing (8-12 weeks)**
   - RAPTOR algorithm implementation
   - Transfer handling
   - Walking integration
   - Time-dependent logic
   - Extensive testing

3. **Multi-Modal (4-6 weeks)**
   - Mode filtering
   - Preference weighting
   - Pareto-optimal filtering
   - Alternative generation

4. **Real-Time (4-6 weeks)**
   - GTFS-RT integration
   - Trip update handling
   - Service alerts
   - Vehicle positions
   - Cache invalidation

5. **UI/UX (4-6 weeks)**
   - Route display
   - Map integration
   - Search interface
   - Accessibility

6. **Testing & Optimization (4-8 weeks)**
   - Edge case testing
   - Performance optimization
   - Memory profiling
   - Battery testing

**Total: 28-44 weeks (7-11 months)**

**Risks:**
- Underestimated complexity (common in routing projects)
- GTFS edge cases (numerous)
- Real-time integration challenges
- Testing coverage (combinatorial explosion)

---

### If Integrating OTP

**Recommended if not using NSW API:**

**Deployment Architecture:**

```
┌─────────────────┐
│  iOS App        │
│                 │
│  OTPKit Client  │
│  (Swift)        │
└────────┬────────┘
         │ HTTPS (GraphQL)
         ↓
┌─────────────────────────────────┐
│   AWS/Digital Ocean/GCP         │
│                                 │
│  ┌───────────────────────────┐  │
│  │  Load Balancer (optional) │  │
│  └─────────────┬─────────────┘  │
│                ↓                 │
│  ┌───────────────────────────┐  │
│  │  OTP Instance 1 (NSW)     │  │
│  │  - 20GB RAM               │  │
│  │  - 4 vCPU                 │  │
│  │  - Java 11+               │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │  OTP Instance 2 (VIC)     │  │
│  │  - 30GB RAM               │  │
│  │  - 4 vCPU                 │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │  OTP Instance 3 (QLD)     │  │
│  │  - 15GB RAM               │  │
│  │  - 4 vCPU                 │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │  Build Server             │  │
│  │  - 64GB RAM (temp)        │  │
│  │  - GTFS feed downloader   │  │
│  │  - Graph builder          │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

**Setup Steps:**

**1. Server Provisioning (Week 1)**
```bash
# Example AWS EC2 instances
# NSW: t3.2xlarge (32GB RAM) or r6i.xlarge (32GB)
# VIC: r6i.xlarge (32GB) or r6i.2xlarge (64GB)
# QLD: t3.xlarge (16GB) or r6i.large (16GB)

# Install Java
sudo apt update
sudo apt install openjdk-11-jdk

# Download OTP
wget https://repo1.maven.org/maven2/org/opentripplanner/otp/2.5.0/otp-2.5.0-shaded.jar
```

**2. GTFS Data Pipeline (Week 1-2)**
```bash
# Automated script
#!/bin/bash

# Download GTFS feeds
wget https://api.transport.nsw.gov.au/v1/gtfs/schedule/sydneytrains -O nsw-trains.zip
wget https://api.transport.nsw.gov.au/v1/gtfs/schedule/buses/sydneybuses -O nsw-buses.zip
# ... more feeds

wget http://data.vic.gov.au/.../gtfs.zip -O vic.zip
wget https://gtfsrt.api.translink.com.au/GTFS/SEQ_GTFS.zip -O qld.zip

# Download OSM (OpenStreetMap)
wget https://download.geofabrik.de/australia-oceania/australia-latest.osm.pbf

# Extract regions (osmium tool)
osmium extract -b 150.5,-34.0,151.5,-33.5 australia-latest.osm.pbf -o nsw.osm.pbf
```

**3. Graph Building (Week 2)**
```bash
# Build graph (takes 1-6 hours depending on size)
java -Xmx30G -jar otp-2.5.0-shaded.jar --build --save /path/to/graphs/nsw

# Directory structure
/var/otp/graphs/nsw/
  ├── graph.obj          # Built graph
  ├── nsw-trains.zip     # GTFS feeds
  ├── nsw-buses.zip
  ├── nsw.osm.pbf        # OSM data
  └── router-config.json # Configuration
```

**4. Configuration (Week 2)**
```json
// router-config.json
{
  "routingDefaults": {
    "walkSpeed": 1.3,
    "bikeSpeed": 5.0,
    "maxWalkDistance": 2000,
    "maxTransfers": 4,
    "waitReluctance": 0.95,
    "walkReluctance": 2.0
  },
  "transit": {
    "maxNumberOfTransfers": 12
  },
  "updaters": [
    {
      "type": "real-time-alerts",
      "url": "https://api.transport.nsw.gov.au/v2/gtfs/alerts/sydneytrains",
      "feedId": "nsw-trains"
    },
    {
      "type": "stop-time-updater",
      "url": "https://api.transport.nsw.gov.au/v2/gtfs/vehiclepos/sydneytrains",
      "feedId": "nsw-trains"
    }
  ]
}
```

**5. Server Deployment (Week 3)**
```bash
# Systemd service
# /etc/systemd/system/otp-nsw.service

[Unit]
Description=OpenTripPlanner NSW
After=network.target

[Service]
Type=simple
User=otp
WorkingDirectory=/var/otp
ExecStart=/usr/bin/java -Xmx28G -jar /var/otp/otp-2.5.0-shaded.jar --load /var/otp/graphs/nsw --port 8080
Restart=always

[Install]
WantedBy=multi-user.target

# Enable and start
sudo systemctl enable otp-nsw
sudo systemctl start otp-nsw
```

**6. iOS Client Integration (Week 3-4)**
```swift
// Using OTPKit
import OTPKit

let otpClient = OTPClient(baseURL: "https://otp-nsw.yourdomain.com")

// GraphQL query
let query = """
{
  plan(
    from: {lat: -33.8688, lon: 151.2093}
    to: {lat: -33.8915, lon: 151.2767}
    date: "2025-10-30"
    time: "09:00:00"
    numItineraries: 3
  ) {
    itineraries {
      duration
      legs {
        mode
        route
        from { name }
        to { name }
        startTime
        endTime
      }
    }
  }
}
"""

otpClient.query(query) { result in
    switch result {
    case .success(let routes):
        // Display routes
    case .failure(let error):
        // Handle error
    }
}
```

**7. Monitoring & Maintenance (Ongoing)**
```bash
# Automated GTFS updates (cron)
0 2 * * * /var/otp/scripts/update-gtfs.sh

# Health check
curl http://localhost:8080/otp/actuators/health

# Logs
journalctl -u otp-nsw -f

# Metrics (Prometheus)
http://localhost:8080/otp/actuators/prometheus
```

**Cost Estimate (AWS us-east-1):**
- r6i.2xlarge (64GB) × 3 = $1.01/hr × 3 × 730hrs = ~$2,200/month
- Cheaper: t3.2xlarge (32GB) × 3 = ~$900/month
- Build server (spot): ~$50/month
- Data transfer: ~$50/month
- **Total: $1,000-2,300/month** (can optimize)

**Optimization:**
- Use smaller instances (r6i.xlarge 32GB = $300/mo each)
- Single instance for VIC+QLD combined
- Reserved instances (40% discount)
- **Optimized: $400-600/month**

---

### If Using Cloud APIs

**Recommended for MVP:**

**Architecture:**

```
┌─────────────────────────────────┐
│         iOS App                 │
│                                 │
│  ┌──────────────────────────┐   │
│  │  API Clients             │   │
│  │                          │   │
│  │  ┌────────────────────┐  │   │
│  │  │ NSW API Client     │  │   │
│  │  │ - Trip planning    │  │   │
│  │  │ - Real-time        │  │   │
│  │  │ - Alerts           │  │   │
│  │  └────────────────────┘  │   │
│  │                          │   │
│  │  ┌────────────────────┐  │   │
│  │  │ PTV API Client     │  │   │
│  │  │ - Timetables       │  │   │
│  │  │ - Stops            │  │   │
│  │  │ - Disruptions      │  │   │
│  │  └────────────────────┘  │   │
│  │                          │   │
│  │  ┌────────────────────┐  │   │
│  │  │ TransLink Client   │  │   │
│  │  │ - GTFS parser      │  │   │
│  │  │ - Schedule display │  │   │
│  │  └────────────────────┘  │   │
│  └──────────────────────────┘   │
│            ↕                     │
│  ┌──────────────────────────┐   │
│  │  Cache Layer             │   │
│  │  - Recent queries        │   │
│  │  - Stop data             │   │
│  │  - Timetables            │   │
│  └──────────────────────────┘   │
│            ↕                     │
│  ┌──────────────────────────┐   │
│  │  UI Layer                │   │
│  │  - Route display         │   │
│  │  - Stop search           │   │
│  │  - Real-time updates     │   │
│  └──────────────────────────┘   │
└─────────────────────────────────┘
```

**Implementation:**

**1. NSW API Integration (Week 1-2)**
```swift
// NSW Trip Planner API Client
import Foundation

struct NSWAPIClient {
    let apiKey: String
    let baseURL = "https://api.transport.nsw.gov.au/v1/tp"

    func tripRequest(
        from: Coordinate,
        to: Coordinate,
        departureTime: Date
    ) async throws -> TripResponse {
        var components = URLComponents(string: "\(baseURL)/trip")!
        components.queryItems = [
            URLQueryItem(name: "outputFormat", value: "rapidJSON"),
            URLQueryItem(name: "coordOutputFormat", value: "EPSG:4326"),
            URLQueryItem(name: "depArrMacro", value: "dep"),
            URLQueryItem(name: "itdDate", value: formatDate(departureTime)),
            URLQueryItem(name: "itdTime", value: formatTime(departureTime)),
            URLQueryItem(name: "type_origin", value: "coord"),
            URLQueryItem(name: "name_origin", value: "\(from.lat):\(from.lon):EPSG:4326"),
            URLQueryItem(name: "type_destination", value: "coord"),
            URLQueryItem(name: "name_destination", value: "\(to.lat):\(to.lon):EPSG:4326"),
            URLQueryItem(name: "calcNumberOfTrips", value: "4")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        return try JSONDecoder().decode(TripResponse.self, from: data)
    }
}

// Usage
let client = NSWAPIClient(apiKey: "your-api-key")
let trips = try await client.tripRequest(
    from: Coordinate(lat: -33.8688, lon: 151.2093),
    to: Coordinate(lat: -33.8915, lon: 151.2767),
    departureTime: Date()
)
```

**2. Caching Layer (Week 2)**
```swift
import Foundation

actor RouteCache {
    private var cache: [CacheKey: CachedRoute] = [:]
    private let maxAge: TimeInterval = 2 * 60 * 60 // 2 hours

    struct CacheKey: Hashable {
        let from: Coordinate
        let to: Coordinate
        let time: Date

        // Round time to 5-minute buckets for better hit rate
        func hash(into hasher: inout Hasher) {
            hasher.combine(from)
            hasher.combine(to)
            hasher.combine(Int(time.timeIntervalSince1970 / 300))
        }
    }

    func get(from: Coordinate, to: Coordinate, time: Date) -> TripResponse? {
        let key = CacheKey(from: from, to: to, time: time)
        guard let cached = cache[key],
              cached.timestamp.timeIntervalSinceNow > -maxAge else {
            return nil
        }
        return cached.response
    }

    func set(from: Coordinate, to: Coordinate, time: Date, response: TripResponse) {
        let key = CacheKey(from: from, to: to, time: time)
        cache[key] = CachedRoute(response: response, timestamp: Date())

        // Cleanup old entries
        cache = cache.filter { $0.value.timestamp.timeIntervalSinceNow > -maxAge }
    }
}

// In view model
class RouteViewModel: ObservableObject {
    private let nswClient = NSWAPIClient(apiKey: "...")
    private let cache = RouteCache()

    func searchRoute(from: Coordinate, to: Coordinate) async {
        // Check cache first
        if let cached = await cache.get(from: from, to: to, time: Date()) {
            self.routes = cached.journeys
            self.showStaleWarning = true
            return
        }

        // Fetch from API
        do {
            let response = try await nswClient.tripRequest(
                from: from,
                to: to,
                departureTime: Date()
            )
            await cache.set(from: from, to: to, time: Date(), response: response)
            self.routes = response.journeys
        } catch {
            // Fallback to cached even if stale
            if let cached = await cache.get(from: from, to: to, time: Date()) {
                self.routes = cached.journeys
                self.showError = "Using cached data"
            }
        }
    }
}
```

**3. Rate Limit Handling (Week 2)**
```swift
actor RateLimiter {
    private var tokens: Int
    private let maxTokens: Int
    private let refillRate: Double // tokens per second
    private var lastRefill: Date

    init(maxTokens: Int, refillRate: Double) {
        self.tokens = maxTokens
        self.maxTokens = maxTokens
        self.refillRate = refillRate
        self.lastRefill = Date()
    }

    func acquire() async throws {
        // Refill tokens
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefill)
        let newTokens = Int(elapsed * refillRate)
        tokens = min(maxTokens, tokens + newTokens)
        lastRefill = now

        // Check if token available
        if tokens > 0 {
            tokens -= 1
            return
        }

        // Wait for next token
        let waitTime = 1.0 / refillRate
        try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        tokens = 0 // Will be refilled on next call
    }
}

// In API client
class NSWAPIClient {
    private let rateLimiter = RateLimiter(maxTokens: 5, refillRate: 5.0) // 5/sec

    func tripRequest(...) async throws -> TripResponse {
        try await rateLimiter.acquire()
        // ... actual request
    }
}
```

**4. Multi-State Routing Logic (Week 3-4)**
```swift
class TransitRouter {
    private let nswClient = NSWAPIClient(apiKey: "...")
    private let ptvClient = PTVAPIClient(apiKey: "...")
    private let transLinkGTFS = TransLinkGTFSClient()

    func route(from: Coordinate, to: Coordinate) async throws -> [Route] {
        let fromState = detectState(from)
        let toState = detectState(to)

        // Same state routing
        if fromState == toState {
            switch fromState {
            case .nsw:
                return try await nswClient.tripRequest(from: from, to: to).toRoutes()
            case .vic:
                // PTV doesn't provide routing, need OTP or show error
                throw RoutingError.notSupported("VIC routing requires OTP server")
            case .qld:
                // TransLink GTFS only, need OTP or show error
                throw RoutingError.notSupported("QLD routing requires OTP server")
            }
        }

        // Inter-state routing
        throw RoutingError.notSupported("Inter-state routing not yet implemented")
    }

    private func detectState(_ coord: Coordinate) -> State {
        // Simple bounding box detection
        if coord.lat > -37.5 && coord.lat < -28.0 && coord.lon > 140.0 && coord.lon < 154.0 {
            return .nsw
        } else if coord.lat > -39.0 && coord.lat < -34.0 && coord.lon > 140.0 && coord.lon < 150.0 {
            return .vic
        } else if coord.lat > -29.0 && coord.lat < -24.0 && coord.lon > 149.0 && coord.lon < 154.0 {
            return .qld
        }
        return .unknown
    }
}
```

**Timeline:**
- Week 1-2: NSW API integration
- Week 2: Caching + rate limiting
- Week 3: PTV/TransLink display (no routing)
- Week 4: Testing + refinement
- Week 5-6: UI/UX polish

**Result:**
- Working app for Sydney (NSW) in 4-6 weeks
- VIC/QLD show stops and schedules but no routing
- Path to add OTP for VIC/QLD in Phase 2

---

### Hybrid Implementation (Recommended)

**Combined Strategy:**

**Phase 1: API-First (Weeks 1-6)**
- Implement NSW API integration (routing)
- Implement PTV API integration (display only)
- Implement TransLink GTFS display
- Basic caching
- Ship MVP

**Phase 2: OTP for Non-NSW (Weeks 7-14)**
- Deploy OTP for VIC
- Deploy OTP for QLD
- Unified routing interface
- Advanced caching
- National coverage

**Phase 3: Offline (Weeks 15-26)**
- GTFS compression implementation
- Offline RAPTOR (simplified)
- Pre-calculated transfers
- Background sync
- Full offline support

**Code Architecture:**
```swift
// Routing abstraction
protocol RoutingProvider {
    func route(from: Coordinate, to: Coordinate, time: Date) async throws -> [Route]
}

// NSW: Use official API
class NSWRoutingProvider: RoutingProvider {
    func route(...) async throws -> [Route] {
        return try await nswAPIClient.tripRequest(...).toRoutes()
    }
}

// VIC/QLD: Use OTP
class OTPRoutingProvider: RoutingProvider {
    let otpClient: OTPClient

    func route(...) async throws -> [Route] {
        return try await otpClient.query(...).toRoutes()
    }
}

// Offline: Use local routing
class OfflineRoutingProvider: RoutingProvider {
    func route(...) async throws -> [Route] {
        return try localRAPTOR.calculate(...)
    }
}

// Main router with fallback
class HybridRouter {
    private let providers: [State: RoutingProvider] = [
        .nsw: NSWRoutingProvider(),
        .vic: OTPRoutingProvider(region: "vic"),
        .qld: OTPRoutingProvider(region: "qld")
    ]
    private let offlineProvider = OfflineRoutingProvider()
    private let cache = RouteCache()

    func route(from: Coordinate, to: Coordinate) async throws -> [Route] {
        let state = detectState(from)

        // Tier 1: Try online provider
        if let provider = providers[state] {
            do {
                let routes = try await provider.route(from: from, to: to, time: Date())
                await cache.store(routes)
                return routes
            } catch {
                // Fall through to cache
            }
        }

        // Tier 2: Try cache
        if let cached = await cache.get(from: from, to: to) {
            return cached.withStalenessWarning()
        }

        // Tier 3: Try offline
        do {
            let routes = try await offlineProvider.route(from: from, to: to, time: Date())
            return routes.withOfflineWarning()
        } catch {
            throw RoutingError.unavailable
        }
    }
}
```

**Benefits:**
- Clean abstraction (easy to swap providers)
- Graceful degradation
- Extensible (add new states/providers)
- Testable (mock providers)

---

## 10. Decision Matrix

### Scoring Criteria (1-5 scale)

| Criteria | Weight | Build | OTP | Cloud API | Hybrid |
|----------|--------|-------|-----|-----------|--------|
| **Time to Market** | 25% | 1 | 3 | 5 | 4 |
| **Cost (Year 1)** | 20% | 1 | 3 | 4 | 4 |
| **Technical Risk** | 20% | 1 | 3 | 4 | 4 |
| **Feature Completeness** | 15% | 5 | 5 | 3 | 4 |
| **Maintenance Burden** | 10% | 1 | 3 | 5 | 4 |
| **Scalability** | 5% | 5 | 3 | 2 | 4 |
| **Control/Flexibility** | 5% | 5 | 4 | 1 | 3 |
| **Data Quality** | 5% | 4 | 4 | 5 | 5 |

### Weighted Scores

**Build Custom:**
- (1×25%) + (1×20%) + (1×20%) + (5×15%) + (1×10%) + (5×5%) + (5×5%) + (4×5%)
- = 0.25 + 0.20 + 0.20 + 0.75 + 0.10 + 0.25 + 0.25 + 0.20
- = **2.20 / 5.0** (44%)

**OTP Integration:**
- (3×25%) + (3×20%) + (3×20%) + (5×15%) + (3×10%) + (3×5%) + (4×5%) + (4×5%)
- = 0.75 + 0.60 + 0.60 + 0.75 + 0.30 + 0.15 + 0.20 + 0.20
- = **3.55 / 5.0** (71%)

**Cloud APIs:**
- (5×25%) + (4×20%) + (4×20%) + (3×15%) + (5×10%) + (2×5%) + (1×5%) + (5×5%)
- = 1.25 + 0.80 + 0.80 + 0.45 + 0.50 + 0.10 + 0.05 + 0.25
- = **4.20 / 5.0** (84%)

**Hybrid (Recommended):**
- (4×25%) + (4×20%) + (4×20%) + (4×15%) + (4×10%) + (4×5%) + (3×5%) + (5×5%)
- = 1.00 + 0.80 + 0.80 + 0.60 + 0.40 + 0.20 + 0.15 + 0.25
- = **4.20 / 5.0** (84%)

### Winner: Hybrid (tied with Cloud APIs)

**Why Hybrid edges out pure Cloud APIs:**
- Cloud APIs score limited by VIC/QLD lack of routing
- Hybrid solves this in Phase 2 while maintaining API benefits
- Long-term flexibility and offline support

---

## 11. Recommended Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         iOS Application                             │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                    Presentation Layer                       │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │    │
│  │  │  Route   │  │   Stop   │  │   Map    │  │ Real-time│   │    │
│  │  │  Search  │  │  Search  │  │   View   │  │  Alerts  │   │    │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              ↕                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                  Business Logic Layer                       │    │
│  │                                                             │    │
│  │  ┌──────────────────────────────────────────────────────┐  │    │
│  │  │              Hybrid Routing Engine                    │  │    │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  │  │    │
│  │  │  │  Route      │  │  Provider   │  │   Fallback   │  │  │    │
│  │  │  │  Cache      │→ │  Selector   │→ │   Logic      │  │  │    │
│  │  │  └─────────────┘  └─────────────┘  └──────────────┘  │  │    │
│  │  └──────────────────────────────────────────────────────┘  │    │
│  │                              ↕                              │    │
│  │  ┌──────────────────────────────────────────────────────┐  │    │
│  │  │            Routing Providers (Tier 1)                 │  │    │
│  │  │  ┌────────┐    ┌────────┐    ┌────────┐              │  │    │
│  │  │  │  NSW   │    │  VIC   │    │  QLD   │              │  │    │
│  │  │  │  API   │    │  OTP   │    │  OTP   │              │  │    │
│  │  │  └────────┘    └────────┘    └────────┘              │  │    │
│  │  └──────────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              ↕                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                    Data Layer                               │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │    │
│  │  │   Route      │  │  Compressed  │  │   GTFS       │     │    │
│  │  │   Cache      │  │   GTFS       │  │  Real-time   │     │    │
│  │  │  (Core Data) │  │  (SQLite)    │  │   Parser     │     │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘     │    │
│  │                                                             │    │
│  │  ┌──────────────────────────────────────────────────────┐  │    │
│  │  │       Offline Routing Engine (Tier 3 - Phase 3)      │  │    │
│  │  │  ┌──────────────┐  ┌──────────────┐                  │  │    │
│  │  │  │   RAPTOR     │  │  Transfer    │                  │  │    │
│  │  │  │ Implementation│ │Pre-calculator│                  │  │    │
│  │  │  └──────────────┘  └──────────────┘                  │  │    │
│  │  └──────────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              ↕                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                  Network Layer                              │    │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐           │    │
│  │  │ URLSession │  │ Rate       │  │  Retry     │           │    │
│  │  │  Manager   │  │ Limiter    │  │  Logic     │           │    │
│  │  └────────────┘  └────────────┘  └────────────┘           │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                              ↕ HTTPS
┌─────────────────────────────────────────────────────────────────────┐
│                        External Services                            │
│                                                                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────────┐  │
│  │  TfNSW API       │  │   OTP VIC        │  │   OTP QLD       │  │
│  │  (NSW Routing)   │  │   (Self-hosted)  │  │  (Self-hosted)  │  │
│  │                  │  │                  │  │                 │  │
│  │  - Trip Planner  │  │  - GraphQL API   │  │  - GraphQL API  │  │
│  │  - Real-time     │  │  - GTFS + OSM    │  │  - GTFS + OSM   │  │
│  │  - Alerts        │  │  - GTFS-RT       │  │  - GTFS-RT      │  │
│  │  - Free 60K/day  │  │  - 30GB RAM      │  │  - 15GB RAM     │  │
│  └──────────────────┘  └──────────────────┘  └─────────────────┘  │
│                                                                     │
│  ┌──────────────────┐  ┌──────────────────────────────────────┐   │
│  │  PTV API         │  │   TransLink GTFS Feeds               │   │
│  │  (Timetables)    │  │   (Static + Realtime)                │   │
│  │                  │  │                                      │   │
│  │  - Stops/Lines   │  │  - GTFS Static ZIP                   │   │
│  │  - Disruptions   │  │  - GTFS-RT Protocol Buffers          │   │
│  │  - No Routing    │  │  - Free access                       │   │
│  └──────────────────┘  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Data Flow

**Happy Path (Online, NSW):**
```
1. User enters origin → destination (Sydney locations)
2. Provider Selector detects NSW
3. Check Route Cache → miss
4. NSW API Client makes request (with rate limiting)
5. Parse TfNSW response
6. Store in cache
7. Display routes to user
8. Background: download compressed schedules for offline
```

**Degraded Path (Offline, NSW):**
```
1. User enters origin → destination
2. Provider Selector detects NSW
3. Network unavailable
4. Check Route Cache → hit (2 hours old)
5. Display cached routes with "Last updated 2 hours ago"
6. If cache miss → Offline Routing Engine
7. Use compressed GTFS + pre-calculated transfers
8. Display schedule-based routes with "Offline mode - schedules only"
```

**Complex Path (VIC/QLD, Online):**
```
1. User enters origin → destination (Melbourne)
2. Provider Selector detects VIC
3. Check Route Cache → miss
4. OTP VIC Provider makes GraphQL request
5. OTP server queries in-memory graph
6. Returns Pareto-optimal routes
7. Store in cache
8. Display routes
```

---

## Conclusion

**Final Recommendation: Hybrid Approach**

**Phase 1 (MVP - 4-6 weeks, $15K):**
- NSW: TfNSW Trip Planner API
- VIC/QLD: Display stops/schedules (no routing)
- Basic caching
- Ship to App Store

**Phase 2 (National - 6-8 weeks, $15K, $270/mo hosting):**
- Deploy OTP for VIC + QLD
- Full routing coverage
- Enhanced caching

**Phase 3 (Offline - 6-8 weeks, $10K):**
- Compressed GTFS storage
- Offline schedule-based routing
- Pre-calculated transfers
- Background sync

**Total Investment:**
- Initial: $40K over 18-26 weeks (phased)
- Ongoing: $15-20K/year

**Expected Outcomes:**
- Week 6: Launch NSW-only app
- Week 14: Full Australia coverage
- Week 26: Offline-capable, feature-complete

**Risk Mitigation:**
- Validate market with Phase 1 before heavy investment
- Use proven technologies (APIs, OTP)
- Incremental complexity
- Multiple fallback tiers

**Not Recommended:**
- ❌ Build custom routing engine (12-18 months, $150-300K)
- ❌ Pure cloud APIs (VIC/QLD lack routing)
- ⚠️ OTP-only (expensive, complex, NSW API better)

---

## Appendix: Additional Resources

### OpenTripPlanner
- GitHub: https://github.com/opentripplanner/OpenTripPlanner
- Docs: https://docs.opentripplanner.org/
- OTPKit: https://github.com/OneBusAway/otpkit

### APIs
- TfNSW: https://opendata.transport.nsw.gov.au/
- PTV: https://www.ptv.vic.gov.au/footer/data-and-reporting/datasets/ptv-timetable-api/
- TransLink QLD: https://www.data.qld.gov.au/dataset/general-transit-feed-specification-gtfs-translink

### GTFS Resources
- GTFS Spec: https://gtfs.org/
- GTFS Realtime: https://developers.google.com/transit/gtfs-realtime

### Algorithms
- RAPTOR Paper: https://www.microsoft.com/en-us/research/publication/round-based-public-transit-routing/
- CSA Paper: https://arxiv.org/abs/1703.05997

### Open Source Implementations
- RAPTOR (TypeScript): https://github.com/planarnetwork/raptor
- CSA (JavaScript): https://github.com/LinkedConnections/csa.js
- Transit Routing (Python): https://github.com/transnetlab/transit-routing

---

**Document Version:** 1.0
**Last Updated:** 2025-10-30
**Author:** Research Analysis for prj_transport
# Competitor Architecture Analysis: TripView, Transit, and NextThere

## Executive Summary

### Key Lessons
- **Offline-first wins**: TripView's local timetable storage = reliable, fast, minimal server dependency
- **Simplicity matters**: NextThere's focused UX (next service vs full journey) appeals to specific use case
- **Multi-city complexity**: Transit handles 10,000+ agencies across 100+ countries via standardized GTFS integration
- **Battery drain critical**: Transit's GO mode uses ~5% battery per 20min trip - significant optimization required for location tracking
- **Subscription backlash**: Transit's paywall frustrated users who relied on free access to essential features
- **Privacy advantage**: TripView minimal data collection vs Transit's extensive SDK integration (Amplitude, Firebase, Sentry, Fabric)

### Critical Insights
1. **Offline reliability > real-time accuracy** for user trust
2. **Local storage = smaller app size** (TripView 5.44MB vs Transit 196MB)
3. **Anonymous analytics preferred** over user tracking
4. **GPS accuracy issues** plague all apps - fallback to timetables essential
5. **GTFS standardization** enables multi-city scalability but requires careful implementation

---

## TripView Architecture Analysis

### Developer & Tech Stack
- **Developer**: Nick Maher, Grofsoft (Sydney)
- **History**: Started 2007 as "Trainview" (Java), ported to iPhone 2009, renamed TripView
- **Platform**: iOS (Objective-C/Swift), Android, Windows Phone 7
- **App Size**: 5.44 MB (iOS)

### Offline-First Implementation

**Core Strategy**: All timetable data stored locally on device
- Enables complete offline functionality
- Fast response times (no network latency)
- Reliable when network unavailable
- Supports incremental timetable updates (only downloads changes)

**Data Storage**:
- Local database (likely SQLite based on platform standards)
- Trip settings stored on device, not on servers (except transient request logs)
- All communications encrypted

### Real-Time Data Integration

**Hybrid Approach**:
- Primary: Local timetable data
- Secondary: Real-time updates when available
- Fallback: If no real-time data, revert to scheduled timetable

**Data Sources**:
- Transport for NSW GTFS feeds (updated daily at ~01:30)
- Real-time data via Transport NSW PTIPS system (99% accuracy claimed)
- Updates every 10-15 seconds when real-time available

**Real-Time Request Flow**:
1. User views trip
2. App transmits relevant routes/stops to TripView servers
3. Servers request real-time data from Transport NSW
4. Return to app
5. If fails, show timetable data

### Privacy & Analytics

**Minimal Data Collection**:
- Trip settings stored locally only
- Server logs include: IP address, routes/stops requested (anonymous)
- Logs automatically deleted regularly
- No persistent user identification

**Analytics**:
- Google Firebase for anonymous usage stats
- Metrics: Active users, device models, OS versions
- No tracking of individual user patterns/trips

### Why It's Reliable

1. **Offline-first eliminates network dependency**
2. **Local storage = instant access**
3. **Graceful degradation** (real-time → timetable)
4. **Minimal server complexity** (only real-time proxy)
5. **Small app size** = fast, less memory

### Known Issues (User Reports)

- Rearrange trips option broken for some users
- Alarm notifications very loud, no vibrate option
- Bluetooth headphone routing issues for alarms
- Occasional sync issues after app restart (fixed in updates)
- Some complaints about developer response time

### Technical Debt Indicators

- Alarm system appears bolted-on (poor UX integration)
- Sync functionality has had bugs (architectural weakness?)
- Windows Phone 7 support suggests legacy code maintenance burden

---

## Transit App Architecture Analysis

### Tech Stack & Scale

**Platform**: iOS, Android, Web
**App Size**: 196 MB (iOS) - significantly larger than competitors
**Requirements**: iOS 16.0+ (recently updated from iOS 14.0)
**Developer**: 9280-0366 Quebec Inc. (Transit App, Inc.)

**Scale**:
- 10,000+ transit agencies
- 100+ countries
- Multi-city data management at massive scale

### Multi-City GTFS Architecture

**Integration Process**:
1. Agencies provide permanent, public, static URL to GTFS dataset
2. Transit auto-fetches new datasets within 4 hours
3. Upload to app within 2 hours (if no errors)
4. Validation before deployment

**Data Management**:
- Multiple feed versions maintained
- Correct feed selected based on date/time
- Regional feed consolidation (single click regional GTFS generation)
- Cloud-based infrastructure (servers in USA & Canada)

**Feed Requirements**:
- Permanent URL (no geolocation/firewall blocks)
- Valid GTFS format
- High coverage (especially high-density areas)
- Update frequency: 30 seconds minimum (VehiclePositions more frequent)

### GO Mode Technical Implementation

**Real-Time Crowdsourcing**:
- GPS + motion detection to detect user state (walking/waiting/on bus)
- Generates real-time ETAs for routes lacking official data
- Anonymous data aggregation

**Performance**:
- Battery: ~5% per 20min trip
- Data: <100 KB per typical trip
- Auto-off when destination reached

**Privacy**:
- Exact position never shared with other riders
- Vehicle position shared only while GO active
- All data anonymous
- Location data only when app in foreground

### Backend Architecture

**Likely Stack** (based on industry standards for transit apps):
- Backend: Node.js, Express, Django/Flask, Phoenix
- Languages: Python, Node.js, Go, Java
- Database: PostgreSQL, MySQL, Redis, Cassandra
- Cloud: AWS, Azure, Google Cloud
- Real-time: Node.js for ETA module, WebSockets
- Mobile: Swift/Objective-C (iOS), Java/Kotlin (Android)

### Analytics & Third-Party SDKs

**Heavy SDK Integration**:
- Amplitude SDK: Product analysis
- Google Analytics SDK: Product analysis
- Sentry SDK: Crash/issue tracking
- Fabric SDK: Crash/issue tracking
- Firebase SDK: User prefs, favorites, push notifications

**Privacy Implications**:
- Extensive data collection (location, preferences, routes)
- Data stored in USA & Canada
- Third-party data sharing via SDKs
- "Structured so can't identify individuals" (claimed)

### Subscription Model (Transit Royale)

**Pricing**: $4.99/month or $24.99/year ($2/month annual)

**Paywalled Features** (after 2-week grace):
- Future schedules beyond immediate time
- Transit lines distant from current location
- Bus departure times outside few-block radius

**Justification**: Avoid ads, avoid selling user data

**User Backlash**:
- Access to transit info should be free (advocacy groups)
- Frustrated users who relied on free features
- Paywall workaround guides published
- Some transit agencies sponsored free access for riders (CT, BC Transit)

### Known Technical Issues (User Reports)

**Battery Drain**:
- Background GPS significantly drains battery
- Drains even when not actively using

**App Crashes**:
- Frequent crashes/freezes
- Disrupts access to real-time info

**Inaccurate Arrivals**:
- Frequent incorrect bus/train times
- Leads to missed connections

**Performance**:
- Large app size (196 MB) suggests bloat
- Memory usage issues likely

### Why UX is Smooth

1. **Immediate relevant info** - opens to nearby lines with wait times
2. **Clean design** - considered best-designed transit app 2024
3. **Comprehensive coverage** - works globally
4. **Real-time focus** - prioritizes current info over planning

### What's Not Working

1. **App bloat** - 196 MB is 36x larger than TripView
2. **Battery drain** - GO mode unsustainable for all-day use
3. **Crash frequency** - reliability issues undermine core value prop
4. **Subscription friction** - paywalling core features alienates users
5. **Privacy concerns** - extensive SDK integration, data collection

---

## NextThere Architecture Analysis

### Developer & Scale

**Developer**: AppJourney Pty Ltd
**Original Purpose**: Built for Sydney Trains employees
**App Size**: 118.95 MB (iOS)
**Requirements**: iOS 14.0+, macOS 11.0+ (Apple M1+)
**Awards**: Gold Winner 2017 GOV Design Awards, Silver Winner 2017 TECH Design Awards

**Scale**:
- 15 million notifications/year
- 1.7 million real-time data requests
- Kept Sydney Trains running when physical screens down during power outages

### Extreme Simplicity Approach

**UI Philosophy**:
- One tap → next arriving/departing service
- Filter by mode or destination
- Latest iOS design (flat, clear text, 3D Touch)
- Lock screen functionality
- Apple Watch companion app

**UX Focus**:
- Primary: Next service (immediate need)
- Secondary: Journey planning
- Contrast with TripView (journey planning primary)

### Technical Implementation

**Data Aggregation**:
- Integrates data from dozens of systems:
  - Control centres
  - Signal boxes
  - Planning systems
  - GPS vehicle telemetry
  - Opal fare data
- Single interface merges all sources

**Real-Time Performance**:
- 10-15 second latency from source to app
- Live train load data (Waratah trains): 10-20 sec after doors close
- GTFS updates daily (~01:30)
- Real-time feeds update every 10 seconds

**Geolocation**:
- Automatic location detection
- Shows relevant services without manual search
- Efficient single-tap experience

### Subscription Model

**Freemium**:
- 3 locations free
- Widget with good info
- Subscription for unlimited locations

### Reliability Secrets

1. **Multi-source data fusion** - doesn't rely on single feed
2. **Low latency** - 10-20 second freshness
3. **Critical infrastructure status** - used when official systems fail
4. **Focused scope** - immediate info only, no trip planning complexity

### Lightweight Experience Achieved Through

1. **Focused feature set** - does one thing extremely well
2. **Modern iOS architecture** - native performance
3. **Efficient data structures** - only stores what's needed
4. **Smart caching** - geolocation reduces unnecessary data fetching

---

## Technical Comparison Table

| Aspect | TripView | Transit | NextThere |
|--------|----------|---------|-----------|
| **App Size (iOS)** | 5.44 MB | 196 MB | 118.95 MB |
| **iOS Requirement** | Earlier versions | iOS 16.0+ | iOS 14.0+ |
| **Primary Focus** | Journey planning | Multi-city coverage | Next service |
| **Offline Support** | Full (all timetables) | Limited | Unknown |
| **Data Storage** | Local first | Cloud first | Hybrid |
| **Privacy Approach** | Minimal collection | Extensive SDKs | Unknown |
| **Analytics** | Anonymous (Firebase) | Heavy (4+ SDKs) | Unknown |
| **Monetization** | $4.99 upfront | $4.99/mo subscription | Freemium subscription |
| **Battery Impact** | Low | High (GO mode) | Unknown |
| **Real-time Update** | 10-15 sec | 30 sec+ (GTFS spec) | 10-15 sec |
| **Multi-city Support** | 3 cities (AU) | 10,000+ agencies | AU + US cities |
| **Known Crashes** | Rare | Frequent | Unknown |
| **Data Accuracy** | 99% (PTIPS) | Variable by agency | High (multi-source) |
| **Developer Response** | Slow (reported) | Unknown | Unknown |

---

## Lessons Learned

### DO THIS

**Architecture**:
1. **Offline-first with local storage** - TripView model = reliability + speed + small size
2. **Graceful degradation** - always have fallback (real-time → timetable → nothing)
3. **Incremental updates** - TripView's delta sync reduces bandwidth/storage
4. **Multi-source data fusion** - NextThere approach increases reliability
5. **Native platform development** - better performance, smaller size

**Data Management**:
6. **GTFS standardization** - enables multi-city scalability
7. **Local-first sync strategy** - reduces server dependency
8. **Efficient caching** - smart geolocation filtering (NextThere)
9. **Fast update cycles** - 10-15 sec acceptable, not 30+ sec
10. **Data validation before deployment** - Transit's 2-hour validation

**UX**:
11. **Focused feature set** - NextThere's "next service" vs TripView's "journey planning"
12. **Immediate relevant info** - Transit's "open to nearby lines"
13. **Progressive disclosure** - simple → complex as needed
14. **Widget support** - quick glance essential for transit

**Privacy**:
15. **Minimal data collection** - TripView model preferred
16. **Anonymous analytics only** - aggregate, not individual
17. **Local storage of user data** - trips, favorites stored on device
18. **Clear privacy communication** - transparent about data use

**Performance**:
19. **Battery optimization critical** - Transit GO's 5% is too high for all-day
20. **Small app size** - TripView 5.44 MB vs Transit 196 MB
21. **Memory efficiency** - avoid bloat, crashes
22. **Lazy loading** - load only what's needed when needed

### AVOID THIS

**Architecture Mistakes**:
1. **Over-reliance on real-time data** - network failures = broken app
2. **Excessive third-party SDKs** - privacy concerns, bloat, dependencies
3. **Cloud-first architecture** - increases latency, costs, failure points
4. **Complex multi-city premature** - start focused, expand later
5. **Large app size** - Transit's 196 MB is warning sign

**Data Management**:
6. **Single data source dependency** - redundancy essential
7. **No offline fallback** - unacceptable for transit apps
8. **Slow update cycles** - 30+ seconds feels stale
9. **Poor sync strategies** - TripView's sync bugs indicate challenges
10. **Inadequate data validation** - bad data = user distrust

**UX**:
11. **Feature bloat** - trying to do everything
12. **Complex navigation** - transit users need speed
13. **Paywalling core features** - Transit subscription backlash
14. **Unclear value proposition** - be TripView OR NextThere, not both

**Privacy**:
15. **Extensive user tracking** - Transit's SDK approach concerning
16. **Cloud storage of personal data** - local-first safer
17. **Opaque data practices** - causes user distrust
18. **Third-party data sharing** - via SDKs creates privacy risks

**Performance**:
19. **Background GPS without optimization** - battery drain kills adoption
20. **Memory leaks** - Transit crash reports indicate issues
21. **Unoptimized assets** - contributes to app bloat
22. **Synchronous blocking operations** - causes UI freezes

**Business Model**:
23. **Aggressive paywalls** - Transit Royale backlash
24. **Removing free features** - user revolt
25. **Unclear pricing value** - what exactly are users paying for?
26. **No free tier for low-income** - transit equity issue

---

## Common Technical Issues Across Apps

### GPS & Real-Time Data
- **Problem**: GPS inaccuracy, "ghost buses" appearing, incorrect vehicle positions
- **Root Cause**: Transit agencies' GPS hardware issues, poor data quality, connectivity problems
- **User Impact**: Missed connections, distrust in app accuracy

### Data Feed Limitations
- **Problem**: Not all agencies provide real-time data (especially small cities)
- **Solution**: Crowdsourcing (Transit GO), timetable fallback (TripView)

### Performance Bottlenecks
- **Memory leaks** → crashes (Transit)
- **Battery drain** → uninstall (Transit GO)
- **Slow loading** → frustration
- **Large app size** → storage concerns

### Offline Functionality
- **TripView**: Full timetables offline ✓
- **Transit**: Limited offline ✗
- **NextThere**: Unknown

### Multi-City Complexity
- **Challenge**: Managing 10,000+ agencies, different GTFS implementations
- **Transit solution**: Automated ingestion, validation, cloud infrastructure
- **Cost**: 196 MB app size, complexity, crash frequency

---

## Opportunities for Differentiation

### 1. Ultra-Lightweight Offline-First
- **TripView size** (5.44 MB) + **TripView offline** + **NextThere simplicity**
- **Target**: <10 MB app, full offline functionality
- **Advantage**: Fast, reliable, low storage, works anywhere

### 2. Privacy-First Architecture
- **Zero third-party SDKs** (vs Transit's 5+)
- **Local-only storage** for user data
- **Anonymous-only analytics**
- **No location tracking** unless explicitly requested
- **Advantage**: Trust, regulatory compliance (GDPR, CCPA)

### 3. Battery-Optimized Location
- **Improve on Transit GO's 5% per 20min**
- **Target**: <2% per 20min
- **Techniques**: Adaptive polling, motion coprocessor, geofencing
- **Advantage**: All-day usability

### 4. Hybrid Data Sources
- **NextThere approach**: Multiple system aggregation
- **Add**: Crowdsourcing (Transit GO), timetables (TripView), official real-time
- **Advantage**: Reliability when official feeds fail

### 5. Context-Aware UX
- **Home screen**: NextThere's "next service"
- **Planning mode**: TripView's journey planning
- **Navigation mode**: Transit's step-by-step
- **Adaptive**: Learn user patterns, predict needs
- **Advantage**: Best of all three apps

### 6. Free + Fair Monetization
- **Avoid Transit's paywall backlash**
- **Core features free forever**
- **Premium**: Advanced features (multi-city, widgets, themes, trip history)
- **Equity**: Free premium for low-income (via agency partnerships)
- **Advantage**: User goodwill, viral growth

### 7. Modern Tech Stack
- **TripView started 2007** → likely legacy code
- **Transit's bloat** → technical debt
- **Fresh start**: SwiftUI/Jetpack Compose, modern architecture
- **Advantage**: Performance, maintainability, faster iteration

### 8. Single City Excellence First
- **Transit went broad** (10,000 agencies) → quality issues
- **TripView went deep** (3 AU cities) → high quality
- **Strategy**: Perfect ONE city, then expand
- **Advantage**: Quality > quantity, loyal core users

---

## Recommendations for Our Architecture

### Phase 1: Foundation (MVP)
1. **Offline-first architecture** (TripView model)
2. **Single city focus** (choose high-quality GTFS feed)
3. **Local SQLite storage** for timetables
4. **Incremental sync** for updates
5. **Minimal analytics** (anonymous only)
6. **Native development** (SwiftUI/Jetpack Compose)
7. **Target**: <10 MB app size

### Phase 2: Real-Time
1. **GTFS Realtime integration**
2. **Fallback to timetables** when unavailable
3. **10-15 second update cycle**
4. **Multi-source validation** (NextThere approach)
5. **Graceful error handling**

### Phase 3: Intelligence
1. **Context-aware UX** (NextThere + TripView hybrid)
2. **Battery-optimized location** (<2% per 20min)
3. **Predictive suggestions** based on time/location
4. **Smart notifications** (proactive delays, alternatives)

### Phase 4: Scale
1. **Multi-city expansion** (after single-city perfection)
2. **GTFS automation** (Transit's ingestion model)
3. **Regional consolidation**
4. **Maintain offline-first** (don't compromise)

### Technical Stack Recommendations

**Mobile**:
- iOS: SwiftUI, Combine, Core Data/SQLite
- Android: Jetpack Compose, Kotlin Flow, Room/SQLite

**Backend** (minimal):
- GTFS ingestion: Python scripts
- Real-time proxy: Node.js/Go
- Database: PostgreSQL (GTFS), Redis (caching)
- Cloud: Start with single region, scale later

**Analytics**:
- Self-hosted Plausible/Umami (vs Firebase)
- On-device only for user prefs
- Aggregate metrics only

**Data**:
- GTFS Static: Daily fetch, validation, incremental sync
- GTFS Realtime: 10-15 sec polling
- Local cache: Full timetables offline
- Sync strategy: Delta updates only

### Performance Targets

- **App size**: <10 MB (vs TripView 5.44 MB, Transit 196 MB)
- **Cold start**: <1 second
- **Offline response**: <100ms
- **Real-time update**: 10-15 seconds
- **Battery drain**: <2% per 20min (vs Transit 5%)
- **Memory usage**: <50 MB typical
- **Crash rate**: <0.1% sessions

### Privacy Principles

1. **Zero third-party analytics SDKs**
2. **Local-first data storage**
3. **Minimal server communication**
4. **Anonymous telemetry only** (opt-in)
5. **No location tracking** unless actively navigating
6. **Open privacy policy** (plain language)
7. **GDPR/CCPA compliant by design**

### Monetization Strategy

**Free Forever**:
- All core transit features
- Offline timetables
- Real-time updates
- Single city
- Basic widgets

**Premium** ($2.99/mo or $19.99/yr):
- Multi-city support
- Advanced widgets
- Trip history/patterns
- Themes/customization
- Priority support

**Equity Program**:
- Free premium for low-income (agency partnerships)
- Free for students (via .edu email)
- Non-profit discounts

---

## What We Can Do Better Than All Three

### 1. Reliability
- **TripView offline** + **NextThere multi-source** = never fails
- Offline timetables + real-time + crowdsourcing + multi-source validation

### 2. Performance
- **TripView size** + **modern stack** = <10 MB, fast, efficient
- Native architecture, lazy loading, smart caching

### 3. Privacy
- **Better than all three**: Zero tracking, local-first, no SDKs
- Trust advantage in privacy-conscious era

### 4. User Experience
- **Context-aware hybrid**: NextThere (immediate) + TripView (planning)
- Adaptive interface based on user context

### 5. Battery Life
- **Better than Transit**: <2% per 20min (vs 5%)
- Geofencing, adaptive polling, motion coprocessor

### 6. Monetization
- **Fairer than Transit**: Core free, premium optional, equity program
- Avoid paywall backlash

### 7. Quality Focus
- **TripView depth** not **Transit breadth**: Perfect one city first
- Reliability > coverage

### 8. Modern Foundation
- **Fresh start advantage**: No legacy code, modern patterns
- SwiftUI/Compose, reactive architecture, testable

---

## Critical Success Factors

### Must-Haves
1. ✓ Offline-first (TripView lesson)
2. ✓ Fast (<1s cold start)
3. ✓ Small (<10 MB)
4. ✓ Reliable (multi-source fallbacks)
5. ✓ Private (local-first, minimal SDKs)
6. ✓ Battery-efficient (<2% per 20min)

### Differentiators
1. ✓ Context-aware UX (adaptive)
2. ✓ Ultra-lightweight (vs Transit bloat)
3. ✓ Privacy-first (vs Transit SDKs)
4. ✓ Fair monetization (vs Transit paywall)
5. ✓ Quality-focused (vs Transit scale issues)

### Avoid at All Costs
1. ✗ Cloud-first architecture
2. ✗ Third-party SDK bloat
3. ✗ Paywalling core features
4. ✗ Battery-draining location tracking
5. ✗ Multi-city premature expansion
6. ✗ Poor offline support

---

## Sources & Research Notes

### Data Sources
- App Store listings (iOS)
- Google Play Store (Android)
- TripView privacy policy
- Transit privacy policy & support docs
- NextThere awards documentation
- GTFS documentation & best practices
- Transport for NSW Open Data
- User reviews on TrustPilot, AppGrooves
- Tech forums (Whirlpool, Reddit mentions)
- Developer blogs & press releases

### Limitations
- Limited public technical details on internal architectures
- No direct developer interviews found
- NextThere privacy policy not located
- Transit backend stack inferred from industry standards
- Specific database choices not publicly documented
- User complaint data from reviews (self-reported, biased)

### Confidence Levels
- **High confidence**: App sizes, features, monetization, GTFS integration
- **Medium confidence**: Tech stack choices, data flows, performance metrics
- **Low confidence**: Internal architecture details, database schemas, specific algorithms

---

*Research completed: 2025-10-30*
*Apps analyzed: TripView (Grofsoft), Transit (Transit App Inc.), NextThere (AppJourney)*
*Total web searches: 20+ queries across app stores, forums, blogs, technical docs*
# Backend Architecture Patterns for Transit App
*Research compiled: October 2025*

## Executive Summary

**Recommended Architecture**: Modular Monolith with PostgreSQL, REST API, Redis caching
**Tech Stack**: Node.js (Express) or Python (FastAPI)
**Hosting**: Railway or Fly.io (startup phase) → AWS/GCP (scale phase)
**Estimated Cost**: $20-50/month (MVP) → $200-500/month (10K users) → $1K-3K/month (100K users)

### Key Decisions Framework

| Decision | Recommendation | Rationale |
|----------|---------------|-----------|
| Architecture | Modular Monolith | Simpler ops, faster iteration, easy to extract services later |
| API Style | REST (primary) + GraphQL (consider 2026) | REST better for caching, simpler for iOS client, mature tooling |
| Database | PostgreSQL | ACID compliance, geospatial support, proven scaling paths |
| Caching | Redis + CDN | Critical for GTFS static data, reduces compute costs |
| Real-time | SSE (server-sent events) | One-way updates, auto-reconnect on mobile, simpler than WebSockets |
| Auth | JWT with Apple Sign-In | Industry standard, stateless, mobile-friendly |
| Hosting | Railway/Fly.io initially | Low cost, simple deploy, migrate to AWS/GCP at scale |

---

## 1. Architecture Patterns

### Modular Monolith vs Microservices

**2024-2025 Consensus**: Modular monolith for startups, microservices only at team scale >10 developers

#### Modular Monolith (RECOMMENDED)

**Definition**: Single deployable unit with well-defined internal module boundaries

**Pros:**
- Simpler deployment (single container/process)
- Easier debugging and monitoring
- Shared database transactions
- Lower infrastructure costs (87% less than microservices initially)
- Faster development iteration
- Single codebase reduces context switching

**Cons:**
- Requires discipline to maintain module boundaries
- Entire app redeploys for any change
- Scaling is vertical initially

**When to Use:**
- Team <10 developers
- <100K active users
- Rapid feature iteration needed
- Limited ops resources
- Clear path to extract services later

**Module Structure for Transit App:**
```
/api
  /auth         # Apple Sign-In, JWT, sessions
  /gtfs         # GTFS static/realtime parsing
  /routes       # Trip planning, route search
  /alerts       # Service alerts, notifications
  /favorites    # User saved trips/stops
  /push         # APNs integration

/services
  /gtfs-sync    # Background jobs for feed updates
  /alert-engine # Alert matching & delivery

/shared
  /models       # Database models
  /cache        # Redis abstractions
  /utils        # Shared utilities
```

#### Microservices

**When to Consider:**
- Team >10 developers
- >500K active users
- Need independent scaling (e.g., push notification service)
- Multiple teams working on different features
- Mature DevOps practices

**Cost Reality**: Microservices have 85% higher initial infrastructure costs but better long-term resource optimization

**Transition Path**: Start modular monolith → Extract high-traffic services (push notifications, real-time feeds) → Full microservices if needed

---

## 2. API Design

### REST vs GraphQL

#### REST (RECOMMENDED for MVP)

**Pros:**
- HTTP caching built-in (CDN, browser, Redis)
- Simpler to implement and debug
- Lower barrier to entry
- Mature tooling and libraries
- Better for mobile bandwidth optimization (specific endpoints)

**Cons:**
- Over-fetching data (getting more than needed)
- Under-fetching (multiple requests needed)
- Version management overhead

**Best for:**
- Simple, static data structures
- Caching-heavy workloads (GTFS static data)
- Standard CRUD operations
- Mobile apps with predictable data needs

**API Structure:**
```
GET  /api/v1/routes                    # List all routes
GET  /api/v1/routes/:id                # Route details
GET  /api/v1/stops/:id/arrivals        # Real-time arrivals
GET  /api/v1/trips/plan                # Trip planning
POST /api/v1/favorites                 # Save favorite
GET  /api/v1/alerts                    # Service alerts
```

#### GraphQL (Consider for Web Dashboard 2026)

**Pros:**
- Single request for complex, nested data
- Client specifies exact data needed
- No over-fetching (saves mobile bandwidth)
- Strong typing and schema validation
- Better for apps with multiple client types

**Cons:**
- More complex caching (each query unique)
- Steeper learning curve
- Less built-in HTTP caching
- Requires more sophisticated cache management

**Best for:**
- Complex, nested data structures
- Multiple client types (iOS, web, future Android)
- Frequent API changes
- When to consider: 2026 web dashboard launch

**Hybrid Approach** (2026+):
- REST for authentication, user registration (OAuth standards)
- GraphQL for complex queries (trip planning, multi-stop routes)
- REST for real-time feeds (better caching)

### API Versioning Strategies

**Recommended: URL Versioning**
```
/api/v1/routes
/api/v2/routes
```

**Pros**: Clear, explicit, easy to route, CDN-friendly
**Cons**: Multiple versions to maintain

**Best Practices:**
- Maintain backward compatibility as long as possible (12-18 months)
- Deprecate with warnings (headers, docs)
- Version major breaking changes only
- Use additive changes when possible (new fields don't break clients)

**GraphQL Versioning**: Use field-level deprecation, avoid URL versioning
```graphql
type Route {
  id: ID!
  name: String!
  oldField: String @deprecated(reason: "Use newField instead")
  newField: String
}
```

### Rate Limiting

**Recommended: Token Bucket with Redis**

**Algorithm**: Token Bucket (allows controlled bursts)

**Implementation:**
- Redis for distributed rate limiting
- Sliding window counter for accuracy
- Per-user and per-IP limits

**Example Limits:**
- Anonymous: 60 requests/minute
- Authenticated: 600 requests/minute
- Real-time endpoints: 10 requests/second

**Libraries:**
- Node.js: `express-rate-limit` with Redis
- Python: `slowapi` or `limits` library

**Cost**: Minimal (Redis used for caching anyway)

---

## 3. Caching Strategies

**Critical for transit apps**: GTFS static data rarely changes, real-time updates frequently

### Multi-Layer Caching Architecture

```
User Request
    ↓
[CDN] (CloudFlare) - GTFS static files, route maps
    ↓
[API Gateway] - Rate limiting
    ↓
[Redis Cache] - Real-time arrivals, route queries
    ↓
[PostgreSQL] - Source of truth
    ↓
[Background Jobs] - GTFS feed sync
```

### Layer 1: CDN (Static GTFS Files)

**Use Case**: GTFS static ZIP files, route maps, static assets

**Providers:**
- CloudFlare (free tier: unlimited bandwidth)
- AWS CloudFront ($0.085/GB)
- Fastly (pay-as-you-go)

**Strategy:**
- Store GTFS static files in S3/R2
- CloudFront/CloudFlare in front
- Long TTL (24 hours, GTFS updates daily at most)
- Purge cache on GTFS update

**Cost Savings**: 60-70% reduction in origin requests

### Layer 2: Redis (Hot Data)

**Use Case**: Real-time arrivals, route queries, user sessions, rate limiting

**Data Structures:**
```
# Real-time arrivals (5min TTL)
SET stop:123:arrivals JSON TTL=300

# Route cache (24hr TTL)
SET route:456 JSON TTL=86400

# User favorites (no expiry)
SADD user:789:favorites stop:123 stop:456

# Rate limiting (sliding window)
ZADD ratelimit:user:789 timestamp uuid
```

**Patterns:**
- **Cache-Aside** (lazy loading): Check cache → miss → fetch DB → populate cache
- **Write-Through**: Update DB → update cache synchronously
- **Cache Prefetching**: Preload popular routes/stops

**Invalidation:**
- TTL-based for real-time data (5min)
- Manual invalidation on GTFS static updates
- Pub/Sub for cache invalidation across instances

**Hosting:**
- Railway Redis: ~$5-10/month (512MB-1GB)
- Upstash: Serverless Redis, pay-per-request
- AWS ElastiCache: $15/month (cache.t3.micro)

### Layer 3: Database (PostgreSQL)

**Indexes:**
```sql
CREATE INDEX idx_stops_location ON stops USING GIST(location);
CREATE INDEX idx_arrivals_stop_time ON arrivals(stop_id, arrival_time);
CREATE INDEX idx_routes_agency ON routes(agency_id);
```

**Query Optimization:**
- Use EXPLAIN ANALYZE
- Materialized views for complex queries
- Partition large tables (arrivals by month)

---

## 4. Real-Time Data Aggregation

### GTFS-RT Feed Architecture

**Challenge**: Poll multiple government feeds (30sec-2min intervals), transform, serve to clients

**Architecture:**
```
[Gov Feed 1] ───┐
[Gov Feed 2] ───┼──→ [Poller Service] → [Transform] → [Redis] → [API] → [iOS App]
[Gov Feed 3] ───┘                           ↓
                                        [PostgreSQL]
                                            ↓
                                      [Alert Engine]
```

**Poller Service:**
- Cron job or background worker (every 30-60 seconds)
- Fetch GTFS-RT protobuf feeds
- Parse: VehiclePosition, TripUpdate, ServiceAlert
- Transform to internal format
- Write to Redis (5min TTL)
- Write to DB for historical analysis

**Tech Options:**
- Node.js: `node-cron` + `gtfs-realtime-bindings`
- Python: `Celery` + `gtfs-realtime-bindings`
- Go: `gocron` (most efficient for polling)

**Data Transformation:**
```
GTFS-RT (protobuf) → Internal JSON → Redis → REST API
```

**Push Notification Triggers:**
- Monitor TripUpdate for delays >5min
- ServiceAlert for user's saved routes/stops
- Queue push notification jobs

**Handling Multiple Cities:**
- Separate poller per city/agency
- Unified data model
- City/agency ID in Redis keys: `arrivals:city1:stop123`

**Cost**: Compute for background jobs (minimal, <$5/month for polling)

---

## 5. User Data Management

### Account System

**Recommended**: Apple Sign-In (primary) + Email/Password (fallback)

**Data Model:**
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  apple_id VARCHAR(255) UNIQUE,  -- Apple User ID (sub from JWT)
  email VARCHAR(255),
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE TABLE favorites (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  type VARCHAR(50),  -- 'stop', 'route', 'trip'
  entity_id VARCHAR(255),
  created_at TIMESTAMP
);

CREATE TABLE saved_trips (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  origin_stop_id VARCHAR(255),
  destination_stop_id VARCHAR(255),
  trip_data JSONB,
  created_at TIMESTAMP
);
```

**Apple Sign-In Flow:**
1. iOS app: User taps "Sign in with Apple"
2. iOS returns: `identityToken` (JWT), `authorizationCode`, email/name (first time only)
3. Send to backend: POST /api/v1/auth/apple with JWT
4. Backend validates JWT:
   - Fetch Apple's public keys: https://appleid.apple.com/auth/keys
   - Verify signature (ES256 algorithm)
   - Check `iss` = appleid.apple.com, `aud` = your bundle ID
   - Extract `sub` (user ID) and `email`
5. Create/update user in database
6. Issue your own JWT (access + refresh tokens)
7. Return JWT to iOS app

**JWT Claims:**
```json
{
  "sub": "user_uuid",
  "email": "user@example.com",
  "iat": 1234567890,
  "exp": 1234571490,
  "iss": "your-app-domain"
}
```

**Session Management:**
- Stateless JWT (no server-side sessions)
- Access token: 15min expiry
- Refresh token: 30 days expiry, stored in DB
- Revocation: Blacklist in Redis on logout

### Cross-Device Sync

**Option 1: Backend Sync (Recommended)**
- Store favorites/saved trips in PostgreSQL
- iOS app syncs on launch and after changes
- Works across any device

**Option 2: CloudKit (iOS-only)**
- Apple's free iCloud sync
- Zero backend work
- iOS-only (no web/Android)

**Decision**: Use backend sync for future web dashboard support

### Privacy-First Approach

**Data Minimization:**
- Don't store location history
- Store only user-initiated favorites
- No tracking of trips/searches

**GDPR Compliance:**
- Easy account deletion
- Data export (JSON)
- Clear privacy policy
- No third-party analytics by default

**Data Retention:**
- User data: Indefinite (until deletion)
- Historical real-time data: 30 days
- Logs: 7 days

---

## 6. Push Notifications (APNs)

### Architecture

```
[GTFS-RT Poller] → [Alert Engine] → [Push Queue] → [APNs Worker] → [Apple APNs]
```

**Alert Engine:**
- Match TripUpdates/ServiceAlerts to user favorites
- Rules:
  - Delay >5min on saved route
  - Service alert on saved stop
  - Departure reminder (user-configured)
- Queue push notification job

**Push Queue:**
- Redis queue or database table
- Deduplication (don't spam same alert)
- Priority levels (urgent alerts first)

**APNs Worker:**
- Background service
- Process queue items
- Send to APNs HTTP/2 endpoint
- Handle failures (retry, dead-letter queue)

**APNs Integration:**

**Authentication**: Token-based (JWT) - Apple mandated 2025, deprecating certificates

**Libraries:**
- Node.js: `apn` or `node-apn`
- Python: `apns2`
- Go: `apns2` package

**Request Format:**
```http
POST https://api.push.apple.com/3/device/{device_token}
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "aps": {
    "alert": {
      "title": "Delay on Route 42",
      "body": "5 min delay due to traffic"
    },
    "sound": "default",
    "badge": 1,
    "collapse-id": "route-42-delay"  // Coalesce duplicate notifications
  },
  "route_id": "42"
}
```

**Scalability:**
- Keep connections open (reuse HTTP/2 connections)
- Pool of workers (5-10 for startup)
- Batch processing (but send individually)
- Rate: 200K+ messages/minute possible

**User Preferences:**
```sql
CREATE TABLE notification_preferences (
  user_id UUID PRIMARY KEY,
  alerts_enabled BOOLEAN DEFAULT TRUE,
  delay_threshold_minutes INT DEFAULT 5,
  quiet_hours_start TIME,
  quiet_hours_end TIME
);
```

**Cost**: APNs free, compute for workers (~$5-10/month)

---

## 7. Tech Stack Options

### Backend Languages/Frameworks

#### Node.js (Express/Fastify)

**Pros:**
- JavaScript ecosystem (huge library selection)
- Non-blocking I/O (good for real-time polling)
- JSON-native (GTFS-RT → JSON easy)
- Large talent pool
- Good performance (7.5x slower than Go, 1.5x faster than Python)

**Cons:**
- Single-threaded (CPU-bound tasks slower)
- Callback hell (use async/await)

**Use Case**: Good all-rounder, best if team knows JS

**Libraries:**
- Express (mature, simple) or Fastify (faster)
- `gtfs-realtime-bindings` for GTFS-RT parsing
- `node-cron` for background jobs
- `ioredis` for Redis

**Cost**: $20-30/month Railway/Fly.io

#### Python (FastAPI/Django)

**Pros:**
- FastAPI: Modern, async, auto-generated docs
- Django: Batteries-included, admin panel
- Excellent data processing libraries
- GTFS parsing libraries mature
- Good for ML/analytics later

**Cons:**
- Slower than Node.js (11x slower than Go)
- GIL limits multi-threading (use async)

**Use Case**: If team knows Python, or planning ML features

**Libraries:**
- FastAPI (recommended for APIs) or Django
- `gtfs-realtime-bindings` for GTFS-RT
- `Celery` for background jobs (better than node-cron)
- `redis-py` for Redis

**Cost**: $20-30/month Railway/Fly.io

#### Go

**Pros:**
- Blazing fast (benchmark: 7.5-11x faster than Node/Python)
- Excellent concurrency (goroutines)
- Compiled, single binary
- Low memory footprint

**Cons:**
- Steeper learning curve
- Smaller ecosystem than Node/Python
- More verbose code
- Smaller talent pool

**Use Case**: If performance critical, or team knows Go

**Libraries:**
- Gin or Fiber framework
- `transit_realtime` for GTFS-RT
- Native Redis client
- `gocron` for background jobs

**Cost**: $10-20/month (more efficient, smaller resources needed)

#### Swift Vapor

**Pros:**
- Same language as iOS (code sharing!)
- Type-safe models shared between client/server
- Reduced context switching
- Performance comparable to Go
- Compile-time safety

**Cons:**
- Small ecosystem (backend libraries limited)
- Fewer GTFS libraries
- Smaller talent pool for backend Swift
- Less mature production tooling

**Use Case**: If team is iOS-focused, wants single language

**Production Adoption**: Spotify, Allegro run Vapor in production (millions of requests/day)

**Cost**: $15-25/month Railway/Fly.io

### Database Options

#### PostgreSQL (RECOMMENDED)

**Pros:**
- ACID compliance (data integrity)
- PostGIS extension (geospatial queries)
- JSONB support (flexible schema)
- Mature, battle-tested
- Excellent scaling story (replication, sharding)
- Stack Overflow: Most admired DB (2023-2024)

**Cons:**
- Vertical scaling first (eventually need sharding)
- Slightly slower writes than NoSQL

**Use Case**: Default choice for structured, relational data

**Schema Example:**
```sql
CREATE TABLE stops (
  stop_id VARCHAR(255) PRIMARY KEY,
  stop_name VARCHAR(255),
  location GEOGRAPHY(POINT),  -- PostGIS
  wheelchair_accessible BOOLEAN
);

CREATE INDEX idx_stops_location ON stops USING GIST(location);
```

**Scaling Path:**
1. Single instance (0-100K users)
2. Read replicas (100K-500K users)
3. Horizontal sharding by city (500K+ users)

**Hosting:**
- Railway: $5/month (shared), $92.50/month (managed 2vCPU, 4GB RAM)
- Fly.io: $2-5/month (small), scales up
- AWS RDS: $15/month (db.t3.micro), scales to $100s/month

#### MongoDB

**Pros:**
- Flexible schema (no migrations)
- Horizontal scaling built-in (sharding)
- Fast reads for unstructured data
- Good for rapid prototyping

**Cons:**
- Weaker ACID guarantees (improving)
- No geospatial as mature as PostGIS
- Over-fetching can waste bandwidth

**Use Case**: If data model very fluid, or need horizontal scale immediately

**Decision**: PostgreSQL better for transit data (structured, geospatial, integrity)

### ORM vs Raw SQL

**Recommended: ORM for development, optimize hot paths with raw SQL**

**ORM Pros:**
- Faster development
- SQL injection protection (auto-sanitization)
- Database-agnostic (easier migration)
- Easier refactoring

**ORM Cons:**
- Performance overhead (10-20% slower)
- Complex queries inefficient
- Excessive DB permissions for reflection

**Raw SQL Pros:**
- Full control, optimized queries
- Faster (hand-tuned)
- Database-specific features

**Raw SQL Cons:**
- SQL injection risk (manual parameterization)
- More code, slower development
- DB vendor lock-in

**Best Practice**: Use ORM (Prisma, SQLAlchemy, GORM) for 80% of queries, optimize bottlenecks with raw SQL

**Example (Node.js Prisma):**
```typescript
// ORM for simple queries
const stop = await prisma.stop.findUnique({ where: { id: '123' } });

// Raw SQL for complex geospatial
const nearbyStops = await prisma.$queryRaw`
  SELECT * FROM stops
  WHERE ST_DWithin(location, ST_MakePoint($1, $2)::geography, 500)
`;
```

---

## 8. Hosting & Deployment

### Platform Comparison

| Platform | Cost (Startup) | Scaling | Complexity | Best For |
|----------|---------------|---------|------------|----------|
| **Railway** | $20-50/month | Easy, auto-scale | Low | MVP, small apps |
| **Fly.io** | $15-40/month | Regional, auto-scale | Low-Medium | Global apps |
| **AWS** | $50-200/month | Infinite | High | Growth stage, custom |
| **GCP** | $50-200/month | Infinite | High | Google ecosystem |
| **Azure** | $50-200/month | Infinite | High | Microsoft stack |

### Startup Phase: Railway or Fly.io

#### Railway

**Pricing:**
- Hobby: $5/month + usage ($20/vCPU, $10/GB RAM)
- Typical: $20-50/month (1 vCPU, 2GB RAM, PostgreSQL)
- $5 free credits for testing

**Pros:**
- Dead simple deploy (connect GitHub)
- Built-in PostgreSQL, Redis
- Auto-scaling
- Great DX (developer experience)

**Cons:**
- More expensive than VPS at scale
- Less control than AWS

**Use Case**: MVP to 10K users

#### Fly.io

**Pricing:**
- Pay-as-you-go (since Oct 2024)
- ~$3-4/month (1 small VM, 1GB storage)
- Invoices <$5 often waived (free!)
- PostgreSQL: $2-5/month

**Pros:**
- Global edge deployment
- Auto-scale to zero
- Low latency (user proximity)
- Docker-based

**Cons:**
- More manual config than Railway
- Requires Dockerfile

**Use Case**: MVP to 50K users, global audience

### Growth Phase: AWS or GCP

**When to Migrate**: 50K+ users, need custom infrastructure, cost optimization

#### AWS

**Services:**
- EC2: Compute instances
- ECS/Fargate: Container orchestration
- RDS: Managed PostgreSQL
- ElastiCache: Managed Redis
- S3: Static file storage
- CloudFront: CDN
- SQS/SNS: Message queues
- CloudWatch: Monitoring

**Cost (50K users):**
- EC2 (t3.medium): $30/month
- RDS (db.t3.small): $30/month
- ElastiCache (cache.t3.micro): $15/month
- S3 + CloudFront: $10/month
- **Total: ~$100-150/month**

**Pros:**
- Mature, battle-tested
- Infinite scaling
- Every service imaginable
- 12-month free tier

**Cons:**
- Complex (steep learning curve)
- Easy to overspend
- Vendor lock-in

#### GCP

**Similar to AWS**, slightly cheaper for compute, better for ML/analytics

**Services:**
- Compute Engine (EC2 equivalent)
- Cloud SQL (RDS equivalent)
- Memorystore (ElastiCache)
- Cloud Storage (S3)
- Cloud CDN
- Pub/Sub (SQS/SNS)

**Cost**: 10-20% cheaper than AWS for similar workloads

### Serverless vs Containers

#### Serverless (AWS Lambda, Vercel, Netlify)

**Pros:**
- Pay per request (scales to zero)
- No server management
- Auto-scaling
- Cheap for low/bursty traffic

**Cons:**
- Cold starts (300ms-2s latency)
- More expensive at consistent traffic (>66 req/sec tipping point)
- Vendor lock-in
- Complex for background jobs

**Cost Comparison:**
- Break-even: ~170M requests/month
- Below: Serverless cheaper
- Above: Containers cheaper

**Use Case**: Marketing website (static/SSG), sporadic API usage

#### Containers (ECS, Fly.io, Railway)

**Pros:**
- Consistent performance (no cold starts)
- Cheaper at steady traffic
- More control
- Better for background jobs (GTFS polling)

**Cons:**
- Always running (even idle)
- Pay for minimum capacity

**Use Case**: Transit API (steady traffic, background jobs)

**Recommendation**: Containers for API backend, Serverless for marketing site

### Deployment Architecture

**Recommended (MVP):**
```
GitHub → Railway/Fly.io (auto-deploy)
  ├── API Server (Node.js/Python/Go)
  ├── PostgreSQL (managed)
  ├── Redis (managed)
  └── Background Worker (GTFS poller)
```

**Recommended (Growth):**
```
GitHub → CI/CD (GitHub Actions) → AWS
  ├── ECS/Fargate
  │   ├── API Servers (2+ instances, load balanced)
  │   └── Background Workers (GTFS poller, APNs)
  ├── RDS PostgreSQL (primary + read replicas)
  ├── ElastiCache Redis
  ├── S3 (GTFS static files)
  └── CloudFront CDN
```

**Infrastructure as Code**: Terraform (AWS, multi-cloud) or Pulumi (type-safe)

---

## 9. Cost Optimization Strategies

### Phase 1: MVP (0-1K users) - Target: <$50/month

**Free Tiers:**
- Fly.io: <$5/month often waived
- CloudFlare: Free CDN (unlimited bandwidth)
- Upstash: Serverless Redis (10K requests/day free)
- Supabase: Free PostgreSQL (500MB)
- Plausible: Self-host analytics (free)

**Strategy:**
- Single instance (1vCPU, 2GB RAM)
- Shared PostgreSQL
- Free CDN
- Minimal monitoring (free tier Sentry)

**Cost Breakdown:**
- Hosting: $20-30/month (Railway/Fly.io)
- Database: $5-10/month (or free tier)
- Redis: Free (Upstash) or $5/month
- CDN: Free (CloudFlare)
- **Total: $25-50/month**

### Phase 2: Growth (1K-50K users) - Target: $100-300/month

**Optimizations:**
- Aggressive caching (reduce DB queries by 70%)
- CDN for GTFS static (reduce compute by 50%)
- Background job optimization (poll only active cities)
- Horizontal scaling (2-3 instances)

**Cost Breakdown:**
- Hosting: $50-100/month (Railway scaled or Fly.io)
- Database: $20-50/month (larger instance)
- Redis: $10-20/month
- CDN: $5-10/month (CloudFlare paid or CloudFront)
- Monitoring: $10-20/month (Sentry, logs)
- **Total: $100-200/month**

### Phase 3: Scale (50K-500K users) - Target: $500-2K/month

**Strategy:**
- Migrate to AWS/GCP (economies of scale)
- Read replicas (offload 60% reads)
- Multi-region (reduce latency)
- Reserved instances (40% savings)
- Spot instances for background jobs (70% savings)

**Cost Breakdown:**
- Compute: $200-500/month (EC2 reserved)
- Database: $100-300/month (RDS with replicas)
- Redis: $50-100/month (ElastiCache)
- CDN: $20-50/month
- Monitoring/Logs: $50-100/month
- Push notifications: $10-20/month
- **Total: $500-1,500/month**

### Cost Killers to Avoid

1. **Unused resources**: Auto-scale down (Fly.io, Railway)
2. **Over-provisioning**: Start small, scale up
3. **No caching**: 70% cost savings with Redis + CDN
4. **Long log retention**: 7 days max for startup
5. **Expensive monitoring**: Use free tiers (Sentry startup program)

### Caching = 60-70% Cost Reduction

**Example**: 1M API requests/day
- No cache: 1M DB queries → $200/month compute
- With cache (80% hit rate): 200K DB queries → $50/month compute
- **Savings: $150/month (75%)**

---

## 10. Serving Multiple Clients

### iOS App API

**Primary client**, optimized for mobile:
- REST API (v1)
- JWT authentication
- Gzip compression
- Pagination (limit battery drain)
- Efficient caching (ETags)

**Endpoints:**
```
GET /api/v1/routes
GET /api/v1/stops/:id/arrivals
POST /api/v1/auth/apple
GET /api/v1/alerts
```

### Marketing Website (Static/SSG)

**Recommended**: Static Site Generation (Next.js, Astro, Hugo)

**Why?**
- Fast (pre-rendered HTML)
- Cheap (host on Vercel/Netlify free)
- SEO-friendly
- No backend needed

**Architecture:**
```
Next.js (Static) → Vercel (free)
  ├── Landing page
  ├── About, Privacy, Terms
  └── Blog (optional)
```

**API Integration:** Minimal (maybe route/city list for SEO)

**Cost**: Free (Vercel/Netlify free tier) or $20/month (pro tier)

### Future Web Dashboard (2026)

**Recommended**: Next.js (React) with SSR or SPA

**Why?**
- Shared API (same backend as iOS)
- Real-time updates (SSE)
- Auth (same JWT system)

**Architecture:**
```
Next.js (SSR/SPA) → Vercel or self-hosted
  ↓
Same REST API as iOS app
```

**Considerations:**
- GraphQL for complex queries (trip planning UI)
- WebSocket/SSE for live updates
- Shared TypeScript types with backend

### Shared Backend Patterns

**Single API Server** serves all clients:
- iOS app: REST API
- Marketing site: Minimal API (route lists)
- Web dashboard: REST + GraphQL (optional)

**Separation Strategies:**
- Different API versions (/v1, /v2)
- Different subdomains (api.app.com, dashboard-api.app.com)
- Same codebase, different routes

**Benefits:**
- Single deploy
- Shared logic (auth, caching)
- Easier maintenance

**When to Separate:**
- Different scaling needs (dashboard more complex queries)
- Different teams
- Different security requirements

---

## 11. Analytics & Monitoring

### Privacy-Compliant Analytics

#### Plausible (RECOMMENDED)

**Features:**
- No cookies, GDPR compliant
- Simple metrics (pageviews, top pages)
- Lightweight (<1KB script)

**Hosting:**
- Cloud: €69/month (1M pageviews/year)
- Self-hosted: Free (Docker Compose)

**Use Case**: Marketing website, public metrics

#### PostHog

**Features:**
- Product analytics (funnels, retention)
- Session recording
- Feature flags
- A/B testing

**Hosting:**
- Cloud: $49/month (1M events), $369/month (10M)
- Self-hosted: Free (single project)

**Use Case**: iOS app analytics, user behavior

**Recommendation:**
- **Startup**: Self-hosted Plausible (free) or PostHog (free)
- **Growth**: PostHog cloud ($49-369/month)

### Error Tracking

#### Sentry (RECOMMENDED)

**Features:**
- Real-time error alerts
- Stack traces, breadcrumbs
- Release tracking
- Performance monitoring

**Pricing:**
- Free: 5K events/month (Developer plan)
- Team: $26/month (50K errors)
- Business: $80/month

**Startup Program**: Discounts for early-stage startups (apply)

**Use Case**: Backend + iOS app errors

**Alternatives:**
- BugSnag: Similar pricing
- Rollbar: Slightly cheaper
- Self-hosted: Sentry open source (free, limited features)

### Performance Monitoring

**Tools:**
- Sentry (APM included in paid plans)
- New Relic (expensive, $99+/month)
- Datadog (expensive, $15+/host/month)
- **Recommended**: Sentry + CloudWatch/Railway logs

**Metrics to Track:**
- API response times (p50, p95, p99)
- Database query times
- Cache hit rates
- Error rates
- Real-time feed update latency

### Logging

**Strategy:**
- Structured JSON logs
- Log levels (debug, info, warn, error)
- Centralized logging (ELK stack or managed)

**Tools:**
- **Startup**: Railway logs (built-in) or AWS CloudWatch
- **Growth**: ELK stack (Elasticsearch, Logstash, Kibana) self-hosted or Datadog

**Retention**: 7 days (cost optimization)

### What to Track

**User Behavior (Privacy-Compliant):**
- App opens
- Route searches (aggregate, no personal data)
- Favorite adds
- Push notification opens

**System Health:**
- API uptime (99.9% target)
- Database latency
- GTFS feed update success rate
- Push notification delivery rate

**Business Metrics:**
- Daily/Monthly active users
- User retention (D1, D7, D30)
- Feature adoption (favorites, alerts)

---

## 12. Authentication & Security

### Apple Sign-In Integration

**See Section 5 for detailed flow**

**Key Security:**
- JWT signature verification (ES256 algorithm)
- Token expiry check
- Audience validation (your bundle ID)
- Server-side validation (never trust client)

### Email/Password (Fallback)

**If needed** (optional for users without Apple ID):

**Implementation:**
- bcrypt password hashing (12 rounds)
- Email verification required
- Password reset flow (JWT tokens, 1hr expiry)

**Libraries:**
- Node.js: `bcryptjs`, `nodemailer`
- Python: `passlib`, `sendgrid`

### API Security Best Practices

#### JWT Implementation

**Access Token:**
```json
{
  "sub": "user_uuid",
  "email": "user@example.com",
  "iat": 1234567890,
  "exp": 1234571490,  // 15min expiry
  "iss": "https://api.yourdomain.com"
}
```

**Refresh Token:**
- 30 day expiry
- Store in database (revocable)
- Rotate on use

**Storage:**
- iOS: Keychain (never UserDefaults)
- Backend: Environment variables for JWT secret

#### Rate Limiting

**See Section 2 for details**

**Abuse Prevention:**
- Per-IP limits (anonymous)
- Per-user limits (authenticated)
- Exponential backoff on auth failures
- Captcha after 5 failed logins

#### Data Encryption

**In Transit:**
- HTTPS only (TLS 1.3)
- Certificate pinning (iOS app)

**At Rest:**
- Database encryption (AWS RDS, Railway support)
- Encrypted backups

**PII (Personally Identifiable Information):**
- Email: Hash with salt (if searchable) or encrypt
- Apple ID: Hash (one-way, only for lookup)

#### API Security Headers

```javascript
// Express middleware
app.use(helmet({
  contentSecurityPolicy: true,
  xssFilter: true,
  noSniff: true,
  hsts: { maxAge: 31536000 }
}));
```

#### Input Validation

**Always validate:**
- Request body schema (Joi, Yup, Zod)
- Query parameters
- Path parameters
- File uploads (if any)

**Example (Zod in Node.js):**
```typescript
const createFavoriteSchema = z.object({
  type: z.enum(['stop', 'route']),
  entity_id: z.string().max(255)
});

app.post('/favorites', async (req, res) => {
  const validated = createFavoriteSchema.parse(req.body);
  // ... safe to use validated data
});
```

#### Secrets Management

**Never in code:**
- Use environment variables
- Use secret managers (AWS Secrets Manager, Railway environment vars)

**Example (.env):**
```bash
DATABASE_URL=postgresql://...
JWT_SECRET=...
APPLE_TEAM_ID=...
APNS_KEY_ID=...
```

**Libraries:**
- Node.js: `dotenv`
- Python: `python-dotenv`

---

## 13. Scalability Considerations

### User Growth Projections

| Phase | Users | Requests/Day | Strategy |
|-------|-------|-------------|----------|
| **MVP** | 0-1K | <100K | Single instance, shared DB |
| **Early** | 1K-10K | 100K-1M | Caching, vertical scaling |
| **Growth** | 10K-100K | 1M-10M | Horizontal scaling, read replicas |
| **Scale** | 100K-1M | 10M-100M | Multi-region, sharding, microservices |

### Database Scaling

#### Vertical Scaling (0-100K users)

**Strategy**: Upgrade instance size
- Start: 1vCPU, 2GB RAM ($10/month)
- Growth: 2vCPU, 8GB RAM ($100/month)
- Max: 8vCPU, 32GB RAM ($500/month)

**Pros**: Simple, no code changes
**Cons**: Expensive, eventual limit

#### Read Replicas (100K-500K users)

**Strategy**: Offload reads to replicas
- 1 primary (writes)
- 2-3 replicas (reads)
- Route 80% reads to replicas

**Implementation:**
```javascript
// Write to primary
await primaryDB.query('INSERT INTO favorites ...');

// Read from replica
await replicaDB.query('SELECT * FROM favorites ...');
```

**Cost**: 2x database cost, but handles 5x traffic

#### Horizontal Sharding (500K+ users)

**Strategy**: Partition data across multiple databases

**Sharding Key**: `city_id` or `user_id`

**Example (by city):**
- DB1: San Francisco data
- DB2: New York data
- DB3: Los Angeles data

**Pros**: Near-infinite scaling
**Cons**: Complex queries (cross-shard joins), more code

**Tools**: Citus (PostgreSQL extension), Vitess

**When to Consider**: 500K+ users, $5K+/month DB costs

### Caching Layers

**Scaling Impact:**
- 80% cache hit rate → 5x more traffic on same infra
- 95% cache hit rate → 20x more traffic

**Redis Scaling:**
- Single instance: 0-100K users
- Redis Cluster: 100K-1M users
- Multi-region Redis: 1M+ users

### Load Balancing

**When**: 2+ API server instances

**Options:**
- Railway/Fly.io: Built-in (auto)
- AWS: Application Load Balancer (ALB)
- NGINX: Self-managed

**Strategy:**
- Round-robin or least-connections
- Health checks (remove unhealthy instances)
- SSL termination at load balancer

### When to Worry About Scale?

**Don't Premature Optimize:**
- <10K users: Single instance fine
- <100K users: Vertical scaling + caching sufficient
- <500K users: Read replicas enough

**Optimize When:**
- Response times >500ms at p95
- Database CPU >70% consistently
- Costs growing faster than revenue
- Approaching hard limits (DB connections)

---

## 14. Security Best Practices

### OWASP Top 10 for APIs

1. **Broken Object Level Authorization**
   - Check user owns resource before read/update/delete
   ```javascript
   const favorite = await db.query('SELECT * FROM favorites WHERE id = ? AND user_id = ?', [id, req.user.id]);
   if (!favorite) return res.status(403).json({ error: 'Forbidden' });
   ```

2. **Broken Authentication**
   - Use JWT properly, validate on every request
   - Refresh token rotation
   - No API keys in URLs

3. **Excessive Data Exposure**
   - Return only needed fields
   - Don't expose internal IDs/structure

4. **Lack of Resources & Rate Limiting**
   - Implement per-user rate limits (see Section 2)

5. **Broken Function Level Authorization**
   - Check user role/permissions for admin actions

6. **Mass Assignment**
   - Validate input, don't blindly accept all fields
   ```javascript
   // BAD: Allows users to set is_admin=true
   await db.update('users', req.body);

   // GOOD: Whitelist fields
   const { email, name } = req.body;
   await db.update('users', { email, name });
   ```

7. **Security Misconfiguration**
   - Disable debug mode in production
   - Remove default credentials
   - Update dependencies (Dependabot)

8. **Injection**
   - Use parameterized queries (ORM or prepared statements)
   ```javascript
   // BAD: SQL injection
   await db.query(`SELECT * FROM stops WHERE id = '${req.params.id}'`);

   // GOOD: Parameterized
   await db.query('SELECT * FROM stops WHERE id = ?', [req.params.id]);
   ```

9. **Improper Assets Management**
   - Document all API endpoints
   - Deprecate old versions
   - No test endpoints in production

10. **Insufficient Logging & Monitoring**
    - Log auth failures, access to sensitive data
    - Alert on anomalies (Sentry)

### Security Checklist

**Pre-Launch:**
- [ ] HTTPS enforced (redirect HTTP)
- [ ] JWT secrets in environment variables
- [ ] Database credentials not in code
- [ ] Input validation on all endpoints
- [ ] Rate limiting enabled
- [ ] Error messages don't leak info
- [ ] CORS configured (restrict origins)
- [ ] Security headers (helmet.js)
- [ ] Dependencies updated (no critical CVEs)
- [ ] SQL injection tested (parameterized queries)

**Post-Launch:**
- [ ] Monitor logs for suspicious activity
- [ ] Update dependencies monthly
- [ ] Rotate secrets quarterly
- [ ] Review access logs
- [ ] Security audit (if scaling)

### Compliance (if needed)

**GDPR (EU users):**
- [ ] Privacy policy
- [ ] Cookie consent (website)
- [ ] Data export (user request)
- [ ] Account deletion (within 30 days)
- [ ] Data breach notification (72hr)

**CCPA (California users):**
- [ ] Privacy policy (data collection disclosure)
- [ ] Opt-out of data sale (if applicable)

**COPPA (if <13 users):**
- [ ] Parental consent
- [ ] Data minimization

**Recommendation**: Avoid collecting data from <13, enforce 13+ in ToS

---

## 15. Implementation Roadmap

### Phase 1: MVP (Weeks 1-8)

**Goal**: iOS app with basic transit features

**Backend Features:**
1. REST API foundation (Express/FastAPI/Vapor)
2. PostgreSQL schema (stops, routes, trips)
3. GTFS static import (one-time script)
4. Basic endpoints (routes, stops, search)
5. Apple Sign-In integration
6. Favorites CRUD
7. Deploy to Railway/Fly.io

**Infra:**
- Single API instance
- Managed PostgreSQL
- No Redis yet (premature)
- CloudFlare CDN (free)

**Cost**: $25-50/month

**Success Metrics:**
- API functional
- <500ms response times
- Deployed and accessible

### Phase 2: Real-Time (Weeks 9-12)

**Goal**: Live arrival times, service alerts

**Backend Features:**
1. GTFS-RT poller (background job)
2. Redis caching (real-time data)
3. Real-time arrivals endpoint
4. Service alerts endpoint
5. SSE for live updates (iOS app)

**Infra:**
- Add Redis ($5-10/month)
- Background worker (same instance or separate)

**Cost**: $40-70/month

**Success Metrics:**
- Real-time data updates every 30-60sec
- <100ms cache response times
- 80%+ cache hit rate

### Phase 3: Notifications (Weeks 13-16)

**Goal**: Push notifications for delays, alerts

**Backend Features:**
1. APNs integration (token-based JWT)
2. Alert engine (match alerts to user favorites)
3. Push queue (Redis or DB)
4. APNs worker (background service)
5. Notification preferences API

**Infra:**
- Same as Phase 2 (APNs free)

**Cost**: $40-70/month

**Success Metrics:**
- Push notifications delivered <5sec
- 90%+ delivery rate
- No spam (proper deduplication)

### Phase 4: Polish & Scale (Weeks 17-24)

**Goal**: Production-ready, 1K+ users

**Backend Features:**
1. API versioning (v1)
2. Rate limiting (per-user, per-IP)
3. Error tracking (Sentry)
4. Analytics (Plausible or PostHog)
5. Monitoring dashboards
6. Automated tests (unit, integration)
7. CI/CD pipeline (GitHub Actions)
8. Caching optimizations
9. Database indexing
10. Documentation (API docs)

**Infra:**
- Optimize instance size
- Aggressive caching
- Set up alerts (uptime, errors)

**Cost**: $50-100/month

**Success Metrics:**
- 99.9% uptime
- <500ms p95 response times
- Zero critical bugs

### Phase 5: Marketing Site (Parallel to Phase 4)

**Goal**: Public-facing website

**Tech Stack:** Next.js (Static Site Generation) + Vercel

**Features:**
1. Landing page
2. About, Privacy, Terms
3. Blog (optional)
4. App Store link

**Cost**: Free (Vercel) or $20/month

### Phase 6: Web Dashboard (2026)

**Goal**: Web app for trip planning

**Tech Stack:** Next.js (SSR/SPA) + same backend API

**Backend Changes:**
1. GraphQL endpoint (optional, for complex queries)
2. WebSocket/SSE for real-time (already have SSE)
3. Shared TypeScript types

**Infra:**
- Same backend API
- Deploy web app to Vercel or self-host

**Cost**: +$20-50/month

---

## 16. Risks & Mitigations

### Technical Risks

**Risk: GTFS Feed Downtime**
- **Impact**: No real-time data
- **Mitigation**:
  - Monitor feed health (alerts)
  - Fallback to scheduled times
  - Cache last known good data (stale but useful)
  - Display "data may be outdated" warning

**Risk: Database Performance Bottleneck**
- **Impact**: Slow API responses
- **Mitigation**:
  - Aggressive caching (Redis)
  - Database indexing
  - Read replicas
  - Query optimization (EXPLAIN ANALYZE)

**Risk: Vendor Lock-In (Railway/Fly.io)**
- **Impact**: Hard to migrate
- **Mitigation**:
  - Use Docker (portable)
  - Avoid vendor-specific features
  - Document infra (IaC with Terraform/Pulumi)
  - Plan migration path to AWS/GCP

**Risk: APNs Token Expiry**
- **Impact**: Push notifications fail
- **Mitigation**:
  - Tokens valid 1 year
  - Set expiry reminder (11 months)
  - Automated renewal script
  - Monitor APNs error rates

**Risk: API Breaking Changes**
- **Impact**: iOS app crashes
- **Mitigation**:
  - API versioning (v1, v2)
  - Deprecation warnings (headers)
  - Maintain old versions (12-18 months)
  - Additive changes only (backward compatible)

### Scaling Risks

**Risk: Sudden Traffic Spike (press coverage)**
- **Impact**: API overload, downtime
- **Mitigation**:
  - Auto-scaling enabled (Railway/Fly.io)
  - Rate limiting (protect backend)
  - CDN for static assets
  - Load testing (before launch)

**Risk: Database Connection Pool Exhaustion**
- **Impact**: API errors (can't connect to DB)
- **Mitigation**:
  - Set max connections (100-200 for startup)
  - Connection pooling (pgBouncer)
  - Monitor connection usage
  - Scale DB instance or add replicas

**Risk: Redis Memory Full**
- **Impact**: Cache evictions, slower responses
- **Mitigation**:
  - Set eviction policy (LRU)
  - Monitor memory usage (alert at 80%)
  - TTLs on all keys
  - Scale Redis instance

### Security Risks

**Risk: JWT Secret Leaked**
- **Impact**: Attackers can forge tokens
- **Mitigation**:
  - Rotate secrets quarterly
  - Use secret manager (not in code)
  - Revoke all tokens if compromised (blacklist + force re-auth)

**Risk: SQL Injection**
- **Impact**: Data breach
- **Mitigation**:
  - Use ORM or parameterized queries
  - Code review (automated tools: SQLmap)
  - Regular security audits

**Risk: DDoS Attack**
- **Impact**: API unavailable
- **Mitigation**:
  - CloudFlare DDoS protection (free tier)
  - Rate limiting
  - Auto-scaling (absorb traffic)
  - Geoblocking if needed

### Business Risks

**Risk: High Infrastructure Costs**
- **Impact**: Burn through budget
- **Mitigation**:
  - Start with cheap hosting (Railway/Fly.io)
  - Aggressive caching (reduce compute)
  - Monitor costs weekly
  - Set billing alerts (AWS, Railway)
  - Optimize before scaling (profiling)

**Risk: GTFS Feed Changes (breaking schema)**
- **Impact**: Parsing fails, no data
- **Mitigation**:
  - Validate GTFS files (gtfs-validator)
  - Error handling (log failures, alert)
  - Fallback to cached data
  - Monitor feed schemas (automated checks)

**Risk: Apple App Store Rejection**
- **Impact**: Can't launch
- **Mitigation**:
  - Follow App Store guidelines
  - Apple Sign-In required (if offering other auth)
  - Privacy policy (transit data usage)
  - Test thoroughly

---

## 17. Deployment Architecture Diagrams

### MVP Architecture (Phase 1-3)

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────────────┬────────────────────────────────────────────────┘
             │
        ┌────┴────┐
        │ iOS App │
        └────┬────┘
             │
        ┌────┴───────────────────────────────────────────────┐
        │              CloudFlare CDN (Free)                  │
        │   ┌─────────────────────────────────────────┐      │
        │   │  GTFS Static Files (routes, stops)      │      │
        │   └─────────────────────────────────────────┘      │
        └────┬───────────────────────────────────────────────┘
             │
        ┌────┴────────────────────────────────────────────────┐
        │           Railway / Fly.io                          │
        │  ┌──────────────────────────────────────────────┐   │
        │  │         API Server (Node.js/Python/Go)       │   │
        │  │  ┌────────────────────────────────────────┐  │   │
        │  │  │  REST API                              │  │   │
        │  │  │  - /api/v1/routes                      │  │   │
        │  │  │  - /api/v1/stops/:id/arrivals          │  │   │
        │  │  │  - /api/v1/auth/apple                  │  │   │
        │  │  │  - /api/v1/favorites                   │  │   │
        │  │  │  - /api/v1/alerts                      │  │   │
        │  │  └────────────────────────────────────────┘  │   │
        │  │                                                │   │
        │  │  ┌────────────────────────────────────────┐  │   │
        │  │  │  Background Worker                     │  │   │
        │  │  │  - GTFS-RT Poller (every 60sec)       │  │   │
        │  │  │  - Alert Engine                        │  │   │
        │  │  │  - APNs Worker                         │  │   │
        │  │  └────────────────────────────────────────┘  │   │
        │  └──────┬──────────────────┬──────────────────┬──┘   │
        │         │                  │                  │      │
        │    ┌────┴────┐      ┌──────┴──────┐    ┌─────┴────┐ │
        │    │ PostgreSQL│    │    Redis    │    │  Volumes │ │
        │    │ (Managed) │    │  (Managed)  │    │  (GTFS)  │ │
        │    └───────────┘    └─────────────┘    └──────────┘ │
        └─────────────────────────────────────────────────────┘
                                  │
                         ┌────────┴────────┐
                         │   Apple APNs    │
                         │ (Push Notifs)   │
                         └─────────────────┘
```

### Growth Architecture (Phase 4+, AWS)

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────┬────────────────────────────────────────────────────┬───┘
     │                                                     │
┌────┴────┐                                          ┌────┴────┐
│ iOS App │                                          │  Web    │
└────┬────┘                                          │Dashboard│
     │                                               └────┬────┘
     │                                                    │
┌────┴────────────────────────────────────────────────────┴───┐
│                   CloudFront CDN                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  S3: GTFS Static Files, Route Maps, Static Assets   │   │
│  └──────────────────────────────────────────────────────┘   │
└────┬─────────────────────────────────────────────────────────┘
     │
┌────┴─────────────────────────────────────────────────────────┐
│         Application Load Balancer (ALB)                      │
└────┬────────────────────────────────────────────┬────────────┘
     │                                             │
┌────┴──────────────────────┐         ┌───────────┴────────────┐
│   ECS Fargate Cluster     │         │ Background Workers     │
│  ┌──────┐ ┌──────┐ ┌──────┐│        │ (ECS Fargate)         │
│  │ API  │ │ API  │ │ API  ││        │ ┌──────────────────┐  │
│  │ Task │ │ Task │ │ Task ││        │ │ GTFS-RT Poller   │  │
│  │  1   │ │  2   │ │  3   ││        │ │ Alert Engine     │  │
│  └──┬───┘ └──┬───┘ └──┬───┘│        │ │ APNs Worker      │  │
│     │        │        │    │        │ └────────┬─────────┘  │
│     └────────┴────────┘    │        └───────────┼────────────┘
└─────────┬──────────────────┘                   │
          │                                       │
     ┌────┴─────────────┐                        │
     │  ElastiCache     │                        │
     │  Redis Cluster   │                        │
     │  ┌───────────┐   │                        │
     │  │ Primary   │   │                        │
     │  └─────┬─────┘   │                        │
     │  ┌─────┴─────┐   │                        │
     │  │ Replica 1 │   │                        │
     │  └───────────┘   │                        │
     └──────────────────┘                        │
          │                                       │
     ┌────┴──────────────────────────────────────┴─────────┐
     │          RDS PostgreSQL (Multi-AZ)                  │
     │  ┌──────────────┐          ┌──────────────┐         │
     │  │   Primary    │  ──────→ │  Replica 1   │         │
     │  │   (Writes)   │          │   (Reads)    │         │
     │  └──────────────┘          └──────────────┘         │
     │                            ┌──────────────┐         │
     │                            │  Replica 2   │         │
     │                            │   (Reads)    │         │
     │                            └──────────────┘         │
     └────────────────────────────────────────────────────┘
                                  │
                         ┌────────┴────────┐
                         │   Apple APNs    │
                         │ (Push Notifs)   │
                         └─────────────────┘

┌────────────────────────────────────────────────────────────┐
│                   Monitoring & Logging                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Sentry   │  │CloudWatch│  │ Datadog  │  │  Logs    │   │
│  │ (Errors) │  │ (Metrics)│  │  (APM)   │  │ (S3/ES)  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└────────────────────────────────────────────────────────────┘
```

---

## 18. Final Recommendations

### Recommended Stack (MVP)

**Language**: Node.js (or Python FastAPI if team prefers)
**Framework**: Express.js (or Fastify for speed)
**Database**: PostgreSQL 15+ (Railway managed)
**Cache**: Redis (Railway managed)
**Hosting**: Railway (simplest) or Fly.io (cheapest)
**CDN**: CloudFlare (free tier)
**Auth**: JWT with Apple Sign-In
**Error Tracking**: Sentry (free tier)
**Analytics**: Self-hosted Plausible or PostHog free tier

**Why?**
- Node.js: Fastest dev iteration, huge ecosystem, JSON-native
- PostgreSQL: Best choice for structured transit data, geospatial support
- Railway: Simplest deploy, auto-scale, managed DB/Redis
- CloudFlare: Free CDN, DDoS protection, unlimited bandwidth

### When to Migrate Stack

**10K users**: Optimize caching, vertical scaling (same stack)
**50K users**: Consider migration to AWS/GCP, add read replicas
**100K users**: Multi-region, microservices extraction, horizontal sharding
**500K users**: Full microservices, multi-region DB, dedicated ops team

### Cost Trajectory

| Users | Monthly Cost | Notes |
|-------|-------------|-------|
| 0-1K | $25-50 | Free tiers, Railway hobby |
| 1K-10K | $50-150 | Scaled Railway, Redis, monitoring |
| 10K-50K | $150-500 | AWS migration point, read replicas |
| 50K-100K | $500-1,500 | Multi-region, dedicated Redis cluster |
| 100K-500K | $1,500-5K | Microservices, sharding, ops team |

### Key Success Factors

1. **Start simple**: Modular monolith, single region, managed services
2. **Cache aggressively**: 70% cost savings from Redis + CDN
3. **Monitor early**: Sentry + logs catch issues before users complain
4. **Scale gradually**: Don't over-engineer, optimize when metrics show need
5. **Security first**: JWT properly, rate limiting, input validation
6. **Privacy-compliant**: GDPR/CCPA ready, minimize data collection

### Avoid These Mistakes

1. **Microservices too early**: Adds complexity, slows development
2. **No caching**: 3-5x more expensive compute
3. **Over-provisioning**: Start small, scale up
4. **Ignoring monitoring**: Bugs in production cost users
5. **Complex auth**: Apple Sign-In + JWT is sufficient
6. **Too many vendors**: Stick to 2-3 platforms (Railway, CloudFlare, Sentry)

---

## Appendix: Tech Stack Quick Reference

### Language Performance (Baseline: Go Fiber = 1x)

- **Go (Fiber)**: 1x (fastest)
- **Node.js (Express)**: 7.5x slower
- **Python (FastAPI)**: 11x slower
- **Swift (Vapor)**: 1.2x slower (comparable to Go)

### Database Comparison

| Feature | PostgreSQL | MongoDB |
|---------|-----------|---------|
| Type | Relational | NoSQL Document |
| Schema | Fixed | Flexible |
| ACID | Strong | Weak (improving) |
| Geospatial | PostGIS (best) | Basic |
| Scaling | Vertical → sharding | Horizontal (built-in) |
| Use Case | Structured, relational | Unstructured, flexible |
| **Verdict** | ✅ **Recommended** | ❌ Not ideal for transit |

### Hosting Quick Comparison (Startup Phase)

| Feature | Railway | Fly.io | AWS |
|---------|---------|--------|-----|
| Ease | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| Cost (MVP) | $20-50/mo | $15-40/mo | $50-100/mo |
| Scaling | Auto | Auto | Manual/Complex |
| Free Tier | $5 credit | ~Free (<$5) | 12 months |
| **Verdict** | ✅ **Simplest** | ✅ **Cheapest** | ❌ Too complex early |

### Real-Time Delivery Comparison

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| **Polling** | Legacy fallback | Simple, HTTP/1.1 | High latency, wasteful |
| **SSE** | One-way updates | Auto-reconnect, simple | Server→client only |
| **WebSocket** | Bidirectional | Low latency | Complex, no auto-reconnect |
| **Verdict** | **SSE** for transit apps | ✅ Best for arrival updates | - |

### Monitoring Tools Quick Reference

| Tool | Use Case | Cost (Startup) | Verdict |
|------|----------|---------------|---------|
| **Sentry** | Error tracking | Free-$26/mo | ✅ Essential |
| **Plausible** | Web analytics | Free (self-host) | ✅ Best privacy |
| **PostHog** | Product analytics | Free (self-host) | ✅ iOS app insights |
| **Datadog** | APM/Logs | $15+/host/mo | ❌ Expensive early |
| **CloudWatch** | AWS metrics | Pay-per-use | ✅ If on AWS |

---

## Questions for Refinement

1. **Multi-city support**: Launch with 1 city or multiple? (Affects GTFS poller complexity)
2. **Offline mode**: Cache GTFS static for offline? (Affects iOS app size, less backend)
3. **Trip planning**: Basic (single route) or advanced (multi-leg)? (Affects algorithm complexity)
4. **Marketing site**: Launch with or after iOS? (Can be parallel)
5. **Analytics depth**: Simple (pageviews) or deep (funnels, retention)? (Affects tool choice)
6. **Budget ceiling**: Max monthly budget? (Affects hosting choice)

---

**Document Version**: 1.0
**Last Updated**: October 30, 2025
**Sources**: Web research 2024-2025, AWS/GCP docs, HackerNews, Reddit, Stack Overflow surveys

---

**Next Steps**:
1. Choose tech stack (Node.js vs Python vs Go vs Vapor)
2. Set up Railway/Fly.io account
3. Initialize codebase (boilerplate)
4. Design database schema (PostgreSQL)
5. Implement GTFS static import script
6. Build REST API endpoints (MVP)
7. Apple Sign-In integration
8. Deploy MVP
9. GTFS-RT poller (Phase 2)
10. Push notifications (Phase 3)
