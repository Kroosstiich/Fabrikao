// Reads a CSV as the wago.tools tables come: rows as objects keyed by column name (strings).
export function parseCsv(text) {
    const rows = [];
    let row = [], field = "", quoted = false;
    for (let i = 0; i < text.length; i++) {
        const c = text[i];
        if (quoted) {
            if (c === '"') { if (text[i + 1] === '"') { field += '"'; i++; } else quoted = false; } else field += c;
        } else if (c === '"') quoted = true;
        else if (c === ",") { row.push(field); field = ""; }
        else if (c === "\n") { row.push(field.replace(/\r$/, "")); rows.push(row); row = []; field = ""; }
        else field += c;
    }
    if (field || row.length) { row.push(field); rows.push(row); }
    const cols = rows.shift();
    return rows.filter((r) => r.length === cols.length).map((r) => {
        const o = {};
        cols.forEach((c, i) => (o[c] = r[i]));
        return o;
    });
}
