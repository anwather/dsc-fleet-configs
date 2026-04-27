# Assignments

`assignments.json` decides **which configs apply to which servers, and how often**.
The runner (`bootstrap/Invoke-DscRunner.ps1`) reads this on every scheduled run.

## Structure

```jsonc
{
  "groups": {
    "<groupName>": {
      "schedule": "<Schedule>",   // see "Schedule formats"
      "mode":     "set" | "test", // set = enforce, test = report-only
      "configs":  [ "configs/.../*.dsc.yaml", ... ]
    }
  },
  "membership": {
    "<groupName>": [ <rule>, <rule>, ... ]   // OR-combined
  }
}
```

A server is in a group when **any** of that group's membership rules match.
The `all` group conventionally exists with `[{ "type": "all" }]`.

## Schedule formats

| Schedule         | Meaning                                                  |
| ---------------- | -------------------------------------------------------- |
| `OnDemand`       | Never run automatically; only via manual trigger.        |
| `Hourly`         | Run at most once per 60 minutes.                         |
| `Every<N>Hours`  | Run at most once per N hours (e.g. `Every6Hours`).       |
| `Every<N>Minutes`| Run at most once per N minutes (e.g. `Every15Minutes`).  |
| `Daily HH:MM`    | Run once per day on/after HH:MM (24h, local time).       |

Cadence is enforced by the runner using a per-group state file at
`C:\ProgramData\DscV3\state\<group>.json` recording `lastRunUtc`.

## Membership rule types

| Type        | Fields              | Match condition                                                                |
| ----------- | ------------------- | ------------------------------------------------------------------------------ |
| `all`       | —                   | Always true.                                                                   |
| `hostname`  | `pattern`           | Regex match against `$env:COMPUTERNAME` (case-insensitive).                    |
| `arcTag`    | `key`, `value`      | Azure Arc-enabled servers: tag with `key` equals `value` (case-insensitive).   |
| `adGroup`   | `value`             | Computer account is a member of the AD group `value` (sAMAccountName).         |

Arc tags are read from the local Arc agent metadata
(`C:\ProgramData\AzureConnectedMachineAgent\Config\agentconfig.json` and the
IMDS endpoint at `http://169.254.169.254`).

## Adding a new group

1. Add an entry under `groups` with `schedule`, `mode`, `configs`.
2. Add an entry under `membership` with at least one rule.
3. Validate locally:
   ```powershell
   pwsh ./bootstrap/Invoke-DscRunner.ps1 -ValidateOnly
   ```
4. Commit + tag. Servers pick up the change on their next scheduled run.

## Validation

`assignments/schema.json` is a JSON Schema for this file. CI validates
`assignments.json` against it on every push.
