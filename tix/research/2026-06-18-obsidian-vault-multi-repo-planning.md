---
date: 2026-06-18T10:55:48-04:00
researcher: Conor
git_commit: f5578ceef3692ab53a2e168f1a3e24fbfbcdd769
branch: main
repository: dot
topic: "Single Obsidian vault as the planning store for many repos — jump command, repo-local symlinks, cross-env reproducibility"
tags: [research, codebase, dotfiles, obsidian, harness, zsh, gitignore, symlinks]
status: complete
last_updated: 2026-06-18
last_updated_by: Conor
---

# Research: Single Obsidian vault as the planning store for many repos

**Date**: 2026-06-18T10:55:48-04:00
**Researcher**: Conor
**Git Commit**: f5578ceef3692ab53a2e168f1a3e24fbfbcdd769
**Branch**: main
**Repository**: dot

## Research Question

How does the current `dot` dotfiles repo handle the building blocks that the
proposed Obsidian-vault-for-planning setup would touch? Specifically:

- bootstrap / install mechanism across Ubuntu, Kali, WSL, macOS,
- shell (zsh) config and where a "jump" command would live,
- gitignore policy and the interplay with the coding harnesses (Claude
  Code, opencode) that reference planning docs,
- existing conventions for `thoughts/` and `tix/` directories that the
  harness commands already assume,
- any pre-existing symlink, OS-detection, or path-discovery infrastructure.

This document describes what exists today in the `dot` repository. It does not
propose a design.

## Summary

The `dot` repo today is a **bare-git-repo style dotfiles checkout** (the
"`config` alias" pattern) with hand-written per-OS install scripts. It contains
**no Obsidian, vault, symlink, jump-command, or OS-detection infrastructure**.

What it *does* contain that is directly relevant to the proposed setup:

- A bare-git bootstrap (`dot-scripts/install/config.sh`) that checks out files
  into `$HOME` and configures `status.showUntrackedFiles no` — the existing
  mechanism for "files present in `$HOME` but invisible to the dotfiles repo."
- A `~/.zshrc` with a dedicated **Aliases** section (lines 124-134) where
  per-machine shortcut commands like `home-squad` currently live — the natural
  location for a future jump command.
- A `~/.gitignore` whose only entry is `.DS_Store` (single line) — and a
  separate **explicit policy** in `.claude/commands/ci_commit.md:25` that
  reads "Never commit the `thoughts/` directory or anything inside it!"
- **Two parallel sets of harness config** under version control:
  - `.claude/commands/` + `.claude/agents/` (Claude Code)
  - `.config/opencode/command/` + `.config/opencode/agents/` (opencode)
  Both reference `thoughts/` and `tix/` paths as a fixed convention.
- A `tix/research/` directory (used by this document) and references in commands
  to `tix/plans/`, `tix/handoffs/issue-XXXX/`, `tix/mrs/`, and `tix/mr_description.md`.
- A stand-alone `ssh_tmux.sh` example of a portable, `set -euo pipefail`,
  POSIX-bash helper script wired into `.zshrc` via an alias (line 134).

There is **no** current code that:

- detects OS (`uname`, `OSTYPE`, `$(uname -s)`, etc. — zero matches outside of
  one commented `ARCHFLAGS` line at `.zshrc:106` and a Linux-specific AWS CLI
  URL at `dot-scripts/install/ubuntu-sudo.sh:42`),
- discovers or refers to an Obsidian vault,
- creates symlinks (neither `ln -s` nor `stow` appear anywhere),
- handles per-repo, non-committed harness artifacts beyond the global
  "don't commit `thoughts/`" rule.

## Detailed Findings

### Dotfiles install/checkout mechanism

The bootstrap script (`dot-scripts/install/config.sh:1-24`) uses the
**bare-git-repo dotfiles pattern**:

```bash
git init --bare $HOME/.myconf
git clone --bare https://github.com/myfoostrong/dot $HOME/.cfg
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
function config { /usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME $@ }
mkdir -p .config-backup
config checkout
# ...backs up pre-existing dotfiles if checkout would clobber them...
config checkout
config config status.showUntrackedFiles no
```

Consequences relevant to the vault question:

- Files in the repo are placed at their literal paths under `$HOME` (so
  `dot-scripts/` in the repo becomes `~/dot-scripts/`, `.claude/commands/` in
  the repo becomes `~/.claude/commands/`, etc.).
- There is **no per-file symlink farm** (no `stow`, no `dotbot`, no `chezmoi`).
- The `status.showUntrackedFiles no` setting (`config.sh:23`) is the
  established mechanism for keeping `$HOME` files out of `config status` output
  *without* listing them in `.gitignore`.
- The same `config` alias is re-exported in `.zshrc:129`, so it remains
  available after install.

