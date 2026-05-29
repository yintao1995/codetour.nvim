local M = {}

local function find_all(text, pattern, build)
  local out = {}
  local init = 1
  while true do
    local s, e, c1, c2 = text:find(pattern, init)
    if not s then
      break
    end
    table.insert(out, build(s, e, c1, c2))
    init = e + 1
  end
  return out
end

function M.extract_links(text)
  local out = {}

  for _, l in ipairs(find_all(text, "%[([^%]]+)%]%[#(%d+)%]", function(s, e, label, step)
    return { kind = "step_ref", label = label, step = tonumber(step), text = text:sub(s, e), range = { s, e } }
  end)) do
    table.insert(out, l)
  end

  for _, l in ipairs(find_all(text, "%[#(%d+)%]", function(s, e, step)
    return { kind = "step_ref", step = tonumber(step), text = text:sub(s, e), range = { s, e } }
  end)) do
    local covered = false
    for _, o in ipairs(out) do
      if o.range[1] <= l.range[1] and o.range[2] >= l.range[2] then
        covered = true
        break
      end
    end
    if not covered then
      table.insert(out, l)
    end
  end

  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    local cmd = line:match("^%s*>>%s*(.+)$")
    if cmd then
      table.insert(out, { kind = "shell", command = cmd })
    end
  end

  for label, cmd in text:gmatch("%[([^%]]+)%]%(command:([^%)]+)%)") do
    table.insert(out, { kind = "command", label = label, command = cmd })
  end

  table.sort(out, function(a, b)
    return (a.range and a.range[1] or 0) < (b.range and b.range[1] or 0)
  end)
  return out
end

return M
