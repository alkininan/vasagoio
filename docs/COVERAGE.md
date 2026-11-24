# Implementation and acceptance status

**Window interior implementation is included in this alpha.** Code and offline fixtures are available; source registration is not a claim that every candidate exists or renders identically in every game state. Development does not launch or control the game. The first user test of alpha.3 found an FPS regression and HUD overlap; alpha.4 addresses those code paths but native acceptance remains open. Status in the addon means an adapter ran without a caught error; it does not certify visual parity, taint safety or combat correctness.

The full accepted target is in [DESIGN.md](DESIGN.md). The following table separates implementation from unresolved work rather than treating a configuration token as a finished feature.

| Scope | Current delivery | Remaining work / constraint |
| --- | --- | --- |
| Addon lifecycle | Native TOC, saved settings, independent modules, slash UI, disable/reload controls | Native loader and secure-frame validation |
| Setup and rollback | Concrete before/after review; serializable snapshots; all-preconditions-before-write; rollback refuses later edits | Owner save/reload normalization may also cause conflicts; retain external WTF backup |
| Unit system | Audited FUF L/M/S/XS geometry, anchors, class/resources/type, current-value slots, raid groups and native health curve | See [unit coverage](unit-coverage.md); native pet/group transitions and scale need testing |
| Nameplates | Threat Plates normalized geometry/scale, inside names and exact HP, scoped player-class/NPC-ivory text, native threat colors and reused aura signals | Custom owner overrides can take precedence; See [nameplate coverage](nameplate-coverage.md); rounded health backing and native aura markers require in-game validation; restricted native widgets may refuse cosmetics |
| Action buttons | Native Bartender slot-preserving layout, stronger empty main-grid slots, rounded art, number roles, cooldown and range presentation; standalone StatusTrackingBar disabled by setup | Restricted cooldown states preserve owner display; exact native timer clipping/font rendering untested |
| Player XP | XP-only 4px strip inside the 304×72 player frame,48/2/16/2/4 active rows and restored54/2/16 at maximum level; event-driven values and combat-deferred layout | No reputation/honor substitute; native geometry, scaling and level transitions require manual testing |
| Buffs/debuffs | FUF-owned aura pools connect to the shared presentation helper; all short/near-unit groups 28; long top-right target remains 36; known harmful/dispel signals | See [HUD coverage](hud-coverage.md); arbitrary urgency classification is never guessed and restricted native aura cosmetics remain conditional |
| Optional aura test | Closed-by-default `/vasagoio auratest show\|hide\|reset`; six native All/Short/Long comparisons for player buffs and debuffs, with existing displays retained | Not a production layout or accepted fallback. Cap40 per view, Long gaps, exact60/permanent pooling and combat behavior remain unresolved; see [test guide](AURA_TEST.md) |
| Bottom HUD | 216×186 masked map with 32px bottom overlay ; 248×186 total Details envelope; 480×186 native Prat chat | Native blip/edge-widget cropping, toolbar bounds and actual UI scale require user-run visual validation |
| Utilities | Two 42px native trinkets and one 42px native bag button beside the three main rows, centered842px combined container | Exact Forever Trinket Menu 1.8.19; flyouts/queue/input and combat need native tests; disable and reload for full cosmetic recovery |
| Unit indicators | Player combat and party/raid aggro edges;16px flagged badges; own hunter-pet happiness name; native cast duplication suppressed | Party threat values pass directly to native status widgets; other-player pet happiness is unavailable; FFA/NPC semantics retained |
| Colors | Shared neutral-black, class, resource, text and status palette | Chat channel identities retained, but per-message desaturation is not implemented; native scenes affect contrast |
| Typography | Native Friz default; native Arial Narrow Regular chat; Bold roles resolve shared media/local file | Actual Arial Narrow Bold is not in the package. Without a licensed source the status reports Regular fallback. Native control sizes remain unchanged |
| Material and radius | Original rounded translucent surfaces with static sheen/grain and normalized redundant backdrops; square bar interiors; radius10 icon masks; audited content-free Skinner decorations replaced with rounded surfaces | No live backdrop blur or global clipping of native content. Unreviewed Skinner reverse-parent arrangements remain native |
| Native windows | Shared interior controls, source-backed decorative maps, narrative typography, native selection bindings and pooled stat rows; 132 native candidates registered across 115 primary hosts | Source availability and runtime rendering remain unverified. Unknown content textures are preserved; see [native interiors](native-interiors.md) and [catalog boundaries](window-catalog-scope.md) |
| Selected addon windows | All 19 Baganator skin-region types with stronger empty-slot surfaces, Talents Forever interiors, MRT tools/popups, Auctionator panes, Gargul audited registries and OpenMap native shell | Audited versions/APIs only; owner-created custom content/state art is preserved. Other selected addons retain their owner interfaces unless covered by a separate adapter. See [addon interiors](addon-interiors.md) |
| Help/tickets | Native surrounding panels and controls styled; original functionality retained | Embedded support webpage is outside addon skin control; login/character-select frontends do not load normal in-game addons |
| Functional addon selection | Full 26-package manifest, including Details' bundled TinyThreat component, installed independently | vasagoio does not bundle, enable, update or test all packages |
| Performance | Scoped, coalesced styling; bounded reentrant work; surface caching; incremental aura updates and visible-window discovery | Offline operation-count regressions pass. The user reports alpha.6 is better; no quantified FPS comparison or full native acceptance is recorded. `/vasagoio perf` measures module applications only. |
| Quest HUD | Existing reviewed RestedXP guide-anchor migration with live/saved apply and restoration | Placement only, exact v4.11.40. The requested hideable RestedXP redesign below buffs and replacement of the native quest tracker remain pending; no fallback has been accepted |
| Preset/status screen | Two main actions, component rows, short issues, required-HUD engine gate and snapshot-based applied checks | Checks cover supported configuration and reported runtime errors; native FPS, visuals and combat still require manual tests |
| Distribution | Standalone addon ZIP, deterministic package, hash manifest, CI | Native acceptance needed before a stable release |

## Native acceptance gate

Before upgrading this release to stable, manually verify at the intended resolution and UI scale:

1. Fresh initialization, setup preview, apply/reload, update without reset, disable/reload and restoration.
2. Character and other window structure, model/equipment positions, controls, tooltips, keyboard focus, scrolling, native locale/font coverage and load-on-demand windows.
3. Solo/party/raid transitions, pets appearing/disappearing, portrait/resource changes, health text/gradient, role-aware threat, aura updates and range.
4. Action paging, every existing binding, cooldown/charge/loss-of-control interactions and spell/item usability.
5. Combat entering/leaving with frames opening/updating; no blocked protected actions or Lua errors.
6. Same-scene FPS comparison with Skinner unchanged and vasagoio enabled/disabled; watch idle gameplay, action/aura updates and open-window behavior.
7. Exact visible bounds and contrast over light and dark scenes, including very long names/place names and large amounts.

The [172-surface ledger](window-coverage.json) retains 132 native interior candidates, 29 dedicated HUD-owner records, 2 media/world-capture overlays, 8 frontend records and 1 embedded browser boundary. It intentionally marks all runtime results untested and does not imply every source-listed surface is available on every character or realm.
