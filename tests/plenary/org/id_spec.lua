describe('org id', function()
  local org_id = require('orgmode.org.id')
  it('should generate an id using uuid method', function()
    local uuid = org_id.new()
    assert.are.same(36, #uuid)
    assert.is.True(uuid:match('%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x') ~= nil)
  end)

  it('should validate an uuid', function()
    local valid_uuid = 'f47ac10b-58cc-4372-a567-0e02b2c3d479'
    assert.is.True(org_id.is_valid_uuid(valid_uuid))
    assert.is.False(org_id.is_valid_uuid(nil))
    assert.is.False(org_id.is_valid_uuid(''))
    assert.is.False(org_id.is_valid_uuid(' '))
    assert.is.False(org_id.is_valid_uuid('not an uuid'))
  end)

  it('should generate an id using "ts" method', function()
    require('orgmode').setup({
      org_id_method = 'ts',
    })
    local ts_id = org_id.new()
    assert.is.True(ts_id:match('%d%d%d%d%d%d%d%d%d%d%d%d%d%d') ~= nil)
    assert.is.True(ts_id:match(os.date('%Y%m%d%H')) ~= nil)
  end)

  it('should generate an id using "ts" method and custom format', function()
    require('orgmode').setup({
      org_id_method = 'ts',
      org_id_ts_format = '%Y_%m_%d_%H_%M_%S',
    })
    local ts_id = org_id.new()
    assert.is.True(ts_id:match('%d%d%d%d_%d%d_%d%d_%d%d_%d%d_%d%d') ~= nil)
    assert.is.True(ts_id:match(os.date('%Y_%m_%d_%H')) ~= nil)
  end)

  it('should generate an id using "org" format', function()
    require('orgmode').setup({
      org_id_method = 'org',
    })

    local oid = org_id.new()
    -- Ensure it does not generate a timestamp format
    assert.is.Nil(oid:match(os.date('%Y%m%d%H')))
    assert.is.True(oid:match('%d+') ~= nil)
    assert.is.True(oid:len() >= 1)
  end)

  it('should generate an id using "org" format with custom prefix', function()
    require('orgmode').setup({
      org_id_method = 'org',
      org_id_prefix = 'org_tests_',
    })

    local oid = org_id.new()
    -- Ensure it does not generate a timestamp format
    assert.is.Nil(oid:match('org_tests_' .. os.date('%Y%m%d%H')))
    assert.is.True(oid:match('org_tests_%d+') ~= nil)
    assert.is.True(oid:len() >= 11)
  end)
end)
