---
name: drawio-architecture
description: "Create, revise, or review infrastructure architecture diagrams in native Draw.io format. Use for .drawio files, especially infra-home diagrams, host/network topology, and deployment-status views."
---

# Draw.io architecture diagrams for infra-home

Use this skill when creating or changing an infrastructure diagram in this repository. Keep diagrams editable as native `.drawio` XML and make the diagram agree with the repository's deployment and design documentation.

## Workflow

1. Read the relevant system READMEs and design notes before drawing. Treat documentation as the source of truth; do not promote proposals or unknowns into deployed facts.
2. Separate operational states visually and label them explicitly: live/verified, target/in progress, proposed, and unknown/to inventory. A diagram is an inventory view, not a deployment claim.
3. Organize by trust boundary, host, or responsibility. Label network paths, ingress, and storage only when documented. Do not invent host placement, ports, routing, or backup guarantees.
4. Use readable titles, concise labels, consistent spacing, orthogonal connectors, and a small status legend. Avoid obsolete personal notes, credentials, IPs, account IDs, and speculative comments.
5. Save editable source under `docs/diagrams/`. For a replacement or major redesign, create a clearly versioned file and preserve any existing file with unreviewed changes.
6. Validate the XML and all cell IDs/edge references. If the Draw.io CLI is installed, export a preview and inspect it for clipping, overlaps, unreadable labels, and misleading connections. Do not add generated exports unless the documentation uses them.
7. Update the relevant README or design index with a relative link and note any significant scope/status caveats.

## Repository-specific conventions

- HeatMesh owns heating behavior and firmware; infra-home owns service deployment and recovery.
- The iot-home service stack is Home Assistant, ESPHome, Mosquitto, and Zigbee2MQTT. Do not depict heating outputs as connected to physical boiler/valve relays.
- Proxmox host inventory is incomplete. Keep guest/service placement unknown unless a system document confirms it.
- VyOS/Sprint 2 networking work is planned; do not present its target design as implemented.
- Excalidraw collaboration and the monitoring appliance are proposals, not deployed services.
- Use terms and status from current documentation; add dates only when a snapshot date is useful and supported.

## References and provenance

This repository-local workflow is independently tailored for infra-home and informed by these public Draw.io skills (consult upstream for their full tooling, export, and lint capabilities):

- GitHub `awesome-copilot`, [`skills/drawio`](https://github.com/github/awesome-copilot/tree/main/skills/drawio) — native diagram authoring and export guidance. Repository is MIT licensed.
- Sunwood-ai-labs, [`draw-io-skill`](https://github.com/Sunwood-ai-labs/draw-io-skill) — authoring, export, visual QA, and SVG linting workflow. Repository is MIT licensed.

No upstream scripts or substantial skill text are vendored here. Review upstream license and dependency information before importing any assets or tooling.
