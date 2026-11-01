# Changelog

## Unreleased

- New: under a recipe in "You can learn", the creatures that drop the pattern or recipe that teaches it (with their level and chance, and the map and waypoint icons), after the trainers and vendors; an item that drops from any creature says so. The "nobody is known" message is only for recipes with no source at all.
- New: Classic Era and TBC Anniversary. The same addon now loads on those clients (one folder, a TOC per client), with the recipes of each game, including Jewelcrafting in TBC.
- New: on those clients, what a character knows is read from its profession windows the first time they are opened (and every time after), so open each profession once. The Craft button opens the profession's window on the recipe.
- New: on Classic Era and TBC, the tooltip of what a recipe makes also shows what you wear in that slot (both slots for rings, trinkets and weapons), with a green "Equipped" title on it, with no key to hold. Forever already does it by itself.
- Data: the recipes of Classic Era and TBC come from the game's own tables and open databases: trainers with their cost and the skill they ask, drop and skinning chances, and the books and quests of the Expert and Artisan ranks.

## 0.4.6

- Data: the trainers of several professions, as the public databases have them now.

## 0.4.5

- Data: recipe data with a few more recipes, sources and trainers, as the public databases have them now.

## 0.4.4

- Data: fresh recipe data, as the public databases have them now.

## 0.4.3

- Fix: the next rank of a profession ("Can train: Journeyman") shows up as soon as the skill is the one a trainer asks for (50 of 75, 125 of 150, 200 of 225...), instead of waiting for the skill to reach the cap of the current rank.

## 0.4.2

- Fix: "You can learn" no longer lists recipes that nobody teaches out of season: the Winter Veil ones (Gingerbread Cookie, Egg Nog, Green Holiday Shirt, Edge of Winter, Winter's Might, Winter Clothes and Boots) and the Lunar Festival fireworks launchers. They are still in the profession's page.

## 0.4.1

- Fix: the "View Quest" button in the panel of a recipe that comes from a quest is Completao!!'s icon, next to the map and waypoint icons, instead of a text button drawn under them.

## 0.4.0

- New: an icon at the right of "You can learn" orders its recipes by proximity (as before, the default), by level or by name; the choice is kept.
- Data: fresh recipe data, as the public databases have them now.
- Fix: the welcome windows of several addons no longer show their text, buttons and links through each other when they open together: each one opens in front, with all its content, and a click brings it forward.

## 0.3.0

- New: look at your other characters' professions. A picker above the professions ("My professions" and each alt) shows an alt's professions and
  the recipes it knows as if it were the one playing, with its skill levels and how many it could make with its own bags (from Embolsao!!'s
  copies, when installed). The window turns blue and says whose they are, as Embolsao!! does with another character's bags, and there is no
  crafting. An alt appears once you have logged in with it with this version.
- New: a button above the professions lists the professions you have not learned too, so you can browse their recipes.
- New: the start screen has your professions (top left), what you can craft now (bottom left: what your bags allow, orange first, with
  how many; a click opens the game's profession window on that recipe, as the Craft button does) and, on the whole right side, what you
  can learn: the ranks a trainer can teach and the recipes your skill reaches that you don't know, by profession, the ones with the
  nearest trainer or vendor first. A click on
  a rank or a recipe opens under it the trainers and vendors that teach it, nearest first, with a map icon and, with TomTom installed, a
  waypoint icon (a right click on a recipe opens its panel). The groups start folded, and what you open stays open. The search box, the
  character picker and the button of the professions not learned are above, under a welcome line.
- New: the ranks that are not taught by a trainer say how to get them: the Expert rank (150-225) of Cooking, First Aid and Fishing is a
  book, so under the rank are the vendors that sell it; the Artisan rank (225-300) of the three is a quest, so it is whoever gives it.
  With Completao!! installed the quest has one more icon, Completao's own, that opens the quest there.
- New: the recipes that come from a quest list the quest under the recipe (by its name, with who gives it under it) with the map and
  waypoint icons of whoever gives it and, with Completao!! installed, its icon. The panel of such a recipe has the same buttons.
- New: rogues have Poisons among their professions (once the spell is learned, at level 20), right after the primary professions: its
  skill goes up five a level, its poisons are listed by the level that learns them, and, as with the ranks, the profession says "Can
  learn: 3" when new poisons can be learned from the rogue trainers. They also show among what you can learn, with their trainers.
- Change: the map and waypoint buttons of the trainers, vendors and creatures are small icons (a map, and a navigation arrow) instead of
  two wide text buttons.
- New: a scroll bar only shows when there is something to scroll: with nothing to scroll the bar goes away and the rows take its room
  (the quadrants, the lists of recipes and the side panels).
- New: a "Trainers" button on a profession's page opens a panel with that profession's trainers, nearest first (with their zone and how far
  they are), each with a "Map" button and, with TomTom installed, a waypoint button. It works for professions you have not learned too.
- New: when a profession's skill is at the cap of its rank and your level lets a trainer teach the next one (Journeyman, Expert,
  Artisan...), the profession says "Can train: Journeyman" on the main screen, next to its skill on its page and in the trainers' panel.
  It follows an alt's own level when you look at an alt.
- Fix: the trainers of Herbalism, Skinning and Fishing are listed too (the data had none of them). Those professions have no recipes, but
  their page opens from the main screen so you can reach its Trainers button.
- New: a click on an ingredient in a recipe's panel opens, under it, where to get it: who sells it, which creatures drop it or are skinned for it
  (with their level and the chance), the zones it is fished in, the nodes it is gathered from and what makes it. The vendors and creatures have a
  "Map" button and, with TomTom installed, a waypoint button, and come nearest first.

## 0.2.0

- New: with Completao!! installed, the recipes that come from a quest have a "View Quest" button in their panel that opens the quest there.

## 0.1.4

- Data: fresh recipe data, as the public databases have them now.
- Fix: the window comes above the windows of the author's other addons when it is shown or clicked (it was drawn under their contents and looked see-through).
- Fix: the welcome window is opaque, so when the welcome windows of several of the author's addons open together each one hides the previous one instead of showing through it.

## 0.1.3

- Fix: the "Craft" button is off when your bags hold nothing to craft the recipe with.
- New: a small public API for other addons, `FabrikaoAPI` (`ShowRecipesUsing(itemID)` opens the search page with the recipes that use that item). Embolsao!! uses it
  for the "Recipes" entry of its item menu.
- New: the search of every recipe lists its results like a profession's page (table or detailed view, with the same filters and sorting) and a click
  on one opens its panel next to the window, with the Craft button for the recipes you know.

## 0.1.2

- New: a welcome window, once per version (and with `/fab changelog` or the preferences' "What's new" button): what's new, where to report bugs, and
  links to the other addons of the same author (Embolsao!!, Completao!!, Aggreao!!), to copy and paste in a browser.
- New: the "Map" and "TomTom" buttons of the trainers, vendors and creatures are in the panel of the recipes you know too, not only of the ones you don't.
- New: the panel of a recipe you know has a "Craft" button, with how many your bags allow, that opens the game's profession window on that
  recipe, ready to craft there (the game does not let addons craft).

## 0.1.1

- Data: fresh recipe data (training costs and where some recipes are learned, as the public databases have them now).

## 0.1.0

First version, only for WoW Forever.

- New: window (`/fab`, the minimap button or a key binding) that lists the character's professions with the game's icons:
  the primary ones first, then First Aid, Cooking and Fishing, each with its skill bar.
- New: a profession's page lists the recipes the character knows (colored by difficulty, with how many can be made from the
  bags in brackets) and then the ones it doesn't know, with a search box (names and where to learn them) and a filter by source.
- New: the recipes you don't know show the skill they need and where they are learned (trainer, vendor, drop, quest), with the skill
  levels where they turn orange, yellow, green and grey in the tooltip. The search also looks at who sells or drops them.
- New: data for every recipe of every crafting profession (also the ones of professions you don't have), from public databases.
- New: search of every recipe in the game (the box above your professions, or `/fab find <text>`): by name, ingredient, vendor, drop,
  quest or zone, also for professions you don't have, with a detail panel (skill levels, what it makes, ingredients with how many you
  have, where to learn it) and a filter by profession.
- New: filters on a profession's recipes (where they are learned, color for your skill, learnable now / needs more skill, only what you can
  make now with your bags, hide grey), sorting (name, level, cost, auction value, how many you can make) and a "Clear" button.
  The "Known recipes" and "Not known" titles fold and unfold with a click.
