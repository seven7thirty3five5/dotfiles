#!/bin/sh
#
# Install the global agent skills with the skills tool (skills.sh), which puts
# each one in ~/.agents/skills for Codex and links it into ~/.claude/skills for
# Claude Code. Add a skill here and the next apply installs it; `update` keeps
# them all current. `pnpm dlx skills add OWNER/REPO --list` lists a repository's.

set -eu

# The skills tool records what it installed here, as it does under fish.
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# From home, with mise's global Node and pnpm (from the mise script, 50). pnpm
# dlx runs the skills tool without installing it.
cd "$HOME"
skills_add() {
  "$HOME/.local/bin/mise" exec -- pnpm dlx skills add "$@" --global --agent claude-code codex --yes
}

# herdr's skill, for controlling herdr panes and agents.
skills_add herdrdev/herdr --skill herdr

# Every skill in Matt Pocock's repository; his plugin would give Claude each twice.
skills_add mattpocock/skills

# This repository's /dotfiles skill, from GitHub, so `update` installs pushed changes.
skills_add seven7thirty3five5/dotfiles --skill dotfiles
