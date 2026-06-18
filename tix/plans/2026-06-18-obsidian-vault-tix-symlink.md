# Single Obsidian Vault as `tix/` Symlink — Implementation Plan

## Overview

Replace the current "every repo has its own `tix/` directory (and may also have a
`thoughts/` directory)" convention with a single Obsidian-synced vault that
holds the planning files for every repo. Each repo gets a `tix` symlink
pointing into the vault. The symlink is visible to Claude Code / opencode but
hidden from `git status` via a `/tix` line in `.git/info/exclude` (not
`.gitignore`, which the harnesses also honour; the leading slash anchors the
match to the repo root so unrelated nested `tix` directories are not affected).
A new `tix` Zsh command provides `cd`, `init`, `open`, `reveal`, and `path`
subcommands. Vault location is resolved by parsing Obsidian's own per-machine
registry (`obsidian.json`) keyed by `$OBSIDIAN_VAULT_NAME`, so the vault
survives being moved on disk without any per-machine config drift. The whole
thing must bootstrap reproducibly on Ubuntu, Debian, Kali, WSL (any of those
distros), and macOS.

## Current State Analysis

From `tix/research/2026-06-18-obsidian-vault-multi-repo-planning.md`:

- The repo is a **bare-git dotfiles checkout** into `$HOME` via
  `dot-scripts/install/config.sh` (`status.showUntrackedFiles no`).
- `~/.zshrc:124-134` has a hand-curated `#### Aliases` block — the only
  current shell-extension point. No `~/.zshrc.d/` directory, no `fpath`
  customisation.
- **No OS detection exists anywhere** in the repo (zero `uname` / `OSTYPE`
  usage outside one commented `ARCHFLAGS` line). Brew path
  (`.zshrc:122`) and a Linux-only `.local/bin` path (`.zshrc:141`) are
  hard-coded.
- **No symlink machinery exists** (no `ln -s`, no `stow`, no `chezmoi`).
- The harness commands hard-code a two-directory split that we are
  collapsing into one:
  - `thoughts/` — historical/external, **never committed**, enforced as
    policy in `.claude/commands/ci_commit.md:25`.
  - `tix/` — generated artifacts (`plans/`, `research/`, `handoffs/issue-XXXX/`,
    `mrs/`, `mr_description.md`) currently committed to each repo.
- 14 files reference `thoughts/`; they need updating to drop the concept and
  point everything at `tix/`:
  - `.claude/commands/`: `create_plan.md`, `research_codebase.md`,
    `iterate_plan.md`, `create_handoff.md`, `ci_commit.md`,
    `ci_describe_mr.md`, `describe_mr.md`
  - `.claude/agents/`: `thoughts-locator.md`, `thoughts-analyzer.md`
  - `.config/opencode/command/`: `create_plan.md`, `research_codebase.md`,
    `iterate_plan.md`, `resume_handoff.md`
  - `.config/opencode/agents/`: `thoughts-locator.md` (and the
    matching `thoughts-analyzer.md` if grep missed it because it lacks the
    string at agent-name boundary)
- The `dot` repo *itself* already contains a committed
  `tix/research/2026-06-18-obsidian-vault-multi-repo-planning.md` — it is
  the first real test case of the migration: that file has to move into the
  vault and the now-committed `tix/` directory has to be removed from
  tracking and replaced with the symlink.

## Desired End State

After this plan is implemented:

1. `$OBSIDIAN_VAULT_NAME` is set in `.zshrc` (and only that — no per-machine
   absolute path). On every supported OS, sourcing `.zshrc` makes the `tix`
   command resolve the vault by reading Obsidian's `obsidian.json` registry
   and matching the named vault. On a fresh machine, if `jq` is missing or the
   named vault is not in any registry, `tix` prints a single actionable error.
2. `tix` is a Zsh function. With no args it `cd`s to
   `<vault>/repos/<repo-name>/`. `tix open` opens that folder *inside Obsidian*
   via the `obsidian://open?vault=...&file=repos/<repo>` URI scheme. `tix
   reveal` opens that folder in the OS file manager (Finder / Nautilus /
   Windows Explorer via WSL). `tix init` (run once per repo) creates the vault
   subdir + the `./tix` symlink + the `/tix` line in `.git/info/exclude`. `tix
   path` prints the resolved path for scripting.
3. In any repo where `tix init` has been run, `ls -la` shows `tix ->
   <vault>/repos/<repo>/`, `git status` is clean, and Claude Code / opencode
   can read and write files under `tix/plans/`, `tix/research/`, etc. as
   if they were normal repo files.
