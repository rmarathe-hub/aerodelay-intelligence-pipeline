# Data Dictionary

Column-level definitions for the **AeroDelay Intelligence Pipeline**. This document describes raw source fields before dbt staging transformations.

**Sources:** BTS / TranStats On-Time Performance · Iowa Mesonet ASOS/METAR  
**Related docs:** [`data_sources.md`](data_sources.md) · [`airports_45.csv`](airports_45.csv) · [`airport_station_map.csv`](airport_station_map.csv)

| Phase | Flights | Weather |
|-------|---------|---------|
| Development sample | BTS January 2025 | ATL, ORD, LAX — January 2025 |
| **Current local warehouse** | **2025-01 → 2025-04 only (~1.69M rows)** | **ATL/ORD/LAX Jan 2025 + DEN Feb 2025 (~19.7K rows)** |
| Production target | 45 U.S. airports, 2023–2025 | 45 mapped stations, 2023–2025 |

See [`DATA_COVERAGE.md`](DATA_COVERAGE.md) for verified counts and on-disk files.

Raw files live under `data/` and are **not committed to Git**.

---

## 1. Dataset grain

### BTS flights (`raw.bts_flights`)

The raw BTS / TranStats **Reporting Carrier On-Time Performance** table is **flight-level**: one row per scheduled flight record reported by a U.S. carrier for a given flight date.

Each row represents a single operated or scheduled flight segment between an origin and destination airport, including scheduled times, actual times (when available), delay metrics, and operational flags.

**Planned staging grain:** one row per flight, keyed by a composite business key such as:

`Reporting_Airline` + `Flight_Number_Reporting_Airline` + `Origin` + `FlightDate` + `CRSDepTime`

Exact key definition will be finalized in dbt staging models and tested for uniqueness.

### Weather observations (`raw.weather_observations`)

The raw Iowa Mesonet ASOS/METAR table is **station-observation-level**: one row per weather observation at a station and timestamp.

Each row is a single automated surface observation (ASOS) or METAR report for one airport weather station at one `valid` time. Observations are typically hourly or sub-hourly depending on station reporting frequency.

**Planned staging grain:** one row per `(station, valid_utc)` after deduplication.

---

## 2. Flight identifiers

Fields that identify the flight, carrier, route, and calendar context.

| Field | Type (raw) | Description |
|-------|------------|-------------|
| `Year` | integer | Calendar year of the flight (e.g. `2025`) |
| `Quarter` | integer | Calendar quarter (`1`–`4`) |
| `Month` | integer | Calendar month (`1`–`12`) |
| `DayOfWeek` | integer | Day of week (`1` = Monday … `7` = Sunday, BTS encoding) |
| `FlightDate` | date | Flight date (`YYYY-MM-DD`) |
| `Reporting_Airline` | string | Reporting carrier code (unique carrier identifier used by BTS) |
| `Tail_Number` | string | Aircraft tail number (may be null or masked on some records) |
| `Flight_Number_Reporting_Airline` | integer | Flight number as reported by the carrier |
| `Origin` | string | Origin airport IATA code (e.g. `ATL`) |
| `OriginCityName` | string | Origin city name |
| `OriginState` | string | Origin state abbreviation |
| `Dest` | string | Destination airport IATA code |
| `DestCityName` | string | Destination city name |
| `DestState` | string | Destination state abbreviation |

**Project filter:** production ingest filters to flights where `Origin` is one of the 45 airports in `docs/airports_45.csv`.

---

## 3. Flight timing fields

Scheduled and actual departure/arrival times and runway movement times. BTS stores these as **local airport times** (HHMM integer or string format depending on column — e.g. `800` = 08:00 local at the relevant airport).

| Field | Description |
|-------|-------------|
| `CRSDepTime` | Scheduled departure time (local to **origin** airport) |
| `DepTime` | Actual departure time (local to **origin** airport); null if cancelled before departure |
| `CRSArrTime` | Scheduled arrival time (local to **destination** airport) |
| `ArrTime` | Actual arrival time (local to **destination** airport); null if cancelled or not completed |
| `WheelsOff` | Actual wheels-off time (local to **origin** airport) |
| `WheelsOn` | Actual wheels-on time (local to **destination** airport) |

### Timezone handling (important)

BTS time fields are **local to the airport** they describe — departure times use origin local time; arrival times use destination local time. They are **not** stored as UTC in the raw file.

Before joining to weather observations:

1. Combine `FlightDate` with each time field in the correct airport timezone.
2. Convert to **UTC** for warehouse storage and joins.
3. Use origin airport timezone for departure-side joins; destination timezone for arrival-side fields.

