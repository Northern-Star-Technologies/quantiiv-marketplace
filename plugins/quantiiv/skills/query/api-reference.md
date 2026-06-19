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
// Company.most_recent_data_date: Monday that starts the most recent week with data.
//   Latest data spans most_recent_data_date (Mon) .. most_recent_data_date + 6 (Sun).
//   Anchor "latest"/"this week"/relative ranges here, not to today's date.

// Get company's locations
client.companies.listLocations(companyId)
// Returns: Location[]
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

// Weekly product overview
client.products.getData(companyId, {
  week: "YYYY-MM-DD",       // required (week start date)
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

## Elasticity

```js
// Summary endpoints — all return ElasticitySummaryRow[]
client.elasticity.getSummaryOverall(companyId, runId?)
client.elasticity.getSummaryChannel(companyId, runId?)
client.elasticity.getSummaryCategory(companyId, runId?)
client.elasticity.getSummaryStore(companyId, runId?)
client.elasticity.getSummaryProduct(companyId, { category?, runId? })

// Pricing opportunities
client.elasticity.getOpportunities(companyId, {
  category?,
  minScore?,          // number
  confidenceTier?,    // string
  limit?,             // default 25, max 100
  offset?,            // default 0
  runId?,
  storeNumber?,
})
// Returns: { data: Record<string, unknown>[], total: number }

// Price relationships (constraints between product pairs)
client.elasticity.getPriceRelationships(companyId, {
  relationshipType?,  // "hard" | "soft"
  product?,           // matches either side
  category?,          // matches either side
})
// Returns: Record<string, unknown>[]
```

## Pricing Plans

```js
// List all pricing plans
client.elasticity.pricingPlans.list(companyId)
// Returns: PricingPlan[]

// Get plan summary
client.elasticity.pricingPlans.get(companyId, planId)
// Returns: PricingPlan (with aggregated metrics, policy_band, solver metadata)

// Get plan items (paginated)
client.elasticity.pricingPlans.getItems(companyId, planId, {
  product?,
  category?,
  priceZone?,
  isExcluded?,                 // boolean
  highJndFlag?,                // boolean
  wholeDollarThresholdFlag?,   // boolean
  constraintAdjusted?,         // boolean
  limit?,                      // default 25
  offset?,                     // default 0
})
// Returns: { items: Record<string, unknown>[], total: number }

// Product-level rollup
client.elasticity.pricingPlans.getProductSummaries(companyId, planId)
// Returns: Record<string, unknown>[] (affected stores, avg prices, total impact per product)

// Store-level rollup
client.elasticity.pricingPlans.getStoreSummaries(companyId, planId)
// Returns: Record<string, unknown>[] (affected products, avg prices, total impact per store)

// Constraint diagnostics
client.elasticity.pricingPlans.getConstraintDiagnostics(companyId, planId, {
  relationshipType?,  // "hard" | "soft"
  status?,
  limit?,             // default 25
  offset?,            // default 0
})
// Returns: { diagnostics: Record<string, unknown>[], total: number }

// Coverage diagnostics
client.elasticity.pricingPlans.getCoverageDiagnostics(companyId, planId, {
  isEligible?,        // boolean
  product?,
  limit?,             // default 25
  offset?,            // default 0
})
// Returns: { diagnostics: Record<string, unknown>[], total: number }
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

// Labor hours + prorated cost bucketed by hour-of-day (0-23) for one location
client.labor.getByHour(companyId, locationName, {
  startDate: "YYYY-MM-DD",  // required
  endDate: "YYYY-MM-DD",    // required
  loadSource?,
})
// Returns:
// {
//   location,
//   data: [{ hourOfDay, laborHours, laborCost }, ...24 rows],
//   summary: { totalLaborHours, totalLaborCost, peakHour, peakHourLaborCost }
// }

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
```

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
