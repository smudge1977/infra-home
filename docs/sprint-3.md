# Sprint 3 — Electricity dashboard and smart-plug coverage

Status: in progress — started 2026-10-12. Initial work: confirm Octopus Energy data sources and inventory existing plug energy entities; additional plug inventory remains to be confirmed.

## Goal

Build a Home Assistant dashboard showing **daily whole-home electricity consumption from Octopus Energy**, **daily kWh per power-monitoring plug**, and **the electricity not yet accounted for by those plugs**. Add the extra power plugs incrementally so we can see how much of each day's electricity use we can explain, and where to measure next.

This is infra-home Sprint 3, independent of HeatMesh sprint numbering. It builds on the home automation stack from [Sprint 1](sprint-1.md). It does not require the [Sprint 2](sprint-2.md) network cutover or change heating behaviour.

## Dashboard scope

- **Whole-home daily kWh** — Octopus electricity consumption, with the consumption date, source freshness and completeness visible.
- **Per-plug daily kWh** — one row per monitored appliance or appliance group, using friendly names and showing unavailable or incomplete readings explicitly.
- **Accounted-for daily kWh** — sum of the eligible, non-overlapping plug readings for that date.
- **Unaccounted daily kWh** — whole-home daily kWh minus accounted-for daily kWh.
- **Accounted-for percentage** — `100 × accounted-for kWh / whole-home kWh`, calculated only when the whole-home total is valid and greater than zero.
- **Daily history** — a day-by-day comparison of whole-home, measured plugs and the remainder, with a per-plug breakdown for a selected day. Prefer native Home Assistant energy/statistics cards where they meet the requirements.
- **Today so far** — provisional plug consumption, kept separate from completed-day reconciliation unless a matching whole-home interval is available.

The initial reconciliation should default to the **latest complete day available from Octopus**, not assume today's or yesterday's meter data has arrived. Show which plugs contributed to that comparison.

## Work items

- [ ] **Confirm Octopus access and data semantics.** Identify the supported Home Assistant integration and any installation dependency; configure credentials locally, never in Git. Inventory the actual electricity entities, units, meter coverage, interval timestamps, update cadence and reporting delay. Confirm that the chosen source represents consumption for a specific day, not an API retrieval date or a rolling period. Record whether solar, export or battery storage affects the comparison; gas is not part of this electricity dashboard.
- [ ] **Inventory existing and additional plugs.** Record each plug's model, integration, location, monitored appliance/group, power entity, cumulative energy entity, units, reset behaviour and installation date. Confirm the extra plugs support energy monitoring, not just switching. Keep unassigned plugs listed so they can be added in stages.
- [ ] **Choose safe measurement points.** Prioritise likely contributors and currently unmeasured loads. Check each plug's electrical rating and suitability for the appliance, especially high-current loads. Do not use an unsuitable plug on fixed wiring or critical equipment, and do not add automatic switching as part of measurement.
- [ ] **Normalise energy sensors.** Prefer reliable cumulative kWh sensors with the appropriate Home Assistant energy metadata and long-term statistics support. Where only power in W is available, configure an integration sensor with a documented sampling/integration strategy and flag gaps rather than presenting estimates as exact measurements.
- [ ] **Create daily plug totals and retain history.** Use suitable daily utility meters/statistics to derive kWh per plug. Handle resets, restarts and unavailable readings explicitly. Retain date-aligned plug totals long enough to reconcile delayed Octopus readings; today's utility-meter value alone is insufficient. Mark the onboarding day and any partial observation days as incomplete; do not invent pre-installation history.
- [ ] **Implement aligned daily reconciliation.** Compare Octopus and plugs over identical start/end boundaries. Confirm supplier timestamps and the Home Assistant time zone, including daylight-saving days. Select eligible plugs explicitly to avoid counting both a parent plug and its downstream plugs. Preserve the signed remainder; a negative value is a data/alignment warning, not something to silently clamp to zero. Missing readings must not silently become zero or produce a misleading complete coverage percentage.
- [ ] **Build the dashboard.** Provide the daily summary, per-plug breakdown, historical comparison, coverage percentage and clear freshness/completeness indicators. Label the remainder as unaccounted consumption, not proven waste or an exact list of missing appliances. Keep optional tariff/cost information secondary to the kWh accounting.
- [ ] **Add the extra plugs incrementally.** Pair, name and assign each device, confirm readings, update the explicit accounting inventory and verify it appears once in the dashboard. Record when each appliance started being measured so changes in coverage can be interpreted correctly.
- [ ] **Document deployment and recovery.** Store reusable dashboard/package YAML and a non-secret entity mapping with this repository's home automation stack. Document integration prerequisites, configuration validation, installation/reload steps and rollback. Keep account details, API keys, meter identifiers and private consumption exports out of Git.
- [ ] **Observe and reconcile real days.** Collect at least three complete matched days after the initial plug set is installed. Check totals against the source readings and investigate negative remainders, missing days or unexpected changes. Record baseline coverage and choose the next measurement points from the remaining gap.

