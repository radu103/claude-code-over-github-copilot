#!/usr/bin/env python3
import os
import sys
import shutil
import time
from pathlib import Path
import subprocess

def fail(msg, code=1):
    print(msg, file=sys.stderr)
    sys.exit(code)

env_path = Path('.') / '.env'
if not env_path.exists():
    fail("❌ .env file not found. Run 'make setup' first.")

master_key = None
for line in env_path.read_text().splitlines():
    if line.strip().startswith('LITELLM_MASTER_KEY'):
        parts = line.split('=', 1)
        if len(parts) > 1:
            master_key = parts[1].strip().strip('"').strip("'")
        break

if not master_key:
    fail("❌ LITELLM_MASTER_KEY not found in .env")

claude_dir = Path.home() / '.claude'
settings = claude_dir / 'settings.json'
if settings.exists():
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    backup = claude_dir / f"settings.json.backup.{timestamp}"
    try:
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(str(settings), str(backup))
        print(f"📁 Backed up existing settings to {backup}")
    except Exception as e:
        fail(f"❌ Failed to backup settings: {e}")

script = Path('scripts') / 'claude_enable.py'
if not script.exists():
    fail('❌ scripts/claude_enable.py not found')

try:
    subprocess.check_call([sys.executable, str(script), master_key])
except subprocess.CalledProcessError as e:
    fail(f"❌ scripts/claude_enable.py failed: {e}", code=e.returncode)

print("✅ claude_enable completed")
