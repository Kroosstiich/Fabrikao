# Fabrikao!! — agent guide

World of Warcraft professions addon (name: "Fabrikao" ~ Spanish "fabricar", to craft). CurseForge summary: "Your professions companion: browse recipes, plan what to craft, and find out where to get every recipe and ingredient."
Features (built, see CHANGELOG.md): professions window, every recipe known or not with filters, table and detailed views, recipe panel, global search, trainers/vendors/creatures on the map, optional Embolsao, Auctionator and TomTom integrations (the maintainer adds ideas as they come). Runs on three clients: **WoW Forever** (`Fabrikao.toc`, interface 16001), **Classic Era** (`Fabrikao_Vanilla.toc`) and **TBC Anniversary** (`Fabrikao_TBC.toc`). Forever is the retail engine; the other two have the old professions API (see "Classic Era and TBC Anniversary"). **Never break Forever**: every Classic path sits behind `ns.IsClassic()`.
Public repo `LechuckThePirate/Fabrikao` (branch `master`), GPLv3, CurseForge project id 1733457. Siblings with the
same conventions: `Completao` (the original template), `Embolsao` and `Aggreao`, under `D:\Source\WowAddons\`.

## How to work with the maintainer

- **Chat in Spanish from Spain** ("tú", never Argentine voseo: not "tenés", "contame", "dale"). **Everything committed is in English**:
  code comments, test names, docs, workflow comments, commit messages. Spanish only in the esES/esMX table of `Localization/Locale.lua` (the `esMX` TOC notes
  are Spanish too).
- Windows machine. Prefer the PowerShell tool over Bash. Multi-line commit messages: write a file and use `git commit -F <file>`.
- Work happens in git worktrees (`.claude/worktrees/<name>`, branch `claude/<name>`). **After every change (tests green) commit and
  push** (`git push origin HEAD`). **Merging to `master` and releasing only happen when the maintainer asks.**
- Keep the maintainer informed in one or two short lines during long tasks.

## Layout

Addon files at the repo root, packaged as the folder `Fabrikao` (`.pkgmeta`):

- `Fabrikao.toc`, `Fabrikao_Vanilla.toc`, `Fabrikao_TBC.toc`: one per client (the game picks the `_Vanilla` / `_TBC` one by suffix), all with the same files: `Load_Core.xml` (Flavor, Compat, Locale, Settings), the client's `Data\...\Recipes.lua`, then `Load_Modules.xml` (everything else, `Fabrikao.lua` last). A new module goes in `Load_Modules.xml`. `Fabrikao.lua` is the entry point: events and `/fabrikao`, `/fab`
- `Modules/Core/Flavor.lua` (`ns.flavor` from the interface number: forever / vanilla / tbc; `ns.IsClassic()`, asked at run time, never at load) and `Compat.lua` (`ns.ItemName / ItemIcon / SpellIcon / ItemInstant`: the `C_Item` / `C_Spell` answer first, the older global as the fallback)
- `Localization/Locale.lua` — English text is the key, with the Spanish (esES/esMX) table; more locales can be added as files
- `Modules/Settings/` — settings per character or shared by the account; new modules go in their own `Modules/<Area>/` folder and are
  added to the TOC. Every `X.lua` has `X.test.lua` next to it
- `Modules/Data/Inventory.lua` — what the OTHER characters carry and keep in their banks, from Embolsao's saved copies (account-wide):
  through Embolsao's public API (`EmbolsaoAPI`, since its branch `claude/public-api`: GetCharacters, GetOthersItemCount, GetItemHolders)
  when installed, else by reading its saved variable (`EmbolsaoDB.characterItems[key] = { name, class, time, bags = { [itemID] = n },
  bank = { [itemID] = n } }`), which older Embolsao versions need. Counts for "can make" go through `ns.Inventory_Count(itemID, alts)`;
  the `useAlts` preference turns it all off. **Embolsao (like Auctionator) is optional**: everything goes through this module, and without
  it the counts are the character's own, the "Other characters" checkbox is hidden and the preferences say it isn't installed (tests
  cover that path in `Alts.test.lua`); never reference `EmbolsaoAPI` / `EmbolsaoDB` anywhere else
- `Modules/Data/Quests.lua` — Completao!! (optional) through its public API (`CompletaoAPI.HasQuest / ShowQuest`): a recipe that comes from a quest
  has a "View Quest" button in its panel when Completao knows the quest; without it nothing shows. Never reference `CompletaoAPI` anywhere else
- `Modules/Data/Prices.lua` — approximate prices for the table view: auction prices from Auctionator's public API when it is installed,
  else what vendors pay; `Modules/UI/RecipeList.lua` — the two views of the recipe list (table with sortable columns, detailed
  with a big icon); `Modules/UI/FilterBar.lua` — the two rows of filters and sorting shared by a profession's page and the search
  of every recipe (dropdowns of the game's menus, `WowStyle1DropdownTemplate` + `SetupMenu` with radios, falling back to cycling buttons when
  the templates are missing; each keeps its own filters: `ns.char.filters`, `ns.char.searchFilters`; the category of a recipe comes from
  its product item through `C_Item.GetItemInfoInstant`, `ns.RecipeDB_Category`); `Modules/UI/Overview.lua` — the start screen under the welcome line, the search, the character picker and the button of the professions
  not learned: the professions (top left), what can be crafted now (bottom left, `ns.Recipes_CraftableNow`) and, the whole right side,
  what can be learned (`ns.Recipes_LearnableNow`: the ranks and the recipes by profession, the recipe with the nearest
  trainer or vendor first: `ns.RecipeDB_TrainerKey` / `_TeacherKey`), where a click on a rank or a recipe opens
  under it the trainers and vendors that teach it (`ns.Recipes_Teachers`, from `RecipeDB_Where`; a rank's are the profession's
  `ns.RecipeDB_Trainers`) with the map and waypoint icons, and a right click opens the recipe's panel; what is under the groups, the ranks
  and the recipes is folded until opened (`ns.char.folded[kind][key] == false` means opened);
  `Modules/UI/IconButton.lua` — the small map / waypoint / quest icon buttons of an NPC (`Icons/Map.png`, `Icons/Pointer.png`, drawn by
  `tools/make_icons.mjs`); `Modules/UI/AutoScroll.lua` — a scroll frame whose bar is only there when the content is taller than it
  (`ns.AutoScroll_Create` / `_SetHeight`; the recipe list and the side panels do the same); `Modules/UI/Trainers.lua` — the panel of a profession's trainers, nearest first, with map and TomTom buttons (`ns.RecipeDB_Trainers`; the "Trainers"
  button of the recipes page; it takes the place of a recipe's panel); `Modules/UI/RecipeDetail.lua` — the panel of a recipe that opens next to the window (a click on an ingredient opens, under it, where to
  get it: `ns.RecipeDB_ReagentWhere`, with the map and waypoint buttons of the vendors and creatures)
  on a click (`ns.RecipeDetail_Build` makes its content as data, `_Show`/`_Hide` the frame); `Modules/UI/Preferences.lua` — the gear's window (view, scale, resets)
- `Modules/Professions/` — `Professions.lua` (the character's professions, ordered: primary, First Aid, Cooking, Fishing; `Professions_Notice` is what is said beside a profession (the rank to train, or, for Poisons, how many can be learned);
  `Professions_Mine` adds Poisons (skill line 40, the rogue's spell 2842, skill five a level) for a rogue, listed with the primary
  professions; `Professions_NextRank` says which rank a trainer can teach it now: skill within 25 of the
  rank's cap (what a trainer asks for: 50 of 75, 125 of 150...), the level the rank asks for and a higher rank in the data's recipes; `Professions_Mine` is the
  playing character's, `Professions_List` the one of the character the window shows; `Professions_Missing` the ones with recipes in the data
  that it lacks) and `Recipes.lua`
  (a profession's recipes for the lists: from the data, with "known" from the spell book; the live answer of the game's window
  instead when that profession's tab is open; filtering, search and the "how many can I make" count from the bags)
- `Modules/Professions/Roster.lua` — the alt viewer's data: each character saves its professions and the recipes of the data it knows in
  `FabrikaoDB.characters[key]` (at login, when the skills or recipes change and at logout); `ns.Roster_SetView(key)` makes the window show
  another character (read only: no live trade skill read, no Craft button, ingredient counts from Embolsao's copies of that character; the
  window is tinted blue and the title and a line on the recipes page name it; closing the window puts the playing character back).
  Everything that asks "does the character know it?" goes through `ns.Roster_Knows`, and the professions through `ns.Professions_List`
- `Modules/UI/` — `MainWindow.lua` (the frame and the recipes page; the start screen is `Overview.lua`), `SearchPage.lua` (search of every recipe in the data, with a detail
  panel) and `MinimapButton.lua`; `Bindings.xml` has the key binding (the game loads it itself: **never list it in the TOC**)
- `Data/Vanilla/Generated/Recipes.lua` and `Data/TBC/Generated/Recipes.lua` (**generated, never edit by hand**): the same shape for Classic Era and TBC Anniversary, see below; `Data/DataClassic.test.lua` checks them
- `Data/Generated/Recipes.lua` (Forever's; **generated, never edit by hand**) — every recipe of the crafting professions (skill levels where each
  turns orange / yellow / green / grey, ingredients, product, how it is learned), the items that teach them (vendors, drops, quests)
  and the trainers; `Data/Data.test.lua` checks its shape. `Modules/Data/RecipeDB.lua` queries it (by spell id, search by name /
  ingredient / NPC / zone, "where to learn it" lines)
- `Modules/Professions/Classic.lua` — everything the Classic clients do differently, see below
- `Modules/Debug/Probe.lua` — `/fab probe` prints, per profession, how many of the data's recipes the client says are known (by each way
  of asking) and compares with the game's window when it is open; result also in `FabrikaoDB.probe` (SavedVariables file after `/reload`)
- `test/` (WoW API mock + local runner), `setupTests.lua`, `Icons/` (addon icon), `images/screencaps/` (CurseForge description images),
  `images/fabrikao_propuesta_iconos.jpg` (the four icon proposals; `Icons/Fabrikao.png` is the top-left one, cut round and transparent, 256x256, with the gold background hue-shifted to red so the four sibling addons are easy to tell apart: Completao green, Embolsao gold, Aggreao blue, Fabrikao red)

## Recipe data

`Data/Generated/Recipes.lua` comes from local tools in `tools/local/` (git-ignored, **never published, and the name of the web source is
never written in anything tracked**: README, CHANGELOG, CurseForge text, commit messages, code comments — credit it only as "public
databases", like Completao). Steps: `node tools/local/recipes_fetch.mjs` (a spell listing and a skill page per profession),
`node tools/local/recipes_items.mjs` (slow: one page per recipe item whose source isn't named yet; resumable; one request every 3 s,
the source answers 403 beyond that), `node tools/local/ranks_fetch.mjs` (the books and quests of the ranks that are not a trainer's: Expert of Cooking, First Aid and
Fishing, Artisan of the three, with the vendors of the books and the givers of the quests; it ends up as `ranks[skill][cap]`, read by
`ns.RecipeDB_RankSources`), `node tools/local/quests_fetch.mjs` (who gives each quest that teaches a recipe: about seventy pages; the givers go into
the `qs` of the items, read by `RecipeDB_Where` and so by `ns.Recipes_Teachers`), `node tools/local/reagents_fetch.mjs` (where each ingredient can be had: who sells it, which
creatures drop it or are skinned for it, the zones it is fished in, the nodes it is gathered from, what makes it; one page per ingredient,
about 600, so the first run is long; it ends up as `reagents[itemID]` in the data, read by `ns.RecipeDB_ReagentWhere`, and the creatures and
vendors it names are among the NPCs whose positions are fetched), then
`node tools/local/recipes_write.mjs <worktree>/Data/Generated/Recipes.lua` (which also writes
`cache/npc_wanted.json`: the vendors, trainers and creatures of the data), `node tools/local/npc_coords.mjs` (where each stands: one page
each, for the map and TomTom buttons) and `recipes_write.mjs` again to put the positions in. Pages are cached in `tools/local/cache/`
(`CACHE_TTL_DAYS` and `REFRESH_BUDGET` make a run download the oldest ones again, a few at a time). Source codes in the data: 1 crafted, 2 drop, 3 PvP, 4 quest, 5 vendor, 6 trainer, 16 gathered, 21 salvaged.

**Layers (since mid-October 2026 the web sources refuse scripted requests to the Forever pages; a refusal is final, the tools never try to get
around it).** `recipes_write.mjs <out> [--mode web|open] [--no-open] [--base ...] [--report f]` builds the data in layers, strongest first:
what the web sources gave this run > what they gave earlier (the page and JSON caches and, in `open` mode, the last published file, which
fills whatever the caches no longer rebuild or is the base when they are lost) > the open layer. The open layer
(`tools/local/open/`) is the game's own client tables for the newest Forever build (`wago_fetch.mjs` downloads the CSVs, `wago.mjs` reads
them) plus Questie's Forever database (`questie_db.mjs`, from the QuestieDB addon: `QUESTIEDB_TOC`), distilled by `build_open.mjs` into the
small `open/open_data.json` (the only thing the server needs; the big sources stay on the maintainer's machine) and merged by
`open_layer.mjs` + `merge.mjs`, which **only fill gaps and never replace or remove a value**: recipes with a teaching item that has a known
source, ingredients, products and teaching items that are missing, vendors / quests / trainers / positions the data lacks (Questie's droppers
and containers only for an item with no other source). Skill colors, learned-at levels, training costs, prices, drop chances, "new in Forever"
and the position of an NPC that already has one are web-only or disputed and are never touched. `wh_probe.mjs` makes ONE request to tell if the
web sources answer; `WH_OFFLINE=1` makes the fetch tools read only their cache; `recipes_fetch.mjs` keeps the earlier listing of a skill it
could not fetch (a refusal used to leave `recipes_raw.json` empty). `compare_data.mjs old.lua new.lua` compares two data files field by
field (lost / changed / added) and `node --test tools/local/selftest.mjs` checks the pipeline code, including that `open` mode on the current
file loses and changes nothing. To refresh the open layer after a game build: `node tools/local/open/wago_fetch.mjs && node
tools/local/open/build_open.mjs`, then `pwsh tools/local/vps/deploy.ps1` (without `-Cache`: the server's cache is newer than the local one).

## Forever's API (what the code relies on)

Forever runs on the retail engine: professions use `GetProfessions()` / `GetProfessionInfo(index)` for the list. **All professions live in one
window with tabs (K key)**, not one window each, and neither `C_TradeSkillUI.OpenTradeSkill` nor casting the profession spell from an
addon opened anything (no `TRADE_SKILL_*` event ever arrived), so the addon never opens it: the recipe lists come from the data and
"known" from `C_SpellBook.IsSpellKnown` / `IsPlayerSpell`; `C_TradeSkillUI` (`GetFilteredRecipeIDs`, `GetRecipeInfo`...) is only read when
the player has that profession's tab open. The game's own UI code for Forever (to check anything about the API) is the `forever` branch of
https://github.com/Gethe/wow-ui-source (`Interface/AddOns/Blizzard_Professions*`, `Blizzard_APIDocumentationGenerated`). Anything the docs
don't settle is verified in game with `/fab probe`.

## Classic Era and TBC Anniversary

What differs from Forever (all in `Modules/Professions/Classic.lua`, called from `Professions.lua`, `RecipeDB.lua`, `Recipes.lua`, `Craft.lua`, `Probe.lua`
and the two Craft buttons, each behind `ns.IsClassic()`):

- **Professions** are skill lines: `GetNumSkillLines` / `GetSkillLineInfo`, named by English name, by the name of the profession's spell in the player's
  language, or by an alias learned from a window (`FabrikaoDB.skillAliases`; the game does not always call the skill what it calls the spell). Folded
  headers of the skills list are opened (and left open: folding them again fires `SKILL_LINES_CHANGED` and the roster would save forever). A profession
  the character dropped has its recipes forgotten, but only when every primary skill was named.
- **Known recipes** are not in the spell book there. `TRADE_SKILL_SHOW/UPDATE` and `CRAFT_SHOW/UPDATE` (Enchanting and Poisons use the older craft
  window) scan the open window: the spell id is inside the recipe link (`enchant:ID`). The ids are kept in `FabrikaoCharDB.knownRecipes`;
  `IsPlayerSpell` / `IsSpellKnown` are also asked. The scan folds back the headers it opened and ignores the events that causes (`quietUntil`).
  `C_TradeSkillUI` is never used, so `Recipes_Read` is always nil and the lists come from the data.
- **Craft** opens the profession window by casting its spell, which only secure code may do: `ns.Craft_Secure(button)` puts a transparent
  `SecureActionButtonTemplate` over the button and `ns.Craft_Prepare(button, recipeID, skillLine)` sets its `spell` attribute (out of combat only);
  after the cast, `PostClick` calls `ns.Craft_Open`, which picks the recipe in the window (`ns.Classic_Select`). Mining opens with Smelting.
  **Not verified in game yet**: whether the cast opens the window from the overlay, and whether `GetTradeSkillRecipeLink` returns `enchant:ID` on both
  clients; `/fab probe` prints what each client answers (skill rows, windows, APIs, recipes saved from the windows).
- **Data**: `tools/local/classic/build_classic.mjs --flavor vanilla|tbc --out <Recipes.lua> --forever Data/Generated/Recipes.lua` (git-ignored, local) builds each
  file from the client tables (wago.tools CSVs in `tools/local/cache/open/wago/vanilla|tbc/`: SkillLineAbility, SpellName, SpellReagents, SpellEffect,
  ItemSparse, ItemEffect), Questie's database (`tools/local/cache/questie/Vanilla|TBC/`, from the QuestieDB releases; vendors, quests, droppers, NPCs and
  where they stand) and CMaNGOS' world database (`tools/local/cache/cmangos/classic.sql.gz` and `tbc.sql.gz`, from `cmangos/classic-db` and `cmangos/tbc-db`
  Full_DB, GPL-3; read by `tools/local/classic/cmangos.mjs`). The client tables say what the recipes are and which items teach them; CMaNGOS says who
  trains what (`npc_trainer` and `npc_trainer_template`): a recipe a trainer teaches is a trainer's, with its cost and the skill it is learned at, and the
  trainers of a skill are the NPCs that teach one of its recipes; a recipe with no trainer and no teaching item that comes with the profession
  (`AcquireMethod` 1) is a starter one; the rest have no known source. CMaNGOS also gives the drop chances of the teaching items and ingredients
  (direct loot only, references are not followed), the creatures skinned for an ingredient, the fishing zones, and the quests (`RewSpell`) that give the
  Artisan rank of Cooking, First Aid and Fishing; the Expert books come from the client tables. Poisons are always the rogue trainers'. The skill a recipe
  with no trainer data is learned at is Forever's for the same spell, else 20 under the yellow level (`requiredFromForever` / `requiredGuessed` in the
  report). Regenerate when a client patches; there is no daily job for these two files, and Forever's refresh does not touch them.
- Deploy to a client with robocopy from PowerShell (not bash): `robocopy <worktree> "D:\Games\World of Warcraft\_anniversary_\Interface\AddOns\Fabrikao" *.lua *.toc *.png *.xml /S /PURGE /XD tools images .github .git test .claude /XF *.test.lua setupTests.lua`
  (also `_classic_era_`; exit codes 0-7 are success). The tests load each toc with `LoadAddon({ toc = "Fabrikao_Vanilla.toc" })`.

## Commands (PowerShell, repo root)

```powershell
lua test/busted.lua                       # all tests, no busted install needed (Lua 5.1+)
busted -p ".test.lua" .                   # real busted (what CI runs, Lua 5.1)
luacheck Fabrikao.lua Localization Modules Data Fabrikao.test.lua test setupTests.lua   # if installed (what CI runs; the generated data is excluded in .luacheckrc)
```

No deploy script: copy or symlink the repo root as `Fabrikao` into
`D:\Games\World of Warcraft\_classic_beta_\Interface\AddOns\` (without `test/`, `images/`, `*.test.lua`, `setupTests.lua`), then
`/reload`.

## Code conventions

- Lua 5.1. Shared namespace: `local ADDON, ns = ...` in every file; no new globals (see `.luacheckrc`, add the game API a file uses to `read_globals`).
- English text is the localization key: `ns.L["Some text"]`; translations go in `Localization/`.
- Every module gets a `*.test.lua` next to it, starting with `dofile("setupTests.lua")`. CI runs luacheck and busted on Lua 5.1.
- Comments explain *why*, are short, and match the surrounding density. Match surrounding naming and idiom.
- Commit style: `feat(scope):`, `fix(scope):`, `perf(scope):`, `release: X.Y.Z -- short summary`.
- User-visible changes go in `CHANGELOG.md` (newest first, `New:` / `Fix:` bullets, plain sentences).

## Infra and release

- **CI:** `.github/workflows/ci.yml` (luacheck + busted on every push and PR).
- **Daily data refresh**, as in Completao: a cron job on the maintainer's VPS (`/etc/cron.d/fabrikao-data`, 03:20; `/opt/fabrikao-data/run.sh`,
  kept as `tools/local/vps/fabrikao-run.sh`) runs the tools above in a node container against a clone of this repo (the scripts and the page
  cache live in the clone's git-ignored `tools/local`; `tools/local/vps/deploy.ps1` copies them there, `-Cache` seeds the cache, `-Cron`
  installs the cron entry) and publishes `Recipes.lua` + `updated.txt` at `https://media.joanvilarino.online/fabrikao-data/` (a run
  that lost more than 5 % of the recipes publishes nothing). The run probes the web sources once (`wh_probe.mjs`): when they answer it crawls
  them as before, when they refuse (or fail midway) it runs in `open` mode (see "Layers") and publishes `source.txt` (`web` or `open since
  <date>`) next to `updated.txt`; the next run that they answer goes back to them by itself.
  `.github/workflows/update-recipe-data.yml` (cron 05:50) fetches it, checks
  its shape and age, warns (does not fail) while `source.txt` says `open`, still fails when `updated.txt` is over 3 days old, runs busted and
  opens the pull request `auto/recipe-data` (its body says where the data came from), which the maintainer merges; nothing merges by itself.
  The server holds no credentials for this repo. Needs the repo setting "Allow GitHub Actions to create and approve pull requests".
  When the generator's output changes shape, update the scripts on the VPS with `deploy.ps1`. Log: `/var/log/fabrikao-data.log`.
