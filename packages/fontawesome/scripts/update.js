#!/usr/bin/env node
/*
 * Updates the Font Awesome package from npm.
 *
 * Usage: node packages/fontawesome/scripts/update.js [version]
 *
 * Installs @fortawesome/fontawesome-free (the latest release unless a version is given),
 * wawoff2 and fonteditor-core into a temporary folder, then:
 *   - decompresses the solid, regular and brands web fonts and converts them to TrueType
 *     outlines in content/resource/fonts of the gamemode, since the engine only loads .ttf
 *     fonts from a mounted content folder and the package ships CFF-based OpenType fonts,
 *   - reads the family name and weight of every font from its name and OS/2 tables,
 *   - regenerates lib/cl_icons.lua from metadata/icon-families.json and metadata/shims.yml,
 *     keeping the old names of renamed icons and the Font Awesome 4 names as aliases,
 *   - copies LICENSE.txt into the package and bumps the version in packagespec.lua.
 *
 * Needs Node.js 18+ and npm on the PATH. Nothing is installed into the repository.
 */
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const PACKAGE_DIR = path.resolve(__dirname, '..');
const FONTS_DIR = path.resolve(PACKAGE_DIR, '..', '..', 'content', 'resource', 'fonts');
const ICONS_FILE = path.join(PACKAGE_DIR, 'lib', 'cl_icons.lua');
const SPEC_FILE = path.join(PACKAGE_DIR, 'packagespec.lua');
const LICENSE_FILE = path.join(PACKAGE_DIR, 'LICENSE.txt');

const FONT_FILES = {
  solid: 'fa-solid-900',
  regular: 'fa-regular-400',
  brands: 'fa-brands-400',
};
const STYLE_ORDER = ['solid', 'brands', 'regular'];
const SHIM_PREFIXES = { fas: 'solid', far: 'regular', fab: 'brands' };

async function main() {
  const requested = process.argv[2] || 'latest';
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'flux-fontawesome-'));

  try {
    console.log(`Installing @fortawesome/fontawesome-free@${requested}...`);
    execFileSync(process.platform === 'win32' ? 'npm.cmd' : 'npm', [
      'install', '--prefix', tmp, '--no-audit', '--no-fund', '--no-package-lock', '--loglevel=error',
      `@fortawesome/fontawesome-free@${requested}`, 'wawoff2', 'fonteditor-core',
    ], { stdio: 'inherit' });

    const modules = path.join(tmp, 'node_modules');
    const source = path.join(modules, '@fortawesome', 'fontawesome-free');
    const wawoff2 = require(path.join(modules, 'wawoff2'));
    const { Font } = require(path.join(modules, 'fonteditor-core'));
    const version = JSON.parse(fs.readFileSync(path.join(source, 'package.json'), 'utf8')).version;

    console.log(`Font Awesome ${version}`);

    const fonts = await installFonts(source, wawoff2, Font);
    const { icons, styles, regular } = buildIcons(source);
    const date = new Date().toISOString().slice(0, 10);

    fs.writeFileSync(ICONS_FILE, renderLua({ version, date, fonts, icons, styles, regular }));
    fs.copyFileSync(path.join(source, 'LICENSE.txt'), LICENSE_FILE);
    updateSpec(version, date);

    console.log(`${Object.keys(icons).length} icons written to ${path.relative(process.cwd(), ICONS_FILE)}`);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
}

/* Converts the web fonts to TrueType in content/resource/fonts and returns their font data by style. */
async function installFonts(source, wawoff2, Font) {
  fs.mkdirSync(FONTS_DIR, { recursive: true });

  for (const name of fs.readdirSync(FONTS_DIR)) {
    if (/^fa-.*\.(ttf|otf)$/.test(name)) fs.unlinkSync(path.join(FONTS_DIR, name));
  }

  const fonts = {};

  for (const [style, base] of Object.entries(FONT_FILES)) {
    const woff2 = fs.readFileSync(path.join(source, 'webfonts', `${base}.woff2`));
    const sfnt = toTrueType(Buffer.from(await wawoff2.decompress(woff2)), Font);
    const fileName = `${base}.ttf`;
    const names = readNames(sfnt);

    fs.writeFileSync(path.join(FONTS_DIR, fileName), sfnt);

    fonts[style] = {
      family: names[1] || names[4],
      weight: readWeight(sfnt),
      file_name: fileName,
    };

    console.log(`${fileName}: '${fonts[style].family}' (weight ${fonts[style].weight})`);
  }

  return fonts;
}

/* Returns a TrueType-flavoured copy of a font, converting CFF outlines to quadratic ones. */
function toTrueType(sfnt, Font) {
  if (sfnt.toString('ascii', 0, 4) !== 'OTTO') return sfnt;

  const font = Font.create(sfnt, { type: 'otf', hinting: false });

  return Buffer.from(font.write({ type: 'ttf', hinting: false }));
}

/* Returns the table directory of an sfnt font as a map of tag to [offset, length]. */
function readTables(sfnt) {
  const count = sfnt.readUInt16BE(4);
  const tables = {};

  for (let i = 0; i < count; i++) {
    const record = 12 + i * 16;
    tables[sfnt.toString('ascii', record, record + 4)] = [sfnt.readUInt32BE(record + 8), sfnt.readUInt32BE(record + 12)];
  }

  return tables;
}

