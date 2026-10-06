# Personal agent skills

This repository versions my personal agent skills.

## Layout

- `claude/` contains Claude Code skills and the agent definitions they require.
  - `claude/skills/<name>/SKILL.md` (plus any supporting files) for each skill.
  - `claude/agents/<name>.md` for each subagent a skill depends on
    (`build-slice` uses `slice-implementer` and `slice-reviewer`).
- `install.ps1` installs or updates them in the personal Claude Code configuration.

## Source of truth

The copies in this repository are the source of truth. Edit skills and agents
here, not in `~/.claude/`. A change takes effect only after it is installed.

## Installation

Claude Code loads personal skills and agents from your home directory:

| Repository path           | Installed location           |
| ------------------------- | ---------------------------- |
| `claude/skills/<name>/`   | `~/.claude/skills/<name>/`   |
| `claude/agents/<name>.md` | `~/.claude/agents/<name>.md` |

On Windows, `~` is `%USERPROFILE%` (for example `C:\Users\<you>`).

`install.ps1` copies every file of every skill directory that contains a
`SKILL.md`, and every `*.md` file under `claude/agents/`, to those locations.
It works from any current directory and runs on Windows PowerShell 5.1.

It copies file by file and never deletes anything: other personal skills,
agents and settings under `~/.claude` are left alone. For each file it reports
one of:

- **installed**: the file did not exist yet and was copied;
- **updated**: the file differed and `-Force` replaced it;
- **unchanged**: the installed file is already identical (byte for byte);
- **conflicting**: the installed file differs and was left untouched.

The script exits with code 1 if no skills are found or a file cannot be copied.

### Preview

```powershell
.\install.ps1 -WhatIf
```

Lists every file that would be created or replaced, and the summary, without
changing anything.

### Install new files

```powershell
.\install.ps1
```

Copies files that are missing and skips identical ones. Installed files that
differ from this repository are reported as conflicts and not changed.

### Update changed installed files

```powershell
.\install.ps1 -Force
```

Replaces installed files that differ with the repository version. Use this
deliberately, after editing a skill or agent here.

A conflict usually means someone edited the installed copy under `~/.claude`
directly. `-Force` overwrites such edits. Before running it, compare the
installed file with the repository version and move any edits you want to keep
into this repository. `.\install.ps1 -WhatIf -Force` shows which files would be
replaced.

Note that the comparison is byte for byte, so an installed copy that differs
only in line endings (this repository uses LF) is also reported as a conflict.

### Testing against another directory

`-DestinationRoot` installs somewhere other than `$env:USERPROFILE\.claude`,
for example to try the script without touching the real configuration:

```powershell
.\install.ps1 -DestinationRoot "$env:TEMP\claude-test"
```

### Confirm the installation

To be sure the installed versions are loaded, check in a fresh Claude Code
session rather than one that was already running:

1. Start a new session with `claude`.
2. Type `/` and check that `/agent-ready`, `/build-slice` and `/draft-issue`
   are listed. These skills are invoked by name only; Claude does not start
   them on its own.
3. Run `/agents` and check that `slice-implementer` and `slice-reviewer` are
   listed as personal (user) agents.
