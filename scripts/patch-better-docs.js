/**
 * Patches better-docs publish.js to:
 * 1. Order categories: Elements, Utilities, Internal (instead of alphabetical)
 * 2. Move Global section to the end of the sidebar
 *
 * Run automatically via npm postinstall, or manually with: node scripts/patch-better-docs.js
 */
const fs = require('fs');
const path = require('path');

const publishPath = path.join(__dirname, '..', 'node_modules', 'better-docs', 'publish.js');

if (!fs.existsSync(publishPath)) {
  console.log('better-docs not installed, skipping patch');
  process.exit(0);
}

let src = fs.readFileSync(publishPath, 'utf8');

const original = `  nav += buildGroupNav(rootScope)
  Object.keys(categorised).sort().forEach(function (category) {
    nav += buildGroupNav(categorised[category], category)
  })`;

const patched = `  var categoryOrder = ['Elements', 'Utilities', 'Internal']
  Object.keys(categorised).sort(function(a, b) {
    var ai = categoryOrder.indexOf(a)
    var bi = categoryOrder.indexOf(b)
    if (ai === -1) ai = categoryOrder.length
    if (bi === -1) bi = categoryOrder.length
    return ai - bi
  }).forEach(function (category) {
    nav += buildGroupNav(categorised[category], category)
  })
  nav += buildGroupNav(rootScope)`;

if (src.includes(patched)) {
  console.log('better-docs already patched');
  process.exit(0);
}

if (!src.includes(original)) {
  console.warn('WARNING: better-docs publish.js has unexpected content, skipping patch');
  process.exit(0);
}

src = src.replace(original, patched);
fs.writeFileSync(publishPath, src);
console.log('Patched better-docs sidebar category order');
