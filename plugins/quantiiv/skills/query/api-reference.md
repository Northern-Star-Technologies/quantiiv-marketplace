# Quantiiv SDK API Reference

## Auth

```js
const { QuantiivClient } = require("@quantiiv-ai/sdk");
const client = new QuantiivClient({
  token: process.env.QUANTIIV_API_KEY,
});
```

## Companies

```js
// List companies (paginated)
client.companies.list({ search?, page?, limit? })
// Returns: { data: Company[], pagination: { total, page, limit, totalPages } }

// Get company details
client.companies.get(companyId)
// Returns: Company (with users, locations, features)
// Company.most_recent_data_date: start of the most recent COMPLETE fiscal week.
//   Falls on the company's fiscal week start day (fiscal_week_start_day, e.g.
//   "Tuesday") — NOT necessarily a Monday. A weekly period anchor only — NOT
//   the data-through date. For freshness use
//   getReportingFreshnessContext().latest_available_data_date.

// Get company's locations
client.companies.listLocations(companyId)
// Returns: Location[]

// Authoritative reporting freshness for the authenticated user's scope.
// Call once after resolving the company; refresh each new session.
client.companies.getReportingFreshnessContext(companyId, {
  data_domain?,                  // "sales" (default)
  include_location_breakdown?,   // default false
})
// Returns:
// {
//   status: "ok" | "unavailable",
//   latest_available_data_date,  // ACTUAL data-through date (newest loaded
//                                //   sales date across locations) — use for
//                                //   freshness language and as max query end date
//   latest_common_complete_date, // newest date ALL locations are complete
//                                //   through — earlier than latest_available
//                                //   when some locations lag; not the anchor
//   latest_safe_data_date,       // legacy alias of latest_common_complete_date
//   latest_complete_business_week: { start_date, end_date, fiscal_year, fiscal_week, ... },
//   latest_complete_fiscal_period, latest_complete_calendar_month,
//   partial_periods, location_scope_summary,
//   calendar_config: { week_start_day, week_end_day, calendar_type, ... },
//                                // week_start_day (e.g. "Tuesday") defines the
//                                //   fiscal week boundary — align all weekly
//                                //   ranges to it, never assume Monday
//   audit,
//   warnings: [{ code, severity, message }],
//   location_breakdown?,         // when include_location_breakdown: true
// }
```

## Locations

```js
// Get location details
client.locations.get(locationId)
// Returns: Location (with company, consolidation status)
```

## Products

```js
// Menu groups & items (paginated)
client.products.getMenuCatalog(companyId, {
  startDate: "YYYY-MM-DD",  // required
  location: "corporate",     // required
  endDate?,                  // optional
  page?,                     // default 1
  limit?,                    // default 50, max 200
  search?,                   // case-insensitive
  menuGroup?,                // exact match filter
})
// Returns: { menu_groups: string[], items: [{menu_group, menu_item}], pagination }

// NOTE: every `week` parameter below expects the FISCAL week start date — a
// date falling on the company's fiscal_week_start_day (e.g. Tuesday), not
// necessarily a Monday. For "latest" questions use the start of the current
// IN-PROGRESS week (the week containing latest_available_data_date) with
// to: latest_available_data_date, presented as week-to-date; use
// latest_complete_business_week.start_date only when the user explicitly asks
// for a complete week. Resolve via client.fiscalCalendar.resolveFiscalWeek().

// Weekly product overview
client.products.getData(companyId, {
  week: "YYYY-MM-DD",       // required (fiscal week start date)
  location: "corporate",     // required
  to: "YYYY-MM-DD",         // required (end date)
  menuGroup?,                // optional filter
})
// Returns: { productWeeklyOverview, weeklySummaryData, weeklyItemsObservations, newProducts, menuDescriptions }

// Top items by metric
client.products.getTopMovers(companyId, {
  week: "YYYY-MM-DD",       // required
  location: "corporate",     // required
  metric?,                   // "net_sales" (default) | "transactions" | "avg_ticket" | "loyalty_pct" | "delivery_pct"
  to?,                       // end date
  limit?,                    // default 10, max 50
})
// Returns: { metric, current_period: [{menu_item, menu_group, value}], prior_period, prior_year }

// Metrics by menu group
client.products.getMenuGroupMetrics(companyId, {
  week: "YYYY-MM-DD",       // required
  location: "corporate",     // required
  metric?,                   // "net_sales" (default) | "units"
  to?,                       // end date
})
// Returns: { metric, current_week: [{menu_group, value}], last_week, last_year }

// Single item deep-dive
client.products.getItemData(companyId, item, {
  week: "YYYY-MM-DD",       // required
  location: "corporate",     // required
})
// Returns: { weeklyItemBreakoutData, locationBreakdownData, weeklySummaryData, corporate90dayData, productHeatmapData, itemDescription, menuDescriptions }

// Daily time-series for an item
client.products.getItemSales(companyId, item, {
  startDate: "YYYY-MM-DD",  // required
  location: "corporate",     // required
  endDate?,                  // optional
})
// Returns: { dailyData: { [date]: { total_sales, units_sold, average_price, loyalty_sales_percentage, repeat_rate, delivery_sales_percentage } } }
```

