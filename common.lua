function split(s, delimiter)
  result = {}
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
    table.insert(result, match)
  end
  return result
end
function qhash(str)
  local hash = 5381
  local wrap = 2^32
  for i=1,#str do
    hash = (hash * 33 + str:byte(i)) % wrap
  end
  return hash
end

timeout = 10

server_events = {
  ping = 0xff,
  pong = 0xfe,
  join = 0x01,
  move = 0x02,
  getPlayerData = 0x03,
  disconnect = 0x04,
}

client_events = {
  ping = 0xff,
  pong = 0xfe,
  token = 0x01,
  playerData = 0x02,
  updatePlayer = 0x03,
  kicked = 0x04,
  playerLeft = 0x05,
}