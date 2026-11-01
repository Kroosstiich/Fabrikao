// Builds Data/<Flavor>/Generated/Recipes.lua for the Classic clients from open sources only (the web sources are not used):
//   * the game's own client tables (wago.tools CSVs of the Classic Era / TBC Anniversary builds, cache/open/wago/<flavor>/): every
//     recipe (skill line, name, ingredients, product, the four skill levels) and the items that teach them;
//   * Questie's database of that client (cache/questie/<Flavor>/): vendors, quests, droppers, containers, NPCs and where they stand;
//   * CMaNGOS' world database (cache/cmangos/classic.sql.gz, tbc.sql.gz; GPL-3, see cmangos.mjs): which NPC trains which spell with its
//     cost and required skill, drop / skinning / fishing chances, and the books and quests behind the Expert and Artisan ranks.
// Its output is the tracked, generated Lua. Sources are read from a cache folder (CLASSIC_CACHE, default tools/classic/cache) that
// fetch_sources.mjs fills (wago tables and CMaNGOS) together with the QuestieDB releases (see .github/workflows/update-classic-data.yml):
//   <cache>/wago/<vanilla|tbc>/<Table>.csv, <cache>/questie/<Vanilla|TBC>/QuestieDB/QuestieDB_<Vanilla|TBC>.toc, <cache>/cmangos/<classic|tbc>.sql.gz
//   node tools/classic/build_classic.mjs --flavor vanilla|tbc [--out Data/<Flavor>/Generated/Recipes.lua] [--forever Data/Generated/Recipes.lua] [--report f]
//
// What each source decides: the recipe list, ingredients and colors are the client's; a recipe is a trainer's (with its cost and the skill
// it is learned at) when CMaNGOS has a trainer teach it, an item's when an item teaches it, a starter one when it comes with the profession
// (SkillLineAbility.AcquireMethod 1), else it has no known source. Poisons (the rogue class skill) are always the rogue trainers'. Where a
// number is missing (the skill a recipe with no trainer data is learned at) Forever's data for the same spell is used (--forever), else
// 20 under the yellow level.
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parseCsv } from "./csv.mjs";
import { parseData, renderData } from "./lua_data.mjs";
import { readTables } from "./cmangos.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const ROOT = join(here, "..", "..");
const CACHE = process.env.CLASSIC_CACHE ? resolve(process.env.CLASSIC_CACHE) : join(here, "cache");
const args = process.argv.slice(2);
const option = (name) => { const i = args.indexOf(name); return i < 0 ? undefined : args[i + 1]; };
const flavor = option("--flavor");
const foreverFile = option("--forever") ?? join(ROOT, "Data", "Generated", "Recipes.lua");
const reportFile = option("--report");

const FLAVORS = {
    vanilla: {
        wago: "vanilla", questie: "Vanilla", cmangos: "classic", skills: [164, 165, 171, 185, 186, 197, 202, 333, 129, 40],
        races: { all: 255, alliance: 77, horde: 178 },
    },
    tbc: {
        wago: "tbc", questie: "TBC", cmangos: "tbc", skills: [164, 165, 171, 185, 186, 197, 202, 333, 129, 40, 755],
        races: { all: 1791, alliance: 1101, horde: 690 },
    },
};
const FLAVOR = FLAVORS[flavor];
if (!FLAVOR) throw new Error("usage: node build_classic.mjs --flavor vanilla|tbc [--out <Recipes.lua>] [--forever <Recipes.lua>] [--report <file>]");
const out = option("--out") ?? join(ROOT, "Data", FLAVOR.questie, "Generated", "Recipes.lua");

// QuestieDB reads the toc named in the environment when it is imported
process.env.QUESTIEDB_TOC = join(CACHE, "questie", FLAVOR.questie, "QuestieDB", `QuestieDB_${FLAVOR.questie}.toc`);
const { item: qItem, npc: qNpc, quest: qQuest, object: qObject, allIds, keyed, tocDir } = await import("./questie_db.mjs");

const WAGO = join(CACHE, "wago", FLAVOR.wago);
const table = (name) => parseCsv(readFileSync(join(WAGO, `${name}.csv`), "utf8"));