## Weather

```js
// Daily weather for a location with prior-week and prior-year comparisons
client.weather.getLocationWeather(companyId, locationName, {
  startDate: "YYYY-MM-DD",  // required
  endDate: "YYYY-MM-DD",    // required
  loadSource?,               // optional POS identifier
})
// Returns:
// {
//   location,
//   data: [{
//     date, minTempF, maxTempF, rainfallIn, snowIn, windSpeedMph,
//     hasRain, hasSnow, isHeavyPrecip,
//     tempCategory: "cold" | "normal" | "hot",
//     priorWeek: { ...same fields } | null,
//     priorYear: { ...same fields } | null,
//   }],
//   summary: { avgMinTemp, avgMaxTemp, totalRainfallIn, totalSnowIn,
//              daysWithPrecip, totalDays, coldDays, hotDays },
//   priorWeekSummary: WeatherSummary | null,
//   priorYearSummary: WeatherSummary | null,
// }
```

## Labor

```js
// Daily labor cost across a date range (optionally filtered to one location)
client.labor.getByDay(companyId, {
  startDate: "YYYY-MM-DD",  // required
  endDate: "YYYY-MM-DD",    // required
  location?,                 // optional location filter
  loadSource?,               // optional POS identifier
})
// Returns:
// { location, data: [{ date, laborCost }], summary: { totalLaborCost, avgDailyLaborCost, totalDays } }

// Labor cost rolled up by location across a date range
client.labor.getByLocation(companyId, {
  startDate: "YYYY-MM-DD",  // required
  endDate: "YYYY-MM-DD",    // required
  loadSource?,
})
// Returns:
// { data: [{ location, laborCost }], summary: { totalLaborCost, locationCount } }

// Labor hours + prorated cost bucketed by hour-of-day (0-23) for one location.
// Each shift's paid hours and paid amount are spread across 15-minute slices
// between clock-in and clock-out, so totals reconcile with getByJob/getByDay.
// Hours are PAID time, not clocked presence — unpaid breaks are excluded.
// Buckets are local store hours; no timezone conversion is applied.
client.labor.getByHour(companyId, locationName, {
  startDate: "YYYY-MM-DD",  // required
  endDate: "YYYY-MM-DD",    // required
  loadSource?,
})
// Returns:
// {
//   location,
//   data: [{ hourOfDay, laborHours, laborCost }, ...24 rows],
//   summary: { totalLaborHours, totalLaborCost, peakHour, peakHourLaborCost },
//   coverage: { totalShifts, countedShifts, openShifts, invalidShifts, missingClockIn }
// }
// Check coverage before drawing staffing conclusions: shifts still clocked in,
// missing a clock-in, or with clock-out not after clock-in are excluded from
// the hourly totals and counted there.

// Daily labor hours + cost grouped by location and job title/position.
// Use to compute sales per labor hour (SPLH) with custom excluded job-code
// denominators, and to build role-based labor breakouts.
client.labor.getByJob(companyId, {
  startDate: "YYYY-MM-DD",  // required
  endDate: "YYYY-MM-DD",    // required
  location?,                 // optional exact location filter
  jobTitle?,                 // optional exact job title / position filter
  loadSource?,
})
// Returns:
// {
//   location, jobTitle,
//   data: [{ date, location, jobTitle, regularHours, overtimeHours, laborHours, laborCost, entryCount }],
//   summary: { totalLaborHours, totalRegularHours, totalOvertimeHours, totalLaborCost, totalDays, locationCount, jobTitleCount }
// }
// WARNING: entryCount is a count of shift rows, NOT unique employees. One
// employee working two shifts is indistinguishable from two employees working
// one shift each. Never report entryCount as a headcount — use getShifts below.
```

## Employee / Shift-Level Labor

Individual clock-in/clock-out rows with a pseudonymous `employeeId`. Use this for
unique headcount and turnover proxies — the aggregate endpoints above cannot
express either.

