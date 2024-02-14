local Search = require('orgmode.files.elements.search')

describe('Search parser', function()
  it('should parse search term and check value value', function()
    local result = Search:new('TODO|PROJECT|MAYBE')
    assert.is.True(result:check({ tags = { 'TODO' } }))
    assert.is.True(result:check({ tags = { 'PROJECT' } }))
    assert.is.True(result:check({ tags = { 'MAYBE' } }))
    assert.is.False(result:check({ tags = { 'NOTIN', 'TAGLIST' } }))
    assert.is.False(result:check({ tags = { 'MISSING', 'FROMTAGLIST' } }))

    result = Search:new('+computer&+urgent')
    assert.is.True(result:check({ tags = { 'computer', 'urgent' } }))
    assert.is.True(result:check({ tags = { 'computer', 'urgent', 'test' } }))
    assert.is.False(result:check({ tags = { 'computer', 'test' } }))
    assert.is.False(result:check({ tags = { 'urgent' } }))

    result = Search:new('+computer|+urgent')
    assert.is.True(result:check({ tags = { 'computer', 'urgent' } }))
    assert.is.True(result:check({ tags = { 'computer', 'urgent', 'test' } }))
    assert.is.False(result:check({ tags = { 'badtag', 'test' } }))
    assert.is.False(result:check({ tags = { 'test' } }))

    result = Search:new('+computer&-urgent')
    assert.is.True(result:check({ tags = { 'computer', 'othertag' } }))
    assert.is.True(result:check({ tags = { 'computer' } }))
    assert.is.False(result:check({ tags = { 'computer', 'urgent' } }))
    assert.is.False(result:check({ tags = { 'computer', 'urgent', 'othertag' } }))
    assert.is.False(result:check({ tags = { 'urgent' } }))

    result = Search:new('+computer-urgent')
    assert.is.True(result:check({ tags = { 'computer', 'othertag' } }))
    assert.is.True(result:check({ tags = { 'computer' } }))
    assert.is.False(result:check({ tags = { 'computer', 'urgent' } }))
    assert.is.False(result:check({ tags = { 'computer', 'urgent', 'othertag' } }))
    assert.is.False(result:check({ tags = { 'urgent' } }))

    result = Search:new('computer-urgent')
    assert.is.True(result:check({ tags = { 'computer', 'othertag' } }))
    assert.is.True(result:check({ tags = { 'computer' } }))
    assert.is.False(result:check({ tags = { 'computer', 'urgent' } }))
    assert.is.False(result:check({ tags = { 'computer', 'urgent', 'othertag' } }))
    assert.is.False(result:check({ tags = { 'urgent' } }))

    result = Search:new('computer&email|work&email')
    assert.is.True(result:check({ tags = { 'computer', 'email', 'one', 'two' } }))
    assert.is.True(result:check({ tags = { 'work', 'email', 'three' } }))
    assert.is.False(result:check({ tags = { 'computer', 'one', 'two' } }))
    assert.is.False(result:check({ tags = { 'four', 'email', 'three' } }))

    result = Search:new('TODO|PROJECT|MAYBE')
    assert.is.True(result:check({ tags = 'TODO' }))
    assert.is.True(result:check({ tags = 'PROJECT' }))
    assert.is.False(result:check({ tags = 'OTHER' }))

    result = Search:new('TAGS|TWO+THREE-FOUR&FIVE')
    assert.are.same({
      {
        and_items = {
          {
            contains = {
              { value = 'TAGS' },
            },
            excludes = {},
          },
        },
      },
      {
        and_items = {
          {
            contains = {
              { value = 'TWO' },
              { value = 'THREE' },
            },
            excludes = {
              { value = 'FOUR' },
            },
          },
          {
            contains = {
              { value = 'FIVE' },
            },
            excludes = {},
          },
        },
      },
    }, result.or_items)

    assert.is.True(result:check({ tags = { 'TAGS', 'THREE' } }))
    assert.is.True(result:check({ tags = { 'TWO', 'THREE', 'FIVE' } }))
    assert.is.False(result:check({ tags = { 'TWO', 'THREE', 'FIVE', 'FOUR' } }))
    assert.is.False(result:check({ tags = { 'TWO', 'THREE' } }))
  end)

  it('should parse search term and match string properties and value', function()
    local result = Search:new('CATEGORY="test"&MYPROP="myval"+WORK')
    assert.is.True(result:check({
      props = { category = 'test', myprop = 'myval', age = 10 },
      tags = { 'WORK', 'OFFICE' },
    }))

    assert.is.False(result:check({
      props = { category = 'invalid', myprop = 'myval', age = 10 },
      tags = { 'WORK', 'OFFICE' },
    }))

    assert.is.False(result:check({
      props = { category = 'test', myprop = 'myval', age = 10 },
      tags = { 'OFFICE' },
    }))
  end)

  it('should parse search term and match number properties and value', function()
    local result = Search:new('PAGES>=1000&ITEMS<500&COUNT=10&CALCULATION<>5&BOOKS>3+WORK')
    assert.is.True(result:check({
      props = { pages = 1010, items = 100, count = 10, calculation = 8, books = 5 },
      tags = { 'WORK', 'OFFICE' },
    }))

    assert.is.True(result:check({
      props = { pages = 1000, items = 499, count = 10, calculation = 10, books = 4 },
      tags = { 'WORK' },
    }))

    assert.is.False(result:check({
      props = { pages = 999, items = 499, count = 10, calculation = 10, books = 4 },
      tags = { 'WORK' },
    }))

    assert.is.False(result:check({
      props = { pages = 1001, items = 500, count = 10, calculation = 10, books = 4 },
      tags = { 'WORK' },
    }))

    assert.is.False(result:check({
      props = { pages = 1001, items = 500, count = 11, calculation = 10, books = 4 },
      tags = { 'WORK' },
    }))

    assert.is.False(result:check({
      props = { pages = 1001, items = 500, count = 11, calculation = 5, books = 4 },
      tags = { 'WORK' },
    }))

    assert.is.False(result:check({
      props = { pages = 1001, items = 500, count = 11, calculation = 5, books = 3 },
      tags = { 'WORK' },
    }))

    assert.is.False(result:check({
      props = { pages = 1010, items = 100, count = 10, calculation = 8, books = 5 },
      tags = { 'OFFICE' },
    }))
  end)

  it('should search props, tags and todo keywords', function()
    local result = Search:new('CATEGORY="test"&MYPROP="myval"+WORK/TODO|NEXT')
    assert.is.True(result:check({
      props = { category = 'test', myprop = 'myval', age = 10 },
      tags = { 'WORK', 'OFFICE' },
      todo = 'TODO',
    }))
    assert.is.True(result:check({
      props = { category = 'test', myprop = 'myval', age = 10 },
      tags = { 'WORK', 'OFFICE' },
      todo = 'NEXT',
    }))
    assert.is.False(result:check({
      props = { category = 'test', myprop = 'myval', age = 10 },
      tags = { 'WORK', 'OFFICE' },
      todo = 'DONE',
    }))

    result = Search:new('CATEGORY="test"+WORK/-WAITING')
    assert.is.True(result:check({
      props = { category = 'test' },
      tags = { 'WORK' },
      todo = 'TODO',
    }))

    assert.is.True(result:check({
      props = { category = 'test' },
      tags = { 'WORK' },
      todo = 'DONE',
    }))

    assert.is.False(result:check({
      props = { category = 'test' },
      tags = { 'WORK' },
      todo = 'WAITING',
    }))

    assert.is.False(result:check({
      props = { category = 'test_bad' },
      tags = { 'WORK' },
      todo = 'DONE',
    }))

    assert.is.False(result:check({
      props = { category = 'test' },
      tags = { 'OFFICE' },
      todo = 'DONE',
    }))
  end)

  it('should parse allowed punctuation in tags', function()
    local result = Search:new('lang_dev|@work|org#mode|a2%')
    assert.is.True(result:check({ tags = { 'lang_dev' } }))
    assert.is.True(result:check({ tags = { '@work' } }))
    assert.is.True(result:check({ tags = { 'org#mode' } }))
    assert.is.True(result:check({ tags = { 'a2%' } }))
    assert.is.False(result:check({ tags = { 'lang', 'dev', 'work', 'org' } }))
    assert.is.False(result:check({ tags = { 'mode', 'a2' } }))
  end)
end)