const SKILLS = new Set(FLAVOR.skills);
const FISHING = 356;
const JUNK = /^(UNUSED|zz|DEPRECATED|DNT|\[PH\]|TEST|OLD)\b|\(OLD\)|\bUNUSED\b|\bDEPRECATED\b|\[UNUSED\]/i;
// the title a trainer of each skill carries in Questie: used for the skills CMaNGOS has no trainer spells for (Poisons, Fishing)
const TRAINER_TITLE = { 40: /^rogue trainer$/i, [FISHING]: /fish/i };
const FLAG_TRAINER = 16;
// the ranks that are a book or a quest and not a trainer's: the skill, the skill it goes up to, and the rank's spell
const RANKS = [
    [185, 225, 3413], [185, 300, 18260], [129, 225, 7924], [129, 300, 10846], [FISHING, 225, 7732], [FISHING, 300, 18248],
];
// the books of the Expert ranks, for when the client tables do not link the book to the rank (Expert Cookbook, Expert First Aid - Under
// Wraps, Expert Fishing - The Bass and You)
const RANK_BOOKS = { "185:225": 16072, "129:225": 16084, [FISHING + ":225"]: 16083 };
const TRAINER_CLASS_SKILL = 40; // Poisons: the rogue class skill; its recipes are abilities a rogue trainer teaches

// ---------------------------------------------------------------------------------------------------------------------------------
// Sources
// ---------------------------------------------------------------------------------------------------------------------------------
// -- client tables
const sla = table("SkillLineAbility").filter((r) => SKILLS.has(Number(r.SkillLine)));
const spellName = new Map(table("SpellName").map((r) => [Number(r.ID), r.Name_lang]));
const reagentRows = new Map(table("SpellReagents").map((r) => [Number(r.SpellID), r]));
const creates = new Map(), learnTrigger = new Map();
for (const e of table("SpellEffect")) {
    if (e.DifficultyID !== "0") continue;
    const spell = Number(e.SpellID);
    if (e.Effect === "24" && !creates.has(spell)) {
        const base = Number(e.EffectBasePoints), die = Math.max(1, Number(e.EffectDieSides));
        creates.set(spell, { item: Number(e.EffectItemType), min: base + 1, max: base + die });
    }
    if (e.Effect === "36") learnTrigger.set(spell, Number(e.EffectTriggerSpell));
}
const sparse = new Map(table("ItemSparse").map((r) => [Number(r.ID), r]));
// the items that teach a spell (a recipe, or a rank): an item whose use is a spell that learns it
const teachers = new Map();
for (const e of table("ItemEffect")) {
    const itemId = Number(e.ParentItemID), spell = Number(e.SpellID);
    // (Classic Era: the use is a spell that learns the recipe; TBC Anniversary also lists, with trigger type 6, the recipe itself)
    const taught = learnTrigger.get(spell) ?? (e.TriggerType === "6" ? spell : undefined);
    if (!taught || !sparse.get(itemId)?.Display_lang) continue;
    if (!teachers.has(taught)) teachers.set(taught, []);
    if (!teachers.get(taught).includes(itemId)) teachers.get(taught).push(itemId);
}

// -- CMaNGOS
const LOOT = ["entry", "item", "ChanceOrQuestChance", "groupid", "mincountOrRef"];
const TRAIN = ["entry", "spell", "spellcost", "reqskill", "reqskillvalue", "reqlevel"];
const cm = await readTables(join(CACHE, "cmangos", `${FLAVOR.cmangos}.sql.gz`), {
    npc_trainer: TRAIN, npc_trainer_template: TRAIN,
    creature_template: ["Entry", "MinLevel", "MaxLevel", "LootId", "SkinningLootId", "TrainerTemplateId"],
    creature_loot_template: LOOT, skinning_loot_template: LOOT, fishing_loot_template: LOOT,
    quest_template: ["entry", "RewSpell", "RewSpellCast"],
});
// who trains which spell: spell -> [{ npc, cost, skill (the skill it is learned at), level }]
const creatureOfTemplate = new Map(); // trainer template -> creatures that use it
for (const c of cm.creature_template) {
    if (!c[5]) continue;
    if (!creatureOfTemplate.has(c[5])) creatureOfTemplate.set(c[5], []);
    creatureOfTemplate.get(c[5]).push(c[0]);
}
const trainedBy = new Map();
const addTrained = (npc, row) => {
    const spellId = learnTrigger.get(row[1]) ?? row[1];
    if (!trainedBy.has(spellId)) trainedBy.set(spellId, []);
    trainedBy.get(spellId).push({ npc, cost: row[2], skill: row[4], level: row[5] });
};
for (const row of cm.npc_trainer) addTrained(row[0], row);
for (const row of cm.npc_trainer_template) for (const npc of creatureOfTemplate.get(row[0]) ?? []) addTrained(npc, row);