```js
// One page of shift rows
client.labor.getShifts(companyId, {
  startDate: "YYYY-MM-DD",  // required
  endDate: "YYYY-MM-DD",    // required — range must be 186 days or fewer
  location?,                 // optional exact location filter
  jobTitle?,                 // optional exact job title / position filter
  loadSource?,
  employeeId?,               // optional — fetch one worker's shifts
  limit?,                    // default 500, max 1000
  cursor?,                   // from a previous pageInfo.nextCursor
})

// Pages through the entire range — prefer this for any aggregate
client.labor.listAllShifts(companyId, { /* same params */ maxPages? })
// Returns: { data, coverage, pages, truncated }

// getShifts returns:
// {
//   data: [{ employeeId, businessDate, location, jobTitle, clockIn, clockOut,
//            regularHours, overtimeHours, totalHours, loadSource }],
//   pageInfo: { pageSize, returned, hasNextPage, nextCursor },
//   coverage: {
//     employeeIdScope: "company" | "location" | "unknown",
//     employeeIdAvailable, timestampSemantics: "local-store-time",
//     totalShiftRows,
//     sources: [{ loadSource, loadSourceFamily, employeeIdScope, shiftRows,
//                 rowsWithEmployeeId, distinctEmployeeIds, openShifts,
//                 missingClockIn, earliestBusinessDate, latestBusinessDate }],
//     notes: [ ... caveats for this company and range ... ]
//   }
// }
```

**How to use this correctly:**

- Rows are punch segments, **not** unique employees and not necessarily shifts —
  one shift can produce several segments after a break or job change. Count
  `new Set(data.map(r => r.employeeId)).size` for headcount, never `data.length`.
- **Check `coverage.employeeIdScope` before aggregating across locations.** When
  it is `"location"` (all Toast customers) or `"unknown"`, the identifier is only
  stable within one location: the same person working two stores appears as two
  identifiers, so a chain-wide unique count overstates headcount and a transfer
  is indistinguishable from a separation plus a new hire. Report per location and
  say so. Only `"company"` permits chain-wide dedup.
- Keep paging while `pageInfo.hasNextPage` is true, or headcount is undercounted.
  With `listAllShifts`, treat `truncated: true` as an incomplete read.
- A first observed shift is a **hire-date proxy**, not a hire date. A long gap
  with no shifts is a **separation proxy**, not a confirmed termination — the
  worker may be on leave, seasonal, or recorded under another identifier.
- Voluntary vs involuntary turnover **cannot** be derived from clock data, and
  neither can rehires as distinct from continuing employment.
- State the assumptions behind any figure: the inactivity threshold that counts
  as a separation, rehire handling, how multi-location workers are attributed,
  and the denominator used. If the user did not specify them, say which you chose.
- Present results as estimates from clock data, not authoritative HR records.
  Read `coverage.notes` — it carries the caveats for the exact range requested.
- Employee names, contact details, and all pay/wage fields are unavailable by
  design. `clockIn`/`clockOut` are local store time with no timezone offset.

## Location Reviews

Public reviews left on review platforms — Google, Yelp, TripAdvisor, Facebook,
DoorDash and others. Use for public reviews, reputation, ratings, star ratings,
low-star feedback, owner responses, and public sentiment about locations.

**These are NOT survey results, customer feedback forms, loyalty data, or Google
Analytics.** Never answer a survey question with review data or vice versa.

```js
// One page of reviews
client.locationReviews.search(companyId, {
  startDate?,        // YYYY-MM-DD. Omit BOTH dates for the default 90-day window
  endDate?,          // YYYY-MM-DD, inclusive. Window must be <= 366 days
  location?,         // location name; display alias matched before canonical name
  locationId?,       // exact review-side location id
  network?,          // review platform: google, yelp, tripadvisor... (case-insensitive)
  minRating?,        // 1-5
  maxRating?,        // 1-5 — use 2 for low-rating feedback
  hasOwnerAnswer?,   // false = still unanswered
  hasReviewText?,    // true = exclude rating-only reviews
  limit?,            // default 50, max 200
  cursor?,
})

// Pages the whole window — prefer this for any count, average, or trend
client.locationReviews.listAll(companyId, { /* same params */ maxPages? })
// Returns: { data, coverage, pages, truncated }

// search returns:
// {
//   data: [{ reviewId, remoteReviewId, locationId, locationName, locationNameAlias,
//            network, sourceProvider, rating, reviewDate, reviewText, reviewUrl,
//            reviewerName, language, sentiment, recommendation,
//            ownerAnswer, ownerAnsweredAt, hasOwnerAnswer }],
//   pageInfo: { pageSize, returned, hasNextPage, nextCursor },
//   coverage: {
//     reviewsEnabled, networks, sourceProviders, ratingScale: "1-5",
//     totalInWindow, ratedReviews, unratedReviews, withReviewText,
//     withOwnerAnswer, averageRating, isLocationScoped, scopedLocationCount,
//     window: { startDate, endDate, defaultWindowApplied },
//     notes: [ ... caveats for this company and window ... ]
//   }
// }
```

