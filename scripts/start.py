#!/usr/bin/env python3
import os
import sys
import subprocess

VENV_DIR = os.path.join(os.getcwd(), 'venv')

def venv_python():
    if os.name == 'nt':
        return os.path.join(VENV_DIR, 'Scripts', 'python.exe')
    return os.path.join(VENV_DIR, 'bin', 'python')

def run_litellm(vpython):
    args = ['--config', 'copilot-config.yaml', '--port', '4444']

    # Try running the litellm console script in the venv (preferred)
    candidates = []
    if os.name == 'nt':
        candidates = [os.path.join(VENV_DIR, 'Scripts', 'litellm.exe'),
                      os.path.join(VENV_DIR, 'Scripts', 'litellm')]
    else:
        candidates = [os.path.join(VENV_DIR, 'bin', 'litellm')]

    for exe in candidates:
        if os.path.exists(exe):
            cmd = [exe] + args
            print('Running:', ' '.join(cmd))
            try:
                subprocess.check_call(cmd)
                return
            except subprocess.CalledProcessError as e:
                print('litellm exited with', e.returncode)
                sys.exit(e.returncode)

    # If no console script was found, try running via the venv python as a module
    cmd = [vpython, '-m', 'litellm'] + args
    print('Attempting fallback:', ' '.join(cmd))
    try:
        subprocess.check_call(cmd)
        return
    except subprocess.CalledProcessError as e:
        print('Fallback -m litellm failed with', e.returncode)

    # Try a secondary fallback: common submodule entrypoint
    cmd2 = [vpython, '-m', 'litellm.cli'] + args
    print('Attempting secondary fallback:', ' '.join(cmd2))
    try:
        subprocess.check_call(cmd2)
        return
    except subprocess.CalledProcessError as e:
        print('Secondary fallback litellm.cli failed with', e.returncode)

    # Final attempt: try system `litellm` on PATH
    try:
        print('Attempting to run `litellm` from PATH')
        subprocess.check_call(['litellm'] + args)
        return
    except Exception:
        print('Error: could not start litellm. Ensure it is installed in the venv or on PATH.')
        sys.exit(3)

if __name__ == '__main__':
    if not os.path.isdir(VENV_DIR):
        print('Error: virtual environment not found (expected at', VENV_DIR + '). Run "make setup" first.')
        sys.exit(1)

    vpython = venv_python()
    if not os.path.exists(vpython):
        print('Warning: venv python not found at', vpython)
        print('Falling back to system python. Ensure litellm is installed in your environment.')
        vpython = sys.executable

    run_litellm(vpython)
