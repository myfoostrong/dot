# tix.zsh — single Obsidian vault planning store
# Sourced from ~/.zshrc. Defines the `tix` user command.

# Print one obsidian.json candidate path per line, in priority order.
# Linux/macOS native paths first; on WSL also try the Windows-side registry
# (Obsidian installed on Windows is the common WSL setup).
__tix_obsidian_config_files() {
  case "$OSTYPE" in
    darwin*)
      print -r -- "$HOME/Library/Application Support/obsidian/obsidian.json"
      ;;
    linux*)
      print -r -- "${XDG_CONFIG_HOME:-$HOME/.config}/obsidian/obsidian.json"
      if [[ -r /proc/version ]] && grep -qi microsoft /proc/version; then
        local win appdata
        win="$(cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r\n')"
        if [[ -n "$win" ]]; then
          appdata="$(wslpath -u "$win" 2>/dev/null)"
          [[ -n "$appdata" ]] && print -r -- "${appdata}/obsidian/obsidian.json"
        fi
      fi
      ;;
  esac
}

# Resolve the vault root by looking up $OBSIDIAN_VAULT_NAME in Obsidian's
# per-machine registry. Echoes the absolute path on success; returns non-zero
# with a message on stderr otherwise.
__tix_resolve_vault() {
  if [[ -z "${OBSIDIAN_VAULT_NAME:-}" ]]; then
    print -r -- "tix: \$OBSIDIAN_VAULT_NAME is not set. Set it to the name of your Obsidian vault (e.g. 'export OBSIDIAN_VAULT_NAME=MyVault')." >&2
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    print -r -- "tix: jq is required for vault discovery (install via apt/brew/pacman)." >&2
    return 1
  fi
  # NOTE: the scratch variable is named `vpath` (not `path`). In zsh, `path`
  # is a special array tied to `PATH` (via `typeset -T`); declaring
  # `local path` would shadow that tied pair with an empty local instance and
  # make every external command (`jq`, `head`, ...) unfindable inside this
  # function. Using a non-colliding name avoids the gotcha.
  local cfg vpath
  while IFS= read -r cfg; do
    [[ -r "$cfg" ]] || continue
    # Normalise backslashes to forward slashes before basename comparison,
    # then return the *original* path so the WSL converter below can detect
    # Windows paths.
    vpath="$(jq -r --arg name "$OBSIDIAN_VAULT_NAME" '
      .vaults // {}
      | to_entries[]
      | select(((.value.path // "") | gsub("\\\\"; "/") | split("/") | last) == $name)
      | .value.path
    ' "$cfg" 2>/dev/null | head -n1)"
    if [[ -n "$vpath" && "$vpath" != "null" ]]; then
      if [[ "$vpath" == *\\* || "$vpath" =~ '^[A-Za-z]:' ]]; then
        vpath="$(wslpath -u "$vpath" 2>/dev/null)" || vpath=""
      fi
      if [[ -n "$vpath" && -d "$vpath" ]]; then
        print -r -- "$vpath"
        return 0
      fi
    fi
  done < <(__tix_obsidian_config_files)
  print -r -- "tix: vault '$OBSIDIAN_VAULT_NAME' not found in any obsidian.json registry. Open Obsidian once with that vault, or check \$OBSIDIAN_VAULT_NAME." >&2
  return 1
}

# Open the planning dir *inside Obsidian* via its URI scheme.
# Argument: relative path inside the vault (e.g. "repos/dot").
__tix_open() {
  local relpath="$1" uri
  [[ -n "${OBSIDIAN_VAULT_NAME:-}" ]] || {
    print -r -- "tix open: \$OBSIDIAN_VAULT_NAME is not set." >&2 ; return 1
  }
  # Minimal percent-encoding: only spaces. Vault names and repo names rarely
  # contain reserved URI characters; if they do, the user can quote-escape.
  uri="obsidian://open?vault=${OBSIDIAN_VAULT_NAME// /%20}&file=${relpath// /%20}"
  case "$OSTYPE" in
    darwin*) open "$uri" ;;
    linux*)
      if [[ -r /proc/version ]] && grep -qi microsoft /proc/version; then
        if command -v wslview >/dev/null 2>&1; then
          wslview "$uri"
        else
          cmd.exe /c start "" "$uri" 2>/dev/null
        fi
      else
        xdg-open "$uri" >/dev/null 2>&1 &
      fi
      ;;
    *) print -r -- "tix open: unsupported OSTYPE=$OSTYPE" >&2 ; return 1 ;;
  esac
}