**How to use this correctly:**

- **`reviewsEnabled: false` means the company does not have Location Reviews
  enabled — it does NOT mean they have no reviews.** Say the capability isn't
  available for them. Likewise an empty result means no reviews *in that window*,
  not none ever.
- **`network` is the review platform. `sourceProvider` is only the ingestion
  vendor** (`dataforseo`, `yext`, `ovation`, `sevenrooms`, `soci`). Never
  attribute a review to its `sourceProvider` or call these "dataforseo reviews".
- **Do not assume Google.** Check `coverage.networks` — one chain carries nine
  platforms at once. Only say "Google reviews" when filtered to `network: "google"`.
- **A null `rating` is unrated, not zero**, and is excluded from
  `coverage.averageRating`. Some platforms carry no rating at all.
- **Many reviews are rating-only with no text**, so `coverage.withReviewText` is
  the real denominator for any text or theme analysis — not `totalInWindow`.
- **Omitting both dates reads only the last 90 days**, and
  `coverage.window.defaultWindowApplied` will be true. Pass explicit dates for
  any other period, and keep paging while `pageInfo.hasNextPage` is true before
  computing a total, average, or trend.
- **`isLocationScoped: true` means the caller only has some locations**, so the
  results are not company-wide. Say so rather than presenting chain totals.
- Read `coverage.notes` — it carries the caveats that actually apply to the
  company and window requested.
- Reviewer contact details and order linkage are unavailable by design. This is
  read-only: it cannot post, edit, or delete a review or an owner response.

## Fiscal Calendar

Resolve a fiscal or calendar reporting period to concrete `start_date` / `end_date`
(plus an optional comparison window) using the company's configured fiscal
calendar. Pass the returned `start_date` and `end_date` straight to the other
data endpoints (sales, labor, weather, etc).

```js
// Calendar year-to-date through reportEndDate
client.fiscalCalendar.resolveCalendarYtd(companyId, {
  reportEndDate: "YYYY-MM-DD",  // required
  comparison?,                    // "prior_year" | "prior_period" | "none"
})

// Fiscal year-to-date through reportEndDate
client.fiscalCalendar.resolveFiscalYtd(companyId, {
  reportEndDate: "YYYY-MM-DD",  // required
  comparison?,
})

// Calendar month (month containing reportEndDate, or explicit year+month)
client.fiscalCalendar.resolveCalendarMonth(companyId, {
  reportEndDate: "YYYY-MM-DD",  // required
  year?,                          // optional, must pair with month
  month?,                         // 1-12, optional
  comparison?,
})

// Fiscal period (P1-P13). Either reportEndDate OR fiscalYear+fiscalPeriod.
client.fiscalCalendar.resolveFiscalPeriod(companyId, {
  reportEndDate?,
  fiscalYear?,
  fiscalPeriod?,                  // 1-13
  comparison?,
})

// Fiscal week (FW1-FW53). Either reportEndDate OR fiscalYear+fiscalWeek.
client.fiscalCalendar.resolveFiscalWeek(companyId, {
  reportEndDate?,
  fiscalYear?,
  fiscalWeek?,                    // 1-53
  comparison?,
})

// Explicit range with custom qualification anchor
client.fiscalCalendar.resolveDateRange(companyId, {
  startDate: "YYYY-MM-DD",        // required
  endDate: "YYYY-MM-DD",          // required
  qualificationAnchorDate: "YYYY-MM-DD",  // required
  comparison?,
})

// Generic — pass the raw discriminated-union spec directly
client.fiscalCalendar.resolvePeriod(companyId, { period_type: "fiscal_period", ... })
```

All methods return a `PeriodResolutionResult` (`start_date`, `end_date`,
`comparison_start_date`/`comparison_end_date`, `fiscal_year`, `fiscal_period`,
`fiscal_week`, `config_snapshot`, `audit`, etc).

## Error Handling

```js
const { QuantiivApiError } = require("@quantiiv-ai/sdk");
try {
  await client.companies.get("bad-id");
} catch (err) {
  if (err instanceof QuantiivApiError) {
    console.log(JSON.stringify({ error: err.status, message: err.body }));
  }
}
```
