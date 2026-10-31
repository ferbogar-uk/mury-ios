import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
const root = new URL('../', import.meta.url);
const json = async p => JSON.parse(await readFile(new URL(p, root), 'utf8'));
const luminance = rgb => rgb.map(v => v <= .04045 ? v / 12.92 : ((v + .055) / 1.055) ** 2.4).reduce((sum, v, i) => sum + v * [.2126, .7152, .0722][i], 0);
const contrast = (a, b) => (Math.max(luminance(a), luminance(b)) + .05) / (Math.min(luminance(a), luminance(b)) + .05);
const reports = [];
for (const theme of ['Pink', 'Tiffany']) {
    const colors = {};
    for (const role of ['Accent', 'OnAccent', 'Tint', 'Canvas', 'Surface', 'Ink', 'Muted', 'Border']) {
        const asset = await json('larping/Assets.xcassets/' + theme + role + '.colorset/Contents.json');
        assert.equal(asset.colors.length, 2);
        colors[role] = asset.colors.map(entry => ['red', 'green', 'blue'].map(channel => {
            const raw = entry.color.components[channel];
            const value = raw.startsWith('0x') ? Number(raw) / 255 : Number(raw);
            assert.ok(Number.isFinite(value) && value >= 0 && value <= 1);
            return value;
        }));
        assert.equal(asset.colors[1].appearances[0].value, 'dark');
    }
    for (const [index, mode] of ['light', 'dark'].entries()) {
        const button = contrast(colors.OnAccent[index], colors.Accent[index]);
        assert.ok(button >= 4.5, theme + ' ' + mode + ' button contrast ' + button);
        for (const surface of ['Canvas', 'Surface']) for (const text of ['Ink', 'Muted', 'Tint']) {
            const ratio = contrast(colors[text][index], colors[surface][index]);
            assert.ok(ratio >= 4.5, theme + ' ' + mode + ' ' + text + '/' + surface + ' ' + ratio);
        }
        reports.push({theme, mode, buttonContrast:button.toFixed(2)});
    }
}
for (const [file, expected] of Object.entries(await json('docs/mury-protected-files.json'))) {
    const actual = createHash('sha256').update(await readFile(new URL(file, root))).digest('hex');
    assert.equal(actual, expected, 'Protected file changed: ' + file);
}
for (const variant of ['light', 'dark', 'tinted']) {
    const png = await readFile(new URL('larping/Assets.xcassets/AppIcon.appiconset/icon-' + variant + '.png', root));
    assert.equal(png.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    assert.equal(png.readUInt32BE(16), 1024);
    assert.equal(png.readUInt32BE(20), 1024);
    assert.equal(png[25], 2, 'AppIcon must be RGB without alpha: ' + variant);
}
const wordmark = await readFile(new URL('larping/Assets.xcassets/LogoHorizontal.imageset/logo-horizontal.png', root));
assert.equal(wordmark[25], 6, 'Wordmark must retain transparency');
console.log(JSON.stringify(reports, null, 2));
console.log('PASS: four palettes meet text contrast; icon formats valid; protected files unchanged.');
