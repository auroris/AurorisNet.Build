# Release automation

Each AurorisNet package follows one primary dependency. When that dependency publishes a
release, the package's repository tests the package on that release and, when the tests
pass, publishes a new package version to nuget.org and GitHub. A person can also start a
release by hand.

## The three workflows

Every package repository has the same three workflow files. Their shared steps come from
the actions and scripts in this repository, at `main`.

| Workflow | Starts | What it does |
|---|---|---|
| `ci.yml` | A pull request, or by hand | Builds the package and runs its tests on the newest supported release of the primary dependency. Merges a Dependabot pull request that passes, and starts a release when the update changes what the package ships. |
| `umbraco-releases.yml` (Umbraco packages) | Each day, or by hand | Looks on nuget.org for Umbraco releases the package does not list. Tests the package on those releases only. Adds each release that passes to `UmbracoReleases` on `main` and starts a release. Opens an issue for each release that fails. |
| `release.yml` | By hand, or from the two above | Chooses the version, runs the tests unless the caller has just run them, packs, pushes to nuget.org and publishes the GitHub release. |

The workflows test one release of the primary dependency: the newest, or the one that was
just published. The full matrix of every supported release runs on a developer's machine,
with the command in each README's **Developing** section. Run it before a release that
changes the package's code.

## Primary dependencies

