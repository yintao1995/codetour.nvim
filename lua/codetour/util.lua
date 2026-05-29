local M = {}

local function normalize(p)
  return (p:gsub("\\", "/"))
end

function M.expand_path(p)
  if p:sub(1, 1) == "~" then
    return vim.env.HOME .. p:sub(2)
  end
  return p
end

function M.relative_to(abs_path, root)
  abs_path = normalize(abs_path)
  root = normalize(M.expand_path(root))
  if root:sub(-1) ~= "/" then
    root = root .. "/"
  end
  if abs_path:sub(1, #root) == root then
    return abs_path:sub(#root + 1)
  end
  return nil
end

local TOUR_KEY_ORDER = {
  "$schema", "title", "description", "projectRoot",
  "ref", "isPrimary", "nextTour", "when", "steps",
}

local STEP_KEY_ORDER = {
  "file", "uri", "directory", "view", "contents", "language",
  "line", "pattern", "selection", "title", "description", "commands", "ref",
}

local function ordered_keys(tbl, hint)
  local seen = {}
  local out = {}
  for _, k in ipairs(hint or {}) do
    if tbl[k] ~= nil then
      table.insert(out, k)
      seen[k] = true
    end
  end
  local rest = {}
  for k, _ in pairs(tbl) do
    if type(k) == "string" and not seen[k] then
      table.insert(rest, k)
    end
  end
  table.sort(rest)
  for _, k in ipairs(rest) do
    table.insert(out, k)
  end
  return out
end

local function is_array(t)
  if type(t) ~= "table" then
    return false
  end
  if vim.tbl_isempty(t) then
    return getmetatable(t) and getmetatable(t).__jsontype == "array"
  end
  for k, _ in pairs(t) do
    if type(k) ~= "number" then
      return false
    end
  end
  return true
end

local function encode(value, depth, key_hint)
  local pad = string.rep("  ", depth)
  local pad_in = string.rep("  ", depth + 1)
  local t = type(value)
  if t == "nil" then
    return "null"
  elseif t == "boolean" or t == "number" then
    return tostring(value)
  elseif t == "string" then
    return vim.json.encode(value)
  elseif t == "table" then
    if is_array(value) then
      if #value == 0 then
        return "[]"
      end
      local parts = {}
      for i, v in ipairs(value) do
        parts[i] = pad_in .. encode(v, depth + 1, STEP_KEY_ORDER)
      end
      return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
    end
    local keys = ordered_keys(value, key_hint)
    if #keys == 0 then
      return "{}"
    end
    local parts = {}
    for _, k in ipairs(keys) do
      table.insert(parts, pad_in .. vim.json.encode(k) .. ": " .. encode(value[k], depth + 1))
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
  end
  error("cannot encode type " .. t)
end

function M.encode_pretty(tbl)
  return encode(tbl, 0, TOUR_KEY_ORDER) .. "\n"
end

function M.write_json(path, tbl)
  local content = M.encode_pretty(tbl)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local fd = assert(io.open(path, "w"))
  fd:write(content)
  fd:close()
end

function M.read_json(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil, "file not found: " .. path
  end
  local content = fd:read("*a")
  fd:close()
  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    return nil, data
  end
  return data
end

function M.git_ref(cwd)
  local res = vim.system(
    { "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" },
    { text = true }
  ):wait()
  if res.code ~= 0 then
    return nil
  end
  local ref = vim.trim(res.stdout or "")
  if ref == "" then
    return nil
  end
  return ref
end

return M
