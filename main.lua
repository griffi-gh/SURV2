local bitser = require'lib.bitser'
local socket = require'socket'
require'common'

local chr = string.char

local function kickmsg(reason)
  if reason=='disconnected' then return end
  love.window.showMessageBox("Kicked", "Reason: "..(reason or 'uknown'), "error", true)
end

local function Connection()
  local udp = socket.udp()
  udp:settimeout(0)
  local c = {udp = udp}
  function c:connect(ip, port)
    udp:setpeername(ip,port)
  end
  function c:join(login, password)
    local phash
    if password then
      phash = qhash(password)
    end
    self.udp:send(chr(server_events.join)..bitser.dumps{login, phash})
    self.lastRefresh = 0
    self.tmp = {}
    self.player = {
      x = 100, y = 100,
      px = math.huge, py = math.huge,
      name = login
    }
  end
  function c:disconnect()
    self.udp:send(chr(server_events.disconnect)..bitser.dumps{self.token})
  end
  function c:ping()
    self.udp:send(chr(server_events.ping)..bitser.dumps{self.token})
  end
  function c:requestPlayerData()
    self.udp:send(chr(server_events.getPlayerData)..bitser.dumps{self.token})
  end
  function c:move()
    self.udp:send(chr(server_events.move)..bitser.dumps{self.token,self.player.x,self.player.y})
  end
  function c:isReady()
    return self.connected and type(self.playerData)=='table'
  end
  function c:update(dt)
    local data = self.udp:receive()
    if type(data)=='string' and #data>0 then
      local e,t = data:byte(1),bitser.loads(data:sub(2,#data))
      if e==client_events.token then
        local ok = t[1]
        self.connected = ok
        if ok then
          self.token = t[2]
          self.publicID = t[3]
          self:requestPlayerData()
        else
          self.fail = t[2]
          kickmsg(t[2])
        end
      elseif e==client_events.playerData then
        self.playerData = bitser.loads(t[1])
      elseif e==client_events.updatePlayer then
        if self.playerData then
          self.playerData[t.ptk] = t
        end
      elseif e==client_events.kicked then
        self.connected = false
        kickmsg(t[1])
      elseif e==client_events.ping then
        self.udp:send(chr(server_events.pong)..bitser.dumps{self.token})
      elseif e==client_events.pong then
        self.lastRefresh = 0
        self.tmp.pinging = false
      elseif e==client_events.playerLeft then
        self.playerData[t[1]] = nil
      end
    end
    if self:isReady() then
      --send movement
      local p = self.player
      if p.x~=p.px or p.y~=p.py then
        p.px = p.x 
        p.py = p.y
        c:move()
      end
      --refresh/check timeout
      self.lastRefresh = self.lastRefresh + dt
      if self.tmp.pinging then
        if self.lastRefresh > timeout then
          self.connected = false
          kickmsg('Connection lost (timeout)')
        end
      elseif self.lastRefresh > timeout/2 then
        self.tmp.pinging = true
        self:ping()
      end
    end
  end
  return c
end

function love.load(arg)
  local ip,port,user,pass
  for i,v in ipairs(arg) do
    local t = split(v,'=')
    if t[1] == '--connect' then
      local a = split(t[2],':')
      ip = a[1]
      port = tonumber(a[2])
    elseif t[1] == '--user' then
      user = t[2]
    elseif t[1] == '--pass' then
      pass = t[2]
    end
  end
  conn = Connection()
  if ip and port then
    conn:connect(ip,port)
    if user then
      conn:join(user,pass)
    end
  end
end

function love.update(dt)
  conn:update(dt)
  if conn:isReady() then
    local p = conn.player
    local d = love.keyboard.isDown
    local spd = 100
    if    d'up' or d'w' then p.y = p.y-spd*dt end
    if  d'left' or d'a' then p.x = p.x-spd*dt end
    if  d'down' or d's' then p.y = p.y+spd*dt end
    if d'right' or d'd' then p.x = p.x+spd*dt end
  end
end

local function renderPlayer(x,y,n)
  local g = love.graphics
  g.print(n,math.floor(x),math.floor(y-18))
  g.rectangle('fill',x,y,30,30)
end

function love.draw()
  local g = love.graphics
  if conn:isReady() then
    for i,v in pairs(conn.playerData) do
      g.setColor(1,1,1)
      renderPlayer(v.pos.x,v.pos.y,v.name)
    end
    g.setColor(1,0,0)
    renderPlayer(conn.player.x,conn.player.y,conn.player.name)
  end
end

function love.quit(r)
  if conn and conn.connected then
    conn:disconnect()
  end
end