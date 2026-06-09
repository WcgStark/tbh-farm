# TBH Farm

Otimizador de farm para o idle-RPG [TBH: Task Bar Hero](https://store.steampowered.com/app/3678970/TBH_Task_Bar_Hero/).

Fork de [shigake/tbh-copilot](https://github.com/shigake/tbh-copilot) — o projeto original é um dashboard completo no browser com farm, runas, gear e muito mais. Este fork é focado só em farm: um app desktop que abre sozinho, encontra o save automaticamente e mostra onde farmar.

> Projeto não oficial. Não afiliado nem endossado pelos desenvolvedores do TBH: Task Bar Hero.

---

## O que faz

Lê o save do jogo (`SaveFile_Live.es3`), decifra localmente e mostra:

- **Agora** — o stage que você está farmando
- **Melhor ouro** — o stage com mais ouro/hora
- **Melhor EXP** — o stage com mais exp/hora
- **Avançar** — próximo stage para desbloquear
- **Tabela completa** — todos os stages liberados ordenados por ouro ou exp, com projeções de ouro/nível em 1h, 3h, 5h e 8h

O app detecta o save automaticamente — não precisa apontar o caminho, não precisa do browser.

## Segurança

- **Somente leitura** — nunca escreve no save, nunca modifica nada
- **Sem rede** — nenhum dado sai da sua máquina
- **Sem processo do jogo** — não abre, não lê memória, não injeta nada
- **Sem anti-cheat** — leitura de arquivo é igual a um backup; nenhum anti-cheat monitora isso

## Como usar

### Rodar direto (desenvolvimento)

```
npm install
npm start
```

### Gerar o executável

Precisa de Python 3 e Node.js instalados.

```
python build.py
```

Isso gera `dist/TBH-Farm.zip`. Extraia em qualquer pasta e clique em `TBH Farm.exe`.

```
python build.py --run    # abre o app sem gerar zip
python build.py --clean  # reinstala tudo e regera o zip
```

O save é encontrado automaticamente em:
```
%USERPROFILE%\AppData\LocalLow\TesseractStudio\TaskbarHero\SaveFile_Live.es3
```

## Como funciona

O save (ES3 / AES-CBC) é decifrado no renderer com Web Crypto usando a senha do próprio jogo. O engine (`engine/engine.js`, UMD) roda no contexto Electron e calcula os rankings de farm via `bestFarm()` e `recommend()`. Nenhuma chamada de rede em runtime.

```
main.js          processo principal Electron — detecta e lê o save
preload.js       bridge IPC segura (contextBridge)
app/index.html   UI de farm
engine/          engine.js, gamedata.js, i18n.js
data/            tabelas de stages e runas
build.py         script de build (gera o .zip distribuível)
```

## Licença

Código: [MIT](LICENSE). Conteúdo e assets do jogo pertencem aos seus respectivos donos.
