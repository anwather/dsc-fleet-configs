# dsc-fleet-configs

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

**Rule of thumb**

* Class-based PSDSC v3 resources → wrap in `Microsoft.DSC/PowerShell` (or use
  directly at the top level — adapter discovery still works).
* MOF-based / function-based PSDSC v1 resources → wrap in
  `Microsoft.Windows/WindowsPowerShell`.

`Microsoft.WinGet.DSC` and `PSDscResources` are installed automatically by
`Install-Prerequisites.ps1` on every onboarded server.

## Getting started — eight authoring patterns

Eight ready-to-paste samples live in [`samples/`](samples/), one per common
scenario. Each is fully commented; pick the closest match and copy it into
`configs/<area>/<name>.dsc.yaml`. All can be tested locally with:

```powershell
dsc config test --file samples\01-registry-single-value.dsc.config.yaml
```

### 1 — Set a single registry value (`Microsoft.Windows/Registry`, built-in)

```yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
metadata:
  Microsoft.DSC: { securityContext: elevated }
resources:
  - name: ManagedBy marker
    type: Microsoft.Windows/Registry
    properties:
      keyPath:   HKLM\SOFTWARE\Contoso\DscV3
      valueName: ManagedBy
      valueData: { DWord: 1 }
      _exist:    true
```

### 2 — Bulk-import a `.reg` file (`DscV3.RegFile/RegFile`, custom)

```yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
metadata:
  Microsoft.DSC: { securityContext: elevated }
resources:
  - name: Baseline registry import
    type: Microsoft.DSC/PowerShell
    properties:
      resources:
        - name: Import baseline-security.reg
          type: DscV3.RegFile/RegFile
          properties:
            Path:   C:\ProgramData\DscV3\repo\configs\registry\files\baseline-security.reg
            Hash:   ''        # optional SHA256 — '' to skip integrity check
            Ensure: Present
```

### 3 — Install a winget package (`Microsoft.WinGet.DSC/WinGetPackage`)

```yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
metadata:
  Microsoft.DSC: { securityContext: elevated }
resources:
  - name: Install 7-Zip
    type: Microsoft.WinGet.DSC/WinGetPackage
    properties:
      Id:     7zip.7zip
      Source: winget
      Ensure: Present
```

### 4 — Install an MSI from a UNC share (`PSDscResources/MsiPackage`)

```yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
metadata:
  Microsoft.DSC: { securityContext: elevated }
resources:
  - name: ACME Agent MSI
    type: Microsoft.Windows/WindowsPowerShell
    properties:
      resources:
        - name: Install ACME Agent
          type: PSDscResources/MsiPackage
          properties:
            ProductId: '{8E9A3C2A-1C7C-4F31-9F1A-AAAAAAAAAAAA}'
            Path:      \\fileshare01.contoso.local\packages\AcmeAgent\AcmeAgent-1.4.0.msi
            Ensure:    Present
            Arguments: /qn /norestart REBOOT=ReallySuppress
```

### 5 — Install a PowerShell module (`PSDesiredStateConfiguration/PSModule`)

```yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
metadata:
  Microsoft.DSC: { securityContext: elevated }
resources:
  - name: PSGallery + PSModule
    type: Microsoft.Windows/WindowsPowerShell
    properties:
      resources:
        - name: Trust PSGallery
          type: PSDesiredStateConfiguration/PSRepository
          properties:
            Name:               PSGallery
            InstallationPolicy: Trusted
        - name: Install Microsoft.WinGet.Client
          type: PSDesiredStateConfiguration/PSModule
          dependsOn:
            - "[resourceId('PSDesiredStateConfiguration/PSRepository','Trust PSGallery')]"
          properties:
            Name:       Microsoft.WinGet.Client
            Repository: PSGallery
            Ensure:     Present
```

### 6 — Run a Get/Test/Set Script (`PSDscResources/Script`)

```yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
metadata:
  Microsoft.DSC: { securityContext: elevated }
resources:
  - name: Provision C:\Tools
    type: Microsoft.Windows/WindowsPowerShell
    properties:
      resources:
        - name: Ensure C:\Tools directory
          type: PSDscResources/Script
          properties:
            GetScript:  '@{ Result = (Test-Path ''C:\Tools'') }'
            TestScript: 'Test-Path ''C:\Tools'''
            SetScript:  'New-Item -Path ''C:\Tools'' -ItemType Directory -Force | Out-Null'
```

### 7 — Configure a Windows service (`PSDesiredStateConfiguration/Service`)

```yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
metadata:
  Microsoft.DSC: { securityContext: elevated }
resources:
  - name: Service baseline
    type: Microsoft.Windows/WindowsPowerShell
    properties:
      resources:
        - name: Disable Print Spooler
          type: PSDesiredStateConfiguration/Service
          properties:
            Name:        Spooler
            StartupType: Disabled
            State:       Stopped
            Ensure:      Present
```

### 8 — Install a server role/feature (`PSDscResources/WindowsFeature`)

```yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
metadata:
  Microsoft.DSC: { securityContext: elevated }
resources:
  - name: Web-Server role
    type: Microsoft.Windows/WindowsPowerShell
    properties:
      resources:
        - name: Install IIS
          type: PSDscResources/WindowsFeature
          properties:
            Name:                 Web-Server
            Ensure:               Present
            IncludeAllSubFeature: false
```

## Assignments

Add new configs by listing them in a group inside `assignments/assignments.json`:

```json
{
  "groups": {
    "all": {
      "configs":  [ "configs/baseline/*.dsc.yaml" ],
      "schedule": "Daily 03:00",
      "mode":     "set"
    },
    "web-servers": {
      "configs":  [ "configs/groups/web-servers.dsc.yaml", "configs/apps/install-7zip-winget.dsc.yaml" ],
      "schedule": "Hourly",
      "mode":     "set"
    }
  },
  "membership": {
    "all":         [ { "type": "all" } ],
    "web-servers": [ { "type": "hostname", "pattern": "^web\\d+$" } ]
  }
}
```

### Schedules

The runner re-evaluates every 30 minutes; the schedule string gates whether
the group runs on this tick:

| String          | Meaning                                          |
| --------------- | ------------------------------------------------ |
| `OnDemand`      | Never auto-runs. Only via `-Now -OnlyGroup`.     |
| `Hourly`        | At least one hour since last run.                |
| `Every5Minutes` | At least 5 min since last run.                   |
| `Every2Hours`   | At least 2 hr since last run.                    |
| `Daily 03:00`   | Once per day on/after 03:00 server-local time.   |

### Membership rules (OR'd within a group)

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

# Or just dsc parse a single file:
dsc config test --file configs/baseline/registry-smbv1.dsc.yaml
```

CI runs both checks on every PR.

## Reporting

Per-run outcome is POSTed to a Function App that lands the data in a Log
Analytics workspace. Dashboards & sample KQL — coming soon.