# Open a path in the host's GUI file manager (not Obsidian).
__tix_reveal() {
  local target="$1"
  case "$OSTYPE" in
    darwin*) open "$target" ;;
    linux*)
      if [[ -r /proc/version ]] && grep -qi microsoft /proc/version; then
        if command -v wslview >/dev/null 2>&1; then
          wslview "$target"
        else
          cmd.exe /c start "" "$(wslpath -w "$target")"
        fi
      else
        xdg-open "$target" >/dev/null 2>&1 &
      fi
      ;;
    *) print -r -- "tix reveal: unsupported OSTYPE=$OSTYPE" >&2 ; return 1 ;;
  esac
}

# Repo identity = basename of `git rev-parse --show-toplevel`, falling back
# to basename of $PWD if not inside a repo.
__tix_repo_name() {
  local repo_root
  if repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    basename "$repo_root"
  else
    basename "$PWD"
  fi
}

# Resolve the vault subdirectory for the *current* repo.
__tix_repo_dir() {
  local vault repo_name
  vault="$(__tix_resolve_vault)" || return 1
  repo_name="$(__tix_repo_name)"
  print -r -- "${vault}/repos/${repo_name}"
}

tix() {
  local sub="${1:-cd}"
  shift 2>/dev/null
  case "$sub" in
    cd|"")
      local dir
      dir="$(__tix_repo_dir)" || return 1
      [[ -d "$dir" ]] || { print -r -- "tix: $dir does not exist. Run 'tix init' first." >&2 ; return 1 ; }
      cd "$dir"
      ;;
    path)
      __tix_repo_dir
      ;;
    open)
      __tix_resolve_vault >/dev/null || return 1
      __tix_open "repos/$(__tix_repo_name)"
      ;;
    reveal)
      local dir
      dir="$(__tix_repo_dir)" || return 1
      [[ -d "$dir" ]] || { print -r -- "tix: $dir does not exist. Run 'tix init' first." >&2 ; return 1 ; }
      __tix_reveal "$dir"
      ;;
    init)
      local repo_root vault repo_name target_dir link_path exclude_file
      repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        print -r -- "tix init: not inside a git repo" >&2 ; return 1
      }
      vault="$(__tix_resolve_vault)" || return 1
      repo_name="$(basename "$repo_root")"
      target_dir="${vault}/repos/${repo_name}"
      link_path="${repo_root}/tix"

      # 1. Create vault subdir layout
      mkdir -p "${target_dir}/plans" \
               "${target_dir}/research" \
               "${target_dir}/handoffs" \
               "${target_dir}/mrs"

      # 2. Create / verify symlink
      if [[ -L "$link_path" ]]; then
        local existing
        existing="$(readlink "$link_path")"
        if [[ "$existing" != "$target_dir" ]]; then
          print -r -- "tix init: $link_path is a symlink to $existing (expected $target_dir). Refusing to overwrite." >&2
          return 1
        fi
      elif [[ -e "$link_path" ]]; then
        print -r -- "tix init: $link_path exists and is not a symlink. Move or remove it first." >&2
        return 1
      else
        ln -s "$target_dir" "$link_path"
      fi

      # 3. Ensure .git/info/exclude contains `/tix` (root-anchored).
      #    The leading slash anchors the pattern to the repo root so unrelated
      #    nested `tix` directories (e.g. src/tix/) are not affected.
      mkdir -p "$(dirname "$exclude_file")"

      print -r -- "tix init: ${link_path} -> ${target_dir}"
      ;;
    help|-h|--help)
      cat <<'EOF'
tix          cd to <vault>/repos/<repo>/
tix path     print resolved vault dir for current repo
tix open     open that dir inside Obsidian (via URI scheme)
tix reveal   open that dir in the OS file manager
tix init     create vault dir, symlink ./tix, hide from git
tix help     this message
EOF
      ;;
    *)
      print -r -- "tix: unknown subcommand: $sub (try 'tix help')" >&2
      return 1
      ;;
  esac
}
