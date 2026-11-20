# Release automation

Each AurorisNet package follows one primary dependency. Once a week the package's repository
looks for new releases of that dependency and tests the package on them. When the tests
pass, it publishes one new package version to nuget.org and GitHub, which holds every update
of that week. A person can also start a release by hand. One package,
AurorisNet.ImageGallery.FFmpeg, releases by hand only.

## The workflows

Every package repository has the same workflow files. Their shared steps come from
the actions and scripts in this repository, at `main`.

| Workflow | Starts | What it does |
|---|---|---|
| `ci.yml` | A pull request, or by hand | Builds the package and runs its tests on the newest supported release of the primary dependency. Merges a Dependabot pull request that passes, and records the update for the weekly release when it changes what the package ships. |
| `umbraco-releases.yml` (Umbraco packages) | Each week, or by hand | Looks on nuget.org for Umbraco releases the package does not list. Tests the package on those releases only. Adds each release that passes to `UmbracoReleases` on `main`, recorded for the weekly release. Opens an issue for each release that fails. |
| `weekly-release.yml` | Each week, the day after the two above, or by hand | Reads the commits on `main` since the last release tag. Starts one release when any of them records an update that ships, and none otherwise. |
| `upstream.yml` (ImageGallery.FFmpeg, in place of the one above) | By hand | Looks for a newer stable FFmpeg release, checks its signature, moves the pin on `main` and starts a release. |
| `release.yml` | By hand, or from `weekly-release.yml` or `upstream.yml` | Chooses the version, runs the tests, packs, pushes to nuget.org and publishes the GitHub release. |

The workflows test one release of the primary dependency: the newest, or the one that was
just published. The full matrix of every supported release runs on a developer's machine,
with the command in each README's **Developing** section. Run it before a release that
changes the package's code.

## Primary dependencies

