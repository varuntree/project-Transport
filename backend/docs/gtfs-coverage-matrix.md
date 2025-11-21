# GTFS Static Feed Coverage Matrix

This matrix documents which NSW static GTFS feeds we use, and how they participate in the GTFS static pipeline.

| Feed Key      | Endpoint                                             | Used for Download | Used for Pattern Model (trips/stop_times) | Used for Stop/Route Coverage | Notes |
|--------------|------------------------------------------------------|-------------------|-------------------------------------------|-------------------------------|-------|
| sydneytrains | `/v1/gtfs/schedule/sydneytrains`                     | ✅                | ✅                                        | ✅                            | Sydney Trains static aligned with v1 realtime feeds. |
| metro        | `/v2/gtfs/schedule/metro`                            | ✅                | ✅                                        | ✅                            | Metro static aligned with v2 realtime feeds. |
| buses        | `/v1/gtfs/schedule/buses`                            | ✅                | ✅                                        | ✅                            | All bus operators used for pattern model + coverage. |
| sydneyferries| `/v1/gtfs/schedule/ferries/sydneyferries`            | ✅                | ✅                                        | ✅                            | Sydney Ferries static aligned with ferry realtime. |
| mff          | `/v1/gtfs/schedule/ferries/MFF`                      | ✅                | ✅                                        | ✅                            | Manly Fast Ferry static aligned with MFF realtime. |
| lightrail    | `/v1/gtfs/schedule/lightrail`                        | ✅                | ✅                                        | ✅                            | Light rail static for L1/L2/L3; used in pattern model. |
| complete     | `/v1/publictransport/timetables/complete/gtfs`       | ✅                | ❌                                        | ✅ (agencies/stops/routes)    | Full NSW bundle, used to augment coverage only (no trips/stop_times used). |
| ferries_all  | `/v1/gtfs/schedule/ferries`                          | ✅                | ❌                                        | ✅ (agencies/stops/routes)    | All ferry contracts; used to ensure wharves like Davistown Central RSL Wharf are present. |
| nswtrains    | `/v1/gtfs/schedule/nswtrains`                        | ✅                | ❌                                        | ✅ (agencies/stops/routes)    | NSW TrainLink regional trains; coverage-only in current pattern model. |
| regionbuses  | `/v1/gtfs/schedule/regionbuses`                      | ✅                | ❌                                        | ✅ (agencies/stops/routes)    | Regional buses; provides coverage for regional stops beyond main Sydney feeds. |

## Coverage Model Summary

- **Pattern model feeds:** `sydneytrains`, `metro`, `buses`, `sydneyferries`, `mff`, `lightrail`  
  These supply `trips`, `stop_times`, and associated `routes`/`calendar` for pattern extraction and GTFS‑RT alignment.

- **Coverage-only feeds:** `complete`, `ferries_all`, `nswtrains`, `regionbuses`  
  These are merged into `agencies`, `stops`, and `routes` to improve stop and route coverage (especially for ferry wharves and regional services). They do **not** currently contribute `trips`/`stop_times` to the pattern model.

## Davistown Central RSL Wharf

Davistown Central RSL Wharf is used as a reference “must-exist” stop in validation. It is expected to appear in at least one of:

- The broader ferry static feeds (`ferries_all` or `complete`), and
- The Sydney bbox used in `_apply_sydney_filter`.

If this stop is missing after a GTFS load, validation in `gtfs_static_sync._validate_load` will fail and surface this as a critical coverage error.

