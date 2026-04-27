Describe 'assignments.json schema' {
    BeforeAll {
        $repoRoot = Resolve-Path "$PSScriptRoot/../.."
        $script:schema      = Join-Path $repoRoot 'assignments/schema.json'
        $script:assignments = Join-Path $repoRoot 'assignments/assignments.json'
    }
    It 'sample assignments.json validates against schema.json' {
        $json = Get-Content -Raw $assignments
        { Test-Json -Json $json -SchemaFile $schema -ErrorAction Stop } | Should -Not -Throw
    }
    It 'rejects an unknown membership rule type' {
        $bad = @{
            groups = @{ x = @{ schedule='Hourly'; configs=@('configs/x.yaml') } }
            membership = @{ x = @( @{ type='magicTag'; key='k'; value='v' } ) }
        } | ConvertTo-Json -Depth 10
        { Test-Json -Json $bad -SchemaFile $schema -ErrorAction Stop } | Should -Throw
    }
    It 'rejects a malformed schedule string' {
        $bad = @{
            groups = @{ x = @{ schedule='WheneverIWant'; configs=@('a.yaml') } }
            membership = @{ x = @( @{ type='all' } ) }
        } | ConvertTo-Json -Depth 10
        { Test-Json -Json $bad -SchemaFile $schema -ErrorAction Stop } | Should -Throw
    }
}

Describe 'Config YAML files parse with dsc' {
    BeforeAll {
        $repoRoot = Resolve-Path "$PSScriptRoot/../.."
        $script:dscExe  = (Get-Command dsc -ErrorAction SilentlyContinue)?.Source
        $script:configs = Get-ChildItem (Join-Path $repoRoot 'configs') -Recurse -Filter *.dsc.yaml
    }
    It 'has at least one config to test' {
        $configs.Count | Should -BeGreaterThan 0
    }
    It '<file> parses without schema errors' -ForEach @(
        $configs | ForEach-Object { @{ file = $_.FullName } }
    ) {
        if (-not $dscExe) { Set-ItResult -Skipped -Because 'dsc CLI not installed'; return }
        $output = & $dscExe config test --file $file 2>&1 | Out-String
        # Exit-2 elevation refusal is acceptable; YAML/schema errors are not.
        $output | Should -Not -Match 'Failed to parse'
        $output | Should -Not -Match 'schema validation'
    }
}
