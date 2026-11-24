# Accepted vasagoio design

This is a derived implementation summary of the authoritative Vasagoio Specs, revision 11. Historical experiments are not active options. A design value being listed here does not imply native implementation; see COVERAGE.md and module coverage documents.

## Layout and ownership

Native Character, Inspect, talents, tickets and other windows keep their existing structures, controls and workflows. Selected functional addons such as Baganator and Talents Forever retain their features and window structures. vasagoio changes their appearance where an audited adapter is available. Custom unit frames, action bars, nameplates and HUD placement are intentional.

Use one functional owner for each area. FUF owns unit behavior and clicks; Threat Plates owns nameplates and threat; Bartender owns action execution, paging and bindings; Prat owns chat features; SexyMap owns the minimap; Details owns meter data; Skinner owns broad native skins when present. There is no gameplay automation in vasagoio.

## Measurements

Reference canvas: **2560×1440**, centered within UIParent on other aspect ratios. Layout units scale uniformly to fit, without changing UIParent scale. Margins are measured from that centered canvas so unit and action anchors stay aligned on ultrawide displays. Eight is the spacing foundation; explicitly accepted 2, 6, 10, 12, 14, 18, 42 and other exceptions take precedence. Owner snapping may produce a one-logical-pixel difference on smaller canvases.

| Variant | Roles | Total | Portrait | Portrait gap | Body width | Health | Bar gap | Power |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Large | Player, target | 304×72 | 72 | 2 | 230 | 54 | 2 | 16 |
| Medium | Party; auxiliary units | 224×56 | 56 | 2 | 166 | 38 | 2 | 16 |
| Small | Pet, attached party pet, target of target | 176×40 | 40 | 2 | 134 | 22 | 2 | 16 |
| Extra small | Raid | 128×32 | None | 0 | 128 | 28 | 0 | 4 |

| Element | Position / size / gap |
| --- | --- |
| Player | x859 y1102, portrait left |
| Target | x1397 y1102, portrait right |
| Pet | x663 y1118, portrait left |
| Target of target | x1721 y1118, portrait right |
| Main unit → nearest action row | 72 |
| Party | x8 y8, five Medium rows, 12 vertical gap |
| Attached party pet | 12 horizontal gap; 8 below owner top; only shown if a pet exists |
| Raid | Eight groups, two columns, five members per group, no group titles |
| Raid gaps | 6 between members; 12 horizontal and 16 vertical between groups |
| Main buttons | 42×42; 8 gaps; 16 columns × 3 rows; 792×142 at x859 y1290 |
| Pet buttons | 32×32; 8 gaps; ten buttons; 392×32 at x859 y1246 |
| Player XP active | Existing 304×72 outer frame and 72px portrait; health 48, gap 2, power 16, gap 2, XP 4 inside the bar body |
| Player XP unavailable / maximum level | Reclaim the XP space; return to health 54, gap 2, power 16; no reputation substitute |
| Utility column | 42px trinket buttons at x1659 y1290 / y1340; single bag button at y1390; 8px gap from main grid |
| Centered combined action container | 842px wide, x859–1701; player left and target right align with these outer edges |
| Pet → main row gap | 12; pet endpoint aligns with main button eight |
| Chat | 480×186 at x8 y1246 |
| Meter | 248×186 at x2072 y1246 |
| Map container | 216×186 at x2336 y1246; 32-high bottom location/time overlay |
| Map + gap + meter | 216 + 16 + 248 = 480, equal to chat width |
| Long / short auras | 36 top right / 28 near units; horizontal gap 8; wrapped-row gap 16; priority changes signal only |
| Aura clearance | At least 8 from icon edge to health/panel |
| Nameplate | 192×24 health; 192×16 cast; 8 gap; 28 aura with 8 clearance |
| Nameplate envelope | 84; 92 including top-attached count; extra aura rows can grow |

Player and target show current health/power amounts, not percentages. Small names and values use compact14; L/M names and main amounts use16. Details total186 includes its toolbar, padding and content; rows24, gap4, inner padding8 and title24. Raid uses compact percentages. Nameplates show exact current health. Names have no background label anywhere. Party and companion units share one size system; no duplicate Small variants.

The player XP row is a conditional composition within Large, not a new outer size variant. Target keeps the original Large health/resource split. Hide the old standalone XP/status strip after explicit setup. Empty main-action slots and empty bag spaces use stronger borderless placeholders so available positions remain readable without moving actions or items.

## Color and material

| Role | Value |
| --- | --- |
| Panel / raised / deep / track | #0B0B0B / #151515 / #060606 / #030303 |
| Health high → low | #151515 → #5B5B5B, progressively lighter as health falls |
| Meter fill | #272727 |
| Main text / secondary / icon text | #E8EDF2 / #B6C0CA / #F0F3F7 |
| Information signal / calm fill | #A8D7EB / #486C89 |
| Danger signal / fill | #E4A0A8 / #8B4E57 |
| Attention signal / fill | #E7CC82 / #866242 |
| Out of range | #AB2D3C at 0.30 opacity |
| Mana / rage / energy / focus | #456A8C / #9E5149 / #75602F / #8F5B2B |
| Class names | Hunter #95AE78; Warrior #BC9972; Druid #CC9561; Mage #83B7C5; Priest #E8EDF2; Paladin #C996AB; Rogue #D4BE70; Shaman #87A5D5; Warlock #B09AC6 |
| Surface opacity | Units 0.56; chat/map label/meter 0.40; input 0.24; windows 0.84 |
| Empty-slot surface | Neutral #272727 at 0.64 opacity; borderless, radius10; preserve owner search/disabled fading |

