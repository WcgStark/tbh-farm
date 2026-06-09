const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const fs = require('fs');
const os = require('os');

const SAVE_PATH = path.join(
  os.homedir(),
  'AppData', 'LocalLow', 'TesseractStudio', 'TaskbarHero', 'SaveFile_Live.es3'
);

let mainWindow;
let lastMtime = 0;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1100,
    height: 780,
    minWidth: 720,
    minHeight: 500,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    title: 'TBH Farm',
    backgroundColor: '#0a0e1a',
    autoHideMenuBar: true,
  });

  mainWindow.loadFile(path.join(__dirname, 'app', 'index.html'));
}

function readSave() {
  if (!fs.existsSync(SAVE_PATH)) {
    return { error: 'notfound', path: SAVE_PATH };
  }
  try {
    const stat = fs.statSync(SAVE_PATH);
    const mtime = stat.mtimeMs;
    const data = fs.readFileSync(SAVE_PATH).toString('base64');
    lastMtime = mtime;
    return { data, mtime };
  } catch (e) {
    return { error: e.message };
  }
}

ipcMain.handle('read-save', () => readSave());

ipcMain.handle('check-save', () => {
  if (!fs.existsSync(SAVE_PATH)) return { changed: false };
  try {
    const mtime = fs.statSync(SAVE_PATH).mtimeMs;
    if (mtime === lastMtime) return { changed: false };
    return { changed: true, ...readSave() };
  } catch {
    return { changed: false };
  }
});

ipcMain.handle('get-save-path', () => SAVE_PATH);

app.whenReady().then(createWindow);
app.on('window-all-closed', () => app.quit());
