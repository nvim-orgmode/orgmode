Installation
============

Use your favourite package manager:

* `vim-packager <https://github.com/kristijanhusak/vim-packager>`_:


.. code-block:: lua

    packager.add('nvim-treesitter/nvim-treesitter')
    packager.add('nvim-orgmode/orgmode')

- `packer.nvim <https://github.com/wbthomason/packer.nvim>`_

**Recommended**


.. code-block:: lua

    use {'nvim-treesitter/nvim-treesitter'}
    use {'nvim-orgmode/orgmode', config = function()
            require('orgmode').setup{}
    end
    }

**Lazy loading (Not recommended)**

Lazy loading via ``ft`` option works, but not completely. Global mappings are not set because plugin is not initialized on startup.
Above setup has startup time of somewhere between 1 and 3 ms, so there are no many benefits in lazy loading.
If you want to do it anyway, here's the lazy load setup:

.. code-block:: lua

    use {'nvim-treesitter/nvim-treesitter'}
    use {'nvim-orgmode/orgmode',
        ft = {'org'},
        config = function()
                require('orgmode').setup{}
        end
        }

- `vim-plug <https://github.com/junegunn/vim-plug>`_


.. code-block:: lua

    Plug 'nvim-treesitter/nvim-treesitter'
    Plug 'nvim-orgmode/orgmode'

- `dein <https://github.com/Shougo/dein.vim>`_


.. code-block:: vim

    call dein#add('nvim-treesitter/nvim-treesitter')
    call dein#add('nvim-orgmode/orgmode')