4. Every harness prompt and agent file under `.claude/` and
   `.config/opencode/` refers to `tix/` (never `thoughts/`). The two
   `thoughts-*` agents are renamed to `tix-locator` / `tix-analyzer`.
5. The `dot` repo itself uses the new layout: the existing
   `tix/research/2026-06-18-obsidian-vault-multi-repo-planning.md` lives in
   the vault, the tracked `tix/` directory has been `git rm`'d, and a
   `tix` symlink replaces it.
6. A new install script `dot-scripts/install/tix.sh` is documented as the
   one-time setup step for new machines (creates vault dir layout under
   `$OBSIDIAN_VAULT/repos/`, writes the `.zshrc` source line if missing).

### Key Discoveries (from prior research):
- The "harness sees it but git doesn't" requirement rules out `.gitignore`.
  `.git/info/exclude` has identical syntax, is per-repo and local-only, and
  is not part of the tree the harness reads — it is the right tool.
- The exclude pattern must be `/tix` (leading slash), not `tix`. The
  unanchored form matches any path component named `tix` at any depth, which
  would silently hide e.g. `src/tix/` or a test fixture named `tix` from
  `git status`. Anchoring to the repo root avoids the collision.
- Shell-function form is required for `tix` because the no-arg case must
  `cd`. A standalone script can't change the parent shell's cwd.
- Obsidian writes a per-machine vault registry at
  `~/.config/obsidian/obsidian.json` (Linux), `~/Library/Application
  Support/obsidian/obsidian.json` (macOS), and `%APPDATA%/obsidian/obsidian.json`
  (Windows; reachable from WSL via `wslpath`). Each `vaults.<id>.path` entry is
  the absolute path Obsidian last saw. Matching by `basename(path) ==
  $OBSIDIAN_VAULT_NAME` lets the same `.zshrc` work on every machine without
  hard-coded paths. Paths in the Windows registry may use backslashes; the
  resolver normalises them and converts to a WSL path when running under WSL.
- The Obsidian URI scheme `obsidian://open?vault=<name>&file=<relpath>` opens
  Obsidian focused on a specific vault path. It works from `open` (macOS),
  `xdg-open` (Linux), and `cmd.exe /c start` / `wslview` (WSL). This is what
  `tix open` uses, so the user lands in Obsidian rather than the file
  manager. `tix reveal` is the separate subcommand for the file-manager case
  (uses `xdg-open` / `open` / WSL `cmd.exe start` against the directory).
- The current `tix/research/2026-06-18-obsidian-vault-multi-repo-planning.md`
  document (created by the research step) is committed in this branch; the
  migration step has to relocate it rather than discard it.

## What We're NOT Doing

- **No `stow` / `chezmoi` / `dotbot` introduction.** The bare-git pattern
  stays. We are adding one new script directory under `dot-scripts/` and
  one source line in `.zshrc`. No new dotfile-manager.
- **No Obsidian plugin or `.obsidian/` config management.** The vault is
  assumed to exist already and is managed by Obsidian Sync. We only write
  files into `<vault>/repos/<repo>/`.
- **No automatic discovery of *which* repos need a `tix` symlink.** The user
  runs `tix init` per repo. No daemon, no global walker.
- **No backfill for repos that don't have the symlink yet.** Existing repos
  that still commit `tix/` keep working until the user runs `tix init` on
  them.
- **No removal of the `tix/` *concept* from harness prompts.** Only the
  `thoughts/` references go. The harness still writes `tix/plans/`,
  `tix/research/`, etc. — those paths now resolve through the symlink.
- **No `searchable/` hard-link mirror.** That mechanism (currently
  documented in `research_codebase.md`) existed because `thoughts/` and
  `tix/` were two physically distinct trees. With one vault-backed `tix/`,
  it is moot; we delete the references rather than re-implement them.
- **No CI / pre-commit hook to enforce the `.git/info/exclude` entry.**
  `tix init` writes it idempotently; that is the only guarantee.

## Implementation Approach

Build the tool first (Phase 1), then the per-repo wiring (Phase 2), then
migrate the harness prompts to the new vocabulary (Phase 3), then dog-food
the whole thing on the `dot` repo itself (Phase 4). Each phase is
independently testable — Phase 1 produces a `tix` command that works
standalone, Phase 2 adds `init` and the symlink dance, Phase 3 updates docs
that have no runtime dependency on the script, Phase 4 is the live
migration.

---

## Phase 1: `tix` Zsh function + vault discovery + OS-aware openers