- New: the search of every recipe has the same filters and sorting (source, color for your skill in each profession, learnable
  now / needs more skill, can make now, hide grey); with no text it lists everything that passes them. It knows which recipes you
  know and colors the others for your skill in their profession.
- New: integration with Embolsao: with the "Other characters" checkbox (next to "Can make now") the counts of what you can make
  include the bags and banks of your other characters, as Embolsao saved them (through Embolsao's new public API when it has it; without
  Embolsao nothing of this shows and everything works with the character's own items); the ingredient icons' tooltips say who has each
  item, and the details of the search show how many the others have. A preference turns it off.
- Fix: the vendors and trainers shown for a recipe are the ones of your faction: the ones the data has no side for are left out when
  they stand in the other faction's capitals or starting zones. Up to five vendors are listed, each with its zone, and how many more there are.
- New: a click on a recipe of the list (table or detailed view) opens its panel next to the window with everything known about it:
  whether you know it, the skill it needs and how its colors look for you, what it makes, how many you can make, the ingredients
  with how many you have (bags, bank and other characters) and their prices, what the ingredients cost, what it sells for and
  the profit, the training cost, the item that teaches it and the full list of where it is learned (trainers, vendors, quests, drops).
  Shift-click still puts the recipe's link in the chat.
- New: in the recipe's panel the trainers, vendors and creatures that drop it are listed nearest first, with how far they are, when the
  game tells where you are (the ones on your map next, then the ones elsewhere).
- New: the trainers, vendors and creatures that drop the recipe you don't know have a "Map" button in the recipe's panel that opens the world map on them
  with a pin, and, with TomTom installed, a "TomTom" button that sets a waypoint (the ones in the zone you are in are listed first).
- New: the filters are dropdowns like the ones of the game's options, and there is a new one by category: the slot of armor (hands,
  wrist, chest...), the kind of weapon, bags, potions, elixirs, food, gems, trade goods, the slot an enchantment goes on... in both
  the profession's page and the search of every recipe. "Clear" moved next to the view button, and the sort dropdown has a
  "Descending" checkbox.
- New: the detailed view shows the ingredients as icons too, with their tooltips (red when you lack them), like the table.
- New: two views of the recipe lists, chosen in the preferences or with the "View" button: table (icon, name, components,
  approximate cost, approximate auction value, level; click a title to sort) and detailed (big icon, three lines). In the table
  the components are the ingredients' icons with their count (red when you lack it on a recipe you know); hover one for the
  item's tooltip.
- New: preferences window (the gear next to the X): view, window scale, minimap button, chat messages, reset window position and
  size, reset filters, restore defaults. The window can be resized and remembers its size.
- The recipe lists no longer need the game's profession window: they come from the data.
- Now only for WoW Forever.
- `/fab probe`: diagnostic that saves what the client's profession API answers.
