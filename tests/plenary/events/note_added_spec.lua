local helpers = require('tests.plenary.helpers')
local EventManager = require('orgmode.events')
local Events = EventManager.event

describe('NoteAdded event', function()
  it('dispatches on add_note with correct payload', function()
    local file = helpers.create_file({ '* Headline 1' })
    file:reload_sync()
    local hl = file:get_headlines()[1]

    local received = {}
    EventManager.listen(Events.NoteAdded, function(ev)
      table.insert(received, ev)
    end)

    local note = { 'my note' }
    hl:add_note(note)

    assert.are.same(1, #received)
    local ev = received[1]
    assert.are.same('orgmode.note_added', ev.type)
    -- Compare stable attributes instead of object identity
    assert.are.same('Headline 1', ev.headline:get_title())
    assert.are.same(file.filename, ev.headline.file.filename)
    assert.are.same(note, ev.note)
  end)

  it('does not dispatch when note is nil', function()
    local file = helpers.create_file({ '* H' })
    file:reload_sync()
    local hl = file:get_headlines()[1]

    local called = false
    EventManager.listen(Events.NoteAdded, function()
      called = true
    end)

    hl:add_note(nil)
    assert.is_false(called)
  end)
end)