**Planned departure time for weather join:**

- Prefer `DepTime` (actual) when available and flight is not cancelled.
- Fall back to `CRSDepTime` (scheduled) when actual departure is missing.

This logic will be implemented in dbt intermediate models (`int_flights__departure_context`).

---

## 4. Delay fields

Delay metrics in minutes. BTS provides both signed delay values and non-negative delay minute fields.

| Field | Type | Description |
|-------|------|-------------|
| `DepDelay` | numeric | Departure delay in minutes; **negative = early departure** |
| `DepDelayMinutes` | numeric | Departure delay minutes (non-negative); early departures typically `0` |
| `DepDel15` | flag | `1` if departure delay ≥ 15 minutes, else `0` |
| `ArrDelay` | numeric | Arrival delay in minutes; **negative = early arrival** |
| `ArrDelayMinutes` | numeric | Arrival delay minutes (non-negative); early arrivals typically `0` |
| `ArrDel15` | flag | `1` if arrival delay ≥ 15 minutes, else `0` |
| `CarrierDelay` | numeric | Minutes of arrival delay attributed to carrier (late aircraft, maintenance, etc.) |
| `WeatherDelay` | numeric | Minutes of arrival delay attributed to weather |
| `NASDelay` | numeric | Minutes of arrival delay attributed to National Aviation System (air traffic, airport ops) |
| `SecurityDelay` | numeric | Minutes of arrival delay attributed to security |
| `LateAircraftDelay` | Minutes of arrival delay attributed to late inbound aircraft |

### Interpretation notes

- **Negative delay** (`DepDelay`, `ArrDelay`): flight departed or arrived **early** relative to schedule.
- **DelayMinutes fields** (`DepDelayMinutes`, `ArrDelayMinutes`): non-negative values suitable for aggregation; early flights are typically recorded as `0` minutes late.
- **Del15 flags** (`DepDel15`, `ArrDel15`): binary indicators for delays of **15 minutes or more** — common industry on-time threshold.
- **Cause delay fields** (`CarrierDelay`, `WeatherDelay`, `NASDelay`, `SecurityDelay`, `LateAircraftDelay`): generally populated when **arrival delay is significant** (typically ≥ 15 minutes); often null or zero for on-time or early flights. Sum of cause delays should approximate total arrival delay when populated.

### Staging rules (planned)

- Cancelled flights: `DepDelay` / `ArrDelay` should not be treated as meaningful operational delays — set to null in staging.
- Use `DepDelayMinutes` / `ArrDelayMinutes` for aggregations; use signed `DepDelay` / `ArrDelay` when early-vs-late direction matters.

---

## 5. Cancellation and diversion fields

Operational status flags requiring special handling in staging and analytics.

| Field | Type | Description |
|-------|------|-------------|
| `Cancelled` | flag | `1` if flight was cancelled, `0` otherwise |
| `CancellationCode` | string | Reason code for cancellation (e.g. carrier, weather, NAS); populated when `Cancelled = 1` |
| `Diverted` | flag | `1` if flight was diverted to a non-scheduled airport, `0` otherwise |

### Handling notes

Cancelled and diverted flights require **special handling** because:

- **Actual times** (`DepTime`, `ArrTime`, `WheelsOff`, `WheelsOn`) may be null or incomplete.
- **Arrival delay** may be missing or not comparable to normal completed flights.
- **Delay cause fields** may be unpopulated even when cancellation reason is known via `CancellationCode`.
- **Weather join** should still attempt scheduled departure time for cancelled flights if analytically useful, but delay metrics should be nullified or flagged.

**Planned staging flags:**

- `is_cancelled` — derived from `Cancelled = 1`
- `is_diverted` — derived from `Diverted = 1`
- Delay fields nulled or zeroed per documented business rules when cancelled.

---

## 6. Flight duration and movement fields

Taxi, airborne, elapsed time, and distance metrics for completed flights.

| Field | Type | Description |
|-------|------|-------------|
| `TaxiOut` | numeric | Taxi-out time in minutes (gate to wheels-off at origin) |
| `TaxiIn` | numeric | Taxi-in time in minutes (wheels-on to gate at destination) |
| `AirTime` | numeric | Airborne time in minutes (wheels-off to wheels-on) |
| `ActualElapsedTime` | numeric | Actual elapsed time in minutes (departure to arrival) |
| `CRSElapsedTime` | numeric | Scheduled elapsed time in minutes |
| `Distance` | numeric | Distance between origin and destination in miles |
| `DistanceGroup` | integer | BTS distance group bucket (`1` = shortest … `4` = longest) |
| `Flights` | numeric | Count of flights represented by row (typically `1.00`; fractional values possible in aggregated BTS exports — treat as `1` for flight-level records) |

