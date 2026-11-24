# Implementation and acceptance status

**This is an alpha, not a completed all-window reskin.** Code and offline fixtures are available. No game session was launched or controlled, so every implemented path still needs user-run native validation. Status in the addon means an adapter ran without a caught error; it does not certify visual parity, taint safety or combat correctness.

The full accepted target is in [DESIGN.md](DESIGN.md). The following table separates implementation from unresolved work rather than treating a configuration token as a finished feature.

| Scope | Current delivery | Remaining work / constraint |
| --- | --- | --- |
| Addon lifecycle | Native TOC, saved settings, independent modules, slash UI, disable/reload controls | Native loader and secure-frame validation |
| Setup and rollback | Concrete before/after review; serializable snapshots; all-preconditions-before-write; rollback refuses later edits | Owner save/reload normalization may also cause conflicts; retain external WTF backup |
| Unit system | Audited FUF L/M/S/XS geometry, anchors, class/resources/type, current-value slots, raid groups and native health curve | See [unit coverage](unit-coverage.md); native pet/group transitions and scale need testing |
| Nameplates | Threat Plates geometry, exact HP, owner role-aware calm blue/attention/danger | Custom owner overrides can take precedence; custom rounded outer shell and all aura signals are not guaranteed |
| Action buttons | Native Bartender slot-preserving layout, rounded art, number roles, cooldown and range presentation | Restricted cooldown states preserve owner display; exact native timer clipping/font rendering untested |
| Buffs/debuffs | FUF-owned aura pools connect to the shared presentation helper; standard36 and owner dispel-group28; known harmful/dispel signals | See [HUD coverage](hud-coverage.md); arbitrary urgency classification is never guessed and nameplate aura internals are not yet connected |
| Bottom HUD | Chat/map containers and explicit meter profile plan | SexyMap retains square154 viewport inside216×186; Details toolbar may extend past its186 body; full equal-height visible bounds unverified |
| Colors | Shared neutral-black, class, resource, text and status palette | Chat channel identities retained, but per-message desaturation is not implemented; native scenes affect contrast |
| Typography | Native Friz default; native Arial Narrow Regular chat; Bold roles resolve shared media/local file | Actual Arial Narrow Bold is not in the package. Without a licensed source the status reports Regular fallback. Native control sizes remain unchanged |
| Material and radius | Original rounded translucent surfaces; square bar interiors; radius10 icon masks | No live backdrop blur. Skinner-managed native frames retain Skinner's rectangular corner model. Not all owner surfaces can enforce radius10 |
| Native windows | Reviewed Skinner palette/scope configuration; explicit native shell fallback preserving geometry | Full internal control parity and all 172 cataloged surfaces are not implemented or validated; see [window adapters](WINDOW_COVERAGE.md) |
| Selected addon windows | Baganator public skin API; reviewed Talents/MRT/Auctionator shells; OpenMap native shell | Internal tool controls and many addon dialogs still use owner styling; Gargul lacks a reviewed skin adapter |
| Help/tickets | Native outer shell adapter candidate; original functionality retained | Embedded support webpage is outside addon skin control |
| Functional addon selection | Full 27-package manifest, installed independently | vasagoio does not bundle, enable, update or test all packages |
| Distribution | Standalone addon ZIP, deterministic package, hash manifest, CI | Native acceptance needed before a stable release |

## Native acceptance gate

Before upgrading this release to stable, manually verify at the intended resolution and UI scale:

1. Fresh initialization, setup preview, apply/reload, update without reset, disable/reload and restoration.
2. Character and other window structure, model/equipment positions, controls, tooltips, keyboard focus, scrolling, native locale/font coverage and load-on-demand windows.
3. Solo/party/raid transitions, pets appearing/disappearing, portrait/resource changes, health text/gradient, role-aware threat, aura updates and range.
4. Action paging, every existing binding, cooldown/charge/loss-of-control interactions and spell/item usability.
5. Combat entering/leaving with frames opening/updating; no blocked protected actions or Lua errors.
6. Exact visible bounds and contrast over light and dark scenes, including very long names/place names and large amounts.

The [172-surface ledger](window-coverage.json) preserves the wider scope for implementation and verification. It intentionally marks all runtime results untested and does not imply every source-listed surface is available on every character or realm.
