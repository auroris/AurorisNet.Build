# AurorisNet.Build

Shared GitHub Actions workflows, release scripts, badges, icon rules, and documentation guides used across the `AurorisNet.*` repositories.

![MIT license](https://raw.githubusercontent.com/auroris/AurorisNet.Build/main/badges/license-mit.svg)

## Contents

| Path | Purpose |
|---|---|
| [`actions/version`](actions/version/action.yml) | Computes release versions and tags (`MAJOR.MINOR.PATCH` or Umbraco-aligned). |
| [`actions/publish`](actions/publish/action.yml) | Reserves the tag, publishes NuGet packages via trusted publishing, and creates the GitHub release. |
| [`actions/dependabot-release`](actions/dependabot-release/action.yml) | Auto-merges passing Dependabot PRs and records them for the weekly release. |
| [`.github/workflows/weekly-release.yml`](.github/workflows/weekly-release.yml) | Reusable workflow that publishes a week's merged updates in one release. |
| [`.github/workflows/umbraco-releases.yml`](.github/workflows/umbraco-releases.yml) | Reusable workflow that tests new Umbraco releases and updates tested ranges. |
| [`scripts/`](scripts) | PowerShell scripts behind the actions, with Pester tests. |
| [`badges/`](badges) | Static SVG badges and `New-Badge.ps1`. |
| [`icons/`](icons/README.md) | Package icon rules and `Render-Icon.ps1`. |
| [`docs/readme-style.md`](docs/readme-style.md) | README layout and Umbraco Marketplace naming rules. |
| [`docs/writing-guide.md`](docs/writing-guide.md) | Technical writing guidelines. |
| [`docs/releasing.md`](docs/releasing.md) | Release workflow and nuget.org trusted-publishing guide. |

## Testing scripts

Requires PowerShell 7 and Pester 5:

```powershell
Invoke-Pester scripts
```

## License

[MIT](LICENSE)
