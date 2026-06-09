#!/usr/bin/env python3
"""
build.py — gera o executável portátil do TBH Farm.

Uso:
    python build.py          # gera o .exe em dist/
    python build.py --run    # só abre o app (npm start)
    python build.py --clean  # apaga dist/ e node_modules/ antes de buildar
"""
import subprocess
import sys
import os
import shutil
import argparse
from pathlib import Path

ROOT = Path(__file__).parent

def run(cmd, **kw):
    print(f"\n>>> {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=ROOT, **kw)
    if result.returncode != 0:
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
        print("node_modules não encontrado — instalando dependências...")
        run(["npm", "install"])
    else:
        print("node_modules já existe — pulando npm install.")
        print("  (use --clean para forçar reinstalação)")

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

    print("\nGerando executável...")
    run(["npm", "run", "build"])

    dist = ROOT / "dist"
    exes = list(dist.glob("*.exe")) if dist.exists() else []
    if exes:
        exe = exes[0]
        size_mb = exe.stat().st_size / 1_048_576
        print(f"\n✓ Executável gerado: {exe}")
        print(f"  Tamanho: {size_mb:.0f} MB")
        # Abre a pasta no Explorer
        subprocess.Popen(["explorer", str(dist)])
    else:
        print(f"\n✓ Build concluída. Verifique a pasta: {dist}")

if __name__ == "__main__":
    main()
