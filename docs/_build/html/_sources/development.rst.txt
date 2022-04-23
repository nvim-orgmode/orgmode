Development
========================================

Tests
************

To run tests, `plenary.nvim <https://github.com/nvim-lua/plenary.nvim>`_ is necessary. Once installed, run:

.. code-block:: bash

    make test

Documentation
************

Vim documentation is auto generated from `DOCS.md <DOCS.md>`_ file with `md2vim <https://github.com/FooSoft/md2vim>`_.

Formatting
************
Formatting is done via `StyLua <https://github.com/JohnnyMorganz/StyLua>`_. To format everything run:

.. code-block:: bash

    make format

Parser
************
Parsing is done via builtin tree-sitter parser and `tree-sitter-org <https://github.com/milisims/tree-sitter-org>`_ grammar.