The repo's own `.gitignore` (top level, single line) is just `.DS_Store`.

### Shell environment

`~/.zshrc` (verbatim layout):

- Lines 1-89: Oh-My-Zsh boilerplate. `ZSH_THEME=random`; `plugins=(git 1password aws docker nmap react-native terraform screen ubuntu poetry)`.
- Line 119: `export DEFAULT_USER=conor`.
- Line 122: `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"` —
  hard-codes the Linux Homebrew path; will not match the macOS default
  (`/opt/homebrew/bin/brew` on Apple Silicon, `/usr/local/bin/brew` on Intel).
- Lines 124-134: `#### Aliases` section. Current contents:
  ```sh
  alias tfp="terraform plan -var-file=envs/stag.tfvars"
  alias tfa="terraform apply -var-file=envs/stag.tfvars -auto-approve"
  alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
  alias c2c-start="$HOME/dot-scripts/aws/start-c2c.sh"
  alias ec2-term="$HOME/dot-scripts/aws/shutdown-instances.sh"
  alias home-squad="$HOME/ssh_tmux.sh kali@c2c.foo.solutions trik@localhost 9900 squad"
  ```
  All shell-script aliases use `$HOME/...` (no hard-coded `/home/conor`).
- Lines 136-141: `#### Path` section. `ANDROID_HOME` is set to
  `$HOME/Library/Android/Sdk` (macOS-style path), then `PATH` appends
  `/home/conor/.local/bin` (Linux-only, hard-coded username — does not use
  `$HOME`).

There is no Zsh function autoload directory in use, no `fpath` customisation,
and no `$ZSH_CUSTOM` override. Per-platform branching, where needed, would have
to be added (no precedent in the file).

### Per-OS install scripts

`dot-scripts/install/` is the install entry point. Each script targets a single
platform explicitly; there is no top-level dispatcher that switches on OS:

| File | Target |
|---|---|
| `config.sh` | Any (bare-git dotfiles bootstrap) |
| `brew.sh` | Linuxbrew (hard-codes `/home/linuxbrew/.linuxbrew/bin/brew` at line 3) — installs `asdf`, `opencode`, `hashicorp/tap/terraform`. |
| `asdf.sh` | Any (asdf-managed runtimes: nodejs, pnpm, python, uv, java) |
| `zsh.sh` | Any (`curl ... ohmyzsh/install.sh`) |
| `ubuntu-sudo.sh` | Debian/Ubuntu/Kali (uses `apt-get`, requires root, line 4 guards `EUID -ne 0`). Hard-codes `awscli-exe-linux-x86_64.zip` at line 42. |
| `elixir-sudo.sh` | Debian-family (apt-get build deps + kerl + asdf-elixir). Shebang is `#!/bin/zsh`. |

There is no macOS install script and no Windows/WSL-specific script. WSL would
use the Ubuntu/Debian script in practice.

A grep of the entire repo for `OSTYPE`, `uname`, `darwin`, `Darwin`,
`case * in`, `if [ ... OS`, etc. returns only:

- `.zshrc:106` — a commented-out `# export ARCHFLAGS="-arch $(uname -m)"`,
- `dot-scripts/install/ubuntu-sudo.sh:42` — a literal
  `awscli-exe-linux-x86_64.zip` URL,
- `dot-scripts/install/brew.sh:3` and similar — hard-coded Linuxbrew paths.

So the existing repo has **no runtime OS-detection pattern to reuse**.

### Example portable helper script: `ssh_tmux.sh`

`ssh_tmux.sh` (47 lines) is the closest analogue in-repo to "a small shell tool
wired into the dotfiles". Notable conventions visible there:

- `#!/bin/bash` shebang, `set -euo pipefail` (line 19).
- `usage()` function, `[ "$#" -eq N ] || usage` guard.
- Lives at the repo root (`$HOME/ssh_tmux.sh` after checkout) and is exposed via
  `.zshrc:134` as an alias.
- Header comment block documents both the manual sequence it replaces and a
  concrete example invocation.

### Coding harness configurations

Two parallel harness setups are versioned in this repo:

**Claude Code** — `.claude/`
- `.claude/commands/` (11 files): `commit.md`, `ci_commit.md`, `create_plan.md`,
  `iterate_plan.md`, `implement_plan.md`, `validate_plan.md`,
  `research_codebase.md`, `create_handoff.md`, `resume_handoff.md`,
  `describe_mr.md`, `ci_describe_mr.md`.
- `.claude/agents/` (6 files): `codebase-locator.md`, `codebase-analyzer.md`,
  `codebase-pattern-finder.md`, `thoughts-locator.md`, `thoughts-analyzer.md`,
  `web-search-researcher.md`.

