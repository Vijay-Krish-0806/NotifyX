#!/usr/bin/env bash
# PreToolUse guard (Claude Code): block `git commit` while a .env file is staged.
# Wired in .claude/settings.json for the Bash and PowerShell tools.
# Exit 2 = block the tool call; stderr is shown to Claude as the reason.
# .gitignore is the first line of defense; this catches `git add -f .env`.
# Limits: best-effort only (it matches command text, so `git -C . commit` is
# not caught), and it cannot see files staged in the same command line.

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# Staged paths whose file name is .env or .env.<anything>, except .env.example.
staged=$(git diff --cached --name-only 2>/dev/null \
  | grep -E '(^|/)\.env(\..+)?$' \
  | grep -vE '(^|/)\.env\.example$')

if [ -n "$staged" ]; then
  {
    echo "Blocked: .env files are staged. Never commit .env files (CLAUDE.md, Git rules)."
    echo "Staged: $staged"
    echo "Unstage them with: git restore --staged <file>"
  } >&2
  exit 2
fi

exit 0