- **Release** (only when asked): one commit `release: X.Y.Z -- short summary` that bumps `## Version` in `Fabrikao.toc` and adds the
  section to `CHANGELOG.md` (and `LATEST_CHANGELOG_TEXT` in `Modules/UI/Welcome.lua`); then
  `git tag vX.Y.Z`, push `master` and the tag, and
  `gh workflow run release.yml --repo LechuckThePirate/Fabrikao --ref vX.Y.Z` (workflow_dispatch only; BigWigsMods/packager uploads to
  CurseForge with repo secret `CF_API_KEY` and creates the GitHub release). Watch with `gh run watch`.
- **Screenshots:** `images/screencaps/*.png` are shrunk and rsynced by `.github/workflows/sync-media.yml` (push to master touching that
  path, or `gh workflow run sync-media.yml`; skipped while there is no PNG) to
  `https://media.joanvilarino.online/fabrikao/images/screencaps/`, which `CURSEFORGE_DESCRIPTION.md` references.
  Secret `FABRIKAO_MEDIA_SSH_KEY` (private key `~/.ssh/id_ed25519_fabrikao_media`): restricted rsync-only VPS user `fabrikao-deploy`
  (`authorized_keys` forced to `rrsync -wo /srv/embolsao-media/fabrikao`, like `aggreao-deploy`; the same Caddy container serves it, so no
  Caddy change); the media host itself is configured in the Embolsao repo.
- `.pkgmeta` keeps images, tests and `CURSEFORGE_DESCRIPTION.md` out of the package.