/* Reads the name table and returns the English strings by name ID, preferring Windows ones. */
function readNames(sfnt) {
  const [offset] = readTables(sfnt).name;
  const count = sfnt.readUInt16BE(offset + 2);
  const strings = offset + sfnt.readUInt16BE(offset + 4);
  const names = {};
  const ranks = {};

  for (let i = 0; i < count; i++) {
    const record = offset + 6 + i * 12;
    const platform = sfnt.readUInt16BE(record);
    const encoding = sfnt.readUInt16BE(record + 2);
    const language = sfnt.readUInt16BE(record + 4);
    const id = sfnt.readUInt16BE(record + 6);
    const length = sfnt.readUInt16BE(record + 8);
    const start = strings + sfnt.readUInt16BE(record + 10);
    const bytes = sfnt.subarray(start, start + length);
    let rank;
    let text;

    if (platform === 3 && (encoding === 1 || encoding === 0)) {
      rank = language === 0x409 ? 3 : 2;
      text = Buffer.from(bytes).swap16().toString('utf16le');
    } else if (platform === 1 && encoding === 0) {
      rank = 1;
      text = bytes.toString('latin1');
    } else {
      continue;
    }

    if ((ranks[id] || 0) < rank) {
      ranks[id] = rank;
      names[id] = text;
    }
  }

  return names;
}

/* Reads usWeightClass from the OS/2 table. */
function readWeight(sfnt) {
  const table = readTables(sfnt)['OS/2'];
  return table ? sfnt.readUInt16BE(table[0] + 4) : 400;
}

/* Builds the icon tables from the metadata of the npm package. */
function buildIcons(source) {
  const families = JSON.parse(fs.readFileSync(path.join(source, 'metadata', 'icon-families.json'), 'utf8'));
  const shims = parseShims(fs.readFileSync(path.join(source, 'metadata', 'shims.yml'), 'utf8'));
  const available = {};
  const icons = {};
  const styles = {};
  const regular = {};

  const add = (name, codepoint, free, style) => {
    const id = `fa-${name}`;

    if (icons[id] !== undefined) return;

    icons[id] = codepoint;
    available[id] = free;

    if (style !== 'solid') styles[id] = style;
    if (free.includes('regular')) regular[id] = true;
  };

  const entries = Object.entries(families).map(([name, icon]) => {
    const free = (icon.familyStylesByLicense?.free || [])
      .filter((entry) => entry.family === 'classic')
      .map((entry) => entry.style);

    return { name, icon, free, codepoint: parseInt(icon.unicode, 16), style: STYLE_ORDER.find((s) => free.includes(s)) };
  }).filter((entry) => entry.style);

  for (const entry of entries) add(entry.name, entry.codepoint, entry.free, entry.style);

  for (const entry of entries) {
    for (const alias of entry.icon.aliases?.names || []) add(alias, entry.codepoint, entry.free, entry.style);
  }

  for (const [old, shim] of Object.entries(shims)) {
    const target = `fa-${shim.name || old}`;

    if (icons[target] === undefined) continue;

    const wanted = SHIM_PREFIXES[shim.prefix];
    const style = wanted && available[target].includes(wanted) ? wanted : styles[target] || 'solid';

    add(old, icons[target], available[target], style);
  }

  return { icons, styles, regular };
}

/* Parses shims.yml, a two-level mapping of old names to { name, prefix }. */
function parseShims(text) {
  const shims = {};
  let current = null;

  for (const line of text.split('\n')) {
    const top = line.match(/^(\S.*?):\s*$/);

    if (top) {
      current = shims[unquote(top[1])] = {};
      continue;
    }

    const field = line.match(/^\s+(\w+):\s*(.+?)\s*$/);

    if (field && current) current[field[1]] = unquote(field[2]);
  }

  return shims;
}

function unquote(value) {
  return value.replace(/^'(.*)'$/, '$1').replace(/^"(.*)"$/, '$1');
}

function luaString(value) {
  return `'${String(value).replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`;
}

/* Renders a Lua table literal with aligned, sorted string keys. */
function luaMap(map, render, indent) {
  const keys = Object.keys(map).sort();

  if (keys.length === 0) return '{}';

  const width = Math.max(...keys.map((key) => luaString(key).length));
  const pad = ' '.repeat(indent);
  const lines = keys.map((key) => `${pad}  [${luaString(key)}]${' '.repeat(width - luaString(key).length)} = ${render(map[key])}`);

  return `{\n${lines.join(',\n')}\n${pad}}`;
}

function renderLua({ version, date, fonts, icons, styles, regular }) {
  const fontLines = STYLE_ORDER.map((style) => {
    const font = fonts[style];
    return `    ${style.padEnd(7)} = { family = ${luaString(font.family)}, weight = ${font.weight}, file_name = ${luaString(font.file_name)} }`;
  });

  return [
    `--- Icon data of Font Awesome Free ${version}, generated by \`scripts/update.js\` on ${date}.`,
    '-- Do not edit by hand: run the script again to update Font Awesome instead.',
    "-- Lists every icon of the Free set under its name with the 'fa-' prefix, along with the old",
    '-- names of icons that were renamed and the Font Awesome 4 names, and hands the data to',
    '-- `FontAwesome.load`. The codepoints are the ones of the fonts in `content/resource/fonts`.',
    '',
    'FontAwesome.load({',
    `  version = ${luaString(version)},`,
    '  fonts = {',
    fontLines.join(',\n'),
    '  },',
    `  icons = ${luaMap(icons, (codepoint) => `0x${codepoint.toString(16)}`, 2)},`,
    `  styles = ${luaMap(styles, luaString, 2)},`,
    `  regular = ${luaMap(regular, () => 'true', 2)}`,
    '})',
    '',
  ].join('\n');
}

function updateSpec(version, date) {
  const spec = fs.readFileSync(SPEC_FILE, 'utf8')
    .replace(/(s\.version\s*=\s*)'[^']*'/, `$1'${version}'`)
    .replace(/(s\.date\s*=\s*)'[^']*'/, `$1'${date}'`);

  fs.writeFileSync(SPEC_FILE, spec);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