| Repository | Packages | Primary dependency | Found by | Version numbers |
|---|---|---|---|---|
| [AurorisNet.IdentityServer](https://github.com/auroris/AurorisNet.IdentityServer) | `AurorisNet.IdentityServer`, `AurorisNet.ActiveDirectory`, `AurorisNet.IdentityServer.Directory` | OpenIddict | Dependabot, weekly | `1.2.3` |
| [AurorisNet.ImageGallery](https://github.com/auroris/AurorisNet.ImageGallery) | None: the application as a Windows ZIP on GitHub | Magick.NET, and `AurorisNet.ImageGallery.FFmpeg` | Dependabot, weekly | `1.2.3` |
| [AurorisNet.ImageGallery.FFmpeg](https://github.com/auroris/AurorisNet.ImageGallery.FFmpeg) | `AurorisNet.ImageGallery.FFmpeg` | FFmpeg's stable releases | `upstream.yml`, started by hand | The FFmpeg release, such as `9.0.2` |
| [AurorisNet.InteractiveReports](https://github.com/auroris/AurorisNet.InteractiveReports) | `AurorisNet.InteractiveReports`, `.Core`, `.AspNetCore`, `.Client.GraphQL`, `.Client.FileDownload` | The .NET platform packages (`Microsoft.Extensions.*`) | Dependabot, weekly | `1.2.3` |
| [AurorisNet.Pressroom](https://github.com/auroris/AurorisNet.Pressroom) | `AurorisNet.Pressroom.Client`, and the server as Windows and Linux archives | Microsoft.Playwright, which selects the Chromium build | Dependabot, weekly | `1.2.3` |
| [AurorisNet.Umbraco.AppBlocks](https://github.com/auroris/AurorisNet.Umbraco.AppBlocks) | `AurorisNet.Umbraco.AppBlocks`, `.Documents`, `.InteractiveReports`, `.Testing` | Umbraco | `umbraco-releases.yml`, weekly | `0.1.0-alpha.2` |
| [AurorisNet.Umbraco.AppHost](https://github.com/auroris/AurorisNet.Umbraco.AppHost) | `AurorisNet.Umbraco.AppHost`, `.Testing` | AppBlocks, with the Umbraco release it pins | Dependabot, weekly | `1.0.0-alpha.2` |
| [AurorisNet.Umbraco.ApplicationVirtualPathFix](https://github.com/auroris/AurorisNet.Umbraco.ApplicationVirtualPathFix) | `AurorisNet.Umbraco.ApplicationVirtualPathFix` | Umbraco | `umbraco-releases.yml`, weekly | `18.3.2.1` |
| [AurorisNet.Umbraco.BreakGlass](https://github.com/auroris/AurorisNet.Umbraco.BreakGlass) | `AurorisNet.Umbraco.BreakGlass` | Umbraco | `umbraco-releases.yml`, weekly | `1.2.3` |
| [AurorisNet.Umbraco.DisableTelemetry](https://github.com/auroris/AurorisNet.Umbraco.DisableTelemetry) | `AurorisNet.Umbraco.DisableTelemetry` | Umbraco | `umbraco-releases.yml`, weekly | `18.3.2.1` |
| [AurorisNet.Umbraco.Drawio](https://github.com/auroris/AurorisNet.Umbraco.Drawio) | `AurorisNet.Umbraco.Drawio`, `.Selfhosted` | Umbraco | `umbraco-releases.yml`, weekly | `1.2.3` |
| [AurorisNet.Umbraco.IdentityServer.Directory](https://github.com/auroris/AurorisNet.Umbraco.IdentityServer.Directory) | `AurorisNet.Umbraco.IdentityServer.Directory` | Umbraco, and `AurorisNet.IdentityServer.Directory` | `umbraco-releases.yml` and Dependabot, weekly | `1.2.3` |
| [AurorisNet.Umbraco.IdentityServer.SSO](https://github.com/auroris/AurorisNet.Umbraco.IdentityServer.SSO) | `AurorisNet.Umbraco.IdentityServer.SSO` | Umbraco, and `AurorisNet.IdentityServer` | `umbraco-releases.yml` and Dependabot, weekly | `1.2.3` |

## The weekly schedule

Each repository looks for updates on one day of the week and publishes on the next. On the
first day Dependabot checks its packages and `umbraco-releases.yml` runs. On the second,
`weekly-release.yml` publishes everything those checks merged as one release, so a
repository has at most one automatic release in a week. The days follow the order of the
dependencies, so an update reaches every package that builds on it within the week.

| Repositories | Checks | Releases | Picks up |
|---|---|---|---|
| IdentityServer, ImageGallery, InteractiveReports, Pressroom, ApplicationVirtualPathFix, BreakGlass, DisableTelemetry, Drawio, PageMedia | Monday | Tuesday | New releases of Umbraco and of the packages from outside the family |
| AppBlocks, Umbraco.IdentityServer.Directory, Umbraco.IdentityServer.SSO | Wednesday | Thursday | Tuesday's releases of IdentityServer, InteractiveReports and Pressroom, and new Umbraco releases |
| AppHost | Friday | Saturday | Thursday's releases of AppBlocks and the two Umbraco IdentityServer packages, with Tuesday's releases of the other Umbraco packages |

ImageGallery.FFmpeg checks its workflow actions on Monday and releases by hand.

The check day is `schedule.day` in each repository's `.github/dependabot.yml`, and the last
field of the `cron` line in its `umbraco-releases.yml`. The release day is the last field of
the `cron` line in its `weekly-release.yml`. In a `cron` line, `1` is Monday. GitHub can
start a scheduled workflow hours after the time in its `cron` line, so the order relies on
the day alone.

## How the weekly release combines updates

An update that changes what a package ships is recorded in the message of its commit on
`main`, as two lines:

```text
Release-Bump: patch
Release-Note: Updates OpenIddict.Server.
```

`ci.yml` writes them when it merges a Dependabot update of a shipped package, and
`umbraco-releases.yml` writes them when it commits an Umbraco release that passed the tests.

`weekly-release.yml` reads the commits on `main` that no release tag reaches. When none of
them has these lines, the week has no release. Otherwise it starts `release.yml` once:

- `bump` is `minor` when any commit asks for `minor`, and `patch` otherwise. A package with
  an Umbraco-aligned version gets no `bump`.
- `notes` lists each `Release-Note`.
- `test` stays on, so the release tests the week's updates together before it publishes.

The release tag marks the commit that was published, which settles every update up to it.
If `release.yml` fails before it reserves its tag, the next weekly run starts it again. To
publish sooner, start `release.yml` by hand.

To have the weekly release publish a change of your own, end its commit message with a
`Release-Bump` line, and a `Release-Note` line for the release notes. To see what the next
weekly release holds, run `weekly-release.yml` by hand with `dry-run`.

A package with no release tag yet has no version to raise, so `weekly-release.yml` leaves
the first release to a person: run `release.yml` with a version such as `1.0.0`.

## Version numbers

**Semantic versions.** Most packages are numbered `MAJOR.MINOR.PATCH`. A release started by
hand takes a version, or raises the newest release tag by a patch or minor number. A
weekly release raises the minor number when one of its updates is a minor release of a
dependency, which can add API surface, and the patch number otherwise. While a package's newest tag is
a prerelease such as `v0.1.0-alpha.1`, each release continues the series with
`0.1.0-alpha.2`; enter a version by hand to leave it.

**Umbraco-aligned versions.** ApplicationVirtualPathFix and DisableTelemetry replace parts
of Umbraco that can change in any release, so each package version accepts Umbraco releases
up to an exact one. Their version is that Umbraco release followed by a count, such as
`18.3.2.1`. One release publishes a package for each supported Umbraco major version, so a
site can float on `18.*` or `17.*`.

**FFmpeg versions.** `AurorisNet.ImageGallery.FFmpeg` holds a build of FFmpeg, so its version
is the FFmpeg release it was built from. A release with two numbers, such as 9.1, becomes
package `9.1.0`. The version is in the repository's `.nuspec` file, and its `release.yml`
has no `version`, `bump` or `test` input.

## How a new Umbraco release becomes a package

1. `umbraco-releases.yml` runs once a week. Its **find** job reads `UmbracoReleases` in
   `Directory.Build.props` and the versions of `Umbraco.Cms` on nuget.org. A stable release
   newer than the newest listed release of its major version is new. A release whose
   failure issue is still open is skipped.
2. The **test** job adds the new releases to `UmbracoReleases` in its checkout and runs the
   package's tests once for each. It has a read-only token, because it runs code that
   nuget.org published minutes ago.
3. The **report** job reads the test summaries. For the releases that passed, it adds them
   to `UmbracoReleases`, updates the release ranges between the `umbraco-releases` markers
   in the README and commits to `main`, with the lines that record the release for the
   weekly release. For each release that failed, it opens an issue titled
   `Umbraco <release> fails the tests`.
4. The next day `weekly-release.yml` starts `release.yml`, which publishes the package with
   the week's other updates.

Close a failure issue once its cause is fixed. The next weekly run tests the release again.
To test a release at once, run the workflow by hand and name the release.

A new Umbraco major version gets an issue titled `Support Umbraco <major>`, because the
package needs code changes before its tests can run on it.

## How a Dependabot update becomes a package

Dependabot opens pull requests for NuGet packages, npm packages where a repository has
them, and workflow actions. The Umbraco packages leave `Umbraco.Cms*` to
`umbraco-releases.yml`. `ci.yml` tests each pull request, and its **dependabot** job then:

- leaves a major version update of a package open, with a comment, for a person to review;
- merges every other update;
- records the update for the weekly release when it is of a package that a shipped project
  references. Updates of test packages and workflow actions merge with nothing recorded, so
  they bring no release.

AppHost's pull request for a new Umbraco release groups Umbraco, uSync and the AurorisNet
packages, because they must move together. Its build fails while AppBlocks,
ApplicationVirtualPathFix or DisableTelemetry has no package for that Umbraco release yet.
Dependabot updates the pull request as those packages appear, and it merges once all of
them are on nuget.org. Until AppHost has merged it, a local AppHost build against a newer
AppBlocks checkout stops with a message that the two name different Umbraco releases.

## How a new FFmpeg release becomes a package

AurorisNet.ImageGallery.FFmpeg releases by hand only, by design: a person decides when a
new FFmpeg release becomes a package. Its workflows have no schedule.

1. A person starts `upstream.yml`. It compares the newest stable FFmpeg release with the one
   that `build/inputs.json` pins.
2. For a newer release it checks the source tarball's signature against FFmpeg's release
   key, commits the new version and checksum to `main`, and starts `release.yml`.
3. `release.yml` builds FFmpeg on a Windows runner, packs it and runs the package test on a
   sample of each input codec. It then publishes the package, and a GitHub release with the
   matching sources as `ffmpeg-<version>-sources.zip`.
4. Dependabot opens a pull request for the new package in ImageGallery, which becomes an
   ImageGallery release as described above.

`release.yml` on its own builds and publishes the version that is pinned already.

## Starting a release by hand

Open **Actions → Release → Run workflow** on `main`.

| Input | Use |
|---|---|
| `version` | The version to publish, such as `1.2.3` or `1.2.3-rc.1`. Leave empty to raise the newest tag. Packages with Umbraco-aligned or FFmpeg versions have no such input. |
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
   `AurorisNet.Pressroom.Client`, `AurorisNet.ImageGallery.FFmpeg`, ApplicationVirtualPathFix,
   DisableTelemetry, BreakGlass and Drawio depend on none.
2. `AurorisNet.Umbraco.IdentityServer.SSO` and `AurorisNet.Umbraco.IdentityServer.Directory`
   need the IdentityServer packages. AppBlocks needs `AurorisNet.InteractiveReports` and
   `AurorisNet.Pressroom.Client`. ImageGallery needs `AurorisNet.ImageGallery.FFmpeg`.
3. AppHost needs AppBlocks, BreakGlass, both Umbraco IdentityServer packages,
   ApplicationVirtualPathFix and DisableTelemetry.

## What this repository holds

| Path | Contents | Used by |
|---|---|---|
| `actions/version` | Chooses the version and tag of a release. | `release.yml` in every repository |
| `actions/publish` | Reserves the tag, pushes to nuget.org and publishes the GitHub release. | `release.yml` in every repository |
| `actions/dependabot-release` | Merges a Dependabot pull request and records the update for the weekly release when it ships. | `ci.yml` in every repository |
| `.github/workflows/weekly-release.yml` | The reusable Weekly release workflow. | `weekly-release.yml` in every repository that releases on a schedule |
| `actions/weekly-release` | Starts one release for the updates recorded since the last release tag. | The reusable workflow |
| `.github/workflows/umbraco-releases.yml` | The reusable New Umbraco releases workflow. | `umbraco-releases.yml` in the Umbraco repositories, except AppHost |
| `actions/find-umbraco-releases`, `test-umbraco-releases`, `report-umbraco-releases` | The steps of that workflow. | The reusable workflow |
| `scripts/` | The PowerShell behind the actions, with Pester tests. | The actions |

Run the scripts' tests with Pester 5:

```powershell
Invoke-Pester scripts
```

The repositories call the actions at `main`, so a change here reaches every repository on
its next run. `ci.yml` in this repository runs the tests on each pull request.
