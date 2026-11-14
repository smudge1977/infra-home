# Idea: Figma + MCP as a UI front-end for coding agents

## Summary

Use Figma as a visual design and requirements layer for home infrastructure
projects, with MCP bridging the design and a coding agent. This is not simply
“Figma to code”: the proposed loop is **idea → Figma → MCP → coding agent →
implementation → test and refine**.

Figma expresses what an interface should look like, feel like and broadly do.
The agent translates accessible design information into an implementation
scaffold; the owner concentrates on detailed behaviour, integration, edge cases
and engineering. Figma is not the runtime technology, including for embedded
displays.

## The problem

Text prompts can describe intent without deciding layout, spacing, typography,
colours, control sizes, navigation, placement or visual states. For example,
“make the room temperature dominant, the setpoint secondary and heating demand
visible but not distracting” still leaves the agent to invent most of the UI.
A design can communicate those choices directly and reduce guesswork.

## Division of responsibility

| Layer | Responsibility |
|---|---|
| **Figma** | Visual hierarchy, screens, navigation, controls, placement, colours, typography, interaction intent and normal/degraded/error states. |
| **Functional specification** | Meaning and behaviour: data sources, validity, user actions, constraints and state transitions. |
| **Code and configuration** | Implement and test the design and behaviour in the chosen technology. |

For illustration only, a functional specification might describe a temperature
source and stale threshold, a setpoint range and increment, the condition for a
heating indicator, and what to show when Home Assistant is disconnected. Actual
values and entity mappings must be agreed and verified for each implementation;
they are not prescribed by the visual design.

Figma should not own control algorithms, safety behaviour, network architecture,
entity IDs, secrets, device configuration, protocol behaviour, persistence,
retry policies or security policy. **Figma is the visual statement of intent;
the functional specification is the behavioural statement; code is the
implementation.**

## Why MCP?

Without MCP the workflow can involve a screenshot, human interpretation and a
prompt. With a suitable Figma MCP integration, the agent may be able to access
structured frames, component hierarchy, dimensions, styles, tokens, names,
variants and relationships rather than just a flat image. The integration is
the machine-readable bridge, not the design tool itself.

This is a hypothesis, not a promise: access, permissions, available MCP tools,
plan limitations and the fidelity of returned data all need to be tested. The
agent must not assume every interaction or visual property is available. Keep
functional requirements and implementation constraints in the repository so
the design is not the only source of project knowledge.

## Starting project: Jane's heating control page

Use a new, approachable Home Assistant heating page for Jane as the first
project exploring this workflow. The aim is to design around her everyday
tasks rather than expose the engineering view. Discuss the layout, wording,
accessibility and actual needs with Jane before treating a mock-up as agreed.

Start with a small set of mobile-friendly frames and states, for example:

- An overview of rooms, current temperature and the relevant target.
- A simple room control and clear feedback for an adjustment or boost, including
  duration and what happens when it ends.
- Heating, satisfied, unavailable and stale-data states that are understandable
  without implying that a running timer necessarily means the boiler is on.
- A safe, clear way to find scheduling information if Jane needs it; decide
  separately whether editing is appropriate and permitted.

The existing HeatMesh live dashboard and controller are the baseline, not a
blank slate. Preserve their established schedule, boost, stale-data, relay and
control behaviour unless a separately reviewed change is agreed. Confirm actual
entity mappings and Home Assistant permissions; dashboard visibility alone is not
an authorization boundary. Test with non-admin access where applicable, and use
mocked or read-only data before any live control testing. Physical acceptance
and operational changes require their own safeguards and verification.

The implementation belongs to HeatMesh; infra-home owns the supporting Home
Assistant service and this cross-project workflow idea. [HeatMesh issue #1](https://git.keithmarston.me.uk/Home/heatmesh/issues/1)
tracks the page as a starting project, not a claim that the design or
implementation already exists.

## Embedded thermostat experiment

The ESP thermostat is another useful proof of concept: Figma describes the
intended experience independently of LVGL/ESPHome. Candidate frames are normal
room display, heating active, setpoint adjustment, Home Assistant disconnected,
sensor stale/unavailable, settings and engineering diagnostics.

The agent can attempt to derive coordinates, dimensions, colours, fonts,
component hierarchy, reusable elements and navigation from the design, then
generate LVGL/ESPHome UI boilerplate. The engineering specification and code
remain responsible for HA/MQTT entity mapping, temperature and setpoint
behaviour, relay semantics, offline and stale-data handling, watchdogs, startup
state and safety limits.

### Suggested proof-of-concept phases

1. Make only a few Figma frames: normal, heating active, adjustment,
   disconnected and diagnostics. Do not model the entire product.
2. Connect the coding environment via Figma MCP and establish what it can
   reliably read and what needs another specification or screenshot.
3. Generate a deliberately non-controlling LVGL UI: navigation, labels,
   controls, layout, colours and visual states, without real heating control.
4. Run in an appropriate LVGL simulator, if supported by the selected build,
   and compare screenshots with Figma; record any gaps and manual work.
5. Only after the translation is useful, connect and test real ESPHome,
   Home Assistant, sensor, setpoint, demand and diagnostic behaviour against
   an agreed functional specification and safety checks.

## Success criteria

The experiment is valuable if an agent can take a changed design and a request
such as “implement this visual update while preserving the existing backend
behaviour and entity mappings”, produce a reasonably faithful scaffold without
manual transcription of every property, and demonstrate that behaviour has not
changed through appropriate tests and review. Perfect production code is not the
goal; quickly moving from **idea → concrete design → useful scaffold** is.

For Jane's page, success also means Jane can understand and use the agreed
everyday tasks on her device, including unavailable states, without needing the
engineering dashboard. Validate with her rather than assuming a design is usable.

## Wider possibilities

The same approach could help with room controllers and sensor displays, Home
Assistant dashboards or custom cards, infrastructure management interfaces,
monitoring views and future hardware projects. A longer-term loop could compare
simulator screenshots with the Figma design and iterate, provided that generated
visual changes remain separate from control and safety logic.