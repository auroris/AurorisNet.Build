# AurorisNet.Build

The release automation, documentation layout, badges and icon rules that the AurorisNet
package repositories share.

![MIT license](https://raw.githubusercontent.com/auroris/AurorisNet.Build/main/badges/license-mit.svg)

Each package repository keeps three short workflow files and calls the actions and scripts
here for the steps they have in common. A change here reaches every repository on its next
workflow run, so the repositories stay alike without copies to keep in step.

## What is here

| Path | Contents | Used by |
|---|---|---|
| [`actions/version`](actions/version/action.yml) | Chooses the version and tag of a release: `MAJOR.MINOR.PATCH`, or a version that follows the Umbraco release. | `release.yml` in every repository |
| [`actions/publish`](actions/publish/action.yml) | Reserves the tag, pushes the packages to nuget.org with trusted publishing and publishes the GitHub release. | `release.yml` in every repository |
| [`actions/dependabot-release`](actions/dependabot-release/action.yml) | Merges a Dependabot pull request that passed, and starts a release when the update ships. | `ci.yml` in every repository |
| [`.github/workflows/umbraco-releases.yml`](.github/workflows/umbraco-releases.yml) | The reusable workflow that tests each new Umbraco release and releases the package for it. | `umbraco-releases.yml` in the Umbraco repositories |
| [`actions/find-umbraco-releases`](actions/find-umbraco-releases/action.yml), [`test-umbraco-releases`](actions/test-umbraco-releases/action.yml), [`report-umbraco-releases`](actions/report-umbraco-releases/action.yml) | The steps of that workflow. | The reusable workflow |
| [`scripts/`](scripts) | The PowerShell behind the actions, each with Pester tests. | The actions, and developers who add an Umbraco release by hand |
| [`badges/`](badges) | The static README badges, and `New-Badge.ps1`, which makes one. | Every README |
| [`icons/`](icons/README.md) | The package icon style, and `Render-Icon.ps1`, which renders an icon's PNG from its SVG. | Every repository's `docs/images/icon.*` |
| [`docs/readme-style.md`](docs/readme-style.md) | The section order and rules for each README and docs page. | Every README |
| [`docs/writing-guide.md`](docs/writing-guide.md) | How the documentation is written. | Every README and docs page |
| [`docs/releasing.md`](docs/releasing.md) | How a release happens, by hand and automatically, and the nuget.org setup. | Each README's **Releases** section links here |

## Repositories that use it

| Repository | Workflows that call this repository |
|---|---|
| [AurorisNet.IdentityServer](https://github.com/auroris/AurorisNet.IdentityServer) | `ci.yml`, `release.yml` |
| [AurorisNet.InteractiveReports](https://github.com/auroris/AurorisNet.InteractiveReports) | `ci.yml`, `release.yml` |
| [AurorisNet.Umbraco.AppBlocks](https://github.com/auroris/AurorisNet.Umbraco.AppBlocks) | `ci.yml`, `release.yml`, `umbraco-releases.yml` |
| [AurorisNet.Umbraco.AppHost](https://github.com/auroris/AurorisNet.Umbraco.AppHost) | `ci.yml`, `release.yml` |
| [AurorisNet.Umbraco.ApplicationVirtualPathFix](https://github.com/auroris/AurorisNet.Umbraco.ApplicationVirtualPathFix) | `ci.yml`, `release.yml`, `umbraco-releases.yml` |
| [AurorisNet.Umbraco.BreakGlass](https://github.com/auroris/AurorisNet.Umbraco.BreakGlass) | `ci.yml`, `release.yml`, `umbraco-releases.yml` |
| [AurorisNet.Umbraco.DisableTelemetry](https://github.com/auroris/AurorisNet.Umbraco.DisableTelemetry) | `ci.yml`, `release.yml`, `umbraco-releases.yml` |
| [AurorisNet.Umbraco.Drawio](https://github.com/auroris/AurorisNet.Umbraco.Drawio) | `ci.yml`, `release.yml`, `umbraco-releases.yml` |
| [AurorisNet.Umbraco.IdentityServer.Directory](https://github.com/auroris/AurorisNet.Umbraco.IdentityServer.Directory) | `ci.yml`, `release.yml`, `umbraco-releases.yml` |
| [AurorisNet.Umbraco.IdentityServer.SSO](https://github.com/auroris/AurorisNet.Umbraco.IdentityServer.SSO) | `ci.yml`, `release.yml`, `umbraco-releases.yml` |

## Using an action

A repository's `release.yml` chooses the version, runs its own test and pack steps, and
publishes:

```yaml
- name: Choose the version
  id: version
  uses: auroris/AurorisNet.Build/actions/version@main
  with:
    version: ${{ inputs.version }}
    bump: ${{ inputs.bump }}
    dry-run: ${{ inputs.dry-run }}

# The repository's own test and pack steps, which pack into artifacts/packages.

- name: Publish
  uses: auroris/AurorisNet.Build/actions/publish@main
  with:
    versions: ${{ steps.version.outputs.versions }}
    dry-run: ${{ inputs.dry-run }}
    notes: ${{ inputs.notes }}
```

The job needs `contents: write` and `id-token: write`. Each action's `action.yml` lists its
inputs. The [release guide](docs/releasing.md) describes the whole flow.

## Developing

The scripts need PowerShell 7 and Pester 5. Run their tests before pushing, because every
repository runs the scripts from `main`:

```powershell
Invoke-Pester scripts
```

`ci.yml` runs the same tests on each push and pull request. To try a workflow change
without publishing, run a repository's Release workflow with `dry-run`, or its New Umbraco
releases workflow with `dry-run` and a release to test.

## License

[MIT](LICENSE)