## Plug inventory to complete during implementation

Do not assume existing entity IDs or appliance assignments. Add one row for every existing or spare plug once confirmed.

| Plug / friendly name | Appliance / location | Model / integration | Power entity | Energy entity | Measurement start | Included in total? | Status / gaps |
|---|---|---|---|---|---|---|---|
| To inventory | Existing monitored loads | To confirm | To confirm | To confirm | To confirm | Pending checks | Not yet inventoried |
| To inventory | Additional plugs / unassigned loads | To confirm | To confirm | To confirm | Not installed | No, until verified | Ready to plan |

## Accounting rules and limitations

- Whole-home imported electricity and appliance consumption are directly comparable only where the supply arrangement allows it. If there is solar generation, export or battery charging/discharging, document the additional measurements needed for an honest energy balance before labelling the difference as unmeasured load.
- The remainder can include lighting, fixed appliances, unmonitored sockets, standby loads and measurement error. Adding plugs should explain more consumption, but does not guarantee 100% coverage.
- Plug totals must represent non-overlapping measurement points. A plug measuring a power strip is an appliance group unless the individual loads are separately measured without double counting.
- An unavailable plug or missing supplier interval makes the day's comparison incomplete. Show any known subtotal as partial; do not publish an apparently final coverage figure.
- A true zero-consumption day has no defined coverage percentage. Display it as not applicable rather than dividing by zero.
- Completed daily comparisons may need recalculation when the supplier backfills or corrects data. Historical results must remain tied to their consumption date.

## Acceptance criteria

- The dashboard shows whole-home kWh, each included plug's kWh, the plug sum, signed unaccounted kWh and coverage percentage for the same explicitly displayed complete day.
- A selected day's per-plug readings add up to the displayed accounted-for total, and that total plus the signed remainder equals the whole-home total within displayed rounding precision.
- At least three matched complete days have been checked against source readings; daily history remains usable when Octopus data arrives late.
- Missing/stale data, partial onboarding days, sensor resets, zero totals and negative remainders are handled visibly rather than silently converted into trustworthy-looking values. Time-zone and daylight-saving boundary behaviour is checked.
- Existing plugs are inventoried and the additional plugs available for this sprint are either added and verified or have a documented blocker. Each included load is counted exactly once.
- Baseline accounted-for percentage and the next candidate unmeasured loads are recorded. There is no arbitrary target percentage before the available loads and measurements are known.
- Home Assistant configuration is validated, deployment/rollback is documented, and no credentials or private account data are committed.

## Out of scope

Automatic appliance switching, tariff-driven scheduling, electrical rewiring, gas accounting and changes to HeatMesh control logic. Cost analysis can follow once daily electricity accounting is trustworthy; this sprint does not promise live whole-home consumption from delayed supplier data.

## References

- [Home automation stack](../systems/iot-home/home-automation/README.md)
- [Home Assistant configuration ownership and backups](design/homeassistant.md)
- [Infrastructure backlog](backlog.md)