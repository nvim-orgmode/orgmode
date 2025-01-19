#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

DOCS_FILES=(
  "$SCRIPTPATH/../docs/configuration.org"
  "$SCRIPTPATH/../docs/troubleshoot.org"
)

pandoc \
  --shift-heading-level-by=0 \
  --metadata=project:orgmode \
  --metadata=vimversion:Neovim \
  --metadata=toc:true \
  '--metadata=description:Orgmode clone written in Lua for Neovim' \
  '--metadata=titledatepattern:%Y %B %d' \
  --metadata=dedupsubheadings:true \
  --metadata=ignorerawblocks:true \
  --metadata=docmapping:true \
  --metadata=docmappingproject:true \
  --metadata=treesitter:true \
  --metadata=incrementheadinglevelby:0 \
  -t $SCRIPTPATH/panvimdoc.lua \
  ${DOCS_FILES[@]} \
  -o $SCRIPTPATH/../doc/orgmode.txt