// the chance (1/100 of a percent) of each wanted item in each entry of a loot table: Map(entry -> Map(item -> pm)).
// A group with chances of 0 shares what the others leave; references to other tables are not followed.
function lootChances(rows, wanted) {
    const byEntry = new Map();
    for (const row of rows) {
        if (row[4] < 0) continue;
        if (!byEntry.has(row[0])) byEntry.set(row[0], []);
        byEntry.get(row[0]).push(row);
    }
    const found = new Map();
    for (const [entry, list] of byEntry) {
        if (!list.some((r) => wanted.has(r[1]))) continue;
        const groups = new Map();
        for (const r of list) {
            if (!groups.has(r[3])) groups.set(r[3], []);
            groups.get(r[3]).push(r);
        }
        const items = new Map();
        for (const [group, members] of groups) {
            let share = 0;
            if (group > 0) {
                const fixed = members.reduce((a, r) => a + Math.abs(r[2]), 0);
                const zeros = members.filter((r) => r[2] === 0).length;
                share = zeros ? Math.max(0, 100 - fixed) / zeros : 0;
            }
            for (const r of members) {
                const pm = Math.min(10000, Math.round((Math.abs(r[2]) || share) * 100));
                if (wanted.has(r[1]) && pm > (items.get(r[1]) ?? 0)) items.set(r[1], pm);
            }
        }
        found.set(entry, items);
    }
    return found;
}

// Forever's data, for the skill a recipe is learned at when nothing else says
const forever = foreverFile && existsSync(foreverFile) ? parseData(readFileSync(foreverFile, "utf8")) : null;
const foreverRequired = (spell) => {
    const r = forever?.recipes?.[spell];
    return r && r.k?.includes(6) ? (r.l ?? r.c?.[0]) : undefined;
};

// -- Questie helpers
const raceSide = (mask) => {
    if (!mask || mask === FLAVOR.races.all) return undefined;
    const a = (mask & FLAVOR.races.alliance) !== 0, h = (mask & FLAVOR.races.horde) !== 0;
    return a && !h ? "A" : h && !a ? "H" : undefined;
};
const sideOf = (x) => (x === "A" ? "A" : x === "H" ? "H" : undefined); // Questie: "A", "H" or "AH"

// ---------------------------------------------------------------------------------------------------------------------------------
// Recipes and what they need
// ---------------------------------------------------------------------------------------------------------------------------------
const recipes = {};
for (const r of sla) {
    const spell = Number(r.Spell);
    if (recipes[spell]) continue;
    const name = spellName.get(spell);
    const rr = reagentRows.get(spell);
    const m = [];
    if (rr) for (let i = 0; i < 8; i++) if (Number(rr[`Reagent_${i}`]) > 0) m.push([Number(rr[`Reagent_${i}`]), Number(rr[`ReagentCount_${i}`])]);
    const made = creates.get(spell);
    // the skill's own ranks (Journeyman...) and Disenchant make nothing and use nothing: not recipes
    if (!name || JUNK.test(name) || (!m.length && !made)) continue;
    recipes[spell] = {
        s: Number(r.SkillLine), n: name, auto: r.AcquireMethod === "1",
        min: Number(r.MinSkillLineRank), low: Number(r.TrivialSkillLineRankLow), high: Number(r.TrivialSkillLineRankHigh),
        m: m.length ? m : undefined,
        p: made ? [made.item, made.min, made.max] : undefined,
    };
}

