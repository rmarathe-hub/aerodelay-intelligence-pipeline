# Data Sources

This document describes the external datasets used by the **AeroDelay Intelligence Pipeline**. Both sources are public, free to access, and require no API keys for the project's download approach.

---

## Overview

| Source | Purpose | Grain |
|--------|---------|-------|
| BTS / TranStats On-Time Performance | Flight-level delay and operations data | One row per flight |
| Iowa State Mesonet ASOS/METAR | Airport weather observations | One row per station observation |

Reference files:

- `docs/airports_45.csv` — 45 major U.S. airports in project scope
- `docs/airport_station_map.csv` — airport-to-weather-station mapping

---

## 1. BTS / TranStats Reporting Carrier On-Time Performance

### Description

The U.S. Bureau of Transportation Statistics (BTS) **Reporting Carrier On-Time Performance** dataset contains scheduled and actual flight times, delay minutes, cancellation/diversion flags, taxi and airborne times, distance, and delay cause breakdowns for U.S. reporting carriers.

**Official portal:** [BTS TranStats — On-Time Performance (DB_ID=120)](https://www.transtats.bts.gov/Tables.asp?DB_ID=120)

### Use in this project

Flight-level on-time performance data is the core fact table input. The pipeline ingests raw monthly files, loads them into `raw.bts_flights`, and transforms them through dbt staging and fact models.

### Key fields used

| Category | Fields |
|----------|--------|
| Identity | `Year`, `Month`, `FlightDate`, `Reporting_Airline`, `Flight_Number_Reporting_Airline`, `Tail_Number` |
| Airports | `Origin`, `Dest`, `OriginCityName`, `DestCityName`, `OriginState`, `DestState` |
| Times | `CRSDepTime`, `DepTime`, `WheelsOff`, `WheelsOn`, `CRSArrTime`, `ArrTime` |
| Delays | `DepDelay`, `DepDelayMinutes`, `DepDel15`, `ArrDelay`, `ArrDelayMinutes`, `ArrDel15` |
| Operations | `TaxiOut`, `TaxiIn`, `Cancelled`, `CancellationCode`, `Diverted` |
| Duration / distance | `CRSElapsedTime`, `ActualElapsedTime`, `AirTime`, `Distance`, `DistanceGroup`, `Flights` |
| Delay causes | `CarrierDelay`, `WeatherDelay`, `NASDelay`, `SecurityDelay`, `LateAircraftDelay` |

Additional BTS columns are preserved in the raw layer for auditability; staging models select and type the fields needed downstream.

### Download format

- Monthly **ZIP** files containing a single large **CSV**
- Filename pattern: `On_Time_Reporting_Carrier_On_Time_Performance_1987_present_YYYY_M.csv.zip`
- Direct HTTP download (no API key required)

### Scope

| Phase | Scope |
|-------|-------|
| **Development sample** | January 2025 (manually downloaded and verified) |
| **Production pipeline** | 2023–2025, filtered to **45 origin airports** defined in `docs/airports_45.csv` |

---

## 2. Iowa State Mesonet ASOS/METAR

### Description

The [Iowa Environmental Mesonet (IEM)](https://mesonet.agron.iastate.edu/) provides historical **ASOS/METAR** airport weather observations. These are the same automated surface observations reported at U.S. airports and used for aviation weather.

**ASOS request endpoint:** [IEM ASOS Data Download](https://mesonet.agron.iastate.edu/request/download.phtml?network=ASOS)

### Use in this project

Weather observations are joined to flights at **departure time** for the **origin airport**. Raw observations load into `raw.weather_observations`; staging normalizes timestamps and numeric fields; intermediate models find the nearest observation to each flight's scheduled or actual departure.

### Key fields used

| Field | Description |
|-------|-------------|
| `station` | Weather station ID (mapped from airport via `docs/airport_station_map.csv`) |
| `valid` | Observation timestamp (converted to UTC in staging) |
| `tmpf` | Temperature (°F) |
| `dwpf` | Dew point (°F) |
| `relh` | Relative humidity (%) |
| `drct` | Wind direction (degrees) |
| `sknt` | Wind speed (knots) |
| `p01i` | One-hour precipitation (inches); `M` = missing, `T` = trace |
| `vsby` | Visibility (miles) |
| `gust` | Wind gust (knots) |
| `skyc1`, `skyc2`, `skyc3` | Sky condition layers |
| `wxcodes` | Weather phenomenon codes |
| `metar` | Raw METAR text |

### Download format

- **CSV** via IEM's ASOS request form or direct HTTP query
- Station IDs match airport codes for all 45 mapped airports (see `docs/airport_station_map.csv`)
- No API key required

### Scope

| Phase | Scope |
|-------|-------|
| **Development sample** | ATL, ORD, LAX — January 2025 (manually downloaded and verified) |
| **Production pipeline** | All **45 weather stations** from `docs/airport_station_map.csv`, 2023–2025 |

### Timestamp handling

All observation timestamps are normalized to **UTC** in the staging layer. Local airport timezones (from `docs/airports_45.csv` region context) are used only for reference and documentation — the warehouse stores UTC to ensure consistent joins with BTS flight times.

---

## Development sample scope

Manual samples used to validate schema, column names, and join feasibility before building automated ingest:

| Dataset | Sample | Location |
|---------|--------|----------|
| BTS OTP | January 2025 (full month file) | `data/samples/` |
| Iowa Mesonet ASOS | ATL, ORD, LAX — January 2025 | `data/samples/` |

These samples confirmed:

- BTS CSV contains all 42 expected delay/operations columns
- Mesonet CSV contains all 15 important weather columns
- Station IDs `ATL`, `ORD`, `LAX` match airport codes
- Mesonet missing values use `M`; trace precipitation uses `T`

---

## Production scope

| Dataset | Airports / stations | Date range | Filter |
|---------|---------------------|------------|--------|
| BTS OTP | 45 origins (`docs/airports_45.csv`) | 2023–2025 | `Origin IN (45 airport codes)` |
| Iowa Mesonet ASOS | 45 stations (`docs/airport_station_map.csv`) | 2023–2025 (+ buffer days) | Per-station download |

Ingestion will be automated via Airflow DAGs (`ingest_bts`, `ingest_weather`) starting Week 1 Day 3+.

---

## Raw data storage policy

| Location | Contents | Git |
|----------|----------|-----|
| `data/samples/` | Manual development samples (BTS ZIP, weather CSVs) | **Ignored** |
| `data/raw/` | Automated pipeline downloads (future) | **Ignored** |
| `raw.*` (Postgres) | Loaded raw tables in the warehouse | N/A (database) |

Raw files can be large (BTS monthly CSVs are ~200+ MB uncompressed). They are never committed to Git.

---

## Git policy

The following are **gitignored** (see `.gitignore`):

```
data/
*.csv        # except docs/*.csv
*.zip
```

**Safe to commit:** `docs/airports_45.csv`, `docs/airport_station_map.csv`, documentation  
**Never commit:** BTS ZIPs, weather CSVs under `data/`, `.env`, secrets

---

## Known limitations

1. **Manual samples are small.** Development samples cover one BTS month and three weather stations. The full pipeline will automate multi-year, multi-station downloads.
2. **Sample weather dates end Jan 30, 2025.** Production backfill will request the full month including Jan 31.
3. **Station ID = airport code.** All 45 mappings use the same code (e.g. `ATL → ATL`). If a station proves unreliable during backfill, the mapping file will be updated with notes.
4. **Mesonet `M` and `T` values.** Missing (`M`) and trace (`T`) values must be handled in staging — they are not valid numerics.
5. **No real-time data.** This pipeline uses historical batch data, not live flight or weather feeds.

---

## Planned join method

Each flight will be matched to the **nearest weather observation** for the **origin airport** around **departure time**:

```
flight (origin airport, dep_time_utc)
  → lookup weather_station_id from airport_station_map
  → find nearest ASOS observation where |obs_time_utc - dep_time_utc| is minimized
  → prefer observation at or before departure (documented tie-break rules)
```

This nearest-observation join (not date-only) is the analytic core of the project and will be documented in `docs/weather_join_methodology.md` when implemented in dbt Week 3.

**Departure time fallback:** actual departure (`DepTime`) when available; scheduled departure (`CRSDepTime`) otherwise.

---

## Related documentation

- `docs/airports_45.csv` — airport reference
- `docs/airport_station_map.csv` — weather station mapping
- `docs/data_dictionary.md` — column-level definitions (Week 1 Day 2+)
- `docs/weather_join_methodology.md` — join rules (Week 3)
