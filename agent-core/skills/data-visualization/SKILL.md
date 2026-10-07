---
name: data-visualization
description: Create or revise data charts from datasets or calculated results, including exported plots and interactive charts. Use for chart selection, data fidelity, labels, scales, and rendered output checks; not for illustrations, diagrams, or text-only metric answers.
---

# Data visualization

Preserve the user's requested chart type and output format. Choose a chart based on the question when the user has not specified one. Use the project's available plotting or UI tools; this skill does not require a particular library or add dependencies.

## Establish the data

Read values, categories, and dates from the supplied dataset or saved calculation output. Transform that source in code rather than transcribing numbers from a conversational summary. Mark synthetic or illustrative data explicitly when the task calls for a demonstration.

Confirm the plotted grain, sorting, units, missing values, and ratio representation. A stored fraction of 0.15 may mean 15%; inspect its definition before formatting. Keep missing periods visible as gaps unless a documented rule permits imputation. For unresolved metric definitions or rollups, use the data-analysis workflow before plotting.

## Choose the encoding

| Question | Useful starting point |
| --- | --- |
| Change over time | Line chart with dates sorted chronologically |
| Category comparison or ranking | Bar or dot chart, ordered by value or a meaningful domain order |
| Distribution | Histogram, box plot, or individual observations |
| Relationship between measurements | Scatter plot |
| Composition | Stacked bars; use a percentage scale when proportions are the question |
| Direct comparison across groups | Small multiples with compatible scales |

Use a zero baseline for bars whose lengths encode magnitude. For a restricted line-chart range, make the scale clear. Keep comparable panels on the same scale, or visibly identify differences. Use a second axis only when the units require it and the labels make both scales clear; coincident lines do not establish correlation.

## Make the output readable

- Label units, date ranges, populations, and any filters needed to interpret the figure. State an insight in the title only when the data supports it.
- Preserve requested currencies and precision. Match abbreviated axis labels to the actual scale; compute with full precision and format at display time.
- Select an installed font that contains the labels' glyphs. For Korean or other non-ASCII text, verify the font and rendered glyphs rather than assuming a fallback exists. Check negative signs as well.
- Distinguish series through direct labels, markers, or line styles as well as color. Use a sequential scale for ordered magnitude and a diverging scale when a meaningful midpoint exists.
- Put panels together when proximity or shared scales aid comparison. Otherwise keep separate figures large enough to read in the intended interface.

## Verify and deliver

Inspect the rendered output at its intended display size. Check clipped labels, overlapping legends, missing glyphs, chronological order, units, baselines, and agreement with the source values. For interactive charts, also inspect tooltips and states that change filters or scales. If rendering or visual inspection is unavailable, state what remains unverified.

Provide the artifact in the requested format with a short description of the finding. Include an accessible text description or supporting table when needed to communicate values. Keep the source and transformation reproducible in the existing project or requested deliverable; create extra files only when the task needs them.