const npcIds = new Set(), questIds = new Set(), objectIds = new Set();
const itemIds = new Set(), reagentIds = new Set();
for (const [spell, rec] of Object.entries(recipes)) {
    for (const i of teachers.get(Number(spell)) ?? []) itemIds.add(i);
    for (const [id] of rec.m ?? []) reagentIds.add(id);
}
// the books of the ranks
const rankBooks = new Set();
const booksOfRank = (skill, cap, spell) => {
    const found = teachers.get(spell) ?? [];
    const fallback = RANK_BOOKS[skill + ":" + cap];
    return found.length || fallback === undefined || !sparse.get(fallback)?.Display_lang ? found : [fallback];
};
for (const [skill, cap, spell] of RANKS) for (const i of booksOfRank(skill, cap, spell)) rankBooks.add(i);

// -- drops, skinning and fishing from CMaNGOS
const wantedItems = new Set([...itemIds, ...reagentIds]);
const creatureLoot = lootChances(cm.creature_loot_template, wantedItems);
const skinLoot = lootChances(cm.skinning_loot_template, reagentIds);
const fishLoot = lootChances(cm.fishing_loot_template, reagentIds);
const creaturesByLoot = (field) => {
    const map = new Map();
    for (const c of cm.creature_template) {
        const loot = c[field];
        if (!loot) continue;
        if (!map.has(loot)) map.set(loot, []);
        map.get(loot).push({ id: c[0], lo: c[1], hi: c[2] });
    }
    return map;
};
const bodiesOfLoot = creaturesByLoot(3), skinsOfLoot = creaturesByLoot(4);
// the creatures that have `item` in their loot (or skinning loot), likeliest first
function creaturesWith(item, lootByEntry, bodies) {
    const found = new Map();
    for (const [entry, items] of lootByEntry) {
        const pm = items.get(item);
        if (!pm) continue;
        for (const c of bodies.get(entry) ?? []) {
            if (pm > (found.get(c.id)?.pm ?? 0)) found.set(c.id, { ...c, pm });
        }
    }
    return [...found.values()].sort((a, b) => b.pm - a.pm || a.id - b.id);
}

// -- the items that teach recipes, with what Questie knows of where they come from
const items = {};
const dropsOfItem = new Map();
for (const id of [...itemIds, ...rankBooks].sort((a, b) => a - b)) {
    const sp = sparse.get(id);
    const q = qItem(id);
    const rec = {
        n: sp.Display_lang, q: Number(sp.OverallQualityID), r: Number(sp.RequiredSkillRank) || undefined, lv: Number(sp.ItemLevel),
        buy: Number(sp.BuyPrice) || undefined,
        v: q?.[14]?.length ? [...q[14]] : undefined, d: q?.[2]?.length ? [...q[2]] : undefined,
        qs: q?.[6]?.length ? [...q[6]] : undefined, o: q?.[3]?.length ? [...q[3]] : undefined,
    };
    items[id] = rec;
    // an item with other sources is not asked for its droppers (the lists are long and unordered)
    if (rec.v || rec.qs || rec.o) { rec.d = undefined; continue; }
    const withChance = creaturesWith(id, creatureLoot, bodiesOfLoot);
    if (withChance.length) {
        // CMaNGOS knows the chances: the likeliest creatures
        rec.dn = Math.max(withChance.length, rec.d?.length ?? 0);
        rec.d = withChance.slice(0, 6).map((c) => c.id);
        dropsOfItem.set(id, new Map(withChance.map((c) => [c.id, c.pm])));
    } else if (rec.d) {
        // Questie's droppers, the few nearest in level
        rec.dn = rec.d.length;
        rec.d = rec.d
            .map((n) => ({ n, gap: Math.abs((qNpc(n)?.[5] ?? 0) - rec.lv) }))
            .filter((x) => qNpc(x.n))
            .sort((a, b) => a.gap - b.gap || a.n - b.n).slice(0, 6).map((x) => x.n);
        if (!rec.d.length) { rec.d = undefined; rec.dn = undefined; }
    }
}
for (const rec of Object.values(items)) {
    for (const n of rec.v ?? []) npcIds.add(n);
    for (const n of rec.d ?? []) npcIds.add(n);
    for (const qq of rec.qs ?? []) questIds.add(qq);
    for (const o of rec.o ?? []) objectIds.add(o);
}

