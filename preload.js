const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('tbhAPI', {
  readSave:    () => ipcRenderer.invoke('read-save'),
  checkSave:   () => ipcRenderer.invoke('check-save'),
  getSavePath: () => ipcRenderer.invoke('get-save-path'),
});