### Overview
Create a single sourced Zsh fragment that defines the `tix` function, an
`__tix_resolve_vault` helper (parses `obsidian.json` by
`$OBSIDIAN_VAULT_NAME`), an `__tix_open` helper (Obsidian URI), and an
`__tix_reveal` helper (system file manager). Wire it into `.zshrc`. After
this phase, `tix path`, `tix open`, and `tix reveal` work in any repo; the
`init` subcommand is stubbed (Phase 2 fills it in).

### Changes Required:

#### 1. New file: `dot-scripts/tix/tix.zsh`
**File**: `dot-scripts/tix/tix.zsh`
**Changes**: New file. Sourced from `.zshrc`. Defines the `tix` shell
function and its helpers.

```zsh
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
  local cfg path
  while IFS= read -r cfg; do
    [[ -r "$cfg" ]] || continue
    # Normalise backslashes to forward slashes before basename comparison,
    # then return the *original* path so the WSL converter below can detect
    # Windows paths.
    path="$(jq -r --arg name "$OBSIDIAN_VAULT_NAME" '
      .vaults // {}
      | to_entries[]
      | select(((.value.path // "") | gsub("\\\\"; "/") | split("/") | last) == $name)
      | .value.path
    ' "$cfg" 2>/dev/null | head -n1)"
    if [[ -n "$path" && "$path" != "null" ]]; then
      if [[ "$path" == *\\* || "$path" =~ '^[A-Za-z]:' ]]; then
        path="$(wslpath -u "$path" 2>/dev/null)" || path=""
      fi
      if [[ -n "$path" && -d "$path" ]]; then
        print -r -- "$path"
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
      # Filled in by Phase 2.
      print -r -- "tix init: not yet implemented" >&2
      return 2
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
```

#### 2. `.zshrc` — source the fragment
**File**: `.zshrc`
**Changes**: Add a one-line source after the `#### Aliases` block. Keep
the existing `home-squad` alias untouched.

```zsh
# After line 134 (the home-squad alias), add:

#### tix — single Obsidian vault planning store
[[ -r "$HOME/dot-scripts/tix/tix.zsh" ]] && source "$HOME/dot-scripts/tix/tix.zsh"
```

### Success Criteria:

#### Automated Verification:
- [ ] File exists and is non-empty: `test -s ~/dot-scripts/tix/tix.zsh`
- [ ] Sourcing the fragment in a fresh subshell succeeds:
      `zsh -c 'source ~/dot-scripts/tix/tix.zsh && type tix' | grep -q "tix is a shell function"`
- [ ] `.zshrc` contains the source line:
      `grep -q "dot-scripts/tix/tix.zsh" ~/.zshrc`
- [ ] `tix help` exits 0 and prints all five user-facing subcommands:
      `zsh -ic 'tix help' | grep -q "tix init"` and
      `zsh -ic 'tix help' | grep -q "tix reveal"` and
      `zsh -ic 'tix help' | grep -q "tix open"`
- [ ] Vault discovery succeeds when a synthetic registry names the vault:
      ```sh
      vault=$(mktemp -d) && cfg=$(mktemp -d)/obsidian.json && \
        printf '{"vaults":{"x":{"path":"%s"}}}\n' "$vault" > "$cfg" && \
        XDG_CONFIG_HOME="$(dirname "$cfg")/.." \
          OBSIDIAN_VAULT_NAME="$(basename "$vault")" \
          zsh -c 'source ~/dot-scripts/tix/tix.zsh
                  __tix_obsidian_config_files() { print -r -- "'"$cfg"'"; }
                  __tix_resolve_vault' | grep -qxF "$vault"
      ```
      (The override of `__tix_obsidian_config_files` keeps the test
      self-contained; verifies the jq parse + path resolution end-to-end.)
- [ ] Vault discovery fails loudly when `$OBSIDIAN_VAULT_NAME` is unset:
      `OBSIDIAN_VAULT_NAME= zsh -c 'source ~/dot-scripts/tix/tix.zsh && __tix_resolve_vault' 2>&1 | grep -q "OBSIDIAN_VAULT_NAME is not set"`
- [ ] Vault discovery fails loudly when the named vault is not in any
      registry:
      `OBSIDIAN_VAULT_NAME=does-not-exist zsh -c 'source ~/dot-scripts/tix/tix.zsh && __tix_resolve_vault' 2>&1 | grep -q "not found in any obsidian.json"`
- [ ] `tix path` returns `<vault>/repos/<basename-of-cwd>` using the
      synthetic-registry setup above:
      one-liner equivalent of the resolve-vault test, but invokes `tix path`
      from inside `/home/trik/dev/dot` and greps for `/repos/dot$`.
