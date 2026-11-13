// RFC 4180 CSV parser for the r3 review package (quoted fields, embedded
// commas, quotes and newlines; UTF-8 BOM stripped). No dependencies.
'use strict';
function parseCsv(text) {
  text = text.replace(/^\uFEFF/, '');
  const rows = [];
  let row = [], field = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"') {
        if (text[i + 1] === '"') { field += '"'; i++; } else quoted = false;
      } else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n') { row.push(field.replace(/\r$/, '')); rows.push(row); row = []; field = ''; }
    else field += c;
  }
  if (field.length || row.length) { row.push(field.replace(/\r$/, '')); rows.push(row); }
  const header = rows.shift();
  return rows
    .filter((r) => r.length > 1 || (r.length === 1 && r[0] !== ''))
    .map((r) => {
      if (r.length !== header.length) throw new Error(`CSV row has ${r.length} fields, expected ${header.length}: ${r.slice(0, 3)}`);
      return Object.fromEntries(header.map((h, i) => [h, r[i]]));
    });
}
module.exports = { parseCsv };
