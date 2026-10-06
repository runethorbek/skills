# Personal agent skills

This repository versions my personal agent skills.

## Layout

- `claude/` contains Claude Code skills and the agent definitions they require.
  - `claude/skills/<name>/SKILL.md` (plus any supporting files) for each skill.
  - `claude/agents/<name>.md` for each subagent a skill depends on
    (`build-slice` uses `slice-implementer` and `slice-reviewer`).

## Installation

Claude Code loads personal skills and agents from your home directory:

| Repository path         | Installed location               |
| ----------------------- | -------------------------------- |
| `claude/skills/<name>/` | `~/.claude/skills/<name>/`       |
| `claude/agents/<name>.md` | `~/.claude/agents/<name>.md`   |

On Windows, `~` is `%USERPROFILE%` (for example `C:\Users\<you>`).

## Source of truth

The copies in this repository are the source of truth. Edit skills here, not in
`~/.claude/`.

After changing a skill or agent in this repository, update the installed
personal copy. The change takes effect only after that. For example, from the
repository root:

```sh
cp -r claude/skills/. ~/.claude/skills/
cp claude/agents/*.md ~/.claude/agents/
```
