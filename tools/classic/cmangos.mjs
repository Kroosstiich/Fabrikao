// Reads a few tables of a CMaNGOS world database dump (open source, GPL-3: cmangos/classic-db and cmangos/tbc-db, Full_DB/*.sql.gz,
// downloaded to cache/cmangos/classic.sql.gz and tbc.sql.gz). Only the INSERT statements of the tables asked for are parsed, and only
// the columns asked for are kept.
//   const t = await readTables(file, { npc_trainer: ["entry", "spell", "spellcost"] })   ->   { npc_trainer: [ [198, 1142, 100], ... ] }
import { createReadStream } from "node:fs";
import { createGunzip } from "node:zlib";
import { createInterface } from "node:readline";

// one INSERT statement's values: "(1,'a b',NULL,2.5),(...)" -> [[1, "a b", null, 2.5], ...]
function parseTuples(line, from) {
    const rows = [];
    let i = from;
    const n = line.length;
    while (i < n) {
        while (i < n && line[i] !== "(") { if (line[i] === ";") return rows; i++; }
        if (i >= n) break;
        i++;
        const row = [];
        for (;;) {
            const c = line[i];
            if (c === "'") {
                let s = "";
                i++;
                for (;;) {
                    const d = line[i];
                    if (d === "\\") { s += line[i + 1]; i += 2; }
                    else if (d === "'") { if (line[i + 1] === "'") { s += "'"; i += 2; } else { i++; break; } }
                    else { s += d; i++; }
                }
                row.push(s);
            } else {
                let j = i;
                while (j < n && line[j] !== "," && line[j] !== ")") j++;
                const word = line.slice(i, j);
                row.push(word === "NULL" ? null : Number(word));
                i = j;
            }
            if (line[i] === ",") { i++; continue; }
            if (line[i] === ")") { i++; break; }
            throw new Error(`bad SQL near ${line.slice(Math.max(0, i - 20), i + 20)}`);
        }
        rows.push(row);
        if (line[i] === ",") i++;
    }
    return rows;
}

export async function readTables(file, wanted) {
    const out = Object.fromEntries(Object.keys(wanted).map((t) => [t, []]));
    const columns = {}; // table -> all its column names, from CREATE TABLE
    let creating = null;
    const rl = createInterface({ input: createReadStream(file).pipe(createGunzip()), crlfDelay: Infinity });
    for await (const line of rl) {
        if (creating) {
            const m = /^\s+`([^`]+)`/.exec(line);
            if (m) columns[creating].push(m[1]);
            else if (line.startsWith(")")) creating = null;
            continue;
        }
        if (line.startsWith("CREATE TABLE `")) {
            const name = /^CREATE TABLE `([^`]+)`/.exec(line)[1];
            if (wanted[name]) { creating = name; columns[name] = []; }
            continue;
        }
        if (line.startsWith("INSERT INTO `")) {
            const m = /^INSERT INTO `([^`]+)`(?: \([^)]*\))? VALUES /.exec(line);
            if (!m || !wanted[m[1]]) continue;
            const all = columns[m[1]];
            const keep = wanted[m[1]].map((c) => {
                const at = all.findIndex((x) => x.toLowerCase() === c.toLowerCase());
                if (at < 0) throw new Error(`${m[1]} has no column ${c} (${all.join(", ")})`);
                return at;
            });
            for (const row of parseTuples(line, m[0].length)) out[m[1]].push(keep.map((at) => row[at]));
        }
    }
    return out;
}