- [ ] `tix open` constructs a URI of the expected shape (no actual launch
      required; verify by stubbing the OS opener):
      ```sh
      OBSIDIAN_VAULT_NAME=MyVault zsh -c '
        source ~/dot-scripts/tix/tix.zsh
        open() { echo "CAPTURED: $*"; }
        xdg-open() { echo "CAPTURED: $*"; }
        cmd.exe() { echo "CAPTURED: $*"; }
        __tix_resolve_vault() { print -r -- /tmp/x; }
        __tix_repo_name() { print -r -- demo; }
        tix open' 2>&1 | grep -qE 'obsidian://open\?vault=MyVault&file=repos/demo'
      ```

#### Manual Verification:
- [ ] On the current WSL/Ubuntu machine, `tix open` launches Obsidian and
      focuses it on `repos/<repo>` inside the named vault.
- [ ] On the same machine, `tix reveal` opens Windows Explorer (via
      `wslview` or `cmd.exe /c start`) on the same directory.
- [ ] On macOS (if available), `tix open` brings Obsidian to the right
      folder; `tix reveal` opens Finder.
- [ ] On plain Linux (Kali / Ubuntu desktop), `tix open` triggers Obsidian
      via `xdg-open` against the URI; `tix reveal` opens the system file
      manager against the directory.

**Implementation Note**: After completing Phase 1 and all automated
verification passes, pause for manual confirmation that the OS opener works
on at least one target environment before proceeding to Phase 2.

---

## Phase 2: `tix init` — vault dir + symlink + git exclude

### Overview
Implement the `init` subcommand. It is idempotent: re-running it on a repo
that already has the symlink and exclude entry is a no-op.

### Changes Required:

#### 1. `dot-scripts/tix/tix.zsh` — replace the stubbed `init` branch
**File**: `dot-scripts/tix/tix.zsh`
**Changes**: Replace the stub `init)` case from Phase 1 with the real
implementation.

```zsh
    init)
      local repo_root vault repo_name target_dir link_path exclude_file
      repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        print -r -- "tix init: not inside a git repo" >&2 ; return 1
      }
      vault="$(__tix_resolve_vault)" || return 1
      repo_name="$(basename "$repo_root")"
      target_dir="${vault}/repos/${repo_name}"
      link_path="${repo_root}/tix"
      exclude_file="${repo_root}/.git/info/exclude"

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
      touch "$exclude_file"
      if ! grep -qxF '/tix' "$exclude_file"; then
        print -r -- '/tix' >> "$exclude_file"
      fi
      # If the user manually added an unanchored `tix` previously, leave it
      # alone — both forms exclude the root symlink, and removing the user's
      # line is out of scope for an idempotent init.

      print -r -- "tix init: ${link_path} -> ${target_dir}"
      ;;
```

### Success Criteria:

#### Automated Verification:
- [ ] Init in a clean throwaway repo creates the symlink and the
      root-anchored exclude line (uses the synthetic-registry pattern from
      Phase 1 to satisfy `__tix_resolve_vault`):
      ```sh
      tmp=$(mktemp -d) && cd "$tmp" && git init -q && \
        vault=$(mktemp -d) && cfg=$(mktemp -d)/obsidian.json && \
        printf '{"vaults":{"x":{"path":"%s"}}}\n' "$vault" > "$cfg" && \
        OBSIDIAN_VAULT_NAME="$(basename "$vault")" \
          zsh -ic "source ~/dot-scripts/tix/tix.zsh
                   __tix_obsidian_config_files() { print -r -- '$cfg'; }
                   tix init" && \
        test -L tix && \
        grep -qxF '/tix' .git/info/exclude && \
        [ -z "$(git status --porcelain)" ] && echo OK
      ```
      (expects to print `OK` — git status is empty because the symlink is
      excluded.)
- [ ] Re-running `tix init` in the same repo is idempotent (no second
      `/tix` line in exclude, symlink unchanged):
      `grep -c '^/tix$' .git/info/exclude` returns `1` before and after a
      second invocation.
- [ ] `git status` does not list `tix/` as untracked after init.
- [ ] If `./tix` already exists as a regular dir, init refuses with a
      clear error and exits non-zero (does not overwrite or move data).
- [ ] If `./tix` is a symlink to the wrong target, init refuses with a
      clear error and exits non-zero.

#### Manual Verification:
- [ ] After `tix init`, opening Claude Code in the repo and running a
      command that writes to `tix/plans/test.md` succeeds, the file appears
      in `<vault>/repos/<repo>/plans/test.md`, and `git status` stays
      clean.
- [ ] Same check in opencode.
- [ ] After `tix init`, `tix` (no args) cd's into the vault dir, and
      `tix open` launches Obsidian on the right folder.

