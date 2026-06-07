

'use strict';
const fs = require('fs');
const path = require('path');

function fail(msg) { process.stdout.write(JSON.stringify({ error: String(msg) })); process.exit(1); }

let E;
try { E = require(path.join(__dirname, '..', 'engine', 'engine.js')); }
catch (e) { fail('engine load failed: ' + (e && e.message || e)); }

const file = process.argv[2];
if (!file) fail('no save file argument');
let raw;
try { raw = fs.readFileSync(file, 'utf8'); } catch (e) { fail('read failed: ' + (e && e.message || e)); }

const gps = process.argv[3] != null && process.argv[3] !== '' ? Number(process.argv[3]) : undefined;

let psd, r;
try {
 psd = E.parseSave(raw);
 r = E.recommend(psd, { goldPerSec: gps, elapsedSec: 0 });
} catch (e) { fail('engine compute failed: ' + (e && e.message || e)); }

const round = n => (typeof n === 'number' && isFinite(n)) ? Math.round(n) : n;
const heroName = k => { const h = E.DB.heroes[String(k)]; return h && h.name ? (h.name['en-US'] || ('Hero ' + k)) : ('Hero ' + k); };
const stageLabel = k => { const s = E.DB.stages[String(k)]; return s ? s.label : ('#' + k); };

const cs = psd.commonSaveData || {};
const out = {
 gold: r.meta.gold,
 partyPower: round(r.heroes.reduce((a, h) => a + h.power, 0)),
 partyDPS: round(r.meta.partyDPS),
 carryHero: r.meta.carryHero,
 curStage: r.meta.currentStage,
 curStageLabel: stageLabel(r.meta.currentStage),

 maxStage: cs.maxCompletedStage != null ? Number(cs.maxCompletedStage) : null,
 party: (cs.arrangedHeroKey || []).join(','),
 pets: (psd.PetSaveData || []).filter(p => p.IsUnlock).length,
 items: (psd.itemSaveDatas || []).length,
 playTime: Math.round(cs.playTime || 0),

 firstDpsCost: r.runes.firstDpsPath ? r.runes.firstDpsPath.totalCost : null,
 firstDpsTarget: r.runes.firstDpsPath ? r.runes.firstDpsPath.target : null,
 firstDpsTargetName: r.runes.firstDpsPath ? runeName(E, r.runes.firstDpsPath.target) : null,

 almostFreeAffordable: r.runes.almostFree.filter(x => x.affordable).length,
 almostFreeKeys: r.runes.almostFree.filter(x => x.affordable).map(x => x.key),

 swaps: r.gear.swaps.map(s => ({ hero: s.heroKey, heroName: heroName(s.heroKey), gt: s.gearType, dPower: round(s.best ? s.best.dPower : 0) })),
 emptyJewelry: r.gear.emptyJewelry.length,

 idle: r.idle && r.idle.unlocked ? { fullGold: r.idle.fullGold, fullExp: r.idle.fullExp, capHours: round(r.idle.capHours) } : null,

 levels: r.level.map(l => ({ hero: l.heroKey, heroName: heroName(l.heroKey), level: l.level, ap: l.ap, expToNext: l.expToNext, etaSec: l.etaSec ? round(l.etaSec) : null })),

 survival: r.survival || null,
 partyComp: r.partyComp ? { hasFront: !!r.partyComp.hasFront, recommendTank: r.partyComp.recommendTank || null,
 recommendTankName: r.partyComp.recommendTank ? heroName(r.partyComp.recommendTank) : null } : null,
};
process.stdout.write(JSON.stringify(out));

function runeName(E, key) { const r = E.DB.runes[String(key)]; return r && r.name ? (r.name['en-US'] || ('Rune ' + key)) : ('Rune ' + key); }
