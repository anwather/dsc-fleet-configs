# dsc-fleet-configs

The **configs** repo for the dsc-fleet system. Pairs with
**[anwather/dsc-fleet](https://github.com/anwather/dsc-fleet)**, which holds
the runner, custom resource module, and reporting backend.

This repo is the data plane: every push here ships to every server on its next
cycle (≤30 min). Platform changes (runner / module) require a re-bootstrap;
config changes do not.

## Layout

| Path                   | Purpose                                                          |
| ---------------------- | ---------------------------------------------------------------- |
| `assignments/`         | `assignments.json` — group → configs + cadence + membership.     |
| `assignments/schema.json` | JSON Schema the runner validates `assignments.json` against.   |
| `configs/baseline/`    | Configurations applied to **every** server.                       |
| `configs/groups/`      | Per-group overrides (web / db / etc.).                           |
| `configs/apps/`        | App install configs (Winget / Chocolatey / MSI / PSResourceGet). |
| `configs/registry/`    | Granular registry tweaks + `.reg` file imports.                  |
| `configs/registry/files/` | Source `.reg` fixtures consumed by `RegFile` resource.         |

## Authoring a config

A config is a DSC v3 configuration document — a YAML file ending in `.dsc.yaml`.

```yaml
# configs/baseline/example.dsc.yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
metadata:
  Microsoft.DSC:
    securityContext: elevated   # all server-targeting configs need this
resources:
  - name: Disable SMBv1
    type: Microsoft.Windows/Registry
    properties:
      keyPath: HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters
      valueName: SMB1
      valueData: { DWord: 0 }
```

Then add it to a group in `assignments/assignments.json`:

```json
{
  "groups": {
    "all": {
      "configs": [ "configs/baseline/*.dsc.yaml" ],
      "schedule": "Daily 03:00",
      "mode": "set"
    }
  },
  "membership": {
    "all": [ { "type": "all" } ]
  }
}
```

## Schedules

The runner re-evaluates every 30 minutes; the schedule string gates whether
the group runs on this tick:

| String              | Meaning                                          |
| ------------------- | ------------------------------------------------ |
| `OnDemand`          | Never auto-runs. Only via `-Now -OnlyGroup`.     |
| `Hourly`            | At least one hour since last run.                |
| `Every5Minutes`     | At least 5 min since last run.                   |
| `Every2Hours`       | At least 2 hr since last run.                    |
| `Daily 03:00`       | Once per day on/after 03:00 server-local time.   |

## Membership rules

In `assignments/assignments.json`, each group's membership is OR'd:

```json
"membership": {
  "web-servers": [
    { "type": "hostname", "pattern": "^web\\d+$" },
    { "type": "arcTag",   "key":     "Role", "value": "Web" },
    { "type": "adGroup",  "value":   "DSC_WebServers" }
  ]
}
```

Supported types: `all`, `hostname` (regex), `arcTag` (key + value, also works
on Azure VMs via IMDS), `adGroup` (sAM name lookup via the computer account).

## Validating before pushing

```powershell
# From a clone of dsc-fleet (the platform repo):
pwsh .\bootstrap\Invoke-DscRunner.ps1 `
    -RepoRoot <path-to-this-clone> -ValidateOnly -NoFetch

# Or just dsc parse:
dsc config test --file configs/baseline/registry-smbv1.dsc.yaml
```

CI runs both checks on every PR.

## Custom resources available

(Provided by `DscV3.Discovery` from the platform repo — installed by bootstrap)

| Resource             | Usage                                          |
| -------------------- | ---------------------------------------------- |
| `WingetPackage`      | Install/uninstall apps via `winget`.            |
| `ChocolateyPackage`  | Install/uninstall apps via `choco`.             |
| `MsiFromShare`       | Install MSI from a UNC share (idempotent).      |
| `PSResourceInstall`  | Install a PowerShell module via PSResourceGet.  |
| `RegFile`            | Bulk-import a `.reg` file (SHA256-keyed re-eval). |

Built-in resources (no module install required) include
`Microsoft.Windows/Registry`, `Microsoft.Windows/WindowsPowerShell` (DSCv1
adapter), `Microsoft.DSC/PowerShell`, etc.