**opencode** — `.config/opencode/`
- `opencode.json` (37 lines): model is `zai-coding-plan/glm-5.1`; declares
  `task-orchestrator`, `lookup`, and `developer` agents; `mcp: {}`.
- `.config/opencode/command/` (8 files; same families as `.claude/commands/`
  plus `parallel_implement.md`).
- `.config/opencode/agents/` (6 files; same as `.claude/agents/`).
- `.config/opencode/prompts/` — a tree of prompts including
  `prompts/task-orchestrator.md` (referenced from `opencode.json:18`).

Both harness sets share the same prompts/agents by content but live at fixed
relative paths that the harnesses themselves discover.

### Where the harness commands expect planning docs to live

The command files encode a fixed two-directory convention:

- `thoughts/` — personal notes, tickets, prior research, anything **historical**.
  References include:
  - `create_plan.md:30-31` — "invoke this command with a ticket file directly:
    `/create_plan thoughts/allison/tickets/eng_1234.md`".
  - `research_codebase.md:54-56,76-78,180,189,199-204` — extensive references;
    explicitly notes `thoughts/searchable/` as a hard-link mirror for
    grep-based search.
  - `ci_commit.md:25` — **"Never commit the `thoughts/` directory or anything
    inside it!"** This is the canonical "policy not gitignore" rule in the
    current repo.
  - `iterate_plan.md:77-78`, `resume_handoff.md`, `create_handoff.md:31` —
    further references.

- `tix/` — generated artifacts that **do** get committed. Subpaths in use:
  - `tix/research/YYYY-MM-DD-issue-XXXX-description.md`
    (`research_codebase.md:87`).
  - `tix/plans/YYYY-MM-DD-issue-XXXX-description.md`
    (`create_plan.md:172,284`, `implement_plan.md:2,7`, `iterate_plan.md`).
  - `tix/handoffs/issue-XXXX/YYYY-MM-DD_HH-MM-SS_issue-ZZZZ_description.md`
    (`create_handoff.md:13`, `resume_handoff.md:21`).
  - `tix/mrs/{number}_description.md` and `tix/mr_description.md`
    (`describe_mr.md:12-13,22-58`, `ci_describe_mr.md:12-13,22-57`).

The split is summarised in
`.claude/commands/research_codebase.md:199-204`:

```
thoughts/searchable/allison/old_stuff/notes.md → thoughts/allison/old_stuff/notes.md
thoughts/searchable/shared/mrs/123.md           → tix/mrs/123.md
thoughts/searchable/global/shared/templates.md  → thoughts/global/shared/templates.md
```

i.e. the harness convention treats `thoughts/` as a (logically external) store
of context, and `tix/` as the in-repo output area for plans, research and MR
descriptions.

### How the "don't commit thoughts/" rule is currently enforced

It is enforced **as policy in the harness prompt**, not via `.gitignore`:

- `.claude/commands/ci_commit.md:25` contains the literal directive
  "Never commit the `thoughts/` directory or anything inside it!".
- Neither the repo's own `~/.gitignore` (`.DS_Store` only) nor any global
  `core.excludesfile` in the repo encodes this rule.
- The bare-git bootstrap sets `status.showUntrackedFiles no`
  (`config.sh:23`), which hides any `thoughts/` directory that happens to
  appear under `$HOME` from `config status`.

In other words, the current setup already demonstrates a pattern of
"harness can see and reference `thoughts/`, but commits never include it" —
achieved through (a) directory location outside the tracked repo,
(b) per-prompt policy, and (c) the `showUntrackedFiles no` bare-git setting,
**not** through `.gitignore`.

### Memory / per-project state directory

The Claude Code per-project memory directory exists but is empty:

```
/home/trik/.claude/projects/-home-trik-dev-dot/memory/
```

No `MEMORY.md` and no individual memory files have been written for this
project yet.

### `tix/research/` current state

`tix/research/` exists and is empty (this document will be its first entry).
The `tix/plans/`, `tix/handoffs/`, `tix/mrs/`, and `thoughts/` directories
referenced by the harness commands do not exist on disk in this repo.

## Code References

- `dot-scripts/install/config.sh:1-24` — bare-git dotfiles bootstrap; sets
  `status.showUntrackedFiles no`.
- `dot-scripts/install/brew.sh:3` — hard-coded Linuxbrew path.
- `dot-scripts/install/asdf.sh:1-28` — asdf runtime installs.
- `dot-scripts/install/ubuntu-sudo.sh:1-79` — Debian/Ubuntu/Kali install;
  `EUID` guard at line 4, Linux-only AWS CLI URL at line 42.
- `dot-scripts/install/elixir-sudo.sh:1-16` — Debian-family Elixir install
  (shebang `#!/bin/zsh`).