| Repository | Packages | Primary dependency | Found by | Version numbers |
|---|---|---|---|---|
| [AurorisNet.IdentityServer](https://github.com/auroris/AurorisNet.IdentityServer) | `AurorisNet.IdentityServer`, `AurorisNet.ActiveDirectory`, `AurorisNet.IdentityServer.Directory` | OpenIddict | Dependabot, daily | `1.2.3` |
| [AurorisNet.InteractiveReports](https://github.com/auroris/AurorisNet.InteractiveReports) | `AurorisNet.InteractiveReports`, `.Core`, `.AspNetCore`, `.Client.GraphQL`, `.Client.FileDownload` | The .NET platform packages (`Microsoft.Extensions.*`) | Dependabot, daily | `1.2.3` |
| [AurorisNet.Pressroom](https://github.com/auroris/AurorisNet.Pressroom) | `AurorisNet.Pressroom.Client`, and the server as Windows and Linux archives | Microsoft.Playwright, which selects the Chromium build | Dependabot, daily | `1.2.3` |
| [AurorisNet.Umbraco.AppBlocks](https://github.com/auroris/AurorisNet.Umbraco.AppBlocks) | `AurorisNet.Umbraco.AppBlocks`, `.Documents`, `.InteractiveReports`, `.Testing` | Umbraco | `umbraco-releases.yml` | `0.1.0-alpha.2` |
| [AurorisNet.Umbraco.AppHost](https://github.com/auroris/AurorisNet.Umbraco.AppHost) | `AurorisNet.Umbraco.AppHost`, `.Testing` | AppBlocks, with the Umbraco release it pins | Dependabot, daily | `1.0.0-alpha.2` |
| [AurorisNet.Umbraco.ApplicationVirtualPathFix](https://github.com/auroris/AurorisNet.Umbraco.ApplicationVirtualPathFix) | `AurorisNet.Umbraco.ApplicationVirtualPathFix` | Umbraco | `umbraco-releases.yml` | `18.3.2.1` |
| [AurorisNet.Umbraco.BreakGlass](https://github.com/auroris/AurorisNet.Umbraco.BreakGlass) | `AurorisNet.Umbraco.BreakGlass` | Umbraco | `umbraco-releases.yml` | `1.2.3` |
| [AurorisNet.Umbraco.DisableTelemetry](https://github.com/auroris/AurorisNet.Umbraco.DisableTelemetry) | `AurorisNet.Umbraco.DisableTelemetry` | Umbraco | `umbraco-releases.yml` | `18.3.2.1` |
| [AurorisNet.Umbraco.Drawio](https://github.com/auroris/AurorisNet.Umbraco.Drawio) | `AurorisNet.Umbraco.Drawio`, `.Selfhosted` | Umbraco | `umbraco-releases.yml` | `1.2.3` |
| [AurorisNet.Umbraco.IdentityServer.Directory](https://github.com/auroris/AurorisNet.Umbraco.IdentityServer.Directory) | `AurorisNet.Umbraco.IdentityServer.Directory` | Umbraco, and `AurorisNet.IdentityServer.Directory` | `umbraco-releases.yml` and Dependabot | `1.2.3` |
| [AurorisNet.Umbraco.IdentityServer.SSO](https://github.com/auroris/AurorisNet.Umbraco.IdentityServer.SSO) | `AurorisNet.Umbraco.IdentityServer.SSO` | Umbraco, and `AurorisNet.IdentityServer` | `umbraco-releases.yml` and Dependabot | `1.2.3` |

## Version numbers

**Semantic versions.** Most packages are numbered `MAJOR.MINOR.PATCH`. A release started by
hand takes a version, or raises the newest release tag by a patch or minor number. An
automatic release raises the minor number when the dependency published a minor release,
which can add API surface, and the patch number otherwise. While a package's newest tag is
a prerelease such as `v0.1.0-alpha.1`, each release continues the series with
`0.1.0-alpha.2`; enter a version by hand to leave it.

**Umbraco-aligned versions.** ApplicationVirtualPathFix and DisableTelemetry replace parts
of Umbraco that can change in any release, so each package version accepts Umbraco releases
up to an exact one. Their version is that Umbraco release followed by a count, such as
`18.3.2.1`. One release publishes a package for each supported Umbraco major version, so a
site can float on `18.*` or `17.*`.

## How a new Umbraco release becomes a package

1. `umbraco-releases.yml` runs each day. Its **find** job reads `UmbracoReleases` in
   `Directory.Build.props` and the versions of `Umbraco.Cms` on nuget.org. A stable release
   newer than the newest listed release of its major version is new. A release whose
   failure issue is still open is skipped.
2. The **test** job adds the new releases to `UmbracoReleases` in its checkout and runs the
   package's tests once for each. It has a read-only token, because it runs code that
   nuget.org published minutes ago.
3. The **report** job reads the test summaries. For the releases that passed, it adds them
   to `UmbracoReleases`, updates the release ranges between the `umbraco-releases` markers
   in the README, commits to `main` and starts `release.yml` with `test` set to `false`. For
   each release that failed, it opens an issue titled `Umbraco <release> fails the tests`.
4. `release.yml` publishes the package.

Close a failure issue once its cause is fixed. The next daily run tests the release again.
To test a release at once, run the workflow by hand and name the release.

A new Umbraco major version gets an issue titled `Support Umbraco <major>`, because the
package needs code changes before its tests can run on it.

A package with no release tag yet has no version to raise. The workflow commits the new
Umbraco release and leaves the first release to a person: run `release.yml` with a version
such as `1.0.0`.

## How a Dependabot update becomes a package

Dependabot opens pull requests for NuGet packages, npm packages where a repository has
them, and workflow actions. The Umbraco packages leave `Umbraco.Cms*` to
`umbraco-releases.yml`. `ci.yml` tests each pull request, and its **dependabot** job then:

- leaves a major version update of a package open, with a comment, for a person to review;
- merges every other update;
- starts `release.yml` when the update is of a package that a shipped project references.
  Updates of test packages and workflow actions merge without a release.

AppHost's pull request for a new Umbraco release groups Umbraco, uSync and the AurorisNet
packages, because they must move together. Its build fails while AppBlocks,
ApplicationVirtualPathFix or DisableTelemetry has no package for that Umbraco release yet.
Dependabot updates the pull request as those packages appear, and it merges once all of
them are on nuget.org. Until AppHost has merged it, a local AppHost build against a newer
AppBlocks checkout stops with a message that the two name different Umbraco releases.

## Starting a release by hand

Open **Actions → Release → Run workflow** on `main`.

| Input | Use |
|---|---|
| `version` | The version to publish, such as `1.2.3` or `1.2.3-rc.1`. Leave empty to raise the newest tag. Packages with Umbraco-aligned versions have no such input. |
| `bump` | `patch` or `minor`, when `version` is empty. |
| `test` | Run the tests before publishing. On by default. |
| `dry-run` | Build, test and pack, and keep the packages as an artifact of the run. Nothing is tagged or published. A dry run can start from any branch. |
| `notes` | Markdown shown above the generated list of changes in the GitHub release. |

The workflow reserves the release tag before it pushes to nuget.org. If a later step fails,
run the workflow again with the same version on the same commit: it finds its tag, skips
the packages nuget.org already has and finishes the release.

## nuget.org trusted publishing

`release.yml` holds no API key. nuget.org exchanges the run's GitHub token for a key that
lasts one hour, when a trusted publishing policy matches the run. Each repository needs one
policy on nuget.org, under **Trusted Publishing**, created by the `AurorisNet` account:

| Setting | Value |
|---|---|
| Repository owner | `auroris` |
| Repository | The repository's name, such as `AurorisNet.Umbraco.BreakGlass` |
| Workflow file | `release.yml` |
| Environment | Empty |

List every package id of the repository in the one policy, from the table under
[Primary dependencies](#primary-dependencies). nuget.org uses a single matching policy for
a run, so two policies for one repository do not combine.

A policy names the repository as it is called now. After a repository is renamed, edit its
policy, or the login step fails with `No matching trust policy`.

The policy matches the workflow file of the job that asks for the key. The publish steps
are a composite action for this reason: they run inside the repository's own `release.yml`.
Keep that file name.

## Order of the first releases

Some packages depend on others from this family, and a package can only be published after
its dependencies are on nuget.org:

1. `AurorisNet.IdentityServer` (with `AurorisNet.ActiveDirectory` and
   `AurorisNet.IdentityServer.Directory`), `AurorisNet.InteractiveReports`,
   `AurorisNet.Pressroom.Client`, ApplicationVirtualPathFix, DisableTelemetry, BreakGlass and Drawio depend on none.
2. `AurorisNet.Umbraco.IdentityServer.SSO` and `AurorisNet.Umbraco.IdentityServer.Directory`
   need the IdentityServer packages. AppBlocks needs `AurorisNet.InteractiveReports` and `AurorisNet.Pressroom.Client`.
3. AppHost needs AppBlocks, BreakGlass, both Umbraco IdentityServer packages,
   ApplicationVirtualPathFix and DisableTelemetry.

## What this repository holds

| Path | Contents | Used by |
|---|---|---|
| `actions/version` | Chooses the version and tag of a release. | `release.yml` in every repository |
| `actions/publish` | Reserves the tag, pushes to nuget.org and publishes the GitHub release. | `release.yml` in every repository |
| `actions/dependabot-release` | Merges a Dependabot pull request and starts a release when it ships. | `ci.yml` in every repository |
| `.github/workflows/umbraco-releases.yml` | The reusable New Umbraco releases workflow. | `umbraco-releases.yml` in the Umbraco repositories, except AppHost |
| `actions/find-umbraco-releases`, `test-umbraco-releases`, `report-umbraco-releases` | The steps of that workflow. | The reusable workflow |
| `scripts/` | The PowerShell behind the actions, with Pester tests. | The actions |

Run the scripts' tests with Pester 5:

```powershell
Invoke-Pester scripts
```

The repositories call the actions at `main`, so a change here reaches every repository on
its next run. `ci.yml` in this repository runs the tests on each pull request.
