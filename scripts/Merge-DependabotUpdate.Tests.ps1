BeforeAll {
    $script = Join-Path $PSScriptRoot 'Merge-DependabotUpdate.ps1'
    $fixture = Join-Path $TestDrive 'repository'
    New-Item -ItemType Directory -Path "$fixture/src/Package", "$fixture/tests/Package.Tests" -Force | Out-Null
    Set-Content -LiteralPath "$fixture/src/Package/Package.csproj" '<Project><ItemGroup><PackageReference Include="OpenIddict.Server" Version="7.9.0" /><PackageReference Include="Serilog" /></ItemGroup></Project>'
    Set-Content -LiteralPath "$fixture/tests/Package.Tests/Package.Tests.csproj" '<Project><ItemGroup><PackageReference Include="xunit.v3" Version="4.0.3" /></ItemGroup></Project>'
    <#
    .SYNOPSIS
    Runs the script on a dry run in the fixture repository and returns what it printed as one string.
    #>
    function Invoke-Merge([hashtable] $arguments) {
        Push-Location $fixture
        try { (& $script -PullRequest 7 -DryRun @arguments 6>&1) -join "`n" } finally { Pop-Location }
    }
}

Describe 'Merging a Dependabot update' {
    It 'merges a shipped patch update and records a patch for the weekly release' {
        $output = Invoke-Merge @{ Ecosystem = 'nuget'; UpdateType = 'version-update:semver-patch'; Dependencies = 'OpenIddict.Server, xunit.v3' }
        $output | Should -BeLike "*gh pr merge 7 --squash --delete-branch --body Release-Bump: patch`nRelease-Note: Updates OpenIddict.Server.*"
        $output | Should -Not -BeLike '*workflow run*'
    }

    It 'records a minor version for a shipped minor update' {
        Invoke-Merge @{ Ecosystem = 'nuget'; UpdateType = 'version-update:semver-minor'; Dependencies = 'Serilog' } |
            Should -BeLike "*--body Release-Bump: minor`nRelease-Note: Updates Serilog.*"
    }

    It 'merges a test package update with nothing recorded' {
        $output = Invoke-Merge @{ Ecosystem = 'nuget'; UpdateType = 'version-update:semver-minor'; Dependencies = 'xunit.v3' }
        $output | Should -BeLike '*gh pr merge 7*'
        $output | Should -Not -BeLike '*Release-*'
    }

    It 'merges a major update of workflow actions with nothing recorded' {
        $output = Invoke-Merge @{ Ecosystem = 'github_actions'; UpdateType = 'version-update:semver-major'; Dependencies = 'actions/checkout' }
        $output | Should -BeLike '*gh pr merge 7*'
        $output | Should -Not -BeLike '*Release-*'
    }

    It 'leaves a major package update for review' {
        $output = Invoke-Merge @{ Ecosystem = 'nuget'; UpdateType = 'version-update:semver-major'; Dependencies = 'Serilog' }
        $output | Should -BeLike '*gh pr comment 7*'
        $output | Should -Not -BeLike '*pr merge*'
    }

    It 'records an npm update only when the package embeds npm files and the update is not development-only' {
        $npm = @{ Ecosystem = 'npm_and_yarn'; UpdateType = 'version-update:semver-minor' }
        Invoke-Merge ($npm + @{ Dependencies = 'esbuild' }) | Should -Not -BeLike '*Release-*'
        Invoke-Merge ($npm + @{ Dependencies = 'esbuild, playwright'; NpmShips = $true; NpmDevelopmentOnly = 'playwright,happy-dom' }) |
            Should -BeLike "*--body Release-Bump: patch`nRelease-Note: Updates esbuild.*"
        Invoke-Merge ($npm + @{ Dependencies = 'playwright'; NpmShips = $true; NpmDevelopmentOnly = 'playwright,happy-dom' }) |
            Should -Not -BeLike '*Release-*'
    }

    It 'stops when no shipped project is found' {
        { Invoke-Merge @{ Ecosystem = 'nuget'; Dependencies = 'Serilog'; ShippedProjects = 'missing' } } | Should -Throw '*No project file*'
    }
}
