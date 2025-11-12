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
