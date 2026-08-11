#!/usr/bin/env bash
# Create/update the "Mereoleona" gnome-terminal profile (Vermillion palette).
# Idempotent. Non-destructive: adds a NEW profile, never edits existing ones.
# Prints the profile UUID on the last stdout line.
set -uo pipefail
ROOT="$HOME/.mereoleona"; STATE="$ROOT/state"; mkdir -p "$STATE"
BASE="/org/gnome/terminal/legacy/profiles:"

if [ -f "$STATE/term-uuid" ]; then
  UUID="$(cat "$STATE/term-uuid")"
else
  UUID="$(python3 -c 'import uuid;print(uuid.uuid4())')"
  echo "$UUID" > "$STATE/term-uuid"
fi
P="${BASE}/:${UUID}/"

# Add UUID to the profile list if not already present
LIST="$(gsettings get org.gnome.Terminal.ProfilesList list 2>/dev/null)"
if ! printf '%s' "$LIST" | grep -q "$UUID"; then
  if [ "$LIST" = "@as []" ] || [ "$LIST" = "[]" ]; then
    NEW="['$UUID']"
  else
    NEW="$(printf '%s' "$LIST" | sed "s/]$/, '$UUID']/")"
  fi
  gsettings set org.gnome.Terminal.ProfilesList list "$NEW"
fi

w(){ dconf write "${P}$1" "$2"; }
w visible-name                "'🔥 Mereoleona'"
w palette                     "['#2B1A12', '#C8341E', '#9D9A2E', '#F2A81E', '#6FA8B5', '#B5471B', '#5E9AA8', '#E8D4B0', '#5A3A28', '#E84B2E', '#C2B23E', '#FFC94D', '#8FCAD6', '#E8650E', '#7FB8C4', '#FFF6E6']"
w background-color            "'#160C07'"
w foreground-color           "'#F5E6CC'"
w use-theme-colors           "false"
w bold-color-same-as-fg      "false"
w bold-color                 "'#FFC94D'"
w cursor-colors-set          "true"
w cursor-background-color    "'#E8650E'"
w cursor-foreground-color    "'#160C07'"
w cursor-shape               "'block'"
w cursor-blink-mode          "'on'"
w highlight-colors-set       "true"
w highlight-background-color "'#C8341E'"
w highlight-foreground-color "'#FFF6E6'"
w bold-is-bright             "true"
w use-transparent-background "true"
w background-transparency-percent "12"
w use-theme-transparency     "false"
w use-system-font            "false"
w font                       "'JetBrainsMono Nerd Font 12'"
w audible-bell               "false"
w scrollbar-policy           "'never'"
w default-size-columns       "112"
w default-size-rows          "32"

echo "$UUID"
