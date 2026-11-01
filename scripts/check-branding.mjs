import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
const root = new URL('../', import.meta.url);
const bytes = p => readFile(new URL(p, root));
const text = async p => (await bytes(p)).toString('utf8');
const json = async p => JSON.parse(await text(p));
const hash = b => createHash('sha256').update(b).digest('hex');
// The existing manifest was captured on Windows; Git checkout may change only line endings.
const protectedHashMatches = (data, expected) => {
    const lf = data.toString('utf8').replace(/\r\n/g,'\n');
    return [data, Buffer.from(lf), Buffer.from(lf.replace(/\n/g,'\r\n'))].some(value => hash(value) === expected);
};
const pack = 'design/branding/brand-pack/';
const assets = 'larping/Assets.xcassets/';
const tokens = (await json(pack + '04-Colours-and-type/mury-tokens.json')).themes;
const roles = {Accent:'action', OnAccent:'actionText', Tint:'selectedNavigation', Canvas:'canvas', Surface:'panel', Ink:'text', Muted:'mutedText', Border:'interactiveBorder', Navigation:'navigation', Route:'route', RouteCasing:'routeCasing'};
const luminance = rgb => rgb.map(v => v <= .04045 ? v / 12.92 : ((v + .055) / 1.055) ** 2.4).reduce((sum,v,i) => sum + v * [.2126,.7152,.0722][i],0);
const contrast = (a,b) => (Math.max(luminance(a),luminance(b))+.05)/(Math.min(luminance(a),luminance(b))+.05);
const colors = {};
for (const [role, token] of Object.entries(roles)) {
    const asset = await json(assets + 'Mury' + role + '.colorset/Contents.json');
    assert.equal(asset.colors.length, 2);
    assert.deepEqual(asset.colors[1].appearances, [{appearance:'luminosity',value:'dark'}]);
    colors[role] = asset.colors.map((entry,i) => {
        const rgb = ['red','green','blue'].map(c => Number(entry.color.components[c]) / (entry.color.components[c].startsWith('0x') ? 255 : 1));
        const expected = tokens[i ? 'dark' : 'light'][token].slice(1).match(/../g).map(c => parseInt(c,16)/255);
        rgb.forEach((v,j) => assert.ok(Math.abs(v-expected[j]) < .00001, role + ' exact pack token'));
        assert.equal(Number(entry.color.components.alpha),1);
        return rgb;
    });
}
for (const i of [0,1]) {
    assert.ok(contrast(colors.OnAccent[i],colors.Accent[i])>=4.5);
    for (const surface of ['Canvas','Surface']) for (const role of ['Ink','Muted','Tint']) assert.ok(contrast(colors[role][i],colors[surface][i])>=4.5, role+'/'+surface);
}
const fontNames = ['Rubik-Regular','Rubik-SemiBold','Rubik-Bold'];
const fontBlock = '\t<key>UIAppFonts</key>\n\t<array>\n' + fontNames.map(n => '\t\t<string>'+n+'.ttf</string>\n').join('') + '\t</array>\n';
for (const name of [...fontNames.map(n=>n+'.ttf'),'OFL.txt']) {
    assert.equal(hash(await bytes('larping/'+name)),hash(await bytes(pack+'04-Colours-and-type/fonts/'+name)),name+' supplied bytes');
}
// Verify the actual PostScript names match the names used by UIFont and SwiftUI.
for (const name of fontNames) {
    const font = await bytes('larping/'+name+'.ttf');
    const count = font.readUInt16BE(4);
    let table;
    for (let i=0;i<count;i++) {
        const at=12+i*16;
        if (font.toString('ascii',at,at+4)==='name') table=font.readUInt32BE(at+8);
    }
    assert.ok(table, 'font name table');
    const records=font.readUInt16BE(table+2), strings=table+font.readUInt16BE(table+4);
    const names=[];
    for (let i=0;i<records;i++) {
        const at=table+6+i*12;
        if (font.readUInt16BE(at+6)!==6) continue;
        const start=strings+font.readUInt16BE(at+10), length=font.readUInt16BE(at+8);
        names.push(font.readUInt16BE(at)===3 ? font.subarray(start,start+length).swap16().toString('utf16le') : font.toString('ascii',start,start+length));
    }
    assert.ok(names.includes(name),'PostScript name '+name);
}
const plist = (await text('larping/Info.plist')).replace(/\r\n/g,'\n');
assert.equal(plist.split(fontBlock).length,2,'exact registered static fonts');
for (const [file,expected] of Object.entries(await json('docs/mury-protected-files.json'))) {
    // Only the explicitly authorized UIAppFonts addition is excluded; all original plist bytes remain protected.
    const data = file === 'larping/Info.plist' ? Buffer.from(plist.replace(fontBlock,'')) : await bytes(file);
    assert.ok(protectedHashMatches(data,expected),'Protected file changed: '+file);
    const lf = data.toString('utf8').replace(/\r\n/g,'\n');
    assert.ok(protectedHashMatches(Buffer.from(lf),expected),'LF checkout: '+file);
    assert.ok(protectedHashMatches(Buffer.from(lf.replace(/\n/g,'\r\n')),expected),'CRLF checkout: '+file);
}
for (const [asset,source] of [['LogoHorizontal','red'],['LogoWhite','white'],['LogoBlueWhite','dark']]) {
    const metadata = await json(assets+asset+'.imageset/Contents.json');
    assert.equal(metadata.properties['template-rendering-intent'],'original');
    for (const entry of metadata.images) {
        const variant = entry.appearances ? 'dark' : source;
        const png = await bytes(assets+asset+'.imageset/'+entry.filename);
        assert.equal(hash(png),hash(await bytes(pack+'01-Logos/mury-horizontal-'+variant+'.png')),'original supplied logo');
        assert.equal(png[25],6,'logo transparency');
        const svg = await text(pack+'01-Logos/mury-horizontal-'+variant+'.svg');
        const fills = [...svg.matchAll(/(?:fill|stroke)="(#[0-9a-fA-F]{6})"/g)].map(m=>m[1].toUpperCase());
        assert.ok(fills.length>0);
        assert.ok(fills.every(c=>['#B20E1C','#FFFFFF','#A7D8F3'].includes(c)),'approved logo palette');
    }
}
const iconDir = assets+'AppIcon.appiconset/';
const icons = await json(iconDir+'Contents.json');
assert.equal(hash(await bytes(iconDir+'Contents.json')),hash(await bytes(pack+'03-App-icons/AppIcon.appiconset/Contents.json')));
for (const entry of icons.images) {
    const png = await bytes(iconDir+entry.filename);
    assert.equal(hash(png),hash(await bytes(pack+'03-App-icons/AppIcon.appiconset/'+entry.filename)));
    assert.equal(png.subarray(0,8).toString('hex'),'89504e470d0a1a0a');
    const dimensions = entry.size.split('x').map(Number);
    const scale = Number(entry.scale.replace('x',''));
    assert.equal(png.readUInt32BE(16),dimensions[0]*scale);
    assert.equal(png.readUInt32BE(20),dimensions[1]*scale);
    assert.equal(png[25],2,'opaque RGB icon');
}
assert.ok(protectedHashMatches(await bytes('larping/Features/Activities/ReplayTimeline.swift'),'95a17eec95aaaf128bdb2a2b129910967a4cb4bc49d715ef94864fa40c843fd6'),'Protected replay timeline');
const theme = await text('larping/Core/BrandTheme.swift');
assert.match(theme,/case mury/);
assert.match(theme,/uiColor\("Route", for: scheme\)/);
for (const role of ['navigation','route','routeCasing']) assert.match(theme,new RegExp('var '+role+': Color'));
assert.match(theme,/\["pink", "tiffany", "mury"\]\.contains/);
const app = await text('larping/larpingApp.swift');
assert.match(app,/BrandTheme.resolvePreference\(themeSelection\)/);
assert.match(app,/\.modelContainer\(for: \[CDActivity.self, CDTrackPoint.self\]\)/);
const typography = await text('larping/Core/MuryTypography.swift');
assert.match(typography,/relativeTo: style/);
const welcome = await text('larping/Features/Root/ThemeSelectionView.swift');
assert.match(welcome,/selection = BrandTheme.mury.rawValue/);
assert.match(welcome,/Move\. Explore\. Achieve\./);
assert.doesNotMatch(welcome,/\.disabled|ForEach/);
const share = await text('larping/Core/ShareImageComposer.swift');
assert.match(share,/stats.metricLabel/g);
assert.doesNotMatch(share,/logo.withTintColor/);
assert.match(share,/MuryTypography.uiFont/);
assert.match(share,/path.lineWidth = 22\s+white.setStroke\(\)\s+path.stroke\(\)\s+path.lineWidth = 14/);
const record = await text('larping/Features/Record/RecordView.swift');
assert.match(record,/stroke\(theme.routeCasing, lineWidth: 9\)/);
assert.match(record,/stroke\(theme.route, lineWidth: 5\)/);
assert.doesNotMatch(record,/stroke\(theme.accent/);
const shareView = await text('larping/Features/Activities/ShareActivityView.swift');
assert.match(shareView,/usesPaceMetric: activity.sportType.usesPaceMetric/);
assert.doesNotMatch(shareView,/pace.replacingOccurrences/);
async function scan(dir) {
    for (const entry of await readdir(new URL(dir,root),{withFileTypes:true})) {
        const p = dir+'/'+entry.name;
        if (entry.isDirectory()) await scan(p);
        else if (p.endsWith('.swift')) {
            const s = await text(p);
            assert.doesNotMatch(s,/BrandTheme\.(pink|tiffany)/,p+' obsolete theme');
            assert.doesNotMatch(s,/Image\("Logo[^"]*"\)\s*\.renderingMode\(\.template\)/,p+' tinted logo');
        }
    }
}
await scan('larping');
console.log('PASS: exact supplied tokens, text contrast, logo provenance/palette, static fonts, icon dimensions/RGB, preference gate, export labels, protected original bytes.');