- `dot-scripts/install/zsh.sh:1-5` — oh-my-zsh installer.
- `.zshrc:5` — `ZSH=$HOME/.oh-my-zsh`.
- `.zshrc:76-87` — plugins list.
- `.zshrc:119` — `export DEFAULT_USER=conor`.
- `.zshrc:122` — `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"`
  (Linux-only path).
- `.zshrc:124-134` — `#### Aliases` block; existing `home-squad` alias is the
  closest pattern to a future "jump" command.
- `.zshrc:138-141` — `#### Path` block; line 141 hard-codes
  `/home/conor/.local/bin`.
- `ssh_tmux.sh:1-39` — example of an in-repo bash helper wired via alias.
- `.gitignore:1` — single line: `.DS_Store`.
- `.config/opencode/opencode.json:1-37` — opencode runtime config.
- `.claude/commands/ci_commit.md:25` — "Never commit the `thoughts/`
  directory" policy.
- `.claude/commands/create_plan.md:30-31,41,172,274-275,284,433` — `thoughts/`
  and `tix/plans/` path conventions.
- `.claude/commands/research_codebase.md:54-56,76-78,87,144-148,180,189,199-204`
  — `thoughts/` vs `tix/research/` conventions including the
  `searchable/` hard-link mirror.
- `.claude/commands/resume_handoff.md:16-37` — `tix/handoffs/issue-XXXX/`
  layout.
- `.claude/commands/describe_mr.md:12-62`,
  `.claude/commands/ci_describe_mr.md:12-61` — `tix/mr_description.md` and
  `tix/mrs/{number}_description.md`.
- `.config/opencode/command/research_codebase.md:37`,
  `.config/opencode/command/create_plan.md:53,110-111`,
  `.config/opencode/command/iterate_plan.md:76-77`,
  `.config/opencode/command/resume_handoff.md:59-63` — same conventions on the
  opencode side, with the `@thoughts-locator` / `@thoughts-analyzer` agent
  invocation form.

## Architecture Documentation

The shape of the current system, as it pertains to the question:

1. **Distribution model**: bare-git checkout into `$HOME`. The entire repo is
   the work-tree; the index lives at `$HOME/.cfg/`. There is no symlink layer
   between repo and home directory.

2. **Cross-environment portability**: handled today by **separate scripts per
   OS family** rather than runtime detection. macOS is not represented;
   Linuxbrew paths are hard-coded into both `.zshrc` and `brew.sh`. WSL is
   covered implicitly by the Ubuntu/Debian path.

3. **Shell extension point**: the `#### Aliases` section of `~/.zshrc` is the
   sole, manually-curated location for shortcut commands. There is no
   `~/.zshrc.d/` directory, no `autoload -Uz` function dir in use, and no
   per-host or per-OS overlay file (e.g. no `~/.zshrc.local`).

4. **Harness/repo boundary for planning docs**: a two-directory split is
   already encoded across both Claude Code and opencode prompts:
   - `thoughts/` — historical / personal / external; **never committed**;
     visibility to the harness is achieved by physically existing on disk,
     enforced as policy rather than as ignore-rules.
   - `tix/` — generated artifacts; committed; subdirectories per artifact type
     (`research/`, `plans/`, `handoffs/issue-XXXX/`, `mrs/`).

5. **Gitignore vs harness visibility**: the existing repo already chose
   "policy + physical location" (`thoughts/` outside the tracked tree,
   `showUntrackedFiles no` in bare-repo config, hard rule in `ci_commit.md`)
   over `.gitignore`. This is the only precedent in the repo for the exact
   constraint the research question raises ("`.gitignore` usually hides files
   from the harness").

## Historical Context (from thoughts/)

No `thoughts/` directory exists in this checkout, and there are no prior
research documents in `tix/research/` (this is the first one). There is no
prior recorded context to draw on.

## Related Research

None — `tix/research/` was empty before this document.

## Open Questions

These are factual gaps in the current repo, surfaced by the question but not
answered by this codebase research:

- **Whether Obsidian Sync paths are stable enough across the supported
  environments** (`~/Documents/...` on macOS vs `~/docs/...` on Linux/WSL etc.)
  to be discoverable without configuration. The repo has no example of vault
  path discovery; this would need empirical confirmation per environment.
- **How Claude Code and opencode treat symbolic links pointing outside the
  repo root** (e.g. whether they follow symlinks, whether they apply
  `.gitignore` rules to symlink targets, whether they treat broken symlinks as
  errors). This is a runtime-behavior question not visible in the repo's
  current configuration.
- **Whether either harness honours `.git/info/exclude` differently from
  `.gitignore`** — relevant because `.git/info/exclude` is local-only and not
  committed, and could be a per-repo place to hide planning symlinks without
  modifying the tracked `.gitignore`. The current repo does not use this file.
