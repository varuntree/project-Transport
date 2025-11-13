# Backend Architecture Patterns for Transit App
*Research compiled: October 2025*

## Executive Summary

**Recommended Architecture**: Modular Monolith with Supabase (PostgreSQL + Auth + Storage), REST API, Redis caching
**Tech Stack**: **Python (FastAPI)** - best for GTFS ecosystem, background jobs (Celery), future ML
**Database & Services**: **Supabase** - consolidates database, authentication, and file storage
**Hosting**: Railway or Fly.io (startup phase) → AWS/GCP (scale phase)
**Estimated Cost**: $0-25/month (MVP with Supabase free tier) → $100-300/month (10K users) → $500-1.5K/month (100K users)

**Note:** Next.js should be used ONLY for static marketing site (deployed to Vercel), NOT as API backend.

### Key Decisions Framework

| Decision | Recommendation | Rationale |
|----------|---------------|-----------|
| Architecture | Modular Monolith | Simpler ops, faster iteration, easy to extract services later |
| API Style | REST (primary) + GraphQL (consider 2026) | REST better for caching, simpler for iOS client, mature tooling |
| Database | Supabase (PostgreSQL) | ACID compliance, geospatial support, built-in auth & storage, generous free tier |
| Caching | Redis + CDN | Critical for GTFS static data, reduces compute costs |
| Real-time | SSE (server-sent events) | One-way updates, auto-reconnect on mobile, simpler than WebSockets |
| Auth | Supabase Auth + Apple Sign-In | Built-in JWT, Apple Sign-In integration, stateless, mobile-friendly |
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
[Supabase PostgreSQL] - Source of truth
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

### Layer 3: Database (Supabase PostgreSQL)

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
                                        [Supabase]
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
- Store favorites/saved trips in Supabase
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

#### Python (FastAPI/Django) - RECOMMENDED FOR THIS PROJECT

**Pros:**
- FastAPI: Modern, async, auto-generated docs (OpenAPI/Swagger)
- Django: Batteries-included, admin panel
- Excellent data processing libraries
- **GTFS parsing libraries mature** (critical for transit apps)
- **Celery for background jobs** (perfect for GTFS-RT polling, alerts, APNs)
- Good for ML/analytics later (predictive transit)
- Great for continuous workers (unlike Next.js API routes)

**Cons:**
- Slower than Node.js (11x slower than Go) - but irrelevant with caching
- GIL limits multi-threading (use async)

**Use Case**: **IDEAL for transit apps** - GTFS ecosystem + background jobs + future ML

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

#### Supabase (PostgreSQL + Auth + Storage) - RECOMMENDED

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

**Decision**: Supabase (PostgreSQL) better for transit data (structured, geospatial, integrity, plus built-in auth & storage)

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
- Typical: $0-25/month (Supabase free tier + small backend instance)
- $5 free credits for testing

**Pros:**
- Dead simple deploy (connect GitHub)
- Built-in Redis (use Supabase for database separately)
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
  ├── Supabase (database + auth + storage)
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
- Supabase: Free tier (500MB database + auth + 1GB storage)
- Plausible: Self-host analytics (free)

**Strategy:**
- Single instance (1vCPU, 2GB RAM)
- Supabase free tier
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

### Marketing Website (Static/SSG) - SEPARATE FROM API BACKEND

**Recommended**: Static Site Generation (Next.js, Astro, Hugo)

**Why?**
- Fast (pre-rendered HTML)
- Cheap (host on Vercel/Netlify free)
- SEO-friendly
- No backend needed
- **IMPORTANT**: Marketing site ≠ API backend (different workloads, separate deployment)

**Architecture:**
```
Next.js (Static) → Vercel (free)
  ├── Landing page
  ├── About, Privacy, Terms
  └── Blog (optional)
```

**API Integration:** Minimal (maybe route/city list for SEO)

**Cost**: Free (Vercel/Netlify free tier) or $20/month (pro tier)

**Critical Separation**: Do NOT use Next.js API Routes for production backend - use FastAPI instead.

### Future Web Dashboard (2026)

**Recommended**: Next.js (React) with SSR or SPA

**Why?**
- Shared API (same FastAPI backend as iOS)
- Real-time updates (SSE)
- Auth (same JWT system)

**Architecture:**
```
Next.js (SSR/SPA) → Vercel or self-hosted
  ↓
Same FastAPI REST API as iOS app
```

**Considerations:**
- GraphQL for complex queries (trip planning UI) - can add to FastAPI with Strawberry/Graphene
- WebSocket/SSE for live updates - FastAPI supports both natively
- OpenAPI schema from FastAPI → TypeScript types via openapi-typescript

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
2. Supabase schema (stops, routes, trips, user data)
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

### Recommended Stack (MVP) - UPDATED

**Language**: **Python (FastAPI)** - for transit apps specifically
**Framework**: FastAPI + Celery (background workers)
**Database**: Supabase (PostgreSQL + Auth + Storage)
**Cache**: Redis (Railway managed) + Celery broker
**Hosting**: Railway (simplest) or Fly.io (cheapest)
**CDN**: CloudFlare (free tier)
**Auth**: JWT with Apple Sign-In
**Error Tracking**: Sentry (free tier)
**Analytics**: Self-hosted Plausible or PostHog free tier
**Marketing Site**: Next.js (SSG) on Vercel (free)

**Why FastAPI over Node.js for this project?**
- **GTFS ecosystem**: Mature Python libraries (gtfs-realtime-bindings)
- **Background jobs**: Celery is battle-tested for GTFS-RT polling, alert engine, APNs workers
- **Future ML**: Predictive transit times, route optimization
- **Auto docs**: OpenAPI/Swagger generated automatically
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
