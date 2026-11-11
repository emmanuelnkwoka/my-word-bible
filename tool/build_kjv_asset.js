// Converts a public-domain KJV JSON source into MWB's compact asset format.
// Usage: node tool/build_kjv_asset.js <source en_kjv.json> assets/bible/kjv.json
const fs = require('fs');
const ids = ['GEN','EXO','LEV','NUM','DEU','JOS','JDG','RUT','1SA','2SA','1KI','2KI','1CH','2CH','EZR','NEH','EST','JOB','PSA','PRO','ECC','SNG','ISA','JER','LAM','EZK','DAN','HOS','JOL','AMO','OBA','JON','MIC','NAM','HAB','ZEP','HAG','ZEC','MAL','MAT','MRK','LUK','JHN','ACT','ROM','1CO','2CO','GAL','EPH','PHP','COL','1TH','2TH','1TI','2TI','TIT','PHM','HEB','JAS','1PE','2PE','1JN','2JN','3JN','JUD','REV'];
const src = JSON.parse(fs.readFileSync(process.argv[2], 'utf8').replace(/^﻿/, ''));
if (src.length !== 66) throw new Error('Expected 66 books');
const out = {
  id: 'KJV',
  name: 'King James Version',
  license: 'Public domain',
  books: src.map((b, i) => ({ id: ids[i], name: b.name, testament: i < 39 ? 'OT' : 'NT', chapters: b.chapters })),
};
fs.writeFileSync(process.argv[3], JSON.stringify(out));
console.log('wrote', process.argv[3]);
