#!/bin/bash

# Run `make format` to format files
make format

# Add only modified files to the staging area
git diff --cached --name-only --diff-filter=ACMRTUXB | xargs git add

# Continue with the commit
exit 0
