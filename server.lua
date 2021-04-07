local bitser = require'lib.bitser'
local socket = require'socket'
local json = require'lib.json'
require'common'

local conf = {
  auth = {
    doAuth = true,
    file = './server_data/users.json'
  }
}

local udp = socket.udp()
udp:setsockname("*", 42069)
udp:settimeout(0)

local emptyTable = bitser.dumps{}

local function randomToken()
  local str = {}
  for i=1,32 do
    local v = math.random(0,0xff)
    str[#str+1] = string.char(v)
  end
  return table.concat(str)
end
local function toPublicToken(str)
  return tostring(qhash(tostring(math.sqrt(qhash(str))))) --totally random lol
end

local events = server_events
local players = {}

local chr = string.char

local function getPublicPlayerData(v)
  return {
    pos = { x = v.pos.x, y = v.pos.y },
    ptk = v.ptk
  }
end

local function getPlayerDataStr(id) --(public)
  local l = {}
  for i,v in pairs(players) do
    if i~=id then
      l[v.ptk] = getPublicPlayerData(v)
    end
  end
  local dmp = bitser.dumps(l)
  local resp = chr(client_events.playerData)..bitser.dumps{dmp}
  return resp
end

local function updatePlayer(token)
  local player = players[token]
  local cev = chr(client_events.updatePlayer)
  local data = bitser.dumps(getPublicPlayerData(player))
  local res = cev..data
  for i,v in pairs(players) do
    if i~=token then
      udp:sendto(res, v.ip, v.port)
    end
  end
end

local function kickPlayer(token, reason)
  local p = players[token]
  if p then
    udp:sendto(
      chr(client_events.kicked)..bitser.dumps{reason},
      p.ip, p.port
    )
    for i,v in pairs(players) do
      --udp:sendto(getPlayerDataStr(i), v.ip, v.port)
      if i~=token then
        udp:sendto(
          chr(client_events.playerLeft)..bitser.dumps{p.ptk}, 
          v.ip, v.port
        )
      end
    end
    players[token] = nil
    print('kicked player!')
    return true
  else
    print('player is not on the server :<')
    return false
  end
end

local function verifyString(s, min, max)
  return type(s)=='string' and #s>=min and #s<=max
end

while true do
  local clk = os.clock()
  data, ip, port = udp:receivefrom()
  if type(data)=='string' and #data>0 then
    local ev,td = data:byte(1),bitser.loads(data:sub(2,#data))
    print(ev)
    if ev==events.join then
      local name,passwordHash = unpack(td)
      local ok,reason = true,nil
      --verify nickname
      if not verifyString(name, 3, 30) then
        ok,reason = false, 'invalid nickname'
      else
        local isOnServer = false
        for i,v in pairs(players) do
          if v.name==name then
            isOnServer = true
            break
          end
        end
        if isOnServer then
          ok,reason = false,'player already on server'
        elseif conf.auth.doAuth then
          --verify password
          if not(type(passwordHash)=='number') or passwordHash<0 then
            ok,reason = false, 'invalid password'
          end
          --read users file
          local f = io.open(conf.auth.file, 'rb')
          local d = f:read('*a')
          f:close()
          local users = json.decode(d)
          --check username/password
          if not(users[name]) then
            ok,reason = false, 'invalid username'
          elseif not(users[name] == passwordHash) then
            ok,reason = false, 'wrong password'
          end
        end
      end
      -- (true, token, pubicID) or (false, reason)
      local resp = chr(client_events.token)
      if ok then
        local tk = randomToken()
        local ptk = toPublicToken(tk)
        players[tk] = {
          pos = { x = 0, y = 0 },
          ip = ip,
          port = port,
          ptk = ptk,
          lastRefresh = clk,
          name = td[1]
        }
        resp = resp..bitser.dumps{true, tk, ptk} 
        print('player joined: ', name) --table.concat({tk:byte(1,#tk)},' ')
      else
        resp = resp..bitser.dumps{false, reason}
        print('failed join att ('..reason..')')
      end
      udp:sendto(resp, ip, port)
    elseif ev==events.move then
      local p = players[td[1]]
      if p then
        p.pos.x = tonumber(td[2]) or p.pos.x
        p.pos.y = tonumber(td[3]) or p.pos.y
        --announce player state change
        updatePlayer(td[1])
      end
    elseif ev==events.getPlayerData then
      if players[td[1]] then
        udp:sendto(getPlayerDataStr(td[1]), ip, port)
      end
    elseif ev==events.disconnect then
      if players[td[1]] then
        kickPlayer(td[1], 'disconnected')
      end
    elseif ev==events.ping then
      udp:sendto(
        chr(client_events.pong)..emptyTable, 
        ip, port
      )
    end
    local p = players[td[1]]
    if p then
      p.lastRefresh = clk
    end
  end
  for i,v in pairs(players) do
    if (clk - v.lastRefresh) > timeout then
      kickPlayer(i, 'Timeout!')
    end
  end
end