# README and package metadata rules

Keep every README short and proportional to the package. A single-purpose utility needs a paragraph and an install command, not eight sections of prose.

## Core rules

- **Say what the package does immediately.** State what the user gets, what it requires, and whether it pulls in or pairs with other packages.
- **Match length to complexity.** Do not pad simple packages with boilerplate sections. Skip `Settings`, `Documentation`, `Developing`, or `Releases` in `README.md` when they add nothing a package consumer needs.
- **Keep maintainer notes out of package READMEs.** `PackageReadmeFile` publishes `README.md` straight to nuget.org and the Umbraco Marketplace. Put build matrices, Playwright commands, major-version checklists, and CI/release notes in `docs/developing.md` (and link to [releasing.md](releasing.md)).
- **Check claims against the source.** Every setting name, default, route, and version range must match the code.

## README shape

```markdown
# Package title

One or two sentences stating what the package does, what it requires, and which Umbraco/.NET versions it targets.

![MIT license](https://raw.githubusercontent.com/auroris/AurorisNet.Build/main/badges/license-mit.svg)
![.NET 10](https://raw.githubusercontent.com/auroris/AurorisNet.Build/main/badges/dotnet-10.svg)

## Install
## Settings        (only if configurable)
## Documentation   (only if docs/ exists)
## License
```

- **Markdown only in packed READMEs.** nuget.org strips HTML and breaks relative links, so use absolute GitHub URLs (`https://github.com/auroris/<repo>/blob/main/<path>` for links, `https://raw.githubusercontent.com/auroris/<repo>/main/<path>` for images). Pages inside `docs/` use relative links.
- **Umbraco release markers.** Repositories that use `Add-UmbracoRelease.ps1` keep `<!-- umbraco-releases <major> -->...<!-- /umbraco-releases -->` markers in `README.md` (or `docs/*.md`) so the weekly workflow can update tested release ranges automatically.
- **Multi-package repos.** Give each secondary NuGet package its own short `README.md` in its project folder so NuGet and the Umbraco Marketplace explain that exact package and its relationship to the others.

## Umbraco Marketplace naming and metadata

- Use plain product names without a leading `Umbraco` or `AurorisNet` (for example: `Disable Telemetry`, `Break Glass`, `Page Media`, `draw.io`, `draw.io (Self-Hosted)`).
- Set `<Title>` and a clear, concise `<Description>` in every packable `.csproj`.
- Set matching `Title`, `Description`, `DocumentationUrl`, and (where applicable) `RelatedPackages` in `umbraco-marketplace.json`.
- When one repository publishes multiple Marketplace packages, add a package-specific `umbraco-marketplace-<lowercase-package-id>.json` for each extra package and give it its own packed `README.md`.

## Package icons

Every package has a 128×128 PNG icon with a white glyph on a `#1e293b` rounded square (`docs/images/icon.svg` and `docs/images/icon.png`), packed via `PackageIcon`. See [`icons/`](../icons).