// -- ingredients: who sells them, the creatures that drop them or are skinned for them, where they are fished, the nodes
const reagentRecs = {};
const MIN_DROP_PM = 100; // 1 %
for (const id of [...reagentIds].sort((a, b) => a - b)) {
    const q = qItem(id);
    const rec = {};
    if (q?.[14]?.length && q[14].length <= 15) { rec.vendors = [...q[14]]; for (const n of rec.vendors) npcIds.add(n); }
    const drops = creaturesWith(id, creatureLoot, bodiesOfLoot).filter((c) => c.pm >= MIN_DROP_PM).slice(0, 8);
    if (drops.length) rec.drops = drops;
    else if (q?.[2]?.length && q[2].length <= 12) rec.drops = q[2].map((n) => ({ id: n }));
    const skins = creaturesWith(id, skinLoot, skinsOfLoot).filter((c) => c.pm >= MIN_DROP_PM).slice(0, 8);
    if (skins.length) rec.skins = skins;
    for (const c of [...(rec.drops ?? []), ...(rec.skins ?? [])]) npcIds.add(c.id);
    const fished = [...fishLoot].map(([area, found]) => ({ z: area, pm: found.get(id) })).filter((f) => f.pm >= MIN_DROP_PM)
        .sort((a, b) => b.pm - a.pm).slice(0, 6);
    if (fished.length) rec.fished = fished;
    if (q?.[3]?.length) { rec.nodes = [...q[3]]; for (const o of rec.nodes) objectIds.add(o); }
    if (Object.keys(rec).length) reagentRecs[id] = rec;
}

// -- trainers: the NPCs CMaNGOS has teach a recipe of the skill (and, for Poisons and Fishing, Questie's by title)
const recipeSkill = new Map(Object.entries(recipes).map(([spell, r]) => [Number(spell), r.s]));
const trainers = {};
for (const [spell, list] of trainedBy) {
    const skill = recipeSkill.get(spell);
    if (!skill) continue;
    for (const t of list) (trainers[skill] ??= new Set()).add(t.npc);
}
for (const id of allIds("Npc")) {
    const n = qNpc(id);
    if (!n || !(n[15] & FLAG_TRAINER)) continue;
    for (const [skill, re] of Object.entries(TRAINER_TITLE)) {
        if (re.test(n[14] ?? "")) (trainers[skill] ??= new Set()).add(id);
    }
}
for (const set of Object.values(trainers)) for (const id of set) npcIds.add(id);

// -- the ranks that are a book or a quest
const rankQuests = {};
for (const [skill, cap, spell] of RANKS) {
    rankQuests[`${skill}:${cap}`] = cm.quest_template.filter((q) => q[1] === spell || q[2] === spell).map((q) => q[0]);
    for (const id of rankQuests[`${skill}:${cap}`]) questIds.add(id);
}

// -- quests: name, level, side and who gives them
const quests = {};
for (const id of [...questIds].sort((a, b) => a - b)) {
    const qq = qQuest(id);
    if (!qq) continue;
    const givers = qq[2]?.[0] ?? [];
    quests[id] = { n: qq[1], lv: qq[5], f: raceSide(qq[6]), g: givers.length ? [...givers] : undefined };
    for (const g of givers) npcIds.add(g);
}

// -- NPCs and objects with where they are
const area2map = new Map();
for (const m of readFileSync(join(tocDir, "support", "Zones", "areaIdToUiMapId.lua"), "utf8").matchAll(/\[(\d+)\]\s*=\s*(\d+)/g)) area2map.set(Number(m[1]), Number(m[2]));
// the spot of the zone Questie lists first with a map, rounded like the rest of the data (one decimal)
const spotOf = (spawns) => {
    for (const [area, list] of Object.entries(keyed(spawns))) {
        const map = area2map.get(Number(area));
        const at = list?.find(([x, y]) => x >= 0 && y >= 0); // (-1, -1 is an instance spawn with no point on the map)
        if (!map || !at) continue;
        return [map, Math.round(at[0] * 10) / 10, Math.round(at[1] * 10) / 10];
    }
    return undefined;
};
const npcs = {};
for (const id of [...npcIds].sort((a, b) => a - b)) {
    const n = qNpc(id);
    if (!n || !n[1] || JUNK.test(n[1])) continue;
    const zones = Object.keys(keyed(n[7])).map(Number).slice(0, 2);
    npcs[id] = {
        n: n[1], lv: [n[4], n[5]], t: n[14] || undefined,
        z: zones.length ? zones : (n[9] ? [n[9]] : undefined),
        f: sideOf(n[13]), p: spotOf(n[7]),
    };
}
const objects = {};
for (const id of objectIds) {
    const o = qObject(id);
    if (o?.[1]) objects[id] = { n: o[1], z: Object.keys(keyed(o[4])).map(Number).slice(0, 3) };
}