Default corners are **10** on containers and icons. Health, resource and damage-meter fills remain square. The selected system is borderless, with no gold/silver outline toggle. Native rendering uses dark translucent surfaces with static low-contrast sheen and grain as a Frosted approximation; there is no supported arbitrary scene blur behind every frame.

Player combat uses a 2px danger edge at35% opacity; party/raid edges follow aggro instead. Native16px player/target PvP badges appear only when flagged and retain FFA/NPC warning semantics. Own hunter-pet names show happy/content/unhappy using hunter green/attention/danger; the separate happiness icon is hidden. Other players’ pets have no invented happiness state.

Class colors remain recognizable and use soft dark shadows for readability. Prat extends native ChatFrame1–10: keep those message frames and reskin their chrome/tabs/input. Native channel colors retain their identities; no global chat color table is replaced. Location names retain native friendly/hostile/contested meaning. A live scene can alter contrast behind transparent surfaces; offline values do not guarantee contrast on every background.

## Typography

| Role | Face | Size / line height |
| --- | --- | --- |
| Names and main amounts | Native Friz Quadrata | 16 / 24 token; single-line units remain centered |
| Compact percentages and nameplate health | Native Friz Quadrata | 14 / 16 |
| Body | Native Friz Quadrata | 16 / 24 |
| Heading / title | Native Friz Quadrata | 24 / 32 and 32 / 40 |
| Chat | Arial Narrow Regular | 16 / 24 |
| Hotkeys, item counts, stacks | Actual Arial Narrow Bold | 14 / 16 |
| Main / compact action countdown | Actual Arial Narrow Bold | 18 / 24 and 16 / 16 |
| Aura durations | Native Friz Quadrata | 14 / 16, bottom inside icon |

No opaque number boxes or solid text outlines. Soft dark shadows only. Existing native window control sizes are preserved to avoid clipping; those controls adopt the face/shadow while retaining their native metrics. FontString line-height controls are not equivalent to browser CSS; single-line text is anchored, chat spacing is explicit.

Arial Narrow is already a native Forever family, not a replacement for a separate normal Arial baseline. Native ARIALN.TTF is Regular. Exact Bold requires an existing shared-media registration or a licensed font supplied locally; the distribution includes no font binaries and reports the Regular fallback honestly.

## Icons and threat

Artwork retains original saturation, 0.92 brightness and full opacity. A full-button radial cooldown wipe uses a dark remaining sector at 0.80 and elapsed layer at 0.12; it is not a circular badge. The button's hotkey disappears while an ordinary readable cooldown is active, and its countdown is centered. Active counts move above the top-right edge (top −8 / right +6); ready counts sit bottom-right with 2 inset. Aura timers stay bottom-inside.

Semantic markers sit below the icon: height3, gap 2, side insets6, opaque, square ends. Harmful uses danger; dispellable uses information; priority uses attention. Normal buffs get no marker. No surrounding border or glow is substituted. Restricted cooldown/range values stay with native owner widgets instead of being inspected or inferred.

For a valid hostile NPC threat context, tanks with secure aggro and DPS/healers without aggro use calm blue. The inverse uses danger; transitional states use attention. Friendly units, PvP opponents and unavailable threat data retain the owner's reaction/class rules. No threat inference is added.

## Window controls and interior states

The user explicitly selects **near-black fill plus a small blue bottom marker only** for selected tabs/list rows and keyboard-focused inputs. The marker uses the existing information color, with a 2px height, 8px side insets and 2px bottom offset. These dimensions are implementation defaults within the agreed system. Selection does not introduce a blue background fill or a surrounding outline.

Window controls reuse the existing neutral palette, 10px outer corner radius, native Friz face and soft text shadows. Hover and pressed states remain neutral; selected/focused states retain their blue marker. Disabled controls remain legible with reduced emphasis. Checkboxes retain their meaningful checked glyph, sliders retain their native value/drag behavior, and scrollbars retain their range and thumb geometry. Item quality, quest difficulty, requirements and other semantic colors are preserved. Neutral black narrative text becomes near-white so it remains readable on dark panels.

Original control sizes, positions, wrapping, scroll behavior and keyboard/click handling are preserved. New decorative surfaces are excluded from native layout calculations. Known decorative art is replaced through explicit source-backed maps or audited owner APIs; content art, models, links, item icons, currency icons and talent-node state remain owned by their functional interface.

## Retained addon decisions

Keep MRT for raid leading, SexyMap, What's Training, Baganator, Talents Forever, Prat, Forever Trinket Menu, Gargul and BattleGroundEnemiesFixed. Details provides damage meters and its bundled TinyThreat plugin provides the selected threat meter. ThreatClassic2 is no longer selected. Threat Plates remains the separate nameplate owner. vasagoio does not enable data collection or automatically switch Details displays. Spy and OneForAll are excluded. Chonky, EUI, ElvUI and DaylightUI are not additional presentation owners in this package. Skinner is the selected native skin foundation. The full 26-package functional selection, including TinyThreat within Details, is in dependencies.json.

## Pending aura and quest work

The accepted aura target places long buffs at the top right, long debuffs below them, and short effects near the unit frames. Grouping uses an effect's full duration with a 60-second threshold, retaining the agreed Battle Shout exception. The themed RestedXP window belongs below the long-aura region, with automatic hiding in combat and a manual visibility toggle; the native quest tracker should be hidden. These changes are still pending implementation and native validation. Keeping the current separate guide/objective columns in alpha.7 is an implementation limitation, not acceptance of a fallback design.

Alpha.7 includes a manually opened [aura experiment](AURA_TEST.md) to evaluate native duration grouping. All, Short and Long/permanent views compare buffs and debuffs without replacing the working aura display. The test does not establish compact packing, exact-60-second behavior, permanent-effect pool reuse or combat correctness. Production aura placement/grouping and spell-specific exceptions require the test results and further implementation.
