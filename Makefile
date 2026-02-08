# Simplified Makefile for Claude Code over GitHub Copilot model endpoints

.PHONY: help setup install-claude start stop clean test verify claude-enable claude-disable claude-status list-models list-models-enabled

ifeq ($(OS),Windows_NT)
NPM_CHECK = where npm >nul 2>&1
else
NPM_CHECK = command -v npm >/dev/null 2>&1
endif

# Default target
help:
	@echo "Available targets:"
	@echo "  make install-claude - Install Claude Code desktop application"
	@echo "  make setup         - Set up virtual environment and dependencies"
	@echo "  make start         - Start LiteLLM proxy server"
	@echo "  make test          - Test the proxy connection"
	@echo "  make claude-enable - Configure Claude Code to use local proxy"
	@echo "  make claude-status - Show current Claude Code configuration"
	@echo "  make claude-disable - Restore Claude Code to default settings"
	@echo "  make stop          - Stop running processes"
	@echo "  make list-models        - List all GitHub Copilot models"
	@echo "  make list-models-enabled - List only enabled GitHub Copilot models"

# Set up environment (delegates to scripts/setup.py which uses venv)
setup:
	@echo "Setting up environment..."
	@python3 scripts/setup.py || python scripts/setup.py
	@echo "Setup complete OK"

# Install Claude Code desktop application
ifeq ($(OS),Windows_NT)
install-claude:
	@echo "Installing Claude Code desktop application..."
	@where npm >nul 2>&1 && (echo "Installing Claude Code via npm..." & npm install -g @anthropic-ai/claude-code & echo "Claude Code installed successfully" & echo "Note: run 'make claude-enable' to configure it") || (echo "npm not found. Please install Node.js and npm first:" & echo "   https://nodejs.org/" & echo "   Then run: npm install -g @anthropic-ai/claude-code")
else
install-claude:
	@echo "Installing Claude Code desktop application..."
	@if command -v npm >/dev/null 2>&1; then \
			echo "Installing Claude Code via npm..."; \
			npm install -g @anthropic-ai/claude-code && echo "Claude Code installed successfully" && \
			echo "Note: run 'make claude-enable' to configure it"; \
	else \
		echo "❌ npm not found. Please install Node.js and npm first:"; \
		echo "   https://nodejs.org/"; \
		echo "   Then run: npm install -g @anthropic-ai/claude-code"; \
	fi
endif

# Start LiteLLM proxy
start:
	@echo "Starting LiteLLM proxy..."
	@python3 scripts/start.py || python scripts/start.py

# Stop running processes
stop:
	@echo "Stopping processes..."
ifeq ($(OS),Windows_NT)
	@powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $$_.CommandLine -match 'litellm' } | ForEach-Object { Stop-Process -Id $$_.ProcessId -Force }" || echo "No matching processes found"
else
	@pkill -f litellm 2>/dev/null || true
endif
	@echo "Processes stopped"

# Test proxy connection
test:
	@echo "Testing proxy connection..."
	@curl -X POST http://localhost:4444/chat/completions \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $$(grep LITELLM_MASTER_KEY .env | cut -d'=' -f2 | tr -d '\"')" \
		-d '{"model": "gpt-4", "messages": [{"role": "user", "content": "Hello"}]}'
	@echo ""
	@echo "Test completed successfully!"

# Configure Claude Code to use local proxy
claude-enable:
	@echo "Configuring Claude Code to use local proxy..."
	@python3 scripts/claude_enable_wrapper.py || python scripts/claude_enable_wrapper.py
	@echo "Claude Code configured to use local proxy"
	@echo "Make sure to run 'make start' to start the LiteLLM proxy server"

# Restore Claude Code to default settings
claude-disable:
	@echo "Restoring Claude Code to default settings..."