// ---------------------------------------------------------------------------------------------------------------------------------
// The data file
// ---------------------------------------------------------------------------------------------------------------------------------
const has = (list) => Array.isArray(list) && list.length > 0;
const zonesOf = (n, count = 3) => (has(n?.z) ? n.z.slice(0, count) : undefined);
const vendorEntry = (id, price) => ({ id: Number(id), n: npcs[id].n, z: zonesOf(npcs[id]), g: price, f: npcs[id].f });
const dropEntry = (id, pm) => ({ id: Number(id), n: npcs[id].n, z: zonesOf(npcs[id]), lo: npcs[id].lv?.[0] || undefined, hi: npcs[id].lv?.[1] || undefined, pm });
const giverEntry = (id) => ({ id: Number(id), n: npcs[id].n, z: has(npcs[id].z) ? [npcs[id].z[0]] : undefined });
const questEntry = (id) => {
    const q = quests[id];
    return { id: Number(id), n: q.n, lv: q.lv || undefined, f: q.f, g: has(q.g) ? q.g.filter((g) => npcs[g]).slice(0, 3).map(giverEntry) : undefined };
};
const objectEntry = (id) => ({ id: Number(id), n: objects[id].n, z: has(objects[id].z) ? objects[id].z : undefined });

// the record of an item as the data has it
const dataItems = {};
const CODE = { v: 5, d: 2, qs: 4 };
const itemRecord = (id) => {
    if (dataItems[id]) return dataItems[id];
    const o = items[id];
    const it = { n: o.n, q: o.q, r: o.r, lv: o.lv };
    const k = new Set();
    const chances = dropsOfItem.get(id);
    const lists = {
        v: (o.v ?? []).filter((n) => npcs[n]).slice(0, 8).map((n) => vendorEntry(n, o.buy)),
        d: (o.d ?? []).filter((n) => npcs[n]).map((n) => dropEntry(n, chances?.get(n))),
        qs: (o.qs ?? []).filter((n) => quests[n]).slice(0, 5).map(questEntry),
        o: (o.o ?? []).filter((n) => objects[n]).slice(0, 5).map(objectEntry),
    };
    for (const [key, list] of Object.entries(lists)) {
        if (!list.length) continue;
        it[key] = list;
        if (CODE[key]) k.add(CODE[key]);
    }
    if (it.d && o.dn) it.dn = o.dn;
    if (k.size) it.k = [...k].sort((a, b) => a - b);
    dataItems[id] = it;
    return it;
};
const hasSources = (it) => has(it.v) || has(it.d) || has(it.qs);

// The trainers of a spell that are real NPCs: CMaNGOS keeps some trainer spells on test creatures named [UNUSED], and Questie has none of them
const realTrainers = (spell) => {
    const list = (trainedBy.get(spell) ?? []).filter((x) => npcs[x.npc] && has(npcs[x.npc].z));
    return list.length ? list : undefined;
};

