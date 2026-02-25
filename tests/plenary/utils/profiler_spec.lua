local Profiler = require('orgmode.utils.profiler')
local emit = require('orgmode.utils.emit')

-- Use unique category prefix to avoid conflicts with real orgmode events
local function cat(name)
  return 'test:profiler:' .. name
end

describe('Profiler', function()
  before_each(function()
    Profiler.clear()
    Profiler.setup({ enabled = true })
  end)

  after_each(function()
    Profiler.clear()
  end)

  describe('payload passthrough', function()
    it('preserves simple payload data', function()
      local c = cat('simple')
      emit.profile('start', c, 'started', { key = 'value' })

      local data = Profiler.get_data()
      assert.is_not_nil(data[c])
      assert.equals(1, #data[c].entries)
      assert.is_not_nil(data[c].entries[1].payload)
      assert.equals('value', data[c].entries[1].payload.key)
    end)

    it('preserves numeric payload values', function()
      local c = cat('numeric')
      emit.profile('start', c, 'started')
      emit.profile('mark', c, 'batch complete', {
        batch_num = 1,
        total_ms = 29.66,
        files_count = 12,
      })

      local data = Profiler.get_data()
      local entry = data[c].entries[2]
      assert.equals(1, entry.payload.batch_num)
      assert.equals(29.66, entry.payload.total_ms)
      assert.equals(12, entry.payload.files_count)
    end)

    it('preserves nested payload structures', function()
      local c = cat('nested')
      emit.profile('start', c, 'started', {
        metadata = {
          source = 'test',
          details = { a = 1, b = 2 },
        },
      })

      local data = Profiler.get_data()
      local payload = data[c].entries[1].payload
      assert.equals('test', payload.metadata.source)
      assert.equals(1, payload.metadata.details.a)
      assert.equals(2, payload.metadata.details.b)
    end)

    it('preserves batch timing payload (real use case)', function()
      -- This mirrors the actual batch payload from OrgFiles
      local c = cat('batch')
      emit.profile('start', c, 'loading', { total_files = 605 })
      emit.profile('mark', c, 'batch 1', {
        batch_num = 1,
        start_idx = 1,
        end_idx = 12,
        files_count = 12,
        total_ms = 23.1,
        mem_before_kb = 50000,
        mem_after_kb = 51200,
        mem_delta_kb = 1200,
      })
      emit.profile('complete', c, 'done', { total_ms = 156.8 })

      local data = Profiler.get_data()
      assert.equals(3, #data[c].entries)

      -- Start entry
      assert.equals(605, data[c].entries[1].payload.total_files)

      -- Batch entry
      local batch = data[c].entries[2].payload
      assert.equals(1, batch.batch_num)
      assert.equals(1, batch.start_idx)
      assert.equals(12, batch.end_idx)
      assert.equals(12, batch.files_count)
      assert.equals(23.1, batch.total_ms)
      assert.equals(1200, batch.mem_delta_kb)

      -- Complete entry
      assert.equals(156.8, data[c].entries[3].payload.total_ms)
    end)

    it('handles nil payload gracefully', function()
      local c = cat('nil_payload')
      emit.profile('start', c, 'started')
      emit.profile('mark', c, 'no payload')

      local data = Profiler.get_data()
      assert.equals(2, #data[c].entries)
      assert.is_nil(data[c].entries[1].payload)
      assert.is_nil(data[c].entries[2].payload)
    end)

    it('handles empty table payload', function()
      local c = cat('empty_payload')
      emit.profile('start', c, 'started', {})

      local data = Profiler.get_data()
      assert.is_not_nil(data[c].entries[1].payload)
      assert.are.same({}, data[c].entries[1].payload)
    end)
  end)

  describe('event ordering', function()
    it('captures events in emission order', function()
      local c = cat('order')
      emit.profile('start', c, 'first')
      emit.profile('mark', c, 'second')
      emit.profile('mark', c, 'third')
      emit.profile('complete', c, 'fourth')

      local data = Profiler.get_data()
      assert.equals(4, #data[c].entries)
      assert.equals('first', data[c].entries[1].label)
      assert.equals('second', data[c].entries[2].label)
      assert.equals('third', data[c].entries[3].label)
      assert.equals('fourth', data[c].entries[4].label)
    end)

    it('maintains order across interleaved categories', function()
      local c_a = cat('interleave_a')
      local c_b = cat('interleave_b')
      emit.profile('start', c_a, 'a1')
      emit.profile('start', c_b, 'b1')
      emit.profile('mark', c_a, 'a2')
      emit.profile('mark', c_b, 'b2')
      emit.profile('complete', c_a, 'a3')
      emit.profile('complete', c_b, 'b3')

      local data = Profiler.get_data()
      assert.equals('a1', data[c_a].entries[1].label)
      assert.equals('a2', data[c_a].entries[2].label)
      assert.equals('a3', data[c_a].entries[3].label)
      assert.equals('b1', data[c_b].entries[1].label)
      assert.equals('b2', data[c_b].entries[2].label)
      assert.equals('b3', data[c_b].entries[3].label)
    end)
  end)

  describe('timing monotonicity', function()
    it('total_ms always increases within a session', function()
      local c = cat('monotonic')
      emit.profile('start', c, 'start')
      vim.wait(5) -- small delay to ensure measurable time passes
      emit.profile('mark', c, 'mark1')
      vim.wait(5)
      emit.profile('mark', c, 'mark2')
      vim.wait(5)
      emit.profile('complete', c, 'end')

      local entries = Profiler.get_data()[c].entries
      for i = 2, #entries do
        assert.is_true(
          entries[i].total_ms >= entries[i - 1].total_ms,
          string.format(
            'Entry %d total_ms (%.2f) should be >= entry %d total_ms (%.2f)',
            i,
            entries[i].total_ms,
            i - 1,
            entries[i - 1].total_ms
          )
        )
      end
    end)

    it('first entry has total_ms of 0', function()
      local c = cat('first_zero')
      emit.profile('start', c, 'start')

      local entries = Profiler.get_data()[c].entries
      assert.equals(0, entries[1].total_ms)
    end)
  end)

  describe('delta calculation', function()
    it('delta_ms equals difference between consecutive total_ms', function()
      local c = cat('delta')
      emit.profile('start', c, 'start')
      vim.wait(10)
      emit.profile('mark', c, 'mark1')
      vim.wait(15)
      emit.profile('complete', c, 'end')

      local entries = Profiler.get_data()[c].entries
      for i = 2, #entries do
        local expected_delta = entries[i].total_ms - entries[i - 1].total_ms
        -- Allow small floating point tolerance
        assert.is_true(
          math.abs(entries[i].delta_ms - expected_delta) < 0.001,
          string.format('Entry %d delta_ms mismatch: got %.3f, expected %.3f', i, entries[i].delta_ms, expected_delta)
        )
      end
    end)

    it('first entry has delta_ms of 0', function()
      local c = cat('delta_first')
      emit.profile('start', c, 'start')

      local entries = Profiler.get_data()[c].entries
      assert.equals(0, entries[1].delta_ms)
    end)
  end)

  describe('section isolation', function()
    it('isolates categories into separate sessions', function()
      local c_init = cat('iso_init')
      local c_files = cat('iso_files')
      emit.profile('start', c_init, 'init start')
      emit.profile('start', c_files, 'files start')
      emit.profile('mark', c_init, 'init mark')
      emit.profile('mark', c_files, 'files mark')

      local data = Profiler.get_data()
      assert.equals(2, #data[c_init].entries)
      assert.equals(2, #data[c_files].entries)
      assert.equals('init mark', data[c_init].entries[2].label)
      assert.equals('files mark', data[c_files].entries[2].label)
    end)

    it('each category has independent timing', function()
      local c_fast = cat('timing_fast')
      local c_slow = cat('timing_slow')
      emit.profile('start', c_fast, 'start')
      emit.profile('complete', c_fast, 'end')

      vim.wait(50) -- delay before starting second category

      emit.profile('start', c_slow, 'start')
      emit.profile('complete', c_slow, 'end')

      local data = Profiler.get_data()
      -- Both should start at 0, regardless of wall clock
      assert.equals(0, data[c_fast].entries[1].total_ms)
      assert.equals(0, data[c_slow].entries[1].total_ms)
    end)
  end)

  describe('disabled state', function()
    it('does not capture events when disabled', function()
      local c = cat('disabled')
      Profiler.setup({ enabled = false })

      emit.profile('start', c, 'start')
      emit.profile('mark', c, 'mark')
      emit.profile('complete', c, 'end')

      local data = Profiler.get_data()
      assert.is_nil(data[c])
    end)
  end)
end)
