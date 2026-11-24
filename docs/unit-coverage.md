# Unit and nameplate implementation coverage

This is source-audited implementation, not an in-game verification claim. The supported schemas are **Forever Unit Frames 0.79.1 and 0.81.0** and **Threat Plates 13.3.9**. Other versions refuse profile setup until reviewed. WoW has not been launched or controlled to test this release.

All dimensions below are the 2560×1440 design reference. Setup converts them through the shared uniform scale; FUF snaps its dimensions to whole UI units. Setup checks resulting sizes against the owner's actual schema bounds and identifies the failing field if scaling would clamp it. Effective scales0.50,1.00 and1.50 were checked; a larger monitor/UI scale can exceed the owner's limits and requires a smaller layout scale. Layouts must be checked at the user's actual resolution and UI scale.

| Accepted detail | Implementation | Practical limit |
| --- | --- | --- |
| L: 320×64, health46, resource16, gap2 | FUF profile; player and target | FUF adds the gap to configured height, so its height field is62. The resulting frame is64. |
| M: 224×48, health34, resource12, gap2 | FUF profile; party, focus and boss frames | Focus/boss positions and visibility retain existing choices. |
| S: 192×32, health22, resource8, gap2 | FUF profile; player pet, target of target and focus target | Units without resources expand health through FUF's native policy. |
| XS: 128×32, health28, resource4 | FUF raid profile | Integer percentage13 produces4px resources at the reference scale; rounding can differ at other scales. |
| 2px portrait-to-bars and health-to-resource gaps | FUF profile plus party-pet decoration | Party-pet geometry hooks defer all repositioning until combat ends. |
| Player (884,1098), target (1356,1098), pet (672,1114), target of target (1696,1114) | FUF profile | Native frame centers are calculated from approved top-left anchors. The main bottom edge is1162; action row1246 gives84px. |
| Left portraits for player/pet; right for target/target of target | FUF profile, native 2D portraits | No copied portrait artwork. |
| Party owner224×48, pet192×32 to right with12px gap and8px vertical inset | FUF BESIDE pet mode plus native decorative portrait/resource bar | FUF hard-codes its attached-pet appearance to health-only. The adapter resizes the existing health bar to158×22 and adds a32px native portrait and158×8 native resource bar, both separated by2px. The same owner button retains click units, tooltip and auras. Native validation pending. |
| Raid group pairs1–2,3–4,5–6,7–8 down left side | FUF group headers, 2-column profile | Existing headers remain responsible for membership, clicks and visibility. |
| Raid cell gap6; block gaps12 horizontal /16 vertical; no titles | Profile plus out-of-combat re-anchors of existing raid headers | FUF's settings support only one block gap. The runtime adapter supplies the independent axes; disabling vasagoio and reloading restores owner layout. |
| Inline raid name and smaller percentage | Re-anchors existing owner FontStrings | FUF normally stacks these lines. Long names truncate in the68px name slot; percentages retain40px. |
| Friz Quadrata names16, compact amounts14, player/target amounts16 | FUF and Threat Plates profile fields | Native media faces, no font binaries included. |
| Exact remaining health/resource amounts | Native FontString pass-through on FUF CURRENT slots | Dead/offline status is retained. Restricted numbers go directly to native formatting; Lua never calculates or serializes them. |
| Muted class-name and resource palette | Audited FUF settings, TP class palette, native raid/party-pet resource tint | Owner/native colors remain for restricted class/power identities. TP social/target/custom overrides remain functional. |
| Health dark#151515, becoming lighter toward#5B5B5B as HP falls | Native ColorCurve applied directly to existing health StatusBars | Requires client's `UnitHealthPercent` + ColorCurve APIs. No derived HP or secret comparisons. Solid dark fallback if APIs are absent. |
| Borderless shell, radius10, square health/resource interiors, transparent name text | Zero owner bar radii/borders plus vasagoio decorative shell | A rounded shell behind square bars is implemented. There is **no compositor backdrop blur** in WoW; the browser's frosted blur is not reproduced. |
| Unit surface/health alpha.56; text stays opaque | Shell alpha and native health color curve; FUF whole-frame alpha100 | Existing range/visibility fades remain owned by FUF. |
| Unit buff/debuff36, gap8, extra row gap8; priority/dispellable28; bottom semantic lines | FUF profile and the aura module | The existing FUF dispels group is sized28 when enabled; native classification stays owner-controlled. Own-cast is not misrepresented as priority. Player FUF buffs are enabled, native duplicate auras hidden, and the owner's secure right-click cancel option enabled. |
| Nameplate health192×24, cast192×16 with8px gap | TP profile | Name and current HP share the health row. Custom unique-nameplate overrides remain owner-controlled. |
| Nameplate one aura row28, 8px gap; total84px health/cast/aura envelope | TP profile | Additional aura rows, markers and cast-target text can extend the envelope. Owner filters remain preserved. |
| Nameplate exact remaining HP, no percentages/abbreviation | TP amount/full settings; truncate/percent/max/deficit off | Native owner widget handles restricted HP. |
| Threat0 and3 invert calm blue/danger red for tank vs DPS;1/2 amber | TP native LOW/MEDIUM/HIGH palette; auto-role detection | No role colors for friendly/player/no-threat contexts. Heuristics and off-tank exception disabled. Existing custom plate rules can override base colors. |
| Nameplate status safety | Existing TP restriction-aware renderer | vasagoio does not query, infer or reconstruct threat. No substitute nameplate engine is installed. |

