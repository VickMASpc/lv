-- Robust and compact JSON library
-- Source: adapted from rxi/json.lua (MIT)
local json = { _version = "0.1.2" }

local encode

local escape_char_map = {
  [ "\\" ] = "\\\\", [ "\"" ] = "\\\"", [ "\b" ] = "\\b", [ "\f" ] = "\\f",
  [ "\n" ] = "\\n", [ "\r" ] = "\\r", [ "\t" ] = "\\t",
}

local function escape_char(c) return escape_char_map[c] or string.format("\\u%04x", c:byte()) end

local function encode_nil(val) return "null" end

local function encode_table(val, stack)
  local res = {}
  stack = stack or {}
  if stack[val] then error("circular reference") end
  stack[val] = true
  if rawget(val, 1) ~= nil or next(val) == nil then
    local n = 0
    for k in pairs(val) do
      if type(k) ~= "number" then n = -1; break end
      n = math.max(n, k)
    end
    if n ~= -1 then
      for i = 1, n do table.insert(res, encode(val[i], stack)) end
      stack[val] = nil
      return "[" .. table.concat(res, ",") .. "]"
    end
  end
  for k, v in pairs(val) do
    if type(k) ~= "string" then error("invalid table key type '" .. type(k) .. "'") end
    table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
  end
  stack[val] = nil
  return "{" .. table.concat(res, ",") .. "}"
end

local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end

local function encode_number(val)
  if val ~= val or val <= -math.huge or val >= math.huge then error("unexpected number value '" .. tostring(val) .. "'") end
  return string.format("%.14g", val)
end

local type_func_map = {
  [ "nil" ] = encode_nil, [ "table" ] = encode_table, [ "string" ] = encode_string,
  [ "number" ] = encode_number, [ "boolean" ] = tostring,
}

encode = function(val, stack)
  local t = type(val)
  local f = type_func_map[t]
  if f then return f(val, stack) end
  error("unexpected type '" .. t .. "'")
end

function json.encode(val) return (encode(val)) end

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do res[ select(i, ...) ] = true end
  return res
end

local space_chars = create_set(" ", "\t", "\r", "\n")
local delim_chars = create_set(" ", "\t", "\r", "\n", ",", "]", "}")
local escape_chars = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals = create_set("true", "false", "null")

local literal_map = { [ "true" ] = true, [ "false" ] = false, [ "null" ] = nil }

local function next_char(str, idx)
  for i = idx, #str do
    local c = str:sub(i, i)
    if not space_chars[c] then return c, i end
  end
  return nil, #str + 1
end

local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error(string.format("%s at line %d, col %d", msg, line_count, col_count))
end

local function parse_number(str, idx)
  local i = idx
  while i <= #str and not delim_chars[str:sub(i, i)] do i = i + 1 end
  local s = str:sub(idx, i - 1)
  local n = tonumber(s)
  if not n then decode_error(str, idx, "invalid number '" .. s .. "'") end
  return n, i
end

local function parse_literal(str, idx)
  local i = idx
  while i <= #str and not delim_chars[str:sub(i, i)] do i = i + 1 end
  local s = str:sub(idx, i - 1)
  if not literals[s] then decode_error(str, idx, "invalid literal '" .. s .. "'") end
  return literal_map[s], i
end

local function parse_string(str, idx)
  local res = ""
  local i = idx + 1
  while i <= #str do
    local c = str:sub(i, i)
    if c == '"' then return res, i + 1 end
    if c == "\\" then
      local next = str:sub(i + 1, i + 1)
      if not escape_chars[next] then decode_error(str, i, "invalid escape char '" .. next .. "'") end
      if next == "u" then
        local hex = str:sub(i + 2, i + 5)
        if not hex:find("^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") then decode_error(str, i, "invalid unicode escape '" .. hex .. "'") end
        res = res .. utf8.char(tonumber(hex, 16))
        i = i + 6
      else
        local map = { ["b"] = "\b", ["f"] = "\f", ["n"] = "\n", ["r"] = "\r", ["t"] = "\t" }
        res = res .. (map[next] or next)
        i = i + 2
      end
    else
      res = res .. c
      i = i + 1
    end
  end
  decode_error(str, idx, "expected closing quote for string")
end

local parse_value

local function parse_array(str, idx)
  local res = {}
  local i = idx + 1
  while true do
    local c, next = next_char(str, i)
    if not c then decode_error(str, i, "expected ']'") end
    if c == "]" then return res, next + 1 end
    local val, next = parse_value(str, next)
    table.insert(res, val)
    i = next
    c, next = next_char(str, i)
    if c == "]" then return res, next + 1 end
    if c ~= "," then decode_error(str, i, "expected ',' or ']'") end
    i = next + 1
  end
end

local function parse_object(str, idx)
  local res = {}
  local i = idx + 1
  while true do
    local c, next = next_char(str, i)
    if not c then decode_error(str, i, "expected '}'") end
    if c == "}" then return res, next + 1 end
    if c ~= '"' then decode_error(str, i, "expected string key") end
    local key, next = parse_string(str, next)
    c, next = next_char(str, next)
    if c ~= ":" then decode_error(str, i, "expected ':'") end
    local val, next = parse_value(str, next + 1)
    res[key] = val
    i = next
    c, next = next_char(str, i)
    if c == "}" then return res, next + 1 end
    if c ~= "," then decode_error(str, i, "expected ',' or '}'") end
    i = next + 1
  end
end

parse_value = function(str, idx)
  local c, i = next_char(str, idx)
  if not c then decode_error(str, idx, "unexpected end of string") end
  if c == "{" then return parse_object(str, i) end
  if c == "[" then return parse_array(str, i) end
  if c == '"' then return parse_string(str, i) end
  if c == "t" or c == "f" or c == "n" then return parse_literal(str, i) end
  return parse_number(str, i)
end

function json.decode(str)
  if type(str) ~= "string" then error("expected string argument, got " .. type(str)) end
  local val, idx = parse_value(str, 1)
  local c = next_char(str, idx)
  if c then decode_error(str, idx, "unexpected character after value") end
  return val
end

return json
