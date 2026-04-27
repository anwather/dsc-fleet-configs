# dsc-fleet-configs — ARCHIVED

> **This repository is archived as of v0.2 of the dsc-fleet platform.**
>
> Configurations, assignments, scheduling, and membership are now managed
> centrally in **[anwather/dsc-fleet-dashboard](https://github.com/anwather/dsc-fleet-dashboard)**.
> The agent runner (`dsc-fleet/bootstrap/Invoke-DscRunner.ps1`) no longer
> pulls from a git repo on disk — it polls the dashboard API for assignments.
>
> This repo is kept as a **read-only reference** for the eight authoring
> patterns under `samples/` and the original group/membership/schedule
> design notes. Copy any sample you need into the dashboard's config editor.

## What replaced this

| What this repo did                    | Where it lives now                                                       |
| ------------------------------------- | ------------------------------------------------------------------------ |
| Hold `.dsc.yaml` configurations       | Dashboard "Configs" page (versioned per-config in Postgres).             |
| Define group → configs + cadence      | Dashboard "Assignments" page (per-server, per-config interval).          |
| Membership rules (hostname, AD group) | Server tags / explicit per-server assignment in the dashboard.           |
| `assignments.json` schema             | Dashboard API contract (`apps/api/src/routes/assignments.ts`).           |
| `samples/*.dsc.yaml`                  | Still useful — copy/paste into the dashboard's YAML config editor.       |

## Why the change

- One source of truth for **what's assigned where** removes the divergence
  problems we hit when servers had stale clones.
- Per-server intervals beat group cadences for real fleets — different
  classes of host need different cadences for the same config.
- Run history, drift, and prereq state need a database. The dashboard has
  Postgres + a websocket UI; this repo had only git log.

## Onboarding (current way)

```powershell
# On the target server, once:
.\bootstrap\Install-DscV3.ps1 `
    -PlatformRepoUrl 'https://github.com/anwather/dsc-fleet.git' `
    -PlatformRef     'main'

# Then from the dashboard UI: Add Server → Provision.
```

See [`anwather/dsc-fleet`](https://github.com/anwather/dsc-fleet) and
[`anwather/dsc-fleet-dashboard`](https://github.com/anwather/dsc-fleet-dashboard)
for the active platform.

## Historical content

The original README content (eight authoring samples, schedules,
membership rules) is preserved below for reference.

---

# dsc-fleet-configs (historical README)

The **configs** repo for the dsc-fleet system. Pairs with
**[anwather/dsc-fleet](https://github.com/anwather/dsc-fleet)**, which holds
the runner, the single custom resource module (`DscV3.RegFile`), and the
reporting backend.

This repo is the data plane: every push here ships to every server on its next
cycle (≤30 min). Platform changes (runner / module) require a re-bootstrap;
config changes do not.

## Layout

| Path                        | Purpose                                                     |
| --------------------------- | ----------------------------------------------------------- |
| `assignments/assignments.json` | Group → configs + cadence + membership.                  |
| `assignments/schema.json`   | JSON Schema the runner validates `assignments.json` against. |
| `configs/baseline/`         | Configurations applied to **every** server.                  |
| `configs/groups/`           | Per-group overrides (web / db / etc.).                      |
| `configs/apps/`             | App install configs (winget / MSI).                         |
| `configs/registry/`         | Granular registry tweaks + `.reg` file imports.             |
| `configs/registry/files/`   | Source `.reg` fixtures consumed by the `RegFile` resource.  |
| `samples/`                  | Eight standalone, copy-pasteable example configurations.    |

## Resource model

Three sources, two adapters:

| Source                          | Examples                                          | How it loads                                                |
| ------------------------------- | ------------------------------------------------- | ----------------------------------------------------------- |
| **`DscV3.RegFile`** (custom, this platform) | `RegFile`                              | `Microsoft.DSC/PowerShell` (class-based v3)                  |
| **`Microsoft.WinGet.DSC`** (PSGallery)      | `WinGetPackage`                        | `Microsoft.DSC/PowerShell` (class-based v3)                  |
| **`PSDscResources`** (PSGallery)            | `MsiPackage`, `Script`, `WindowsFeature`, `Group`, `Registry`, … | Wrap in **`Microsoft.Windows/WindowsPowerShell`**           |
| **`PSDesiredStateConfiguration`** (in-box)  | `Service`, `PSModule`, `PSRepository`, `WindowsFeature`, …       | Wrap in **`Microsoft.Windows/WindowsPowerShell`**           |
| Built-ins (DSC v3 CLI)                      | `Microsoft.Windows/Registry`, `Microsoft.DSC/Assertion`, `Microsoft.DSC/Group` | Use directly                                |

The eight authoring samples remain available under [`samples/`](samples/).
