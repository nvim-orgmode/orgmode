#!/bin/bash

# Run `make format` to format files. Abort the commit if formatting fails,
# for example when stylua is not installed.
if ! make format; then
  echo "pre-commit: 'make format' failed; aborting commit." >&2
  exit 1
fi

# Add only modified files to the staging area
git diff --cached --name-only --diff-filter=ACMRTUXB | xargs git add

# Continue with the commit
exit 0
