---
title: "PRD: LiveView local-first async dashboard states"
labels:
  - ready-for-agent
source_prd: docs/prds/liveview-async-dashboard-states.md
---

# PRD: LiveView local-first async dashboard states

See `docs/prds/liveview-async-dashboard-states.md`.

This issue is ready for an agent to implement. It should preserve the current boundary where the LiveView calls only `Analytics`, add the `Analytics.get_dashboard_refresh_state/2` API, and implement the local-first async dashboard states described in the PRD.
