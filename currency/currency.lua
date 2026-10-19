_addon.name = 'currency'
_addon.author = 'Cromakre'
_addon.version = '1.1.0'
_addon.command = 'curr'

require('lists')
local packets = require('packets')
local file = require('files')

local incomingCurrencyMenu1 = 0x113
local incomingCurrencyMenu2 = 0x118

local outgoingCurrencyMenu1 = 0x10F
local outgoingCurrencyMenu2 = 0x115

local packetARecieved = false
local packetBRecieved = false

local currencyCache = {}

local function inject()
  packets.inject(packets.new('outgoing', outgoingCurrencyMenu1, {}))
  packets.inject(packets.new('outgoing', outgoingCurrencyMenu2, {}))
end

local function stripNames(str)
  local ret = string.lower(str)
  ret = string.gsub(ret, "[.'-]+", '')
  ret = string.gsub(ret, ' ', '')
  return ret
end

local function search(searchTerm)
  local results = {}
  for name, val in pairs(currencyCache) do
    local altered = stripNames(name)
    if string.match(altered, searchTerm) then
      results[name] = val
    end
  end
  local keys = {}
  for k in pairs(results) do
    table.insert(keys, k)
  end
  table.sort(keys)
  if #keys > 0 then
    for _, val in ipairs(keys) do
      windower.add_to_chat(4, val .. '   ' .. results[val])
    end
  else
    windower.add_to_chat(4, "Couldn't find " .. searchTerm)
  end
end

local function encase_key(key)
  if type(key) == 'number' then
    return '[' .. tostring(key) .. ']'
  elseif type(key) == 'string' then
    return '["' .. key .. '"]'
  else
    return tostring(key)
  end
end

local function make_table(data)
  local ret = 'return{'
  for k, v in pairs(data) do
    ret = ret .. encase_key(k) .. '='
    if type(v) == 'table' then
      ret = ret .. make_table(v) .. ','
    else
      ret = ret .. tostring(v) .. ','
    end
  end
  return ret .. '}'
end

local function saveData()
  local fileStr = make_table(currencyCache)
  local playerName = windower.ffxi.get_player().name
  local file = file.new('data\\' .. playerName .. '.lua')

  if not file:exists() then
    file:create()
  end

  file:write(fileStr)
  collectgarbage()
end

windower.register_event('addon command', function(...)
  if windower.ffxi.get_info().logged_in == false then
    windower.add_to_chat(4, 'You must be logged in to check currencies.')
    return
  end

  local args = L({ ... })
  if args[1] == 'help' then
    windower.add_to_chat(4, 'Usage:')
    windower.add_to_chat(
      4,
      [[
curr me <term>
> searches for currency that matches <term> for current character
> checks the game for currency saves it to a local file and
curr Cromakre <term>
> searches for currency that matches <term> for specific character
> reads from local files so it may not be up to date with the server
curr all <term>
> searches for currency that matches <term> for all known characters
> reads from local files so it may not be up to date with the server
]]
    )
    return
  end

  if args[1] == 'me' then
    inject()
    local searchTerm = stripNames(L({ ... }):slice(2):concat(' '))
    packetARecieved = false
    packetBRecieved = false
    windower.add_to_chat(4, 'Loading currency...')
    while not (packetARecieved and packetBRecieved) do
      -- use this so the game doesn't crash
      coroutine.sleep(0.01)
    end
    search(searchTerm)
    saveData()
  elseif args[1] == 'all' then
    for _, f in pairs(windower.get_dir(windower.addon_path .. '\\data')) do
      local name = f:sub(1, -5)
      if f:sub(-4) == '.lua' then
        local pass, data = pcall(dofile, windower.addon_path .. '\\data\\' .. f)
        if pass then
          for name, val in pairs(data) do
            currencyCache[name] = val
          end
          windower.add_to_chat(4, 'Loaded data for ' .. name)
          search(searchTerm)
        else
          windower.add_to_chat(4, "Couldn't load data for " .. f)
        end
      end
    end
  else
    local file = file.new('data\\' .. args[1] .. '.lua')
    if file:exists() then
      local pass, data = pcall(dofile, windower.addon_path .. '\\data\\' .. args[1] .. '.lua')
      if pass then
        for name, val in pairs(data) do
          currencyCache[name] = val
        end
        search(searchTerm)
      else
        windower.add_to_chat(4, "Couldn't load data for " .. args[1])
      end
    else
      windower.add_to_chat(4, "Couldn't find " .. args[1])
    end
  end
end)

windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
  if id == incomingCurrencyMenu1 or id == incomingCurrencyMenu2 then
    local data = packets.parse('incoming', original)
    for name, val in pairs(data) do
      if name ~= nil and not string.match(name, '^_') then
        currencyCache[name] = val
      end
    end
  end
  if id == incomingCurrencyMenu1 then
    packetARecieved = true
  end
  if id == incomingCurrencyMenu2 then
    packetBRecieved = true
  end
end)
