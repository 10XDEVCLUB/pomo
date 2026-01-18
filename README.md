# pomo

A Pomodoro timer with shell integrations, notifications, sound alerts, and session tracking.

## Features

- Pomodoro technique with work/break cycles
- One-off countdown timers
- Stopwatch mode
- Native macOS notifications
- Sound alerts
- Session history tracking
- Powerlevel10k prompt segment integration
- Pause/resume support
- Configurable durations

## Installation

### Manual

```bash
git clone https://github.com/briancorbinxyz/pomo.git ~/.zsh/plugins/pomo
echo 'source ~/.zsh/plugins/pomo/pomo.plugin.zsh' >> ~/.zshrc
```

### Oh-My-Zsh

```bash
git clone https://github.com/briancorbinxyz/pomo.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/pomo
```

Add to plugins in `~/.zshrc`:
```zsh
plugins=(... pomo)
```

### Zinit

```zsh
zinit light briancorbinxyz/pomo
```

### Antigen

```zsh
antigen bundle briancorbinxyz/pomo
```

### Nix / Home-Manager

Add to your `flake.nix` inputs:
```nix
inputs.pomo.url = "github:briancorbinxyz/pomo";
```

Then in your home-manager config:
```nix
imports = [ inputs.pomo.homeManagerModules.default ];

programs.zsh.pomodoro = {
  enable = true;
  workDuration = 1500;  # 25 minutes
  shortBreak = 300;     # 5 minutes
  longBreak = 900;      # 15 minutes
};
```

Or manually add the plugin:
```nix
programs.zsh.plugins = [
  {
    name = "pomo";
    src = inputs.pomo.packages.${pkgs.system}.pomo + "/share/zsh/plugins/pomo";
    file = "pomo.plugin.zsh";
  }
];
```

## Powerlevel10k Setup

Add `pomodoro` to your prompt elements in `~/.p10k.zsh`:

```zsh
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  # ... other elements ...
  pomodoro
  # ... other elements ...
)
```

## Usage

```bash
pomo start                # Start a 25-minute work session
pomo start break          # Start a 5-minute break
pomo start long-break     # Start a 15-minute long break
pomo stop                 # Stop the current timer
pomo pause                # Pause the timer
pomo resume               # Resume the timer
pomo skip                 # Skip to next phase
pomo status               # Show current status
pomo timer 10m            # Start a 10-minute countdown
pomo stopwatch            # Start a stopwatch
pomo history              # Show today's sessions
pomo config               # Show configuration
```

### Duration Formats

- `25m` - 25 minutes
- `1h` - 1 hour
- `1h30m` - 1 hour 30 minutes
- `90s` - 90 seconds
- `300` - 300 seconds (bare number)

## Configuration

Set these variables in your `.zshrc` before sourcing the plugin:

```zsh
# Durations (in seconds)
export POMODORO_WORK_DURATION=1500         # 25 minutes
export POMODORO_SHORT_BREAK=300            # 5 minutes
export POMODORO_LONG_BREAK=900             # 15 minutes
export POMODORO_CYCLES_BEFORE_LONG=4       # Long break after 4 work sessions

# Features
export POMODORO_SOUND_ENABLED=true
export POMODORO_NOTIFY_ENABLED=true
export POMODORO_AUTO_START_BREAK=false
export POMODORO_AUTO_START_WORK=false

# Custom sounds (macOS)
export POMODORO_SOUND_WORK_END="/System/Library/Sounds/Submarine.aiff"
export POMODORO_SOUND_BREAK_END="/System/Library/Sounds/Glass.aiff"

# Display icons
export POMODORO_ICON_WORK="🍅"
export POMODORO_ICON_BREAK="☕"
export POMODORO_ICON_PAUSED="⏸"
export POMODORO_ICON_TIMER="⏱"

# Colors (p10k color codes)
export POMODORO_COLOR_WORK=1               # Red
export POMODORO_COLOR_BREAK=2              # Green
export POMODORO_COLOR_WARNING=3            # Yellow
export POMODORO_COLOR_PAUSED=8             # Gray
```

## How It Works

The timer state is stored in `~/.local/state/pomo/state`, allowing timers to persist across terminal sessions.

The Powerlevel10k segment reads this state and displays:
- Work session: Red background with tomato icon
- Break: Green background with coffee icon
- Warning (< 1 min): Yellow background
- Paused: Gray background with pause icon

When a timer completes, you'll receive a macOS notification and sound alert.

## Migrating from zsh-pomodoro-p10k

If you previously used `zsh-pomodoro-p10k`, your state and history files will be automatically migrated to the new location on first load.

## License

MIT
