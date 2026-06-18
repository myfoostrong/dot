# Review: Single Obsidian Vault as `tix/` Symlink — Implementation Plan

## What's well-designed

**`.git/info/exclude` over `.gitignore`** is the right call. Harness commands
see `tix/` as a normal directory, git ignores it locally, and no `.gitignore`
entry lands in anyone else's clone. A committed `.gitignore` entry would also
be honoured by the harnesses (which respect gitignore-style filtering), which
would break the whole point of the symlink.

**Shell function, not a standalone script.** The no-arg `cd` subcommand
requires the function to run in the parent shell's process — a child script
can't change the caller's cwd. The plan correctly identifies this and commits
to function form throughout.

**Phased structure with machine-executable success criteria.** Each `[ ]`
item in the success criteria is actually runnable, not just descriptive. The
phase ordering (build the tool → per-repo wiring → harness migration →
dogfood on the `dot` repo itself) means each phase is independently
testable before the next one depends on it.

**Dropping `searchable/` entirely.** That mechanism only existed to bridge
`thoughts/` and `tix/` as two physically separate trees. With a single
vault-backed `tix/`, there's nothing to mirror. Removing it rather than
re-implementing it is the right call.

**WSL opener branching.** The `/proc/version` + `microsoft` check, with
`wslview` preferred and `cmd.exe /c start` as fallback, covers the realistic
WSL surface area. The `wslpath -w` conversion before handing off to
`cmd.exe` is necessary and present.

---

## Things worth questioning before implementing

### Vault discovery: fallback path list

The `__tix_resolve_vault` function checks `$OBSIDIAN_VAULT` first, then
falls back to a hardcoded list of candidate directories (`~/vault`,
`~/docs/vault`, `~/Documents/vault`, `~/Obsidian/vault`,
`~/obsidian/vault`).

The failure mode to be aware of: if a machine has a directory that coincidentally
matches one of those paths but is not the intended vault, discovery silently
succeeds with the wrong path. The function has no way to distinguish "a vault
named `vault`" from "any directory named `vault`".

An alternative is to read Obsidian's own per-machine vault registry, which
tracks every known vault by name with its current absolute path:

- macOS: `~/Library/Application Support/obsidian/obsidian.json`
- Linux/WSL: `~/.config/obsidian/obsidian.json`

The registry entry format is `{ "vaults": { "<id>": { "path": "...", ... } } }`,
where the vault name is recoverable as `basename` of the `path` value. A
`jq` one-liner can resolve it: given `OBSIDIAN_VAULT_NAME="MyVault"`,
the correct path on any machine is:

```sh
jq -r --arg name "$OBSIDIAN_VAULT_NAME" \
  '.vaults | to_entries[]
   | select(.value.path | split("/") | last == $name)
   | .value.path' \
  "$obsidian_cfg" | head -n1
```

This requires `jq` (a reasonable dependency) and Obsidian having been opened
on the machine at least once — both true in the target environments. The
upside: no env var needed per machine, no chance of a path collision, and if
the vault is ever moved on disk Obsidian updates its own registry automatically.

The current approach (env var + fallback list) is simpler and works cleanly
when `$OBSIDIAN_VAULT` is set correctly. The tradeoff is: on a fresh machine
the user must set the env var or happen to keep the vault in one of the
candidate paths. Neither approach is strictly better; it's worth picking
deliberately.

### `tix open` opens a folder, not an Obsidian note

`open <dir>` on macOS opens Finder. `xdg-open <dir>` on Linux opens the
system file manager. Neither opens Obsidian focused on that folder.

If the intent is to open the planning folder *inside Obsidian*, the URI
scheme does this reliably across all platforms:

```
obsidian://open?vault=<vault-name>&file=repos/<repo-name>
```

Since `$OBSIDIAN_VAULT` is already resolved, the vault name is available as
`basename "$OBSIDIAN_VAULT"`. The opener would become:

```zsh
__tix_open() {
  local vault_name repo_name uri
  vault_name="$(basename "$OBSIDIAN_VAULT")"
  repo_name="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")"
  uri="obsidian://open?vault=${vault_name// /%20}&file=repos/${repo_name// /%20}"
  case "$OSTYPE" in
    darwin*) open "$uri" ;;
    linux*)
      if [[ -r /proc/version ]] && grep -qi microsoft /proc/version; then
        cmd.exe /c start "" "$uri" 2>/dev/null || wslview "$uri"
      else
        xdg-open "$uri" >/dev/null 2>&1 &
      fi ;;
  esac
}
```

This is only worth the added complexity if opening in Obsidian (rather than
the system file manager) is actually the desired behaviour for `tix open`.
Worth deciding explicitly.

### `.git/info/exclude` pattern matching depth

The pattern `tix` written into `.git/info/exclude` matches any file or
directory named `tix` at *any* depth in the working tree, not just at the
root. For most repos this is irrelevant, but worth noting if a project has
nested paths like `src/tix/` or test fixtures named `tix` — they'd be
silently excluded from git status too.

To restrict the pattern to the repo root only, use `/tix` (leading slash
anchors it). The init code would become:

```zsh
if ! grep -qxF '/tix' "$exclude_file"; then
  print -r -- '/tix' >> "$exclude_file"
fi
```

### `grep -qxF 'tix'` won't match `/tix` and vice versa

Related to the above: if someone has manually added `/tix` to their exclude
file before running `tix init`, the current idempotency check
(`grep -qxF 'tix'`) won't match it, and `tix` (without the slash) gets
appended as a second entry. Both entries work for exclusion purposes, but
the idempotency guarantee is technically broken. Normalising on one form
(preferably `/tix`) and checking for that exact string avoids the ambiguity.

---

## Minor notes

- The `wslview`/`cmd.exe` fallback order in `__tix_open` checks
  `command -v wslview` first, which is correct — `wslview` is the cleaner
  path when `wslu` is installed. The `cmd.exe /c start ""` fallback is the
  right safety net for machines where `wslu` isn't available.
- The install script's idempotency check for the `.zshrc` source line
  (`grep -q 'dot-scripts/tix/tix.zsh'`) is robust as long as the source
  line itself never changes. If the path to `tix.zsh` is ever reorganised,
  the grep would miss the old line. Low risk, just worth knowing.
- Phase 4's manual migration recipe (move files, `git rm -r tix/`, run
  `tix init`) is documented as the worked example for any future repo
  migration, which is a good pattern — the dotfiles repo serves as the
  canonical reference case.
