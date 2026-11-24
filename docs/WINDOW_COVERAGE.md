# Window skin coverage

This alpha preserves native window structure. It never replaces the Character model, equipment slots, stat layout or tabs, and does not move native controls. Addons retain their functional interfaces. Appearance changes are cosmetic; none of the adapters opens a window or performs gameplay actions.

## Native windows

When Skinner is loaded and enabled, Skinner owns native skins. The explicit setup review offers a profile adapter for **Skinner beta12.70938.1** only. It changes neutral black background/white text colors, disables continuous borders/gradients, enables native window families, and excludes HUD and third-party skins from Skinner ownership. It leaves Skinner's layout implementation intact. Colors are applied after a UI reload because Skinner caches them. Unknown Skinner versions are not written; the setup status explains that manual configuration or a reviewed adapter is needed.

Without Skinner, vasagoio decorates these explicitly named roots when present:

| Window family | Root coverage |
| --- | --- |
| Character and inspect | CharacterFrame, InspectFrame, PaperDollFrame, ReputationFrame, TokenFrame |
| Spells and talents | PlayerSpellsFrame, SpellBookFrame, PlayerTalentFrame |
| Quests and NPCs | QuestLogFrame, QuestFrame, GossipFrame, MerchantFrame, TradeFrame, ClassTrainerFrame, PetStableFrame |
| Professions | TradeSkillFrame, CraftFrame, ProfessionsFrame |
| Mail | MailFrame, SendMailFrame, OpenMailFrame |
| Economy | AuctionFrame, AuctionHouseFrame, BankFrame |
| Social and groups | FriendsFrame, GuildFrame, CommunitiesFrame, ChannelFrame, PVPUIFrame, PVPFrame, LFGParentFrame, LFDParentFrame, RaidInfoFrame |
| Other native windows | CalendarFrame, AchievementFrame, WorldMapFrame, DressUpFrame, LegacySystemFrame |
| System and support | GameMenuFrame, SettingsPanel, InterfaceOptionsFrame, KeyBindingFrame, MacroFrame, HelpFrame, ReportFrame, TicketStatusFrameButton |
| Tooltips and dialogs | ItemRefTooltip, GameTooltip, StaticPopup1–4 |

These are **shell adapters**, not a claim that every inner widget or every possible screen is covered. They replace known decorative backdrops/NineSlice edges, add a borderless surface and style named titles. Character stone backgrounds are handled explicitly. Portrait content, maps, models, quest/loot text and action controls remain intact. Native text sizes are retained to avoid clipping existing rows; the Friz face and soft shadow are shared with the design system. Load-on-demand native addons trigger a refresh, and already-discovered roots refresh on show.

The Help/ticket outer shell can be styled; the embedded support webpage cannot be styled through this addon. Forbidden frames are skipped. Skinner's native skin surfaces do not acquire vasagoio's 10 px corner radius. The direct fallback uses the common surface renderer where supported; this is not a promise that all existing native inner art is clipped to that radius. No native backdrop blur or refraction is implemented.

## Selected addon windows

| Owner / reviewed release | Implemented | Preserved or pending |
| --- | --- | --- |
| Baganator / public Skins API, verified with 868 | `API.Skins.RegisterListener` and `GetAllFrames`; ButtonFrame/Dialog shells and ItemButton count typography | Item icons, rarity, quests, search, inventory actions, cooldowns and layout remain owner-controlled. Other API region types are not restyled. |
| TalentsForeverBook / 0.38.28.20261116 | Main window, trainer and toast outer shells; named outer cover art removed; named titles use Friz | Talent nodes, trees, planning, training, internal panels and controls retain owner styling. Full inner adaptation remains pending. |
| MRT / 5335 | Options window outer shell and title | Raid-leading features are retained. Notes, timers, checks and other internal tools are not comprehensively reskinned. |
| Auctionator / 352 | Full scan and named page-status/throttling dialogs | Native AuctionFrame/AuctionHouseFrame use the native adapter. Search, buying, selling and internal tab layouts remain owner-controlled. |
| OpenMap | Native WorldMap shell via the native adapter | Canvas, map markers, navigation and OpenMap behavior retained. |
| Gargul | No skin adapter yet | Functionality retained; no verified skin API/frame contract was available for this alpha. |
| Other addons | No broad traversal or global restyling | Existing functionality and styling retained unless separately covered by a HUD module. |

Named addon adapters are version gated. New versions remain functional and skip that cosmetic adapter until reviewed. A lightweight two-second watcher checks only the listed global roots for windows created on first use; it does not enumerate the global UI tree. Baganator's documented listener handles newly-created regions. Work encountered in combat defers through the core. Disabling the module stops discovery and makes existing listeners inert; reload removes hooks and surfaces completely.

## Offline verification

`tests/windows_spec.lua` runs with Lua 5.1 and exercises native structure preservation, repeated-hook safety, combat deferral, forbidden/secret object rejection, Skinner schema-version rejection, serializable rollback path resolution, single skin ownership, Baganator API dispatch and lazy root discovery. Its fixtures fail if a native size or anchor is changed. These checks do not replace user-run in-game validation; the game has not been launched for development.
