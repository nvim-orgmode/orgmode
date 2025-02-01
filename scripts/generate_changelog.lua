local function populate_section(content, name, list, format)
  if #list == 0 then
    return
  end
  local heading = format == 'md' and '### ' or '*** '
  content[#content + 1] = heading .. name
  vim.list_extend(
    content,
    vim.tbl_map(function(item)
      return '- ' .. item
    end, list)
  )
  content[#content + 1] = ''
end

---@param format 'org' | 'md'
---@param latest_tag? string
---@return string[]
local function get_changes(format, latest_tag)
  format = format or 'org'
  latest_tag = latest_tag or vim.fn.system('git describe --tags `git rev-list --tags --max-count=1`'):gsub('\n', '')
  local commit_format = '[[https://github.com/nvim-orgmode/orgmode/commit/%h][%h]]'
  if format == 'md' then
    commit_format = '[%h](https://github.com/nvim-orgmode/orgmode/commit/%h)'
  end
  local feature_format = format == 'md' and '**%s**' or '*%s*'

  local commits = vim.fn.systemlist(("git log %s..master --pretty=format:'%%s (%s)'"):format(latest_tag, commit_format))
  local fixes = {}
  local features = {}
  local breaking_changes = {}

  for _, commit in ipairs(commits) do
    local type = commit:match('^(.-):')
    if type then
      local feature = type:match('%((.-)%)')
      local message = vim.trim(commit:sub(#type + 2))
      if feature then
        message = ('%s: %s'):format(feature_format:format(feature), message)
      end
      if vim.endswith(type, '!') then
        table.insert(breaking_changes, message)
      elseif vim.startswith(type, 'fix') then
        table.insert(fixes, message)
      elseif vim.startswith(type, 'feat') or vim.startswith(type, 'feature') then
        table.insert(features, message)
      end
    end
  end
  local content = {}

  populate_section(content, 'Breaking changes', breaking_changes, format)
  populate_section(content, 'Features', features, format)
  populate_section(content, 'Bug fixes', fixes, format)

  return content
end

local function generate_changelog()
  local latest_tag = vim.fn.system('git describe --tags `git rev-list --tags --max-count=1`'):gsub('\n', '')
  local new_tag = arg[1]

  local new_content = {
    ('** [[https://github.com/nvim-orgmode/orgmode/compare/%s...%s][%s]] (%s)'):format(latest_tag, new_tag, new_tag, os.date('%Y-%m-%d')),
  }

  local changes = get_changes('org', latest_tag)
  if #changes == 0 then
    print('No changes since last release\n')
    return os.exit(1)
  end
  vim.list_extend(new_content, changes)

  local changelog = vim.fn.readfile('./docs/changelog.org')
  local start = { unpack(changelog, 1, 2) }
  local remaining = { unpack(changelog, 3) }

  local new_changelog = vim.list_extend(start, new_content)
  new_changelog = vim.list_extend(new_changelog, remaining)

  vim.fn.writefile(new_changelog, './docs/changelog.org')
  return os.exit()
end

if arg[2] and arg[2] == 'print' then
  return io.write(table.concat(get_changes('md'), '\n'))
end

generate_changelog()
