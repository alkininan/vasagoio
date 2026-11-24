# Native interior implementation

The native module now applies the design inside windows as well as to their outer shells. The original model, equipment slots, content panes, tab positions, list row sizes, click areas, scrolling and native actions are unchanged. No window is opened by the addon.

## Applied scope

`WindowCatalog.lua` provides the source-reviewed native candidate set. Each eligible existing host is visited using a bounded child traversal through the shared interior service. Detached catalog dialogs and explicit aliases are included; front-end screens, the embedded Help browser and dedicated HUD owners are excluded. Full-canvas roots such as Barber Shop and AlertFrame are scan-only and never receive a full-screen black surface. Edit Mode's settings dialog is styled, while its full-screen alignment overlays are skipped.

The shared service handles text buttons, checkboxes, edit boxes, dropdown controls, sliders, scrollbars, labels and native decorative panels. Reviewed native button chrome includes SecureUIPanelTemplates segmented backgrounds and exact native handler contracts for controls using numeric texture IDs. It preserves native font sizes/wrapping and colored item-quality, requirements, reputation, quest and status text. The face and soft shadow follow the design; explicit narrative text receives readable near-white rather than remaining black on a dark pane.

| Family | Additional interior work |
| --- | --- |
| Character and inspect | Neutral pane surfaces; exact stone/category/row atlas removal; character-model backdrop removal with model content retained; title/equipment-manager panels; stats and pet-stat scroll rows restyled when pooled rows initialize |
| Talents and spellbook | Existing tree/book panes, text controls, tabs, inputs and exact decorative dividers; native nodes, connections, selected/learned states, spell icons and learned-spell behavior remain native |
| Quest and NPC | Native pane controls plus readable story/objective/progress text; decorative greeting separator removed; quest markers, objectives, reward icons and semantic colors remain |
| Mail | Native recipients/subject/body inputs, buttons and tabs; stationery artwork removed while message text, attachments, item counts, money/COD controls and mail actions remain native |
| Professions | Crafting/book interior surfaces and controls; exact background-template artwork removed; recipe list, reagent/result icons, skill requirements and crafting actions retained |
| Social and system | Cataloged native dialogs and their controls, including Settings category/content panes; original keyboard focus and control state remain |
| Help/tickets | Native outer controls and the browser's surrounding inset only; embedded support HTML is a separate browser surface and cannot be themed by this addon |

Selected tabs and reviewed list rows use the accepted near-black fill with a small blue bottom marker. Bindings observe native TabSystem, MinimalTab and legacy tab selection; Character mode/sidebar tabs; Settings categories; and Character equipment/title rows. Their old full-width selection artwork is replaced without changing selection, tab placement or click behavior. Native icons, title checks and new-feature indicators remain. Focused input treatment comes from the shared interior service.

The exact decorative atlas allowlist is source-backed. The code never removes arbitrary textures by a broad name substring, recolors game models, replaces item art or parses user text. Native geometry setters are not used by this adapter.

## Skinner coexistence

Skinner remains the native skin foundation when loaded. The reviewed profile controls its neutral palette and excludes third-party/HUD takeover. vasagoio overlays its interior design on known native roots without calling private Skinner functions or changing Skinner source. The shared service replaces reviewed `frame.sf` and `frame.sb` decorations only when each is still a child of the same frame and contains no child content; replaced decorative children are excluded from further traversal. Skinner's reverse-parent configurations are not blindly hidden. Eligible decorative surfaces receive the 10px corner treatment; native content is not globally clipped.

## Updates and disable

Load-on-demand events and native OnShow hooks trigger application. Character's modern ScrollUtil callbacks style newly initialized stat rows. A two-second watcher checks only registered names and refreshes effectively visible roots to catch newly allocated native controls. It prefers `IsVisible` so child panes under closed native windows are not repeatedly traversed, with `IsShown` as the older-API fallback. Reviewed MinimalTab hover handlers also refresh neutral text immediately after native font-object updates. Combat and forbidden/restricted regions defer presentation. Disable stops discovery and restores shared primitive snapshots; a reload is required to remove native hooks and fully restore owner rendering.

## Evidence and validation

Reviewed source: the Forever/Camelot CharacterFrame and PaperDollFrame XML/Lua, PlayerSpellsFrame XML, shared ScrollUtil public callback implementation, TabSystem/MinimalTab/SharedUIPanelTemplates selection methods, SecureUIPanelTemplates button chrome, MailFrame, HelpFrame, SettingsPanel/CategoryList, GossipFrame, QuestFrame and ProfessionsFrame XML at the recorded client snapshot. Skinner's `Core/NewSkinFuncs.lua` supplied the `.sf` and `.sb` decorative-frame contracts. Only original adapter code is distributed.

`tests/native_interiors_spec.lua` verifies catalog boundaries, one outer surface per native host, no native anchor/size/parent changes, model and semantic-art preservation, both ScrollUtil callback signatures, new pooled rows, selected-tab/row state hooks, load-on-demand roots, combat deferral and disabled cleanup. The shared interior service has its own primitive/state tests. These are offline tests; native pixel rendering, all real control states and combat/taint behavior still require user-run validation with WoW.

## Native recovery boundary

Release Spirit, player resurrection, corpse recovery, spirit-healer confirmations, the ghost return button and death recap remain native. All four pooled StaticPopup slots and recovery descendants are excluded before vasagoio traversal/hooks; the reviewed Skinner preset also disables StaticPopups, GhostFrame and DeathRecap. Reload after Apply clears old hooks. The reported disappearance prompted this change; source/offline tests cannot prove the live cause or that a recovery prompt is now visible. No recovery action is automatically invoked.

World-map decorative replacement preserves Skinner's deliberately LOW strata instead of inheriting its higher BorderFrame layer. This prevents our replacement background from covering map art/controls; it does not change RareScanner/OpenMap settings or native unexplored-region shading.
