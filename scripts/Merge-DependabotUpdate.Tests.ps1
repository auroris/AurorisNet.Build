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
    It 'merges a shipped patch update and releases a patch' {
        $output = Invoke-Merge @{ Ecosystem = 'nuget'; UpdateType = 'version-update:semver-patch'; Dependencies = 'OpenIddict.Server, xunit.v3' }
        $output | Should -BeLike '*gh pr merge 7 --squash --delete-branch*'
        $output | Should -BeLike '*gh workflow run release.yml --ref main -f test=false -f notes=Updates OpenIddict.Server. -f bump=patch*'
    }

    It 'releases a minor version for a shipped minor update' {
        Invoke-Merge @{ Ecosystem = 'nuget'; UpdateType = 'version-update:semver-minor'; Dependencies = 'Serilog' } |
            Should -BeLike '*-f bump=minor*'
    }

    It 'sends no bump to a package whose version follows the Umbraco release' {
        $output = Invoke-Merge @{ Ecosystem = 'nuget'; UpdateType = 'version-update:semver-minor'; Dependencies = 'Serilog'; Versioning = 'umbraco' }
        $output | Should -BeLike '*gh workflow run release.yml*'
        $output | Should -Not -BeLike '*bump=*'
    }

    It 'merges a test package update without a release' {
        $output = Invoke-Merge @{ Ecosystem = 'nuget'; UpdateType = 'version-update:semver-minor'; Dependencies = 'xunit.v3' }
        $output | Should -BeLike '*gh pr merge 7*'
        $output | Should -Not -BeLike '*workflow run*'
    }

    It 'merges a major update of workflow actions without a release' {
        $output = Invoke-Merge @{ Ecosystem = 'github_actions'; UpdateType = 'version-update:semver-major'; Dependencies = 'actions/checkout' }
        $output | Should -BeLike '*gh pr merge 7*'
        $output | Should -Not -BeLike '*workflow run*'
    }

    It 'leaves a major package update for review' {
        $output = Invoke-Merge @{ Ecosystem = 'nuget'; UpdateType = 'version-update:semver-major'; Dependencies = 'Serilog' }
        $output | Should -BeLike '*gh pr comment 7*'
        $output | Should -Not -BeLike '*pr merge*'
    }

    It 'releases an npm update only when the package embeds npm files and the update is not development-only' {
        $npm = @{ Ecosystem = 'npm_and_yarn'; UpdateType = 'version-update:semver-minor' }
        Invoke-Merge ($npm + @{ Dependencies = 'esbuild' }) | Should -Not -BeLike '*workflow run*'
        Invoke-Merge ($npm + @{ Dependencies = 'esbuild, playwright'; NpmShips = $true; NpmDevelopmentOnly = 'playwright,happy-dom' }) |
            Should -BeLike '*-f notes=Updates esbuild. -f bump=patch*'
        Invoke-Merge ($npm + @{ Dependencies = 'playwright'; NpmShips = $true; NpmDevelopmentOnly = 'playwright,happy-dom' }) |
            Should -Not -BeLike '*workflow run*'
    }

    It 'stops when no shipped project is found' {
        { Invoke-Merge @{ Ecosystem = 'nuget'; Dependencies = 'Serilog'; ShippedProjects = 'missing' } } | Should -Throw '*No project file*'
    }
}
