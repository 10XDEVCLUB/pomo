# CLAUDE.md

This file provides guidance to Claude Code when working with the pomo project.

## Overview

**pomo** is a Pomodoro timer plugin for Zsh with Powerlevel10k integration. It provides:
- Work/break session management with the Pomodoro technique
- Timer and stopwatch modes
- Real-time countdown display in the p10k prompt
- macOS notifications and sounds
- Session history tracking

## Project Structure

```
pomo/
├── pomo.plugin.zsh      # Main plugin entry point, command dispatcher, real-time setup
├── lib/
│   ├── config.zsh       # Configuration variables with defaults
│   ├── core.zsh         # Timer logic, state management, segment updates
│   └── notifications.zsh # macOS notifications and sounds
├── functions/
│   └── prompt_pomodoro  # Powerlevel10k segment function (autoloaded)
├── scripts/
│   └── debug_realtime.zsh # Debug script for troubleshooting real-time mode
├── tests/               # zunit test files
└── sounds/              # Sound files (if any custom sounds)
```

## Key Concepts

### State Management
- Timer state stored in `~/.local/state/pomo/state`
- Variables: `POMO_MODE`, `POMO_STATUS`, `POMO_START_TIME`, `POMO_DURATION`, etc.
- State persists across terminal sessions

### Real-time Mode (`POMODORO_REALTIME=true`)
- Uses `TMOUT=1` and `TRAPALRM` to refresh prompt every second
- `_pomo_update_segment()` updates global segment variables
- p10k segment uses `-e` flag for dynamic variable evaluation
- `zle .reset-prompt && zle -R` triggers display refresh

### P10k Integration
- Segment function: `prompt_pomodoro` in `functions/prompt_pomodoro`
- Uses `p10k segment` with `-e` flag for real-time updates
- Segment variables: `_POMO_SEGMENT_TIME`, `_POMO_SEGMENT_COLOR`, `_POMO_SEGMENT_ICON`, etc.

## Common Commands

```bash
# Run tests
./run-tests.zsh

# Debug real-time mode
source scripts/debug_realtime.zsh

# Manual real-time enable (if needed)
pomo_enable_realtime
```

## Configuration Variables

Key variables in `lib/config.zsh`:
- `POMODORO_WORK_DURATION` - Work session length (default: 1500s/25min)
- `POMODORO_SHORT_BREAK` - Short break length (default: 300s/5min)
- `POMODORO_REALTIME` - Enable real-time countdown (default: false)
- `POMODORO_SOUND_ENABLED` - Enable sounds (default: true)
- `POMODORO_NOTIFY_ENABLED` - Enable notifications (default: true)

## Testing Changes

1. Make changes to files in this repo
2. Push to GitHub: `git push`
3. Update nix flake: `nix flake update pomo --flake ~/dotfiles-nix`
4. Rebuild: `nix-rebuild`
5. Open new terminal window to test

## Known Limitations

- Real-time mode requires `POMODORO_REALTIME=true` set before plugin loads (or use `pomo_enable_realtime`)
- Background notifications run in subshells to avoid job completion messages
- Works with p10k transient prompt enabled
