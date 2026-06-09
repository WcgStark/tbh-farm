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