ifeq ($(OS),Windows_NT)
	@powershell -NoProfile -Command "$$dir = Join-Path $$env:USERPROFILE '.claude'; if (Test-Path (Join-Path $$dir 'settings.json')) { Copy-Item (Join-Path $$dir 'settings.json') (Join-Path $$dir ('settings.json.proxy_backup.' + (Get-Date -Format 'yyyyMMdd_HHmmss'))); Write-Host 'Backed up proxy settings to' (Join-Path $$dir ('settings.json.proxy_backup.' + (Get-Date -Format 'yyyyMMdd_HHmmss')) ) } ; $$backups = Get-ChildItem $$dir -Filter 'settings.json.backup.*' -ErrorAction SilentlyContinue; if (-not $$backups) { $$backups = Get-ChildItem $$dir -Filter 'settings.json.proxy_backup.*' -ErrorAction SilentlyContinue }; if ($$backups) { $$latest = $$backups | Sort-Object LastWriteTime -Descending | Select-Object -First 1; Copy-Item $$latest.FullName (Join-Path $$dir 'settings.json'); Write-Host 'Restored settings from' $$latest.FullName } else { try { & python3 scripts/claude_disable.py } catch { & python scripts/claude_disable.py } }"
else
	@if [ -f ~/.claude/settings.json ]; then \
		cp ~/.claude/settings.json ~/.claude/settings.json.proxy_backup.$$(date +%Y%m%d_%H%M%S); \
		echo "📁 Backed up proxy settings to ~/.claude/settings.json.proxy_backup.$$(date +%Y%m%d_%H%M%S)"; \
	fi; \
	@if ls ~/.claude/settings.json.backup.* >/dev/null 2>&1; then \
		LATEST_BACKUP=$$(ls -t ~/.claude/settings.json.backup.* | head -1); \
		cp "$$LATEST_BACKUP" ~/.claude/settings.json; \
		echo "✅ Restored settings from $$LATEST_BACKUP"; \
	else \
		python3 scripts/claude_disable.py; \
	fi
endif

# Show current Claude Code configuration
claude-status:
	@echo "Current Claude Code configuration:"
	@echo "=================================="
ifeq ($(OS),Windows_NT)
	@powershell -NoProfile -Command "if (Test-Path -Path (Join-Path $$env:USERPROFILE '.claude\\settings.json')) { Write-Host 'Settings file:' (Join-Path $$env:USERPROFILE '.claude\\settings.json'); Write-Host ''; try { Get-Content (Join-Path $$env:USERPROFILE '.claude\\settings.json') | ConvertFrom-Json | ConvertTo-Json -Depth 6 } catch { Get-Content (Join-Path $$env:USERPROFILE '.claude\\settings.json') }; Write-Host ''; $$content = Get-Content (Join-Path $$env:USERPROFILE '.claude\\settings.json') -Raw; if ($$content -match 'localhost:4444') { Write-Host 'Status: Using local proxy'; try { Invoke-WebRequest -Uri 'http://localhost:4444/health' -UseBasicParsing -TimeoutSec 2 | Out-Null; Write-Host 'Proxy server: Running' } catch { Write-Host 'Proxy server: Not running (run ''make start'')' } } else { Write-Host 'Status: Using default Anthropic servers' } } else { Write-Host 'No settings file found - using Claude Code defaults'; Write-Host 'Status: Using default Anthropic servers' }"
else
	@if [ -f ~/.claude/settings.json ]; then \
		echo "📄 Settings file: ~/.claude/settings.json"; \
		echo ""; \
		cat ~/.claude/settings.json | python3 -m json.tool 2>/dev/null || cat ~/.claude/settings.json; \
		echo ""; \
		if grep -q "localhost:4444" ~/.claude/settings.json 2>/dev/null; then \
			echo "🔗 Status: Using local proxy"; \
			if curl -s http://localhost:4444/health >/dev/null 2>&1; then \
				echo "✅ Proxy server: Running"; \
			else \
				echo "❌ Proxy server: Not running (run 'make start')"; \
			fi; \
		else \
			echo "🌐 Status: Using default Anthropic servers"; \
		fi; \
	else \
		echo "📄 No settings file found - using Claude Code defaults"; \
		echo "🌐 Status: Using default Anthropic servers"; \
	fi
endif

# List available GitHub Copilot models
list-models:
	@echo "Listing available GitHub Copilot models..."
	@./list-copilot-models.sh

# List only enabled models
list-models-enabled:
	@echo "Listing enabled GitHub Copilot models..."
	@./list-copilot-models.sh --enabled-only