## Profile and rollback behavior

Preparing either setup plan is read-only. Every change has a SavedVariables path for the setup engine's persistent rollback record. Both owners receive newly named profiles on every setup apply, with a per-character pointer selecting the new profile after reload. FUF's private live profile and TP's live AceDB tables remain intact until reload. Previous profiles remain present. Raid changes preserve existing nonappearance settings. TP copies existing filters and unique-nameplate rules; dual-spec slots that shared the previous profile now share its themed copy, while independently chosen spec profiles stay intact. Its audited AceDB logout handler does not reset the selected-profile pointer. Reload after applying or restoring profiles.

Disabling vasagoio's cosmetic module stops its hook callbacks. Unchecking the addon and reloading removes hooks and surfaces. Profiles are separate: use the setup engine's profile restore when also reverting owner configuration.

## Evidence and tests

The adapters were matched to FUF `Core/Settings.lua`, `Core/UnitProfiles.lua`, `Core/Storage.lua`, `Units/Single.lua`, `Units/Party.lua`, `Units/PartyPets.lua`, `Raid/Settings.lua`, `Raid/Cell.lua`, `Raid/Panel.lua`, `Elements/Health.lua` and `Elements/Texts.lua`; and TP `Constants.lua`, `Database.lua`, `Styles/basicThemes.lua`, `Modules/Threat.lua`, `Modules/Color.lua`, `Elements/StatusText.lua` and its bundled AceDB identity handling. No upstream code or media is included.

`tests/unit_adapters_spec.lua` checks read-only preparation, rollback paths, exact reference row math, preserved user settings, fresh owner profile names, ordinary/regional TP identities and spec bindings, version/scale refusal, native opaque-value pass-through, owner offline text, party-pet dimensions/gaps/absent units/combat deferral and disabled hooks. Run it from the repository root with `lua tests/unit_adapters_spec.lua`. The proposed FUF unit and raid profiles were also checked against the installed owner's real schema sanitizer, with zero differences at effective scales0.50,1.00 and1.50.

## Idle rows and scoped updates

Alpha.6 reviews FUF 0.81.0 storage, unit hooks and aura pools. Its new `partyPerLine` option is set to five to retain the agreed single party column; attached pets remain beside their owners. New raid resource-color fields use the shared palette, and the missing-health track retains the neutral background. A read-only check against the installed owner's schema accepted all 690 proposed values without normalization. Earlier 0.79.1 remains supported without writing these newer fields.

Alpha.4 explicitly disables inherited always-visible idle cast rows and the player's extra threat row in the reviewed FUF profile. Actual enabled cast bars remain available during casts; TinyThreat remains the selected threat meter. Unit creation and roster callbacks request only the unit-frame module, so they do not trigger unrelated window styling. Applying this profile correction requires setup and reload.
