---
name: data-analysis
description: Analyze datasets or query results for metrics, rankings, cohorts, or before-and-after comparisons. Use when aggregation, joins, date alignment, or interpretation can change the answer; not for spreadsheet editing or chart rendering alone.
---

# Data analysis

Use the available data-access tools and documented metric definitions. This skill does not supply a database connection, company schema, or default currency.

## Define the measurement

Before calculating, establish the row grain, entity key, population, date range, timezone, units, and metric formula. For ratios, identify both base components. For cohorts, distinguish the cohort start from the outcome measurement date and observation window.

Use documented defaults where they exist and disclose assumptions that affect the result. Ask about unresolved definitions only when alternative interpretations would materially change the answer.

## Select and inspect sources

1. Inspect source documentation or file structure before choosing columns. For spreadsheets, inspect tabs, headers, merged cells, and totals before treating the sheet as a rectangular dataset; use a dedicated spreadsheet skill for access or editing.
2. Prefer maintained metric sources when their definitions and grain match the question. Check coverage, freshness, embedded filters, and whether rows are snapshots or incremental events. Use raw data when the maintained aggregate cannot answer the requested measurement.
3. Start exploration with a small date range and the relevant columns. For database queries, use documented partition or clustering filters where applicable; a row limit alone may still scan the entire source. Expand to the full requested scope for the final calculation, or identify any remaining sampling explicitly.
4. Apply population filters according to the analysis purpose. A filter for normal users in business metrics can remove the very traffic needed for ingestion or incident diagnosis. Check for filters already embedded in a source before adding them again.

## Calculate at the requested grain

- Recompute rolled-up ratios from compatible base components, rather than averaging row-level rates. An unweighted mean is appropriate only when the requested measurement is the mean of those rates; label it accordingly.
- Distinct entities are not additive across overlapping days or segments. Compute the distinct count at the requested grain or use a documented aggregate at that grain. If only daily counts exist, a monthly distinct count may be unavailable; a daily average is a different metric.
- Check key uniqueness and join cardinality before joining. Aggregate each source to compatible keys where appropriate, then compare row counts and base totals before and after the join. Resolve many-to-many multiplication before calculating metrics.
- Preserve missing values separately from genuine zeros. Handle zero denominators explicitly and report undefined rates as unavailable, unless the metric definition specifies another convention. Round only presentation values.
- Rank using the exact metric and scope requested. A global Top-N is one ranking; create N per segment only when the user requests that partitioning.
- For retention or delayed outcomes, verify that each cohort's full observation window and ingestion delay have elapsed. Identify immature cohorts; keep historical periods that are already complete.

## Verify the result and its meaning

Reconcile detail rows with totals using code or a query. Reconcile additive measures by summing; recalculate rates and distinct counts at the total grain. Check coverage, missing values, unexpectedly sparse groups, and implausible changes against the source before presenting a conclusion.

For before-and-after comparisons, inspect actual release or event dates, equal observation lengths, weekday or seasonal effects, and population changes. Compare equivalent phases of a recurring release cycle when that cycle affects the metric. A descriptive difference alone does not establish a causal effect.

When reporting an existing statistical analysis, inspect the method's assumptions and diagnostics before interpreting its estimate or interval. A failed validity check means the estimate cannot support the requested conclusion; it does not mean that the effect is zero. An interval containing the null value is inconclusive about a nonzero effect, not proof of no effect. If the analyzed population changes to obtain a valid comparison, state both the original limitation and the narrower population the new result covers.

## Deliver

Lead with the answer supported by the executed calculation. Include the source, adopted definitions, date window, units, and material verification outcome in enough detail to reproduce it. Separate measured values from estimates and causal hypotheses. Include only limitations that affect this answer, and identify any part of the original request the available data cannot resolve.
