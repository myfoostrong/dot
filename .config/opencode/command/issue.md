---
description: Fetch a GitLab issue, create the associated branch, and save the ticket as markdown under tix/issues/
argument-hint: <issue-id-or-url> (e.g. 25, squad-api#25, or full GitLab URL)
---

# Fetch GitLab issue and create branch + ticket file

Argument: $ARGUMENTS

## Output contract (critical)

This command is invoked via `claude -p /issue ...` and its stdout is consumed by another CLI. **Your final assistant message MUST be exactly the relative path to the created markdown file and NOTHING else.** No prose, no markdown, no backticks, no leading/trailing whitespace beyond a single newline. Do all narration via tool calls only — never emit user-facing text during the run.

If anything fails, your final message must be exactly: `ERROR: <one-line reason>` and exit.

## Steps

1. **Parse the argument** into a form `glab` understands:
   - Pure integer like `25` → pass as-is (uses current repo's default).
   - `project#NN` (e.g. `squad-api#25`) → strip to `NN` and pass `-R <owner>/<project>` if you can infer owner from `glab repo view` or git remote; otherwise pass the shorthand directly to glab.
   - Full URL like `https://gitlab.com/foo_solutions/squad/squad-api/-/work_items/25` or `.../-/issues/25` → extract the numeric id at the end and the project path (everything between the host and `/-/`). Use `-R <project-path>` with the id.

2. **Fetch the issue as JSON** with:
   ```
   glab issue view <id> [-R <project-path>] --output json
   ```
   Parse `iid`, `title`, `description`, `web_url`, `state`, `labels`, `author.username`.

3. **Build the branch name** as `<iid>-<slug>` where `<slug>` is the title:
   - lowercased
   - non-alphanumerics replaced with `-`
   - collapsed repeated `-`, trimmed leading/trailing `-`
   - truncated to 60 chars total (including the `<iid>-` prefix), no trailing `-`

4. **Create/checkout the branch** from the current HEAD:
   - If the branch already exists locally: `git checkout <branch>`.
   - Else: `git checkout -b <branch>`.
   - If not inside a git repo, fail per the output contract.

5. **Write the markdown file** at `tix/issues/<branch>.md`. Create `tix/issues/` if missing. If the file already exists, overwrite it. Contents:

   ```
   ---
   id: <iid>
   url: <web_url>
   state: <state>
   author: <author.username>
   labels: [<comma-separated>]
   ---

   # <title>

   <description>
   ```

6. **Emit only the relative path** `tix/issues/<branch>.md` as your final message. Nothing else.
