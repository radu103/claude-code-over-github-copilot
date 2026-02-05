#!/usr/bin/env python3
import sys
import shutil
import subprocess
import os
from pathlib import Path

def fail(msg, code=1):
    print(msg, file=sys.stderr)
    sys.exit(code)

def run(cmd):
    print('> ' + ' '.join(cmd))
    subprocess.check_call(cmd)

root = Path.cwd()

# Ensure scripts directory exists
try:
    (root / 'scripts').mkdir(parents=True, exist_ok=True)
except Exception as e:
    fail(f"Failed to create scripts directory: {e}")

# Find a Python executable
py = shutil.which('python3') or shutil.which('python') or sys.executable
if not py:
    fail('Python not found on PATH')

# Create virtual environment if needed
venv_dir = root / 'venv'
if venv_dir.exists():
    if os.name == 'nt':
        venv_python = venv_dir / 'Scripts' / 'python.exe'
    else:
        venv_python = venv_dir / 'bin' / 'python'
    if not venv_python.exists():
        print('Existing venv incomplete; attempting to recreate')
        try:
            shutil.rmtree(str(venv_dir))
        except Exception:
            fail('Cannot remove existing venv; check permissions')
        try:
            run([py, '-m', 'venv', 'venv'])
        except subprocess.CalledProcessError as e:
            fail(f'Failed to create virtualenv: {e}')
else:
    try:
        run([py, '-m', 'venv', 'venv'])
    except subprocess.CalledProcessError as e:
        fail(f'Failed to create virtualenv: {e}')

# Determine venv python
if os.name == 'nt':
    venv_python = venv_dir / 'Scripts' / 'python.exe'
else:
    venv_python = venv_dir / 'bin' / 'python'

if not venv_python.exists():
    # fallback to provided python
    venv_python = Path(py)

# Install requirements
try:
    run([str(venv_python), '-m', 'pip', 'install', '-r', 'requirements.txt'])
except subprocess.CalledProcessError as e:
    fail(f'Failed to install requirements: {e}')

# Generate .env if missing
env_file = root / '.env'
if not env_file.exists():
    try:
        run([py, 'generate_env.py'])
    except subprocess.CalledProcessError as e:
        fail(f'Failed to generate .env: {e}')
else:
    print('✓ .env file already exists, skipping generation')
