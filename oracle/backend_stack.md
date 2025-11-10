# Backend Stack - Recommended Architecture
**For Implementation**

---

## Recommended Stack (MVP)

**Language**: Python (FastAPI)
**Framework**: FastAPI + Celery (background workers)
**Database**: PostgreSQL 15+ (Railway managed)
**Cache**: Redis (Railway managed) + Celery broker
**Hosting**: Railway (simplest) or Fly.io (cheapest)
**CDN**: CloudFlare (free tier)
**Auth**: JWT with Apple Sign-In
**Error Tracking**: Sentry (free tier)
**Analytics**: Self-hosted Plausible or PostHog free tier
**Marketing Site**: Next.js (SSG) on Vercel (free)

### Why FastAPI for Transit Apps

- **GTFS ecosystem**: Mature Python libraries (gtfs-realtime-bindings)
- **Background jobs**: Celery is battle-tested for GTFS-RT polling, alert engine, APNs workers
- **Future ML**: Predictive transit times, route optimization
- **Auto docs**: OpenAPI/Swagger generated automatically
- PostgreSQL: Best choice for structured transit data, geospatial support
- Railway: Simplest deploy, auto-scale, managed DB/Redis
- CloudFlare: Free CDN, DDoS protection, unlimited bandwidth

---

## Architecture Pattern

**Modular Monolith**
- Single deployable unit with well-defined internal module boundaries
- Simpler deployment (single container/process)
- Easier debugging and monitoring
- Lower infrastructure costs (87% less than microservices initially)
- Extract services later if needed

---

## Cost Trajectory

| Users | Monthly Cost | Notes |
|-------|-------------|-------|
| 0-1K | $25-50 | Free tiers, Railway hobby |
| 1K-10K | $50-150 | Scaled Railway, Redis, monitoring |
| 10K-50K | $150-500 | AWS migration point, read replicas |
| 50K-100K | $500-1,500 | Multi-region, dedicated Redis cluster |
| 100K-500K | $1,500-5K | Microservices, sharding, ops team |

**MVP Budget Constraint: $50/month max**

---

## Scaling Strategy

**10K users**: Optimize caching, vertical scaling (same stack)
**50K users**: Consider migration to AWS/GCP, add read replicas
**100K users**: Multi-region, microservices extraction, horizontal sharding
**500K users**: Full microservices, multi-region DB, dedicated ops team

---

## Key Design Principles

1. **Start simple**: Modular monolith, single region, managed services
2. **Cache aggressively**: 70% cost savings from Redis + CDN
3. **Monitor early**: Sentry + logs catch issues before users complain
4. **Scale gradually**: Don't over-engineer, optimize when metrics show need
5. **Security first**: JWT properly, rate limiting, input validation
6. **Privacy-compliant**: GDPR/CCPA ready, minimize data collection

---

## What NOT to Do

1. ❌ **Microservices too early**: Adds complexity, slows development
2. ❌ **No caching**: 3-5x more expensive compute
3. ❌ **Over-provisioning**: Start small, scale up
4. ❌ **Ignoring monitoring**: Bugs in production cost users
5. ❌ **Complex auth**: Apple Sign-In + JWT is sufficient
6. ❌ **Too many vendors**: Stick to 2-3 platforms (Railway, CloudFlare, Sentry)

---

## Hosting Options

### Railway (Recommended for MVP)
- **Ease**: Dead simple deploy (connect GitHub)
- **Cost**: $20-50/month (1 vCPU, 2GB RAM, PostgreSQL)
- **Pros**: Built-in PostgreSQL, Redis, auto-scaling, great DX
- **Use until**: 10K users

### Fly.io (Alternative)
- **Cost**: $15-40/month
- **Pros**: Global edge deployment, auto-scale to zero
- **Cons**: More manual config than Railway

### AWS/GCP (Migration at Scale)
- **When**: 50K+ users, need custom infrastructure
- **Cost**: $100-500/month initially

---

## Database: PostgreSQL

**Why:**
- ACID compliance (data integrity)
- PostGIS extension (geospatial queries)
- JSONB support (flexible schema)
- Mature, battle-tested
- Excellent scaling paths (replication, sharding)

**Scaling Path:**
1. Single instance (0-100K users)
2. Read replicas (100K-500K users)
3. Horizontal sharding by city (500K+ users)

---

## Real-Time Architecture

**Recommended: Server-Sent Events (SSE)**
- One-way updates (server → client)
- Auto-reconnect on mobile
- Simpler than WebSockets
- Perfect for arrival updates

---

## Monitoring & Error Tracking

**Sentry (Error tracking)**: Free tier, 5K events/month
**Plausible (Web analytics)**: Self-hosted (free) or cloud
**PostHog (Product analytics)**: Self-hosted for iOS app insights

**What to Track:**
- API uptime (99.9% target)
- Database latency
- GTFS feed update success rate
- Push notification delivery rate
- Error rates

---

## Security Best Practices

### JWT Implementation
- Access token: 15min expiry
- Refresh token: 30 days, stored in DB, revocable
- Apple Sign-In signature verification (ES256)

### API Security
- Rate limiting (Redis-based, per-user and per-IP)
- Input validation (Pydantic schemas)
- HTTPS only (TLS 1.3)
- Security headers (CORS, CSP, XSS protection)

### Data Encryption
- In transit: HTTPS, certificate pinning (iOS)
- At rest: Database encryption (Railway support)
- PII: Hash or encrypt sensitive data

---

## Deployment Architecture (MVP)

```
GitHub → Railway/Fly.io (auto-deploy)
  ├── API Server (FastAPI)
  ├── Background Workers (Celery)
  ├── PostgreSQL (managed)
  ├── Redis (managed)
  └── CloudFlare CDN (GTFS static files)
```

---

## Infrastructure as Code

**Not required for MVP** (Railway handles automatically)
**Consider at scale**: Terraform or Pulumi for AWS/GCP migration
