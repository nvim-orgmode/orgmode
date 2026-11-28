local Agenda = require('orgmode.agenda')
local AgendaType = require('orgmode.agenda.types.agenda')
local AgendaView = require('orgmode.agenda.view.init')
local Files = require('orgmode.files')
local OrgFile = require('orgmode.files.file')
local Date = require('orgmode.objects.date')
local Promise = require('orgmode.utils.promise')
local stub = require('luassert.stub')
local spy = require('luassert.spy')

describe('Agenda preparation', function()
  ---@type string[]
  local paths
  ---@type OrgFiles
  local files

  before_each(function()
    paths = {}
    for i = 1, 2 do
      local path = vim.fn.tempname() .. '.org'
      vim.fn.writefile({
        '* TODO Task ' .. i,
        'SCHEDULED: <2026-10-15 Thu>',
        '* Archived :ARCHIVE:',
        '<2026-10-15 Thu>',
      }, path)
      table.insert(paths, path)
    end
    files = Files:new({ paths = paths })
  end)

  after_each(function()
    for _, path in ipairs(paths) do
      vim.fn.delete(path)
    end
  end)

  ---@param orgfiles OrgFiles
  ---@return OrgAgendaType
  local function new_view(orgfiles)
    return AgendaType:new({
      files = orgfiles,
      from = Date.from_string('2026-10-15'),
      span = 'day',
      start_on_weekday = false,
    })
  end

  it('loads files asynchronously and yields during headline scanning and date matching', function()
    local view = new_view(files)
    local clock = 0
    local phases = {}
    local phase = 'headlines'
    local original_yield = Promise.yield
    local original_matches = view._matches_filters
    local time_stub = stub(vim.uv, 'hrtime', function()
      clock = clock + 6000000
      return clock
    end)
    local yield_stub = stub(Promise, 'yield', function()
      phases[phase] = true
      return original_yield()
    end)
    view._matches_filters = function(self, headline)
      phase = 'dates'
      return original_matches(self, headline)
    end

    local event_processed = false
    local ok, err = pcall(function()
      local preparing = view:prepare()
      vim.defer_fn(function()
        event_processed = true
      end, 0)
      assert.are.equal(view, preparing:wait())
      assert.is.True(event_processed)
      assert.is.True(phases.headlines)
      assert.is.True(phases.dates)
      assert.are.equal(2, #view._agenda_days[1].agenda_items)
      assert.are.equal('Task 1', view._agenda_days[1].agenda_items[1].headline:get_title())
      assert.are.equal('Task 2', view._agenda_days[1].agenda_items[2].headline:get_title())
    end)
    time_stub:revert()
    yield_stub:revert()
    assert(ok, err)
  end)

  it('renders prepared results without scanning the files again', function()
    local view = new_view(files)
    view:prepare():wait()
    local collect_stub = stub(view, '_get_agenda_days', function()
      error('Agenda was scanned again during rendering')
    end)
    local render_stub = stub(AgendaView, 'render', function(self)
      return self
    end)
    local ok, err = pcall(function()
      view:render(0, 1)
      assert.is.Nil(view._agenda_days)
    end)
    collect_stub:revert()
    render_stub:revert()
    assert(ok, err)
  end)

  it('parses agenda files incrementally and skips archive files', function()
    local archive = vim.fn.tempname() .. '.org_archive'
    vim.fn.writefile({ '* Archived file', '<2026-10-15 Thu>' }, archive)
    table.insert(paths, archive)
    local view = new_view(files)
    local parse_spy = spy.on(OrgFile, 'parse_async')
    local ok, err = pcall(function()
      view:prepare():wait()
      assert.spy(parse_spy).was.called(2)
      assert.are.equal(2, #view._agenda_days[1].agenda_items)
    end)
    parse_spy:revert()
    assert(ok, err)
  end)

  it('yields while preparing files with thousands of lines', function()
    local lines = {}
    for i = 1, 1500 do
      table.insert(lines, '* TODO Task ' .. i)
      table.insert(lines, 'SCHEDULED: <2026-10-15 Thu>')
    end
    for _, path in ipairs(paths) do
      vim.fn.writefile(lines, path)
    end
    local view = new_view(files)
    local yield_spy = spy.on(Promise, 'yield')
    local ok, err = pcall(function()
      view:prepare():wait()
      assert.are.equal(3000, #view._agenda_days[1].agenda_items)
      assert.spy(yield_spy).was.called_at_least(1)
    end)
    yield_spy:revert()
    assert(ok, err)
  end)

  it('does not synchronously wait for custom agenda files in the constructor', function()
    local view = AgendaType:new({
      files = files,
      agenda_files = paths,
      from = Date.from_string('2026-10-15'),
      span = 'day',
      start_on_weekday = false,
    })
    assert.are.equal('loading', view.files.load_state)
    view:prepare():wait()
    assert.are.equal(2, #view._agenda_days[1].agenda_items)
  end)

  it('prepares again when navigating and refreshing the agenda', function()
    local view = new_view(files)
    view.view = {
      is_in_range = function()
        return true
      end,
    }
    local agenda = Agenda:new({ files = files })
    agenda.views = { view }
    local prepare_spy = spy.on(view, 'prepare')
    local render_stub = stub(agenda, 'render', function() end)
    local ok, err = pcall(function()
      agenda:advance_span(1):wait()
      assert.are.equal(0, #view._agenda_days[1].agenda_items)
      agenda:advance_span(-1):wait()
      assert.are.equal(2, #view._agenda_days[1].agenda_items)
      vim.fn.writefile({ '* TODO Replacement', 'SCHEDULED: <2026-10-15 Thu>' }, paths[1])
      agenda:redo():wait()
      assert.are.equal('Replacement', view._agenda_days[1].agenda_items[1].headline:get_title())
      assert.spy(prepare_spy).was.called(3)
    end)
    prepare_spy:revert()
    render_stub:revert()
    assert(ok, err)
  end)
end)
