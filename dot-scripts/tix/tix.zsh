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

# Print one obsidian-headless sync config.json path per line.
# On a headless server the Obsidian GUI never runs, so there is no
# obsidian.json registry. The `obsidian-headless` sync CLI instead writes a
# flat per-vault config under
# ${XDG_CONFIG_HOME:-~/.config}/obsidian-headless/sync/<vaultId>/config.json,
# shaped { "vaultName": ..., "vaultPath": ..., ... }. We use these as a
# fallback registry so `tix` works with no GUI installed.
__tix_obsidian_headless_configs() {
  local base="${XDG_CONFIG_HOME:-$HOME/.config}/obsidian-headless/sync"
  [[ -d "$base" ]] || return 0
  local cfg
  # (N) = nullglob: expand to nothing (not the literal pattern) if no match.
  for cfg in "$base"/*/config.json(N); do
    print -r -- "$cfg"
  done
}

# Validate one candidate vault path and, if good, print its absolute Linux
# form and return 0. Handles Windows-style paths (WSL) by converting via
# wslpath. Returns non-zero for empty/"null"/nonexistent candidates. Shared by
# the obsidian.json and headless-config resolution loops.
__tix_emit_vault() {
  local vpath="$1"
  [[ -n "$vpath" && "$vpath" != "null" ]] || return 1
  if [[ "$vpath" == *\\* || "$vpath" =~ '^[A-Za-z]:' ]]; then
    vpath="$(wslpath -u "$vpath" 2>/dev/null)" || return 1
  fi
  [[ -n "$vpath" && -d "$vpath" ]] || return 1
  print -r -- "$vpath"
  return 0
}

# Resolve the vault root by looking up $OBSIDIAN_VAULT_NAME. First consult
# Obsidian's per-machine GUI registry (obsidian.json), then fall back to the
# obsidian-headless sync configs (for GUI-less servers). Echoes the absolute
# path on success; returns non-zero with a message on stderr otherwise.
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
  # 1. GUI registry (obsidian.json): a `.vaults` map keyed by id. Match the
  #    basename of each vault's path. Normalise backslashes to forward slashes
  #    before the basename compare, but return the *original* path so
  #    __tix_emit_vault can detect and convert Windows paths.
  while IFS= read -r cfg; do
    [[ -r "$cfg" ]] || continue
    vpath="$(jq -r --arg name "$OBSIDIAN_VAULT_NAME" '
      .vaults // {}
      | to_entries[]
      | select(((.value.path // "") | gsub("\\\\"; "/") | split("/") | last) == $name)
      | .value.path
    ' "$cfg" 2>/dev/null | head -n1)"
    __tix_emit_vault "$vpath" && return 0
  done < <(__tix_obsidian_config_files)

  # 2. Headless sync configs: flat { vaultName, vaultPath } files, one vault
  #    each. Match either the explicit vaultName or the basename of vaultPath,
  #    so a plain folder-name $OBSIDIAN_VAULT_NAME resolves the same way it does
  #    against the GUI registry above.
  while IFS= read -r cfg; do
    [[ -r "$cfg" ]] || continue
    vpath="$(jq -r --arg name "$OBSIDIAN_VAULT_NAME" '
      select(((.vaultName // "") == $name)
             or (((.vaultPath // "") | gsub("\\\\"; "/") | split("/") | last) == $name))
      | .vaultPath
    ' "$cfg" 2>/dev/null | head -n1)"
    __tix_emit_vault "$vpath" && return 0
  done < <(__tix_obsidian_headless_configs)

  print -r -- "tix: vault '$OBSIDIAN_VAULT_NAME' not found in any obsidian.json registry or obsidian-headless sync config. Open Obsidian once with that vault (GUI), or check \$OBSIDIAN_VAULT_NAME." >&2
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

# Idempotently bind-mount the current repo's vault subdir onto ./tix.
# Used by `tix init`, `tix mount`, and the shell-startup auto-remount below.
# Safe to call when already mounted (no-op). Requires bindfs + mountpoint.
#
# --no-allow-other is mandatory: bindfs adds `-o allow_other` by default,
# which FUSE rejects unless `user_allow_other` is set in /etc/fuse.conf.
# A symlink is NOT used because ripgrep won't follow a symlinked tix/.
__tix_mount() {
  if ! command -v bindfs >/dev/null 2>&1; then
    print -r -- "tix: bindfs is required for the tix/ bind mount (install via apt/brew/pacman)." >&2
    return 1
  fi
  if ! command -v mountpoint >/dev/null 2>&1; then
    print -r -- "tix: mountpoint is required (provided by util-linux)." >&2
    return 1
  fi

  local repo_root target_dir link_path
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    print -r -- "tix mount: not inside a git repo" >&2 ; return 1
  }
  target_dir="$(__tix_repo_dir)" || return 1
  link_path="${repo_root}/tix"

  [[ -d "$target_dir" ]] || {
    print -r -- "tix mount: vault dir $target_dir does not exist. Run 'tix init' first." >&2
    return 1
  }

  # Replace a leftover symlink from the old recipe with a real mount point.
  if [[ -L "$link_path" ]]; then
    rm -f "$link_path" || {
      print -r -- "tix mount: failed to remove stale symlink $link_path" >&2 ; return 1
    }
  fi

  # Refuse to clobber a real, non-directory entry (file/socket/etc.).
  if [[ -e "$link_path" ]] && [[ ! -d "$link_path" ]]; then
    print -r -- "tix mount: $link_path exists and is not a directory. Move or remove it first." >&2
    return 1
  fi

  # Refuse to hide a non-empty real dir that isn't already our mount.
  if [[ -d "$link_path" ]] && ! mountpoint -q "$link_path" 2>/dev/null; then
    local _cnt
    _cnt="$(command ls -A "$link_path" 2>/dev/null | wc -l)"
    if [[ "$_cnt" -ne 0 ]]; then
      print -r -- "tix mount: $link_path exists and is not empty. Move or remove it first." >&2
      return 1
    fi
  fi

  mkdir -p "$link_path" || {
    print -r -- "tix mount: failed to create mount point $link_path" >&2 ; return 1
  }

  # Idempotent: already mounted → no-op.
  if mountpoint -q "$link_path" 2>/dev/null; then
    return 0
  fi

  bindfs --no-allow-other "$target_dir" "$link_path" || {
    print -r -- "tix mount: bindfs failed for $link_path -> $target_dir" >&2
    return 1
  }
  print -r -- "tix mount: ${link_path} -> ${target_dir}"
}

# Detach the ./tix bind mount. Idempotent: no-op if not mounted.
# Useful before `git clean -x` (which would otherwise recurse the mount and
# delete real vault notes) or to tear the mount down cleanly.
__tix_unmount() {
  if ! command -v fusermount >/dev/null 2>&1; then
    print -r -- "tix: fusermount is required to unmount (provided by fuse3)." >&2
    return 1
  fi
  local repo_root link_path
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    print -r -- "tix unmount: not inside a git repo" >&2 ; return 1
  }
  link_path="${repo_root}/tix"
  [[ -e "$link_path" ]] || return 0
  if mountpoint -q "$link_path" 2>/dev/null; then
    fusermount -u "$link_path" || {
      print -r -- "tix unmount: fusermount -u failed for $link_path" >&2 ; return 1
    }
    print -r -- "tix unmount: $link_path"
  fi
  return 0
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
      local repo_root vault repo_name target_dir link_path ignore_file
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

      # 2. Create / verify the ./tix bind mount (idempotent). This replaces
      #    the old symlink recipe — ripgrep won't follow a symlinked tix/.
      __tix_mount || return $?

      # 3. Ensure the repo-root .ignore re-includes tix/ for ripgrep and the
      #    @-picker. git still ignores tix/ via the user's .gitignore (we do
      #    not touch it); .ignore is git-invisible and takes precedence over
      #    .gitignore for ripgrep, so the @-picker can descend the mount.
      #    Idempotent: a no-op once the `!tix/` line is present.
      ignore_file="${repo_root}/.ignore"
      if ! grep -qx '!tix/' "$ignore_file" 2>/dev/null; then
        # Separate from any pre-existing content with a blank line.
        [[ -f "$ignore_file" && -s "$ignore_file" ]] && print -r -- '' >> "$ignore_file"
        {
          print -r -- '# Re-include tix/ (bind-mounted Obsidian vault notes) for ripgrep / the @-picker.'
          print -r -- '# git still ignores tix/ via .gitignore; .ignore is git-invisible and takes'
          print -r -- '# precedence over .gitignore for ripgrep, so the @-picker can descend it.'
          print -r -- '!tix/'
        } >> "$ignore_file"
      fi

      print -r -- "tix init: ${link_path} -> ${target_dir}"
      ;;
    mount)
      __tix_mount
      ;;
    unmount)
      __tix_unmount
      ;;
    help|-h|--help)
      cat <<'EOF'
tix          cd to <vault>/repos/<repo>/
tix path     print resolved vault dir for current repo
tix open     open that dir inside Obsidian (via URI scheme)
tix reveal   open that dir in the OS file manager
tix init     create vault dir + bind-mount ./tix, add .ignore for ripgrep
tix mount    (re)establish the ./tix bind mount (idempotent)
tix unmount  detach the ./tix bind mount (fusermount -u)
tix help     this message

Safety: `git clean -x`/`-X` recurses the ./tix mount and deletes real vault
notes; plain `git clean -fd` is safe (skips ignored dirs). Run `tix unmount`
first if you need a destructive clean.
EOF
      ;;
    *)
      print -r -- "tix: unknown subcommand: $sub (try 'tix help')" >&2
      return 1
      ;;
  esac
}

# Auto-remount the current repo's ./tix bind mount if it evaporated (e.g. after
# a WSL restart). This file is sourced from ~/.zshrc in every interactive shell,
# so the block must stay cheap and failure-tolerant. Guarded: only under WSL,
# only when bindfs+mountpoint exist, only when ./tix is a dir that is NOT already
# a mountpoint. A temp var is used (no `local`: invalid at file scope) and unset.
if [[ -r /proc/version ]] && grep -qi microsoft /proc/version \
  && command -v bindfs >/dev/null 2>&1 \
  && command -v mountpoint >/dev/null 2>&1; then
  _tix_auto_mp="$(git rev-parse --show-toplevel 2>/dev/null)/tix"
  if [[ -n "$_tix_auto_mp" && "$_tix_auto_mp" != "/tix" && -d "$_tix_auto_mp" ]] \
    && ! mountpoint -q "$_tix_auto_mp" 2>/dev/null; then
    tix mount >/dev/null 2>&1
  fi
  unset _tix_auto_mp
fi