### Notes

- `TaxiOut`, `AirTime`, `TaxiIn` are null or unreliable for cancelled flights.
- `ActualElapsedTime` ≈ `TaxiOut` + `AirTime` + `TaxiIn` for completed flights.
- `Distance` and `DistanceGroup` are useful for route-level analytics and normalizing delay rates.

---

## 7. Weather fields

Iowa Mesonet ASOS/METAR observation fields. Raw downloads include 30 columns; all fields below are present in verified January 2025 samples for ATL, ORD, and LAX.

| Field | Type (raw) | Description |
|-------|------------|-------------|
| `station` | string | Weather station ID (matches `weather_station_id` in `docs/airport_station_map.csv`) |
| `valid` | timestamp | Observation valid time — **treat as UTC** in this project (IEM downloads use UTC) |
| `tmpf` | numeric | Air temperature (°F) |
| `dwpf` | numeric | Dew point (°F) |
| `relh` | numeric | Relative humidity (%) |
| `drct` | numeric | Wind direction (degrees; `0` = calm variable) |
| `sknt` | numeric | Wind speed (knots) |
| `p01i` | numeric / special | One-hour precipitation (inches) |
| `alti` | numeric | Altimeter setting (inches Hg) |
| `mslp` | numeric | Mean sea level pressure (hPa) |
| `vsby` | numeric | Visibility (miles) |
| `gust` | numeric | Wind gust (knots) |
| `skyc1` | string | Sky condition layer 1 (e.g. `CLR`, `BKN`, `OVC`) |
| `skyc2` | string | Sky condition layer 2 |
| `skyc3` | string | Sky condition layer 3 |
| `skyc4` | string | Sky condition layer 4 |
| `skyl1` | numeric | Sky layer 1 height (feet) |
| `skyl2` | numeric | Sky layer 2 height (feet) |
| `skyl3` | numeric | Sky layer 3 height (feet) |
| `skyl4` | numeric | Sky layer 4 height (feet) |
| `wxcodes` | string | Weather phenomenon codes (e.g. `RA`, `SN`, `FG`, `-RA`) |
| `feel` | numeric | Apparent / feels-like temperature (°F) |
| `metar` | string | Raw METAR text for the observation |
| `snowdepth` | numeric | Snow depth (inches) |

### Timestamp handling

- `valid` is the **observation timestamp** used for all weather joins.
- Downloads from Iowa Mesonet with UTC selected produce timestamps that should be stored and joined as **UTC** (`obs_time_utc` in staging).
- Do not mix local flight times with UTC weather times without conversion.

### Missing and special values

| Value | Meaning | Staging treatment |
|-------|---------|-------------------|
| `M` | Missing / not reported | Convert to `NULL` |
| `T` | Trace amount (precipitation) | Convert to `0` or a trace constant (document choice) |
| Empty string | Missing | Convert to `NULL` |

Common columns with frequent `M` values: `gust`, `skyc2`, `skyc3`, `wxcodes`.

### Sky and weather codes

- **`skyc1`–`skyc4`**: cloud coverage layers from lowest to highest (CLR = clear, FEW, SCT, BKN, OVC).
- **`wxcodes`**: present weather codes from METAR (rain, snow, fog, thunderstorm, etc.); often `M` when no significant weather.
- **`metar`**: full raw METAR string — useful for audit and debugging; not used directly in aggregations.

### Planned weather join (preview)

Each flight at its **origin airport** will be matched to the **nearest `valid` observation** for the mapped station around **departure time (UTC)**. See [`data_sources.md`](data_sources.md) and future `docs/weather_join_methodology.md` for full join rules.

---

## Raw storage and Git policy

| Location | Contents | In Git? |
|----------|----------|---------|
| `data/samples/` | Manual BTS ZIP and weather CSVs | No |
| `data/raw/` | Automated downloads (future) | No |
| `raw.bts_flights` | Loaded flight records (Postgres) | N/A |
| `raw.weather_observations` | Loaded weather records (Postgres) | N/A |
| `docs/*.csv` | Reference airport and station maps | Yes |

---

## Related documentation

- [`data_sources.md`](data_sources.md) — download URLs, scope, and policies
- [`airports_45.csv`](airports_45.csv) — 45 airports in project scope
- [`airport_station_map.csv`](airport_station_map.csv) — airport → weather station mapping
- `docs/weather_join_methodology.md` — join rules (planned, Week 3)
