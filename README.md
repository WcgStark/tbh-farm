# TBH Farm

A farm optimizer for the idle-RPG [TBH: Task Bar Hero](https://store.steampowered.com/app/3678970/TBH_Task_Bar_Hero/).

Fork of [shigake/tbh-copilot](https://github.com/shigake/tbh-copilot) — the original is a full in-browser dashboard with farm, runes, gear and more. This fork is focused on farming only: a desktop app that opens on its own, finds your save automatically, and shows you where to farm.

> Unofficial fan project. Not affiliated with or endorsed by the developers of TBH: Task Bar Hero.

---

## What it does

Reads the game save (`SaveFile_Live.es3`), decrypts it locally, and shows:

- **Now** — the stage you're currently farming
- **Best gold** — the stage with the most gold/hour
- **Best EXP** — the stage with the most exp/hour
- **Push** — the next stage to unlock
- **Full table** — every unlocked stage ranked by gold or exp, with gold/level projections at 1h, 3h, 5h and 8h

The app detects the save automatically — no need to point to a path, no browser required.

## Using the app

Open it and it does everything on its own — no setup, no file picker. The window has two things worth knowing:

### Language (EN / PT)

The **EN / PT** button in the top-right toggles the whole interface between English and Portuguese (cards, table, status, stage and difficulty names). The button shows the language it will switch *to*. Your choice is remembered between sessions, and on first launch it follows your system language.

### Live calibration

The numbers start as a **theoretical estimate** (based on your party's DPS) and get more accurate as you play. While the game runs and autosaves, the app measures your **real gold/sec and exp/sec** and recalibrates, so "Best gold" reflects your actual farm instead of a model guess.

The status next to the party bar shows the progress:

| Status | Meaning |
|---|---|
| `calibrating…` | Collecting samples — keep the game running and farming. Takes a minute or two. |
| `calibrated (live)` | Numbers now match your measured gold/exp rate on the current stage. |
| `calibrated (N stages)` | You've farmed N different stages; the app uses a cross-stage model — the most accurate. |

You don't have to do anything: just leave the app open while you play. The more stages you farm, the better it gets, and measured clear times are remembered between sessions. The 🟢 **live** dot means the app is watching the save and updating on its own (it re-reads only when the save file changes — never touching the game).

## Safety

- **Read-only** — never writes to the save, never modifies anything
- **No network** — no data ever leaves your machine
- **No game process access** — doesn't open, read memory, or inject anything
- **Anti-cheat safe** — reading a file is the same as a backup; no anti-cheat monitors this

## Usage

### Run directly (development)

```
npm install
npm start
```

### Build the executable

Requires Python 3 and Node.js installed.

```
python build.py
```

This produces `dist/TBH-Farm.zip`. Extract it anywhere and run `TBH Farm.exe`.

```
python build.py --run    # open the app without building the zip
python build.py --clean  # reinstall everything and rebuild the zip
```

The save is found automatically at:
```
%USERPROFILE%\AppData\LocalLow\TesseractStudio\TaskbarHero\SaveFile_Live.es3
```

## How it works

The save (ES3 / AES-CBC) is decrypted in the renderer with Web Crypto using the game's own password. The engine (`engine/engine.js`, UMD) runs in the Electron context and computes the farm rankings via `bestFarm()` and `recommend()`. No network calls at runtime.

Live calibration works by sampling gold, exp and clear counts from the save on each update (keyed off in-game play time), measuring the real gold/sec and exp/sec, and feeding them back into `recommend()` so the engine back-solves your true DPS and bonus multipliers. Per-stage clear times are persisted in `localStorage`; once two or more stages are measured the engine fits a cross-stage clear model.

```
main.js          Electron main process — detects and reads the save
preload.js       safe IPC bridge (contextBridge)
app/index.html   farm UI
engine/          engine.js, gamedata.js, i18n.js
data/            stage and rune tables
build.py         build script (produces the distributable zip)
```

## License

Code: [MIT](LICENSE). Game content and assets belong to their respective owners.
