# Maintenance

## Update model

Keep the functional addons in their original folders and let their normal updater manage them. Update only the `vasagoio` folder from a new tagged release. No vendor patches need to survive updates.

vasagoio settings use a schema version. A downgrade encountering a newer schema disables writes rather than resetting it. Updates preserve user preferences and never silently reapply the design preset. Each explicit setup stores a local before/after snapshot; restoration requires the current field to match the snapshot's after value. This protects edits made after installation.

Owner compatibility is checked per adapter. Exact-version adapters pause after an unreviewed update; schema-gated adapters validate their required tables and APIs. This is deliberately visible in Status, not hidden behind a blanket compatibility claim. After changing owner versions, inspect the adapter, update its tests, and perform the manual verification in INSTALLATION.md.

For window interiors, update the shared primitives in `core/Interiors.lua` and the source-scoped adapters in `modules/NativeInteriors.lua` / `modules/AddonInteriors.lua`. Keep decorative additions outside native layout measurement. Retain original anchors, dimensions, click scripts, values, content art and semantic colors. When an addon changes, review its named roots, public skin API or owner registry and its selection/row callbacks before changing the version gate; a successful version comparison alone does not establish compatibility.

The portable native ledger is `docs/window-coverage.json`. Its 172 records include unavailable boundaries and nested states, not 172 independent live windows. Change host/alias/boundary data there, regenerate `modules/WindowCatalog.lua` with `python3 tools/window_catalog.py`, and keep runtime acceptance separate from registration. See [Native window scope](window-catalog-scope.md) for counts and exclusions.

## Release process

1. Change code and the accepted design/coverage ledger together. Mark each feature implemented, partial, pending or unavailable; keep native validation separate.
2. Add behavior tests for risk-bearing logic: migrations, profile transactions, combat guards and owner schema changes. Interior changes also need meaningful coverage for retained content/semantic art, lazy or recycled controls, selected/focused states and restoration when native/addon ownership overlaps. Avoid tests that only duplicate every constant.
3. Run `python3 tools/check.py`. It uses Lua5.1 fixtures without launching the game. CI runs the same checks on pushes and pull requests.
4. Have a person validate in the supported game build: load-on-demand screens, setup/reload, combat, role/resource changes, group changes, secure clicks, addon updates and disable/recovery. For interior releases, include Character and Settings, scrolling/recycled rows, selected and disabled tabs, keyboard focus, bag item quality/cooldowns, talent planning states and a window shared by native and addon adapters. Until that pass is complete, record native appearance as untested and keep the release a prerelease.
5. Update the TOC/Core version and changelog, tag a release, and build with `python3 tools/package.py`.
6. Publish the install ZIP and SHA256 checksum. Use prereleases until the manual acceptance list is complete. Never replace an existing release asset with changed contents under the same version.

The packager has an explicit allowlist and creates deterministic archives with an internal file-hash manifest. It excludes test tools, development contracts, fonts, other addons and account files. Do not package the parent project folder or local game backups.

## Bug reports

Include the vasagoio version, game build, relevant addon versions, a short reproduction and the first Lua error. Screenshots should omit chat/identity information you do not want public. Do not upload complete WTF, SavedVariables, paid guides, authentication tokens or account folders to issues.

## Technical boundaries

- Protected layout work waits for combat to end; there is no combat automation.
- Restricted data is either passed directly to supported native widgets or left with its owner. Unknown values never become guessed threat/range/cooldown states.
- Native layouts remain native. A shared token is not permission to resize every control, traverse every global frame or replace a character/talent workflow.
- Font paths are resolved locally. Actual Arial Narrow Bold is optional user-provided media; its distribution rights are not assumed.
- Rounded translucent surfaces approximate Frosted glass. Native arbitrary background blur and embedded support-webpage restyling are outside this build.