const outRecipes = {};
const stats = { trainer: 0, starter: 0, item: 0, itemNoSource: 0, noSource: 0, requiredFromTrainer: 0, requiredFromTable: 0, requiredFromForever: 0, requiredGuessed: 0, costs: 0 };
for (const [spell, r] of Object.entries(recipes)) {
    const rec = { s: r.s, n: r.n, p: r.p, m: r.m };
    const trained = realTrainers(Number(spell));
    const codes = new Set();
    // the teaching item: one with a source Questie knows, else the first
    const candidates = teachers.get(Number(spell)) ?? [];
    let teacher;
    for (const id of candidates) if (hasSources(itemRecord(id))) { teacher = id; break; }
    teacher ??= candidates[0];
    let required;
    if (teacher !== undefined) {
        rec.i = teacher;
        const it = itemRecord(teacher);
        required = it.r || (r.min > 1 ? r.min : undefined);
        if (!hasSources(it) && !has(it.o)) stats.itemNoSource++;
        stats.item++;
    }
    if (trained) {
        codes.add(6);
        stats.trainer++;
        const cost = Math.min(...trained.map((t) => t.cost).filter((c) => c > 0));
        if (Number.isFinite(cost)) { rec.g = cost; stats.costs++; }
        const skill = Math.min(...trained.map((t) => t.skill).filter((s) => s > 0));
        if (Number.isFinite(skill)) { required = skill; stats.requiredFromTrainer++; }
    } else if (r.s === TRAINER_CLASS_SKILL) {
        codes.add(6);
        stats.trainer++;
    } else if (teacher === undefined) {
        if (r.auto) stats.starter++;
        else stats.noSource++;
    }
    if (required === undefined) {
        if (r.auto && !codes.has(6)) required = Math.max(1, r.min);
        else if (r.min > 1) { required = r.min; stats.requiredFromTable++; }
        else if (foreverRequired(Number(spell)) !== undefined) { required = foreverRequired(Number(spell)); stats.requiredFromForever++; }
        else { required = Math.max(1, r.low - 20); stats.requiredGuessed++; }
    }
    if (codes.size) rec.k = [...codes];
    if (r.high > 0) {
        // (the table has a few where the yellow level is above the grey one)
        const low = Math.min(r.low, r.high), high = Math.max(r.low, r.high);
        required = Math.min(required, low);
        // (the four levels: where it turns orange, yellow, green and grey; the skill it is learned at is the first)
        rec.c = [required, low, Math.round((low + high) / 2), high];
    }
    outRecipes[spell] = rec;
}

// ingredients
const outReagents = {};
const made = new Map(); // item -> recipes that make it
for (const [spell, rec] of Object.entries(outRecipes)) {
    if (rec.p) {
        if (!made.has(rec.p[0])) made.set(rec.p[0], []);
        made.get(rec.p[0]).push({ s: rec.s, n: rec.n, i: Number(spell) });
    }
}
for (const id of reagentIds) {
    const o = reagentRecs[id];
    const rec = {};
    if (o?.vendors) {
        const price = Number(sparse.get(id)?.BuyPrice) || undefined;
        const v = o.vendors.filter((n) => npcs[n]).sort((a, b) => (npcs[b].p ? 1 : 0) - (npcs[a].p ? 1 : 0) || a - b).slice(0, 6).map((n) => vendorEntry(n, price));
        if (v.length) rec.v = v;
    }
    const creatures = (list) => list.filter((c) => npcs[c.id]).map((c) => dropEntry(c.id, c.pm));
    if (o?.drops) { const d = creatures(o.drops); if (d.length) rec.d = d; }
    if (o?.skins) { const k = creatures(o.skins); if (k.length) rec.k = k; }
    if (o?.fished) rec.f = o.fished;
    if (o?.nodes) {
        const byName = new Map();
        for (const oid of o.nodes) {
            if (!objects[oid]) continue;
            const zones = byName.get(objects[oid].n) ?? [];
            for (const z of objects[oid].z ?? []) if (z > 0 && !zones.includes(z)) zones.push(z);
            byName.set(objects[oid].n, zones);
        }
        const g = [...byName].map(([n, z]) => ({ n, z: z.slice(0, 4) }));
        if (g.length) rec.g = g;
    }
    if (made.has(id)) rec.c = made.get(id).slice(0, 4);
    if (Object.keys(rec).length) outReagents[id] = rec;
}

// trainers
const outTrainers = {};
for (const [skill, ids] of Object.entries(trainers)) {
    const list = [];
    for (const id of ids) {
        const n = npcs[id];
        if (!n || !has(n.z)) continue; // (no spawn: a test NPC)
        list.push({ id: Number(id), n: n.n, t: n.t, z: zonesOf(n, 2), lv: n.lv?.[0] || undefined, f: n.f });
    }
    list.sort((a, b) => (a.lv ?? 0) - (b.lv ?? 0) || a.n.localeCompare(b.n));
    if (list.length) outTrainers[skill] = list;
}