**Implementation Note**: After Phase 2, pause for manual confirmation that
both Claude Code and opencode actually read/write through the symlink
without choking on `.gitignore`-style filtering before proceeding to
Phase 3.

---

## Phase 3: Migrate harness prompts — drop `thoughts/`, rename agents

### Overview
Update every prompt that references `thoughts/` to refer to `tix/`
instead. Rename the two `thoughts-*` agents to `tix-*` (file rename +
all in-prompt invocation strings). Update the `ci_commit` policy to
acknowledge that `tix/` is now a symlink hidden by `.git/info/exclude`,
not something to refuse to commit.

### Changes Required:

#### 1. Rename agent files
**Files**:
- `.claude/agents/thoughts-locator.md` → `.claude/agents/tix-locator.md`
- `.claude/agents/thoughts-analyzer.md` → `.claude/agents/tix-analyzer.md`
- `.config/opencode/agents/thoughts-locator.md` → `.config/opencode/agents/tix-locator.md`
- `.config/opencode/agents/thoughts-analyzer.md` → `.config/opencode/agents/tix-analyzer.md`

**Changes**: `git mv` each file. Inside each, update the `name:`
frontmatter field and every body reference from `thoughts-locator` /
`thoughts-analyzer` to `tix-locator` / `tix-analyzer`, and every
`thoughts/` path reference to `tix/`. Update the descriptions to read
"Discovers relevant documents in the `tix/` directory (the
Obsidian-vault-backed planning store)…".

#### 2. Update agent file bodies
**File**: `.claude/agents/tix-locator.md` (and opencode twin)
**Changes**:
- Drop all references to `thoughts/shared/`, `thoughts/allison/`,
  `thoughts/global/`, `thoughts/searchable/` — these were artefacts of a
  multi-user shared-thoughts tree. Replace with the single
  `tix/{plans,research,handoffs,mrs}/` layout that already exists in the
  harness commands.
- Replace example paths
  (`thoughts/allison/tickets/eng_1234.md`, etc.) with `tix/handoffs/...`
  or `tix/research/...` equivalents.

**File**: `.claude/agents/tix-analyzer.md` (and opencode twin)
**Changes**: Same substitutions; preserve all analyzer-specific
methodology.

#### 3. Update commands that invoke the renamed agents
**Files**:
- `.claude/commands/create_plan.md`
- `.claude/commands/research_codebase.md`
- `.claude/commands/iterate_plan.md`
- `.claude/commands/create_handoff.md`
- `.claude/commands/ci_commit.md`
- `.claude/commands/ci_describe_mr.md`
- `.claude/commands/describe_mr.md`
- `.config/opencode/command/create_plan.md`
- `.config/opencode/command/research_codebase.md`
- `.config/opencode/command/iterate_plan.md`
- `.config/opencode/command/resume_handoff.md`

**Changes** (apply to every file above):
- Replace `thoughts-locator` → `tix-locator` and `thoughts-analyzer` →
  `tix-analyzer` (both the `@`-prefixed opencode form and the bare
  Claude-Code form).
- Replace `thoughts/` path references with `tix/` equivalents:
  - `thoughts/allison/tickets/eng_XXXX.md` → `tix/handoffs/issue-XXXX/ticket.md`
    (or whichever subdir is appropriate per file context — see file-by-file
    list below).
  - `thoughts/shared/research/...` → `tix/research/...`
  - `thoughts/shared/plans/...` → `tix/plans/...`
  - `thoughts/shared/decisions/...` → `tix/research/...` (no separate
    decisions dir in the new layout).
- Delete the entire `thoughts/searchable/` mechanism description in
  `.claude/commands/research_codebase.md:199-204` and any opencode
  equivalent. With one vault, there is no "searchable mirror".
- In `.claude/commands/ci_commit.md:25`, replace
  `Never commit the thoughts/ directory or anything inside it!`
  with:
  `The repo-local 'tix' is a symlink into the Obsidian vault and is
   hidden by .git/info/exclude; never 'git add tix' or 'git add -f tix'.`
- In `.claude/commands/research_codebase.md` and its opencode twin,
  rename the `## Historical Context (from thoughts/)` template section to
  `## Historical Context (from tix/)` and update the description to point
  at `tix/research/` and `tix/handoffs/` rather than `thoughts/`.

#### 4. Spot-check files not in the grep hit list
**Files**: `.claude/commands/resume_handoff.md`, `.claude/commands/commit.md`,
`.claude/commands/implement_plan.md`, `.claude/commands/validate_plan.md`,
`.config/opencode/command/*.md` (any not already listed).
**Changes**: Grep each for `thoughts` and apply the same substitution rule
if anything turns up that the original sweep missed.

