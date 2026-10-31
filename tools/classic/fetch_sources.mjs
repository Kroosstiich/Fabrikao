// Downloads what build_classic.mjs reads, except QuestieDB (its release zips are fetched by the workflow, or by hand):
//   * the client tables (wago.tools CSV) of the newest Classic Era and TBC Anniversary builds -> <cache>/wago/<vanilla|tbc>/<Table>.csv
//   * CMaNGOS' world databases (cmangos/classic-db and cmangos/tbc-db, Full_DB/*.sql.gz) -> <cache>/cmangos/<classic|tbc>.sql.gz
// What is already in the cache is kept (delete a file, or the folder, to download it again). One request a second to wago.tools.
//   node tools/classic/fetch_sources.mjs [--only vanilla|tbc]
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const CACHE = process.env.CLASSIC_CACHE ? resolve(process.env.CLASSIC_CACHE) : join(here, "cache");
const onlyAt = process.argv.indexOf("--only");
const only = onlyAt > 0 ? process.argv[onlyAt + 1] : undefined;

const FLAVORS = {
    vanilla: { product: "wow_classic_era", cmangos: "classic-db", file: "classic" },
    tbc: { product: "wow_anniversary", cmangos: "tbc-db", file: "tbc" },
};
const TABLES = ["SkillLineAbility", "SpellName", "SpellReagents", "SpellEffect", "ItemSparse", "ItemEffect"];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const headers = { "user-agent": "fabrikao-data-tools" };
if (process.env.GITHUB_TOKEN) headers.authorization = `Bearer ${process.env.GITHUB_TOKEN}`;

// fetch with a few retries: the sources are public and sometimes slow
async function get(url, options = {}) {
    let last;
    for (let attempt = 1; attempt <= 4; attempt++) {
        try {
            const res = await fetch(url, { headers, ...options });
            if (res.status === 200) return res;
            last = new Error(`${url}: HTTP ${res.status}`);
        } catch (error) {
            last = error;
        }
        await sleep(2000 * attempt);
    }
    throw last;
}

const builds = await (await get("https://wago.tools/api/builds")).json();
const newest = (product) => {
    const list = [].concat(builds[product] ?? []);
    list.sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)));
    return list[0]?.version;
};

for (const [flavor, info] of Object.entries(FLAVORS)) {
    if (only && only !== flavor) continue;

    const build = newest(info.product);
    if (!build) throw new Error(`no ${info.product} build on wago.tools`);
    const dir = join(CACHE, "wago", flavor);
    mkdirSync(dir, { recursive: true });
    console.log(`${flavor}: ${info.product} ${build}`);
    for (const name of TABLES) {
        const file = join(dir, `${name}.csv`);
        if (existsSync(file)) continue;
        await sleep(1000);
        const text = await (await get(`https://wago.tools/db2/${name}/csv?build=${build}`)).text();
        if (text.length < 1000 || text.startsWith("{")) throw new Error(`${flavor} ${name}: ${text.slice(0, 80)}`);
        writeFileSync(file, text);
        console.log(`  ${name}.csv: ${text.length} bytes`);
    }
    writeFileSync(join(dir, "build.txt"), build + "\n");

    const sql = join(CACHE, "cmangos", `${info.file}.sql.gz`);
    if (!existsSync(sql)) {
        mkdirSync(dirname(sql), { recursive: true });
        const listing = await (await get(`https://api.github.com/repos/cmangos/${info.cmangos}/contents/Full_DB`)).json();
        const dump = listing.find((f) => f.name.endsWith(".sql.gz"));
        if (!dump) throw new Error(`no .sql.gz in cmangos/${info.cmangos} Full_DB`);
        const bytes = Buffer.from(await (await get(dump.download_url)).arrayBuffer());
        if (bytes.length < 5_000_000) throw new Error(`${dump.name}: only ${bytes.length} bytes`);
        writeFileSync(sql, bytes);
        console.log(`  ${dump.name}: ${bytes.length} bytes`);
    }
}
console.log("done");
