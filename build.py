#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build.py — gera o executável portátil do TBH Farm.

Uso:
    python build.py          # gera TBH-Farm.zip em dist/
    python build.py --run    # só abre o app (npm start)
    python build.py --clean  # apaga dist/ e node_modules/ antes de buildar
"""
import subprocess
import sys
import os
import shutil
import argparse
import zipfile
from pathlib import Path

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).parent.resolve()
UNPACKED = ROOT / "dist" / "win-unpacked"
OUT_ZIP  = ROOT / "dist" / "TBH-Farm.zip"

BUILD_ENV = {
    **os.environ,
    "CSC_IDENTITY_AUTO_DISCOVERY": "false",
    "WIN_CSC_LINK": "",
}


def run(cmd, env=None, check=True):
    print(f"\n>>> {' '.join(cmd)}")
    result = subprocess.run(
        cmd, cwd=ROOT,
        shell=(sys.platform == "win32"),
        env=env or os.environ,
    )
    if check and result.returncode != 0:
        print(f"\nERRO: comando falhou (código {result.returncode})")
        sys.exit(result.returncode)
    return result


def check_npm():
    if not shutil.which("npm"):
        print("ERRO: npm não encontrado. Instale o Node.js: https://nodejs.org")
        sys.exit(1)


def install_deps():
    nm = ROOT / "node_modules"
    if not nm.exists():
        print("node_modules não encontrado — instalando dependencias...")
        run(["npm", "install"])
    else:
        print("node_modules ja existe — pulando npm install.")


def make_zip():
    """Zipa dist/win-unpacked/ para dist/TBH-Farm.zip."""
    if not UNPACKED.exists():
        print("ERRO: dist/win-unpacked/ não encontrado — build falhou.")
        sys.exit(1)

    print(f"\nEmpacotando {UNPACKED.name}/ → {OUT_ZIP.name} ...")
    with zipfile.ZipFile(OUT_ZIP, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for f in UNPACKED.rglob("*"):
            if f.is_file():
                zf.write(f, Path("TBH Farm") / f.relative_to(UNPACKED))

    size_mb = OUT_ZIP.stat().st_size / 1_048_576
    print(f"\nPronto!")
    print(f"  Arquivo : {OUT_ZIP}")
    print(f"  Tamanho : {size_mb:.0f} MB")
    print(f"\nComo usar:")
    print(f"  1. Extraia o ZIP em qualquer pasta")
    print(f"  2. Abra a pasta 'TBH Farm' e clique em 'TBH Farm.exe'")

    # abre a pasta dist/ no Explorer
    subprocess.Popen(["explorer", str(ROOT / "dist")])


def main():
    parser = argparse.ArgumentParser(description="Build TBH Farm")
    parser.add_argument("--run",   action="store_true", help="Abre o app (npm start)")
    parser.add_argument("--clean", action="store_true", help="Apaga dist/ e node_modules/ antes")
    args = parser.parse_args()

    check_npm()

    if args.clean:
        for d in ["dist", "node_modules"]:
            p = ROOT / d
            if p.exists():
                print(f"Apagando {d}/...")
                shutil.rmtree(p)

    if args.run:
        install_deps()
        print("\nAbrindo o app...")
        run(["npm", "start"])
        return

    install_deps()

    print("\nEmpacotando app (isso pode demorar na primeira vez)...")
    # electron-builder falha no winCodeSign (symlinks sem admin), mas o
    # win-unpacked/ já foi criado antes disso — ignoramos o exit code.
    result = run(["npm", "run", "build"], env=BUILD_ENV, check=False)

    if not UNPACKED.exists():
        # falha real: packaging em si não gerou nada
        print("\nERRO: build falhou antes de gerar os arquivos.")
        print("Tente rodar como administrador ou verifique os logs acima.")
        sys.exit(result.returncode)

    # winCodeSign pode ter falhado (exit 1) mas win-unpacked/ existe — ok
    make_zip()


if __name__ == "__main__":
    main()
