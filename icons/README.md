# Package icons

Every AurorisNet package has an icon in one style, so the packages read as a family on
nuget.org and in the Umbraco Marketplace.

## The style

- A 128 by 128 canvas with a rounded square of `#1e293b` behind the glyph (`rx="26"`).
- A white glyph (`#fff`) and no other colour. Shapes are filled, or drawn with round-capped
  strokes 7 to 9 units wide.
- One idea per icon, drawn to stay readable at 32 pixels: two or three large shapes, with at
  least 18 units between the glyph and the edge of the square.
- A comment in the SVG beside each part that says what it stands for.

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <rect width="128" height="128" rx="26" fill="#1e293b"/>
  <!-- Three stacked building blocks -->
  <rect x="50" y="32" width="28" height="28" rx="6" fill="#fff"/>
  <rect x="30" y="68" width="28" height="28" rx="6" fill="#fff"/>
  <rect x="70" y="68" width="28" height="28" rx="6" fill="#fff"/>
</svg>
```

## Files

Each repository keeps `docs/images/icon.svg`, the source, and `docs/images/icon.png`, which
its project files pack:

```xml
<PackageIcon>icon.png</PackageIcon>
...
<None Include="../docs/images/icon.png" Pack="true" PackagePath="/" />
```

Render the PNG from the SVG after each change, from the repository's root with this
repository cloned beside it:

```powershell
pwsh ../AurorisNet.Build/icons/Render-Icon.ps1 docs/images/icon.svg
```

The script uses Microsoft Edge or Google Chrome in headless mode. Pass `-Browser` to name
another Chromium-based browser.

## The icons

| Repository | Glyph |
|---|---|
| AurorisNet.IdentityServer | A key (`AurorisNet.IdentityServer`), an organisation tree (`AurorisNet.ActiveDirectory`), a person under a magnifying glass (`AurorisNet.IdentityServer.Directory`) |
| AurorisNet.InteractiveReports | A table |
| AurorisNet.Umbraco.AppBlocks | Three stacked blocks |
| AurorisNet.Umbraco.AppHost | A house built of blocks |
| AurorisNet.Umbraco.ApplicationVirtualPathFix | `~/`, the application-relative path |
| AurorisNet.Umbraco.BreakGlass | A key behind a cracked pane |
| AurorisNet.Umbraco.DisableTelemetry | A struck-through signal |
| AurorisNet.Umbraco.Drawio | A flowchart |
| AurorisNet.Umbraco.IdentityServer.Directory | A person with a plus sign |
| AurorisNet.Umbraco.IdentityServer.SSO | A key inside a ring of sites |
