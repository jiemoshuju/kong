local utils  = require "kong.tools.utils"
local mysql = require "kong.tools.mysql"


local max          = math.max
local fmt          = string.format
local concat       = table.concat
local setmetatable = setmetatable
local new_tab
do
  local ok
  ok, new_tab = pcall(require, "table.new")
  if not ok then
    new_tab = function(narr, nrec) return {} end
  end
end


local INSERT_QUERY = [[
INSERT INTO cluster_events(id, node_id, at, nbf, expire_at, channel, data)
 VALUES(%s, %s, FROM_UNIXTIME(%f), FROM_UNIXTIME(%s), FROM_UNIXTIME(%s), %s, %s)
]]

local SELECT_INTERVAL_QUERY = [[
SELECT id, node_id, channel, data,at,nbf
FROM cluster_events
WHERE channel IN (%s)
  AND at >  FROM_UNIXTIME(%f)
  AND at <= FROM_UNIXTIME(%f)
]]


local _M = {}
local mt = { __index = _M }


function _M.new(dao_factory, page_size, event_ttl)
  local self  = {
    db        = dao_factory.db,
    --page_size = page_size,
    event_ttl = event_ttl,
  }

  return setmetatable(self, mt)
end


function _M:insert(node_id, channel, at, data, nbf)
  local expire_at = max(at + self.event_ttl, at)

  if not nbf then
    nbf = "NULL"
  end

  local pg_id      = ngx.quote_sql_str(utils.uuid())
  local pg_node_id = ngx.quote_sql_str(node_id)
  local pg_channel = ngx.quote_sql_str(channel)
  local pg_data    = ngx.quote_sql_str(data)

  local q = fmt(INSERT_QUERY, pg_id, pg_node_id, at, nbf, expire_at,
                pg_channel, pg_data)

  local res, err = self.db:query(q)
  if not res then
    return nil, "could not insert invalidation row: " .. err
  end

  return true
end


function _M:select_interval(channels, min_at, max_at)
  local n_chans = #channels
  local pg_channels = new_tab(n_chans, 0)

  for i = 1, n_chans do
    pg_channels[i] = mysql.escape_literal(channels[i])
  end

  local q = fmt(SELECT_INTERVAL_QUERY, concat(pg_channels, ","), min_at,
                max_at)

  local ran

  -- TODO: implement pagination for this strategy as
  -- well.
  --
  -- we need to behave like lua-cassandra's iteration:
  -- provide an iterator that enters the loop, with a
  -- page = 0 argument if there is no first page, and a
  -- page = 1 argument with the fetched rows elsewise

  return function(_, p_rows)
    if ran then
      return nil
    end

    local res, err = self.db:query(q)
    if not res then
      return nil, err
    end

    local page = #res > 0 and 1 or 0

    ran = true

    return res, err, page
  end
end


function _M:truncate_events()
  return self.db:query("TRUNCATE cluster_events")
end


return _M