### Success Criteria:

#### Automated Verification:
- [ ] No file under `.claude/` or `.config/opencode/` contains the literal
      string `thoughts`:
      `! grep -r -l 'thoughts' .claude/ .config/opencode/`
- [ ] The two renamed agents exist under their new names:
      `test -f .claude/agents/tix-locator.md && test -f .claude/agents/tix-analyzer.md && test -f .config/opencode/agents/tix-locator.md && test -f .config/opencode/agents/tix-analyzer.md`
- [ ] The old agent filenames no longer exist:
      `! test -e .claude/agents/thoughts-locator.md && ! test -e .claude/agents/thoughts-analyzer.md`
- [ ] Each renamed agent file's `name:` frontmatter matches its new
      filename:
      `grep -q '^name: tix-locator' .claude/agents/tix-locator.md`
- [ ] `ci_commit.md` no longer contains "Never commit the thoughts/"
      directive: `! grep -q 'Never commit the thoughts' .claude/commands/ci_commit.md`
- [ ] `ci_commit.md` contains the new `git add tix` warning:
      `grep -q "never 'git add tix'" .claude/commands/ci_commit.md`

#### Manual Verification:
- [ ] Run `/research_codebase` (Claude Code) and confirm it invokes the
      `tix-locator` agent under the new name with no errors.
- [ ] Run the opencode equivalent and confirm the same.
- [ ] Open one of the updated command files in the harness and skim for
      grammatical artefacts left by mechanical substitution (e.g. doubled
      words, broken sentences where `thoughts/` was part of a noun phrase).

**Implementation Note**: After Phase 3, pause for manual confirmation that
the harness commands still run end-to-end with the renamed agents before
moving on to the live `dot`-repo migration in Phase 4.

---

## Phase 4: Migrate the `dot` repo to the new layout + bootstrap script

### Overview
Apply the new convention to the dotfiles repo itself, and add a one-shot
install script that automates Phases 1+2 on a new machine.

### Changes Required:

#### 1. New file: `dot-scripts/install/tix.sh`
**File**: `dot-scripts/install/tix.sh`
**Changes**: New file. One-shot setup for a new machine.

```sh
#!/bin/bash
# tix.sh — set up the single-Obsidian-vault planning store on this machine.
# Idempotent. Safe to re-run.

set -euo pipefail

# 1. Require $OBSIDIAN_VAULT_NAME — we resolve the absolute path at runtime
#    from Obsidian's per-machine registry, so this install does NOT need the
#    path itself, only the vault name.
if [ -z "${OBSIDIAN_VAULT_NAME:-}" ]; then
  echo "tix install: \$OBSIDIAN_VAULT_NAME is not set." >&2
  echo "  Export it to the name of your Obsidian vault and re-run, e.g.:" >&2
  echo "    OBSIDIAN_VAULT_NAME=MyVault bash dot-scripts/install/tix.sh" >&2
  exit 1
fi

# 2. jq is required by __tix_resolve_vault at runtime; warn now if missing.
if ! command -v jq >/dev/null 2>&1; then
  echo "tix install: jq not found. Install it before using 'tix' (apt install jq / brew install jq / pacman -S jq)." >&2
fi

# 3. Ensure .zshrc sources tix.zsh.
if ! grep -q 'dot-scripts/tix/tix.zsh' "$HOME/.zshrc"; then
  {
    echo ''
    echo '#### tix — single Obsidian vault planning store'
    echo '[[ -r "$HOME/dot-scripts/tix/tix.zsh" ]] && source "$HOME/dot-scripts/tix/tix.zsh"'
  } >> "$HOME/.zshrc"
fi

# 4. Persist OBSIDIAN_VAULT_NAME in .zshrc if it's not already set there.
if ! grep -q 'OBSIDIAN_VAULT_NAME=' "$HOME/.zshrc"; then
  printf 'export OBSIDIAN_VAULT_NAME=%q\n' "${OBSIDIAN_VAULT_NAME}" >> "$HOME/.zshrc"
fi

# 5. Eagerly resolve the vault now to fail fast on first install if the
#    name does not match anything in Obsidian's registry. This sources the
#    fragment in a subshell rather than relying on the user's .zshrc state.
if ! resolved=$(
  OBSIDIAN_VAULT_NAME="$OBSIDIAN_VAULT_NAME" \
    zsh -c "source $HOME/dot-scripts/tix/tix.zsh && __tix_resolve_vault" 2>&1
); then
  echo "tix install: could not resolve vault now, but .zshrc is configured." >&2
  echo "  Detail: $resolved" >&2
  echo "  Open Obsidian once with the '$OBSIDIAN_VAULT_NAME' vault, then re-run." >&2
  exit 1
fi

# 6. Ensure the per-repo root exists in the resolved vault.
mkdir -p "${resolved}/repos"

echo "tix install: vault='${OBSIDIAN_VAULT_NAME}' resolved to ${resolved}, .zshrc updated."
echo "  Open a new shell, cd into any repo, and run 'tix init'."
```

