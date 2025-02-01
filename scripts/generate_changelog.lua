local function populate_section(content, name, list)
  if #list == 0 then
    return
  end
  content[#content + 1] = '*** ' .. name
  vim.list_extend(
    content,
    vim.tbl_map(function(item)
      return '- ' .. item
    end, list)
  )
  content[#content + 1] = ''
end

local function get_changes(latest_tag)
  if not latest_tag then
    latest_tag = vim.fn.system('git describe --tags `git rev-list --tags --max-count=1`'):gsub('\n', '')
  end
  local commits = vim.fn.systemlist('git log ' .. latest_tag .. "..master --pretty=format:'%s'")
  local fixes = {}
  local features = {}
  local breaking_changes = {}

  for _, commit in ipairs(commits) do
    local type = commit:match('^(.-):')
    if type then
      type = type
      local message = vim.trim(commit:sub(#type + 2))
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

  populate_section(content, 'Breaking changes', breaking_changes)
  populate_section(content, 'Features', features)
  populate_section(content, 'Bug fixes', fixes)

  return content
end

local function generate_changelog()
  local latest_tag = vim.fn.system('git describe --tags `git rev-list --tags --max-count=1`'):gsub('\n', '')
  local new_tag = arg[1]

  local new_content = {
    '** ' .. new_tag,
    '- Date: [[' .. os.date('%Y-%m-%d') .. ']]',
    ('- [[https://github.com/nvim-orgmode/orgmode/compare/%s...%s][Compare]]'):format(latest_tag, new_tag),
    ('- [[https://github.com/nvim-orgmode/orgmode/releases/tag/%s][Link to release]]'):format(new_tag),
    '',
  }
  vim.list_extend(new_content, get_changes(latest_tag))

  local changelog = vim.fn.readfile('./docs/changelog.org')
  local start = { unpack(changelog, 1, 2) }
  local remaining = { unpack(changelog, 3) }

  local new_changelog = vim.list_extend(start, new_content)
  new_changelog = vim.list_extend(new_changelog, remaining)

  vim.fn.writefile(new_changelog, './docs/changelog.org')
end

if arg[2] and arg[2] == 'print' then
  return io.write(table.concat(get_changes(), '\n'))
end

generate_changelog()
