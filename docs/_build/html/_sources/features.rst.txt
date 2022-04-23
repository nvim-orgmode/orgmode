Features
================================
TL;DR
*****************
* Agenda view
* Search by tags/keyword
* Clocking time
* Repeatable dates, date and time ranges
* Capturing to default notes file/destination
* Archiving (archive file or ARCHIVE tag)
* Exporting (via ``emacs``, ``pandoc`` and custom export options)
* Notifications (experimental, see `Issue #49 <https://github.com/nvim-orgmode/orgmode/issues/49>`_)
* Calendar popup for easier navigation and date updates
* Various org file mappings:

  * Promote/Demote
  * Change TODO state
  * Change dates
  * Insert/Move/Refile headlines
  * Change tags
  * Toggle checkbox state

* Clocking time
* Remote editing from agenda view
* Repeatable mapping via `vim-repeat <https://github.com/tpope/vim-repeat>`_

Detailed breakdown
******************************
* Agenda prompt:

  * Agenda view (``a``):

    * Ability to show daily(``vd``)/weekly(``vw``)/monthly(``vm``)/yearly(``vy``) agenda
    * Support for various date settings:

      * DEADLINE:  Warning settings - example:  `<2021-06-11 Fri 11:00 -1d>`
      * SCHEDULED: Delay setting - example: `<2021-06-11 Fri 11:00 -2d>`
      * All dates - Repeater settings:

        * Cumulate type: `<2021-06-11 Fri 11:00 +1w>`
        * Catch-up type: `<2021-06-11 Fri 11:00 ++1w>`
        * Restart type: `<2021-06-11 Fri 11:00 .+1w>`

      * Time ranges - example: `<2021-06-11 Fri 11:00-12:30>`
      * Date ranges - example: `<2021-06-11 Fri 11:00-12:30>--<2021-06-13 Sun 22:00>`

    * Properly lists tasks according to defined dates (DEADLINE,SCHEDULED,Plain date)
    * Navigate forward (``f``)/backward(``b``) or jump to specific date (``J``)
    * Go to task under cursor in current window(``<CR>``) or other window(``<TAB>``)
    * Print category from ":CATEGORY:" property if defined

  * List tasks that have "TODO" state (``t``):
  * Find headlines matching tag(s) (``m``):
  * Search for headlines (and it's content) for a query (``s``):
  * `Advanced search <DOCS.md#advanced-search>`_ for tags/todo kewords/properties
  * Notifications (experimental, see `Issue #49 <https://github.com/nvim-orgmode/orgmode/issues/49>`_)
  * Clocking time

* Capture:

  * Define custom templates
  * Fast capturing to default notes file via ``<C-c>``
  * Capturing to specific destination ``<Leader>or``
  * Abort capture with ``<Leader>ok``

* Org files

  * Clocking time
  * Refile to destination/headline: ``<Leader>or``
  * Increase/Decrease date under cursor: ``<C-a>``/``<C-x>``
  * Change date under cursor via calendar popup: ``cid``
  * Change headline TODO state: forward``cit`` or backward``ciT``
  * Open hyperlink or date under cursor: ``<Leader>oo``
  * Toggle checkbox: ``<C-space>``
  * Toggle current line to headline and vice versa: ``<Leader>o*``
  * Toggle folding of current headline: ``<TAB>``
  * Toggle folding in whole file: ``<S-TAB>``
  * Archive headline: ``<Leader>o$``
  * Add archive tag: ``<Leader>oA``
  * Change tags: ``<Leader>ot``
  * Promote headline: ``<<``
  * Demote headline: ``>>``
  * Promote subtree: ``<s``
  * Demote subtree: ``>s``
  * Add headline/list item/checkbox: ``<Leader><CR>``
  * Insert heading after current heading and it's content: ``<Leader>oih``
  * Insert TODO heading after current line: ``<Leader>oiT``
  * Insert TODO heading after current heading and it's content: ``<Leader>oit``
  * Move headline up: ``<Leader>oK``
  * Move headline down: ``<Leader>oJ``
  * Highlighted code blocks (`#+BEGIN_SRC filetype`)
  * Exporting (via ``emacs``, ``pandoc`` and custom export options)

Link to detailed documentation: `DOCS <https://github.com/nvim-orgmode/orgmode/blob/master/DOCS.md>`_
