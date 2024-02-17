# Contributing Guide

Thanks for wanting to help out with nvim-orgmode, we appreciate the effort!

## Reporting Bugs/Features

> :mega: Please always make a quick search in our [issue-tracker](https://github.com/nvim-orgmode/orgmode/issues) before reporting anything. If the bug/feature has already been reported, continue the conversation on the existing issue.

We distinguish between `core` (part of [orgmode](https://orgmode.org/)) and `non-core` features.
The former will be prioritized. Bugs get the highest priority.

If you're reporting a `core` feature, please be sure to provide a link that describes it. There are several places where features could be documented, have a look at these [resources](https://orgmode.org/worg/#resources). The more info you provide the better!

## Documentation

If you spot something missing in our [docs](DOCS.md), don't hesitate making a PR. The [wiki](https://github.com/nvim-orgmode/orgmode/wiki) can be edited freely.

## Local dev

Requirements:
- [StyLua](https://github.com/JohnnyMorganz/StyLua) - For formatting

To set up local development, run `make setup_dev`. This will add a pre-commit hook that will auto format all files before committing them.
You can always manually format all files with `make format` command

## Code

You can take a look at our [feature completeness](https://github.com/nvim-orgmode/orgmode/wiki/Feature-Completeness) list and see if any of the missing features catch your interest.

If you prefer working on an issue that has been reported, please leave a comment voicing your interest.

Please document any new code you add with [emmylua annotations](https://emmylua.github.io/annotation.html). Feel free to add annotations/docs to any existing functions integral to your PR that are missing them.

### Tests

 To run tests run `make test` in the nvim-orgmode directory:
```
make test
```

To run a specific test you can set a `FILE` environment variable to a specific
spec you want to test. Example:
```
make test FILE=./tests/plenary/api/api_spec.lua
```

### Parser

Parsing is done via builtin treesitter parser and the [tree-sitter-org](https://github.com/milisims/tree-sitter-org) grammar.