// which of a skill's trainers teach each recipe (`t`), when not all of them do: the NPCs of the skill's trainer list that CMaNGOS has teach it
for (const [spell, rec] of Object.entries(outRecipes)) {
    const teaching = realTrainers(Number(spell));
    const all = outTrainers[rec.s];
    if (!teaching || !all) continue;
    const listed = new Set(all.map((t) => t.id));
    const ids = [...new Set(teaching.map((x) => x.npc))].filter((id) => listed.has(id)).sort((x, y) => x - y);
    if (ids.length < all.length) rec.t = ids;
}

// the ranks of a book or a quest: ranks[skill][cap] = { b = books with their vendors, q = quests with their givers }
const outRanks = {};
for (const [skill, cap, spell] of RANKS) {
    const rec = { b: [], q: [] };
    for (const book of booksOfRank(skill, cap, spell)) {
        const price = Number(sparse.get(book)?.BuyPrice) || undefined;
        const vendors = (items[book]?.v ?? []).filter((n) => npcs[n]).slice(0, 8).map((n) => vendorEntry(n, price));
        if (vendors.length) rec.b.push({ i: book, n: sparse.get(book).Display_lang, v: vendors });
    }
    for (const id of rankQuests[`${skill}:${cap}`]) if (quests[id]) rec.q.push(questEntry(id));
    for (const key of ["b", "q"]) if (!rec[key].length) rec[key] = undefined;
    if (rec.b || rec.q) (outRanks[skill] ??= {})[cap] = rec;
}

// where the NPCs of the data stand
const wanted = new Set();
for (const it of Object.values(dataItems)) {
    for (const e of [...(it.v ?? []), ...(it.d ?? [])]) wanted.add(e.id);
    for (const q of it.qs ?? []) for (const g of q.g ?? []) wanted.add(g.id);
}
for (const list of Object.values(outTrainers)) for (const t of list) wanted.add(t.id);
for (const rec of Object.values(outReagents)) for (const e of [...(rec.v ?? []), ...(rec.d ?? []), ...(rec.k ?? [])]) wanted.add(e.id);
for (const caps of Object.values(outRanks)) {
    for (const rec of Object.values(caps)) {
        for (const book of rec.b ?? []) for (const v of book.v ?? []) wanted.add(v.id);
        for (const q of rec.q ?? []) for (const g of q.g ?? []) wanted.add(g.id);
    }
}
const outNpcs = {};
for (const id of wanted) if (npcs[id]?.p) outNpcs[id] = npcs[id].p;

// only the teaching items some recipe uses (the others were looked at while choosing)
const used = new Set(Object.values(outRecipes).map((r) => r.i).filter((i) => i !== undefined));
const outItems = {};
for (const id of used) outItems[id] = itemRecord(id);

const data = { recipes: outRecipes, items: outItems, reagents: outReagents, ranks: outRanks, trainers: outTrainers, npcs: outNpcs };
const generated = new Date().toISOString().slice(0, 10);
writeFileSync(out, renderData(data, generated));
const count = (key) => Object.values(outReagents).filter((r) => r[key]).length;
const report = {
    flavor, recipes: Object.keys(outRecipes).length, items: Object.keys(outItems).length, reagents: Object.keys(outReagents).length,
    npcs: Object.keys(outNpcs).length, trainers: Object.fromEntries(Object.entries(outTrainers).map(([k, v]) => [k, v.length])),
    ranks: Object.fromEntries(Object.entries(outRanks).map(([k, v]) => [k, Object.keys(v)])), stats,
    reagentSources: { vendors: count("v"), drops: count("d"), skins: count("k"), fished: count("f"), nodes: count("g"), madeBy: count("c") },
    bySkill: Object.fromEntries(FLAVOR.skills.map((s) => [s, Object.values(outRecipes).filter((r) => r.s === s).length])),
};
if (reportFile) writeFileSync(reportFile, JSON.stringify(report, null, 2));
console.log(JSON.stringify(report));
