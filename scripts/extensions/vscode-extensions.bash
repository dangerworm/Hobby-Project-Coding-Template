#!/usr/bin/env bash
set -euo pipefail

# VS Code extension bootstrapper
# - Installs the allowlist below
# - Optionally uninstalls any currently-installed extensions not in the allowlist
# - Optionally confirms installation per group or per extension
#
# Usage:
#   bash vscode-extensions-master.bash [OPTIONS]
#   CODE_BIN=code-insiders bash vscode-extensions-master.bash [OPTIONS]
#
# Options:
#   --remove               Remove extensions not in allowlist
#   --confirm-groups       Prompt before installing each extension group
#   --confirm-each         Prompt before installing each individual extension
#   -h, --help             Show this help message

canon() {
  # canonical extension id for comparisons
  printf "%s" "$1" | tr '[:upper:]' '[:lower:]'
}

show_usage() {
  echo "VS Code Extension Bootstrapper"
  echo
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "Options:"
  echo "  --remove               Remove extensions not in allowlist"
  echo "  --confirm-groups       Prompt before installing each extension group"
  echo "  --confirm-each         Prompt before installing each individual extension"
  echo "  -h, --help             Show this help message"
  echo
  echo "Environment:"
  echo "  CODE_BIN               VS Code binary to use (default: 'code')"
  echo "                         e.g., CODE_BIN=code-insiders"
  exit 0
}

confirm() {
  # Prompt user for y/n confirmation
  # Returns 0 (true) for yes, 1 (false) for no
  local prompt="$1"
  local response
  while true; do
    read -r -p "$prompt [y/n]: " response
    case "$response" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

# Parse arguments
REMOVE_EXTENSIONS=false
CONFIRM_GROUPS=false
CONFIRM_EACH=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remove)
      REMOVE_EXTENSIONS=true
      shift
      ;;
    --confirm-groups)
      CONFIRM_GROUPS=true
      shift
      ;;
    --confirm-each)
      CONFIRM_EACH=true
      shift
      ;;
    -h|--help)
      show_usage
      ;;
    *)
      echo "Error: Unknown option '$1'"
      echo "Use --help for usage information."
      exit 1
      ;;
  esac
done

CODE_BIN="${CODE_BIN:-code}"

if ! command -v "$CODE_BIN" >/dev/null 2>&1; then
  echo "Error: '$CODE_BIN' not found on PATH."
  echo "Set CODE_BIN=code or CODE_BIN=code-insiders and ensure the VS Code CLI is installed."
  exit 1
fi

# ---------------------------------------------------------------------------
# Load extensions from YAML file
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YAML_FILE="${SCRIPT_DIR}/vscode-extensions.yaml"

if [[ ! -f "$YAML_FILE" ]]; then
  echo "Error: Extensions configuration file not found at: $YAML_FILE"
  exit 1
fi

