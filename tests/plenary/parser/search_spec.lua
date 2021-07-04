local Search = require('orgmode.parser.search')

describe('Search parser', function()
  it('should parse search term and check value value', function()
    local result = Search:new('TODO|PROJECT|MAYBE')
    assert.Is.True(result:check({ tags = {'TODO'} }))
    assert.Is.True(result:check({ tags = {'PROJECT'} }))
    assert.Is.True(result:check({ tags = {'MAYBE'} }))
    assert.Is.False(result:check({ tags = {'NOTIN', 'TAGLIST'} }))
    assert.Is.False(result:check({ tags = {'MISSING', 'FROMTAGLIST'} }))

    result = Search:new('+computer&+urgent')
    assert.Is.True(result:check({ tags = {'computer', 'urgent'} }))
    assert.Is.True(result:check({ tags = {'computer', 'urgent', 'test'} }))
    assert.Is.False(result:check({ tags = {'computer', 'test'} }))
    assert.Is.False(result:check({ tags = {'urgent'} }))

    result = Search:new('+computer|+urgent')
    assert.Is.True(result:check({ tags = {'computer', 'urgent'} }))
    assert.Is.True(result:check({ tags = {'computer', 'urgent', 'test'} }))
    assert.Is.False(result:check({ tags = {'badtag', 'test'} }))
    assert.Is.False(result:check({ tags = {'test'} }))

    result = Search:new('+computer&-urgent')
    assert.Is.True(result:check({ tags = {'computer', 'othertag'} }))
    assert.Is.True(result:check({ tags = {'computer'} }))
    assert.Is.False(result:check({ tags = {'computer', 'urgent'} }))
    assert.Is.False(result:check({ tags = {'computer', 'urgent', 'othertag'} }))
    assert.Is.False(result:check({ tags = {'urgent'} }))

    result = Search:new('+computer-urgent')
    assert.Is.True(result:check({ tags = {'computer', 'othertag'} }))
    assert.Is.True(result:check({ tags = {'computer'} }))
    assert.Is.False(result:check({ tags = {'computer', 'urgent'} }))
    assert.Is.False(result:check({ tags = {'computer', 'urgent', 'othertag'} }))
    assert.Is.False(result:check({ tags = {'urgent'} }))

    result = Search:new('computer-urgent')
    assert.Is.True(result:check({ tags = {'computer', 'othertag'} }))
    assert.Is.True(result:check({ tags = {'computer'} }))
    assert.Is.False(result:check({ tags = {'computer', 'urgent'} }))
    assert.Is.False(result:check({ tags = {'computer', 'urgent', 'othertag'} }))
    assert.Is.False(result:check({ tags = {'urgent'} }))

    result = Search:new('computer&email|work&email')
    assert.Is.True(result:check({ tags = {'computer', 'email', 'one', 'two'} }))
    assert.Is.True(result:check({ tags = {'work', 'email', 'three'} }))
    assert.Is.False(result:check({ tags = {'computer', 'one', 'two'} }))
    assert.Is.False(result:check({ tags = {'four', 'email', 'three'} }))

    result = Search:new('TODO|PROJECT|MAYBE')
    assert.Is.True(result:check({ tags = 'TODO' }))
    assert.Is.True(result:check({ tags = 'PROJECT' }))
    assert.Is.False(result:check({ tags = 'OTHER' }))

    result = Search:new('TAGS|TWO+THREE-FOUR&FIVE')
    assert.are.same({
      { contains = {'TAGS'}, excludes = {} },
      { contains = {'TWO', 'THREE', 'FIVE'}, excludes = {'FOUR'}}
    }, result.logic)

    assert.Is.True(result:check({ tags = {'TAGS', 'THREE'} }))
    assert.Is.True(result:check({ tags = {'TWO', 'THREE', 'FIVE'} }))
    assert.Is.False(result:check({ tags = {'TWO', 'THREE', 'FIVE', 'FOUR'} }))
    assert.Is.False(result:check({ tags = {'TWO', 'THREE'} }))
  end)

  it('should parse search term and match string properties and value', function()
    local result = Search:new('CATEGORY="test"&MYPROP=myval+WORK')
    assert.Is.True(result:check({
      props = { CATEGORY = 'test', MYPROP = 'myval', AGE = 10 },
      tags = {'WORK', 'OFFICE'},
    }))

    assert.Is.False(result:check({
      props = { CATEGORY = 'invalid', MYPROP = 'myval', AGE = 10 },
      tags = {'WORK', 'OFFICE'},
    }))

    assert.Is.False(result:check({
      props = { CATEGORY = 'test', MYPROP = 'myval', AGE = 10 },
      tags = {'OFFICE'},
    }))
  end)

  it('should parse search term and match number properties and value', function()
    local result = Search:new('PAGES>=1000&ITEMS<500&COUNT=10&CALCULATION<>5&BOOKS>3+WORK')
    assert.Is.True(result:check({
      props = { PAGES = 1010, ITEMS = 100, COUNT = 10, CALCULATION = 8, BOOKS = 5 },
      tags = {'WORK', 'OFFICE'},
    }))

    assert.Is.True(result:check({
      props = { PAGES = 1000, ITEMS = 499, COUNT = 10, CALCULATION = 10, BOOKS = 4 },
      tags = {'WORK'},
    }))

    assert.Is.False(result:check({
      props = { PAGES = 999, ITEMS = 499, COUNT = 10, CALCULATION = 10, BOOKS = 4 },
      tags = {'WORK'},
    }))

    assert.Is.False(result:check({
      props = { PAGES = 1001, ITEMS = 500, COUNT = 10, CALCULATION = 10, BOOKS = 4 },
      tags = {'WORK'},
    }))

    assert.Is.False(result:check({
      props = { PAGES = 1001, ITEMS = 500, COUNT = 11, CALCULATION = 10, BOOKS = 4 },
      tags = {'WORK'},
    }))

    assert.Is.False(result:check({
      props = { PAGES = 1001, ITEMS = 500, COUNT = 11, CALCULATION = 5, BOOKS = 4 },
      tags = {'WORK'},
    }))

    assert.Is.False(result:check({
      props = { PAGES = 1001, ITEMS = 500, COUNT = 11, CALCULATION = 5, BOOKS = 3 },
      tags = {'WORK'},
    }))

    assert.Is.False(result:check({
      props = { PAGES = 1010, ITEMS = 100, COUNT = 10, CALCULATION = 8, BOOKS = 5 },
      tags = {'OFFICE'},
    }))
  end)

  it('should search props, tags and todo keywords', function()
    local result = Search:new('CATEGORY="test"&MYPROP=myval+WORK/TODO|NEXT')
    assert.Is.True(result:check({
      props = { CATEGORY = 'test', MYPROP = 'myval', AGE = 10 },
      tags = {'WORK', 'OFFICE'},
      todo = {'TODO'}
    }))
    assert.Is.True(result:check({
      props = { CATEGORY = 'test', MYPROP = 'myval', AGE = 10 },
      tags = {'WORK', 'OFFICE'},
      todo = 'NEXT'
    }))
    assert.Is.False(result:check({
      props = { CATEGORY = 'test', MYPROP = 'myval', AGE = 10 },
      tags = {'WORK', 'OFFICE'},
      todo = {'DONE'}
    }))

    result = Search:new('CATEGORY="test"+WORK/-WAITING')
    assert.Is.True(result:check({
      props = { CATEGORY = 'test' },
      tags = {'WORK'},
      todo = {'TODO'}
    }))

    assert.Is.True(result:check({
      props = { CATEGORY = 'test' },
      tags = {'WORK'},
      todo = {'DONE'}
    }))

    assert.Is.False(result:check({
      props = { CATEGORY = 'test' },
      tags = {'WORK'},
      todo = {'WAITING'}
    }))

    assert.Is.False(result:check({
      props = { CATEGORY = 'test_bad' },
      tags = {'WORK'},
      todo = {'DONE'}
    }))

    assert.Is.False(result:check({
      props = { CATEGORY = 'test' },
      tags = {'OFFICE'},
      todo = {'DONE'}
    }))
  end)
end)
