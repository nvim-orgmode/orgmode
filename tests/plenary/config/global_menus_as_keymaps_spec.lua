local config = require('orgmode.config')
local Promise = require('orgmode.utils.promise')
local Templates = require('orgmode.capture.templates')
local stub = require('luassert.stub')
local match = require('luassert.match')

local function get_map(lhs)
  local map = vim.fn.maparg(lhs, 'n', false, true)
  if vim.tbl_isempty(map) then
    return nil
  end
  return map
end

local function assert_label(lhs, desc)
  local map = get_map(lhs)
  assert.are.same({ rhs = '<Nop>', desc = desc }, { rhs = map and map.rhs, desc = map and map.desc })
end

describe('Global menus as keymaps', function()
  local registered = {}
  local default_mappings = vim.deepcopy(config.opts.mappings)
  local default_agenda_custom_commands = config.opts.org_agenda_custom_commands
  local default_capture_templates = config.opts.org_capture_templates
  local capture_templates = {
    t = { description = 'Task', template = '* TODO %?' },
    j = 'Journal',
    jd = { description = 'Daily', template = '* %?' },
    w = {
      description = 'Work',
      template = '* %?',
      subtemplates = { m = { description = 'Meeting', template = '* %?' } },
    },
  }

  local function setup(opts)
    local before = {}
    for _, map in ipairs(vim.api.nvim_get_keymap('n')) do
      before[map.lhs] = true
    end
    config:extend(opts)
    config:setup_mappings('global')
    for _, map in ipairs(vim.api.nvim_get_keymap('n')) do
      if not before[map.lhs] then
        table.insert(registered, map.lhs)
      end
    end
  end

  after_each(function()
    for _, lhs in ipairs(registered) do
      pcall(vim.keymap.del, 'n', lhs)
    end
    registered = {}
    config.opts.mappings = vim.deepcopy(default_mappings)
    config.opts.org_agenda_custom_commands = default_agenda_custom_commands
    config.opts.org_capture_templates = default_capture_templates
  end)

  it('keeps the agenda prompt on the agenda key when disabled', function()
    setup({ mappings = { global_menus_as_keymaps = false } })

    assert.are.same('org agenda', get_map('<Leader>oa').desc)
    assert.is_nil(get_map('<Leader>oaa'))
  end)

  it('does not load the agenda and capture modules on setup', function()
    local agenda_module, capture_module = package.loaded['orgmode.agenda'], package.loaded['orgmode.capture']
    package.loaded['orgmode.agenda'] = nil
    package.loaded['orgmode.capture'] = nil

    setup({ mappings = { global_menus_as_keymaps = true }, org_capture_templates = capture_templates })
    local loaded = { package.loaded['orgmode.agenda'], package.loaded['orgmode.capture'] }
    package.loaded['orgmode.agenda'], package.loaded['orgmode.capture'] = agenda_module, capture_module

    assert.are.same({}, loaded)
  end)

  it('waits for longer keymaps after each entry', function()
    setup({
      mappings = { global_menus_as_keymaps = true },
      org_agenda_custom_commands = { ab = { description = 'Extends a', types = { { type = 'agenda' } } } },
    })

    assert.are.same(0, get_map('<Leader>oaa').nowait)
    assert.are.same('Extends a', get_map('<Leader>oaab').desc)
  end)

  it('maps built-in agenda views under the agenda key when enabled', function()
    setup({ mappings = { global_menus_as_keymaps = true } })

    assert_label('<Leader>oa', 'org agenda')
    assert.are.same('Agenda for current week or day', get_map('<Leader>oaa').desc)
    assert.are.same('List of all TODO entries', get_map('<Leader>oat').desc)
    assert.are.same('Match a TAGS/PROP/TODO query', get_map('<Leader>oam').desc)
    assert.are.same('Like m, but only TODO entries', get_map('<Leader>oaM').desc)
    assert.are.same('Search for keywords', get_map('<Leader>oas').desc)
    assert.is_nil(get_map('<Leader>oaq'))
  end)

  it('labels the agenda key with the desc of the mapping', function()
    setup({ mappings = { global_menus_as_keymaps = true, global = { org_agenda = { '<prefix>a', desc = 'Agenda' } } } })

    assert_label('<Leader>oa', 'Agenda')
  end)

  it('maps custom agenda commands under the agenda key', function()
    setup({
      mappings = { global_menus_as_keymaps = true },
      org_agenda_custom_commands = {
        w = { description = 'Work', types = { { type = 'tags', match = '+work' } } },
        c = { types = { { type = 'agenda' }, { type = 'tags_todo', match = '+urgent' } } },
        a = { description = 'My agenda', types = { { type = 'agenda' } } },
      },
    })

    assert.are.same('Work', get_map('<Leader>oaw').desc)
    assert.are.same('agenda + tags_todo', get_map('<Leader>oac').desc)
    assert.are.same('My agenda', get_map('<Leader>oaa').desc)
  end)

  it('maps the views under every agenda key', function()
    setup({ mappings = { global_menus_as_keymaps = true, global = { org_agenda = { 'gA', '<prefix>a' } } } })

    assert_label('gA', 'org agenda')
    assert.are.same('Agenda for current week or day', get_map('gAa').desc)
    assert.are.same('Agenda for current week or day', get_map('<Leader>oaa').desc)
  end)

  it('maps no views when the agenda key is disabled', function()
    setup({ mappings = { global_menus_as_keymaps = true, global = { org_agenda = false } } })

    assert.is_nil(get_map('<Leader>oa'))
    assert.is_nil(get_map('<Leader>oaa'))
  end)

  it('opens the agenda view by its key', function()
    setup({ mappings = { global_menus_as_keymaps = true } })
    local agenda = require('orgmode').agenda
    local open_by_key = stub(agenda, 'open_by_key')

    get_map('<Leader>oat').callback()

    open_by_key:revert()
    assert.stub(open_by_key).was_called_with(match.is_ref(agenda), 't')
  end)

  it('opens the custom agenda command that shares a key with a built-in view', function()
    setup({
      mappings = { global_menus_as_keymaps = true },
      org_agenda_custom_commands = { a = { description = 'My agenda', types = { { type = 'agenda' } } } },
    })
    local agenda = require('orgmode').agenda
    local builtin = stub(agenda, 'agenda')
    local render = stub(agenda, 'prepare_and_render').returns(Promise.resolve())

    get_map('<Leader>oaa').callback()

    builtin:revert()
    render:revert()
    assert.stub(builtin).was_not_called()
    assert.stub(render).was_called(1)
  end)

  it('maps capture templates under the capture key', function()
    setup({ mappings = { global_menus_as_keymaps = true }, org_capture_templates = capture_templates })

    assert_label('<Leader>oc', 'org capture')
    assert.are.same('Task', get_map('<Leader>oct').desc)
    assert_label('<Leader>ocj', 'Journal')
    assert.are.same('Daily', get_map('<Leader>ocjd').desc)
    assert_label('<Leader>ocw', 'Work')
    assert.are.same('Meeting', get_map('<Leader>ocwm').desc)
  end)

  it('opens the capture template of the keymap', function()
    setup({ mappings = { global_menus_as_keymaps = true }, org_capture_templates = capture_templates })
    local capture = require('orgmode').capture
    capture.templates = Templates:new()
    local open_template = stub(capture, 'open_template')

    get_map('<Leader>ocjd').callback()
    get_map('<Leader>ocwm').callback()

    open_template:revert()
    assert.are.same('Daily', open_template.calls[1].vals[2].description)
    assert.are.same('Meeting', open_template.calls[2].vals[2].description)
  end)
end)