#### 2. Migrate the `dot` repo's existing committed `tix/`
**File**: working tree of `/home/trik/dev/dot`
**Changes**: One-time, performed by the user on their machine (this is a
documented manual step, not automated, because it touches the user's
vault):

1. Resolve the vault path once for the recipe:
   `vault=$(zsh -c 'source ~/dot-scripts/tix/tix.zsh && __tix_resolve_vault')`
2. Move existing content into the vault:
   `mkdir -p "$vault/repos/dot/research" "$vault/repos/dot/plans"`
   `mv tix/research/2026-06-18-obsidian-vault-multi-repo-planning.md "$vault/repos/dot/research/"`
   `mv tix/plans/2026-06-18-obsidian-vault-tix-symlink.md "$vault/repos/dot/plans/"`
   `mv tix/plans/tix-plan-critique.md "$vault/repos/dot/plans/"` (if present
   — this file was added during plan iteration and is also currently
   tracked or untracked under the old `tix/` tree).
3. Remove the now-empty `tix/` from tracking:
   `git rm -r tix/`
4. Run `tix init` to create the symlink and exclude entry.
5. Verify: `ls -la tix` shows the symlink; `git status` is clean; the moved
   docs are readable through the symlink path.

This step is documented as a checklist inside `dot-scripts/install/tix.sh`
output (the `echo` at the end already nudges the user toward `tix init`),
plus a one-paragraph block in this plan's References section.

#### 3. Idempotency edit to `.zshrc`
**File**: `.zshrc`
**Changes**: The Phase-1 source line is already added by hand-edit; the
new install script in step 1 above is the *bootstrap* path for a fresh
machine and must produce the same line. Confirm the two paths agree (same
exact line, same indentation, same quoting).

### Success Criteria:

#### Automated Verification:
- [ ] Install script exists and is executable: `test -x ~/dot-scripts/install/tix.sh`
- [ ] Running the install script on a machine that already has the setup
      is a no-op (does not duplicate the source line or the env-var export):
      ```sh
      OBSIDIAN_VAULT_NAME="$OBSIDIAN_VAULT_NAME" bash ~/dot-scripts/install/tix.sh && \
      OBSIDIAN_VAULT_NAME="$OBSIDIAN_VAULT_NAME" bash ~/dot-scripts/install/tix.sh && \
      [ "$(grep -c 'dot-scripts/tix/tix.zsh' ~/.zshrc)" -eq 1 ] && \
      [ "$(grep -c 'OBSIDIAN_VAULT_NAME=' ~/.zshrc)" -eq 1 ]
      ```
- [ ] After the migration, the `dot` repo's `tix` is a symlink to the
      vault:
      ```sh
      vault=$(zsh -c 'source ~/dot-scripts/tix/tix.zsh && __tix_resolve_vault') && \
      test -L ~/dev/dot/tix && \
      [ "$(readlink ~/dev/dot/tix)" = "${vault}/repos/dot" ]
      ```
- [ ] After the migration, `git -C ~/dev/dot status` is clean.
- [ ] After the migration, `git -C ~/dev/dot ls-files tix/` returns
      nothing (the directory is no longer tracked).
- [ ] The moved research doc is readable through the symlink:
      `test -r ~/dev/dot/tix/research/2026-06-18-obsidian-vault-multi-repo-planning.md`
- [ ] The moved plan is readable through the symlink:
      `test -r ~/dev/dot/tix/plans/2026-06-18-obsidian-vault-tix-symlink.md`

#### Manual Verification:
- [ ] On a second supported OS (Kali or macOS), run the install script
      against a freshly cloned `dot` repo; confirm `.zshrc` is updated,
      vault is set, and `tix init` in any other local repo produces a
      working symlink.
- [ ] Run `tix` (no args) inside the `dot` repo: cd's into
      `<vault>/repos/dot`.
- [ ] Open Claude Code in the `dot` repo and confirm it sees and can edit
      `tix/research/2026-06-18-obsidian-vault-multi-repo-planning.md`
      under its new home (read through the symlink).
- [ ] Same check in opencode.
- [ ] Commit the changes from this plan (the new `dot-scripts/tix/`
      directory, the `.zshrc` edit, the new install script, the harness
      prompt updates, the `tix/` removal) and confirm `git diff
      HEAD^ HEAD` does NOT contain the `tix/` directory tree — only the
      removal entry and the rest of the changes.

