# Third-party boundaries and source references

This repository contains original adapter code and original generated masks. It does not contain third-party addon source, font binaries, game screenshots/textures, paid guide content or user account settings. The MIT license applies only to the original materials here.

Referenced integrations retain their own licenses and must be installed separately. Runtime paths such as `Fonts\\FRIZQT__.TTF` refer to media provided by the user's client, not bundled assets.

Source/API review references:

- [Blizzard UI source mirror, reviewed Forever snapshot](https://github.com/Gethe/wow-ui-source/tree/bebcb6bf309cf41b41bd74f8ca651e6a105b2676) — frame names, original layouts and client API usage. This is a community mirror of client UI source.
- [Skinner beta12.70938.1](https://github.com/jncl/Skinner/tree/beta12.70938.1) — native skin ownership and profile schema.
- [Bartender4](https://github.com/Nevcairiel/Bartender4) — native bar geometry, profile model and action ownership; locally reviewed 4.19.2.
- [Baganator publisher distribution](https://www.curseforge.com/wow/addons/baganator) — installed public `API.Skins.RegisterListener` / `GetAllFrames` skin integration.
- [Threat Plates](https://github.com/Backupiseasy/ThreatPlates) — locally reviewed 13.3.9 schema and owner threat rendering.
- [Details](https://github.com/Tercioo/Details-Damage-Meter) — native instance APIs and local profile model.
- [Prat](https://github.com/sylvanaar/prat-3-0) — Font namespace and shared-media font selection.
- [SexyMap](https://github.com/funkydude/SexyMap) — minimap profile, native shape, zone and clock APIs.
- [Gargul 8.1.0](https://github.com/papa-smurf/Gargul/releases/tag/v8.1.0) — public window registries, interface constructors and native font wrapper behavior.

Forever Unit Frames 0.79.1 and selected addon shells were inspected from their installed/distributed source without copying implementation code. Version numbers are compatibility targets, not an endorsement or claim of universal compatibility. Exact frame and adapter limitations are documented with the implementation.

World of Warcraft, Blizzard fonts and all addon names/trademarks remain the property of their respective owners. No affiliation is implied.