# Simple YAML parser for our specific format
# Reads groups and extensions without external dependencies
parse_yaml() {
  local current_group=""
  declare -g -A group_extensions  # associative array: group_name -> extensions
  declare -g -a group_names       # ordered list of group names
  declare -g -a all_extensions    # flat list of all extensions

  while IFS= read -r line; do
    # Remove leading/trailing whitespace
    line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # Parse group name (- name: "...")
    if [[ "$line" =~ ^-[[:space:]]*name:[[:space:]]*[\"\'](.*)[\"\']\$ ]]; then
      current_group="${BASH_REMATCH[1]}"
      group_names+=("$current_group")
      group_extensions["$current_group"]=""
      continue
    fi

    # Parse extension (- extension.id)
    if [[ "$line" =~ ^-[[:space:]]*(.+)\$ ]]; then
      local ext="${BASH_REMATCH[1]}"
      if [[ -n "$current_group" ]]; then
        if [[ -z "${group_extensions[$current_group]}" ]]; then
          group_extensions["$current_group"]="$ext"
        else
          group_extensions["$current_group"]+=$'\n'"$ext"
        fi
        all_extensions+=("$ext")
      fi
    fi
  done < "$YAML_FILE"
}

echo "Loading extensions from: $YAML_FILE"
parse_yaml

# Build allowlist from parsed extensions
mapfile -t allowlist < <(
  printf "%s\n" "${all_extensions[@]}" \
    | tr -d '\r' \
    | sed -E 's/[[:space:]]+$//' \
    | awk 'NF' \
    | sort -fu
)

# Build allowlist lookup for fast/robust membership checks
declare -A allow
for ext in "${allowlist[@]}"; do
  allow["$(canon "$ext")"]=1
done

# ---------------------------------------------------------------------------
# Read installed extensions (dedupe + strip CR/whitespace)
# ---------------------------------------------------------------------------

echo "Reading currently installed extensions using: $CODE_BIN"
mapfile -t installed < <(
  "$CODE_BIN" --list-extensions 2>/dev/null \
    | tr -d '\r' \
    | sed -E 's/[[:space:]]+$//' \
    | awk 'NF' \
    | sort -fu
)

echo
echo "Allowlist: ${#allowlist[@]} extensions"
echo "Installed: ${#installed[@]} extensions"

# ---------------------------------------------------------------------------
# Uninstall anything not on the allowlist
# ---------------------------------------------------------------------------

if [[ "$REMOVE_EXTENSIONS" == "true" ]]; then
  to_remove=()
  for ext in "${installed[@]}"; do
    if [[ -z "${allow[$(canon "$ext")]+x}" ]]; then
      to_remove+=("$ext")
    fi
  done

  if ((${#to_remove[@]} > 0)); then
    echo
    echo "Uninstalling ${#to_remove[@]} extension(s) not in allowlist:"
    for ext in "${to_remove[@]}"; do
      echo "× $ext"
      "$CODE_BIN" --uninstall-extension "$ext" >/dev/null || true
    done
  else
    echo "No extensions to uninstall."
  fi
else
  echo
  echo "Skipping removal of non-allowlisted extensions (default behavior, use --remove to enable)."
fi

# ---------------------------------------------------------------------------
# Re-read installed extensions (after uninstall) so install step is accurate
# ---------------------------------------------------------------------------

if [[ "$REMOVE_EXTENSIONS" == "true" ]]; then
  mapfile -t installed < <(
    "$CODE_BIN" --list-extensions 2>/dev/null \
      | tr -d '\r' \
      | sed -E 's/[[:space:]]+$//' \
      | awk 'NF' \
      | sort -fu
  )
fi

# ---------------------------------------------------------------------------
# Install missing allowlisted extensions
# ---------------------------------------------------------------------------

declare -A is_installed
for ext in "${installed[@]}"; do
  is_installed["$(canon "$ext")"]=1
done

to_install=()
for ext in "${allowlist[@]}"; do
  if [[ -z "${is_installed[$(canon "$ext")]+x}" ]]; then
    to_install+=("$ext")   # keep original casing for install output
  fi
done

echo
if ((${#to_install[@]} > 0)); then
  if [[ "$CONFIRM_GROUPS" == "true" ]]; then
    # Install by groups with confirmation
    echo "Installing missing extensions by group..."
    echo

    install_group() {
      local group_name="$1"
      shift
      local group_exts=("$@")
      local group_to_install=()

      for ext in "${group_exts[@]}"; do
        if [[ -z "${is_installed[$(canon "$ext")]+x}" ]]; then
          group_to_install+=("$ext")
        fi
      done

      if ((${#group_to_install[@]} > 0)); then
        echo "$group_name: ${#group_to_install[@]} extension(s) to install"
        if confirm "Install $group_name extensions?"; then
          for ext in "${group_to_install[@]}"; do
            if [[ "$CONFIRM_EACH" == "true" ]]; then
              if confirm "  Install $ext?"; then
                echo "  → $ext"
                "$CODE_BIN" --install-extension "$ext" >/dev/null
              else
                echo "  ⊘ Skipped $ext"
              fi
            else
              echo "  → $ext"
              "$CODE_BIN" --install-extension "$ext" >/dev/null
            fi
          done
        else
          echo "  ⊘ Skipped $group_name group"
        fi
        echo
      fi
    }

    # Install each group from YAML
    for group_name in "${group_names[@]}"; do
      IFS=$'\n' read -r -d '' -a group_exts < <(printf '%s\0' "${group_extensions[$group_name]}")
      install_group "$group_name" "${group_exts[@]}"
    done

  elif [[ "$CONFIRM_EACH" == "true" ]]; then
    # Install all with per-extension confirmation
    echo "Installing ${#to_install[@]} missing extension(s) with confirmation:"
    for ext in "${to_install[@]}"; do
      if confirm "Install $ext?"; then
        echo "→ $ext"
        "$CODE_BIN" --install-extension "$ext" >/dev/null
      else
        echo "⊘ Skipped $ext"
      fi
    done

  else
    # Install all without confirmation
    echo "Installing ${#to_install[@]} missing extension(s):"
    for ext in "${to_install[@]}"; do
      echo "→ $ext"
      "$CODE_BIN" --install-extension "$ext" >/dev/null
    done
  fi
else
  echo "All allowlisted extensions already installed."
fi

echo
echo "Done."