**Implementation Note**: Phase 4 is the live migration of the dotfiles
repo itself. After all automated checks pass, hold a manual confirmation
that nothing in the user's normal workflow has broken (especially any
existing scripts or aliases that assumed `tix/` was a real directory).

---

## Testing Strategy

### Unit Tests:
- Vault discovery: `$OBSIDIAN_VAULT_NAME` unset, `jq` missing, named vault
  not in registry, named vault present (Linux/macOS paths), and (on WSL)
  Windows path resolution via `wslpath`.
- Symlink creation: clean repo, repo where `./tix` already correctly
  points, repo where `./tix` is a stray dir, repo where `./tix` is a
  wrong-target symlink.
- `.git/info/exclude` idempotency.

### Integration Tests:
- Full Phase-2 flow in a `mktemp -d` throwaway repo (scripted as one of
  the automated success-criteria checks).
- Cross-shell: source `tix.zsh` in `zsh -c '...'` (non-interactive) and
  `zsh -ic '...'` (interactive); both must define `tix` and resolve
  paths.

### Manual Testing Steps:
1. **Bootstrap on a fresh shell**: open a brand new terminal, source
   `.zshrc`, run `tix help`. Should print the usage including `tix open`
   and `tix reveal`. Run `tix path` inside the `dot` repo, should print
   `<vault>/repos/dot` where `<vault>` is the path Obsidian has registered
   for `$OBSIDIAN_VAULT_NAME`.
2. **Per-repo init**: `cd` into a non-dot repo, run `tix init`, confirm
   the symlink, confirm `/tix` is present in `.git/info/exclude`, confirm
   `git status` is clean, confirm Claude Code sees `tix/`.
3. **OS coverage**: verify Phase 1 + Phase 2 on at least: WSL Ubuntu
   (current), macOS, Kali. Skip Debian and WSL/Debian if no machine
   available — they share the Ubuntu code path.
4. **Harness end-to-end**: in a repo with `tix init` done, run
   `/create_plan` (Claude Code). It should write to `tix/plans/...`,
   which lands in the vault. Then run the opencode `/create_plan` and
   confirm the same.

## Performance Considerations

`tix.zsh` is sourced once per shell startup; sourcing alone defines
functions but does no IO and is effectively free. `__tix_resolve_vault`
*runs* a `jq` invocation against one (or, on WSL, up to two) small JSON
files, but only when the user invokes a `tix` subcommand — never at shell
startup. The registry files are tens of KB at most, so a single `jq` parse
is sub-10 ms in practice. `git rev-parse --show-toplevel` runs only inside
`tix` invocations, not on every prompt. The Obsidian URI opener is fire-
and-forget. No measurable impact on shell responsiveness.

## Migration Notes

Existing repos that today have a tracked `tix/` directory will keep
working unchanged. The migration to symlink form is opt-in per repo
(via `tix init` after moving the existing content into the vault). The
documented migration recipe is exactly what Phase 4 performs on the `dot`
repo itself, so the dotfiles repo serves as the worked example for any
other repo the user wants to migrate later.

The `thoughts/` concept disappears entirely from the harness vocabulary
in Phase 3. Any external documents, scripts, or tickets that referenced
`thoughts/allison/tickets/...` will need to be updated by hand; this is
unavoidable and out of scope for this plan.

## References

- Original ticket: this conversation (no GitLab issue)
- Prior research: `tix/research/2026-06-18-obsidian-vault-multi-repo-planning.md`
  (will move to `<vault>/repos/dot/research/` during Phase 4)
- Plan critique that drove this iteration:
  `tix/plans/tix-plan-critique.md` (also moves to
  `<vault>/repos/dot/plans/` during Phase 4)
- Obsidian URI scheme: `obsidian://open?vault=<name>&file=<relpath>`
  (documented in Obsidian's help vault under "Using Obsidian URI").
- Obsidian registry locations: `~/.config/obsidian/obsidian.json` (Linux),
  `~/Library/Application Support/obsidian/obsidian.json` (macOS),
  `%APPDATA%/obsidian/obsidian.json` (Windows; reachable from WSL via
  `wslpath -u "$(cmd.exe /c 'echo %APPDATA%')"`).
- Existing bare-git bootstrap: `dot-scripts/install/config.sh:1-24`
- Existing alias-section pattern: `.zshrc:124-134`
- Existing `thoughts/` policy (to be replaced): `.claude/commands/ci_commit.md:25`
- Files touched in Phase 3 (full list above under "Current State Analysis")
