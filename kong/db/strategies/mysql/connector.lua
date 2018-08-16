local fmt = string.format


local mysql = require "kong.tools.mysql"

local setmetatable = setmetatable
local concat       = table.concat
--local pairs        = pairs
--local type         = type
local ngx          = ngx
local get_phase    = ngx.get_phase
local null         = ngx.null
local log          = ngx.log
local cjson        = require "cjson"
local cjson_safe = require "cjson.safe"


local WARN                          = ngx.WARN
local SQL_INFORMATION_SCHEMA_TABLES = [[
SELECT table_name
  FROM information_schema.tables
 WHERE table_schema = 'public';
]]

local function iterator(rows)
  local i = 0
  return function()
    i = i + 1
    return rows[i]
  end
end

local setkeepalive


local function connect(config)
  local phase  = get_phase()
  if phase == "init" or phase == "init_worker" or ngx.IS_CLI then
    -- Force LuaSocket usage in the CLI in order to allow for self-signed
    -- certificates to be trusted (via opts.cafile) in the resty-cli
    -- interpreter (no way to set lua_ssl_trusted_certificate).
    config.socket_type = "luasocket"

  else
    config.socket_type = "nginx"
  end

  local connection = mysql.new()

  connection.convert_null = true
  connection.NULL         = null

  local ok, err = connection:connect(config)
  if not ok then
    return nil, err
  end

  connection:set_timeout(3000)

  return connection
end

setkeepalive = function(connection)
  if not connection or not connection.sock then
    return nil, "no active connection"
  end

  local ok, err
  if connection.sock_type == "luasocket" then
    ok, err = connection:close()
    if not ok then
      if err then
        log(WARN, "unable to close mysql connection (", err, ")")

      else
        log(WARN, "unable to close mysql connection")
      end

      return nil, err
    end

  else
    ok, err = connection:set_keepalive(1000,10)
    if not ok then
      if err then
        log(WARN, "unable to set keepalive for mysql connection (", err, ")")

      else
        log(WARN, "unable to set keepalive for mysql connection")
      end

      return nil, err
    end
  end

  return true
end

local _mt = {}


_mt.__index = _mt


function _mt:connect()
  if self.connection and self.connection.sock then
    return true
  end

  local connection, err = connect(self.config)
  if not connection then
    return nil, err
  end

  self.connection = connection

  return true
end


function _mt:setkeepalive()
  local ok, err = setkeepalive(self.connection)

  self.connection = nil

  if not ok then
    return nil, err
  end

  return true
end


function _mt:query(sql)
  if self.connection and self.connection.sock then
    return self.connection:query(sql)
  end

  local connection, err = connect(self.config)
  if not connection then
    return nil, err
  end

  local res, err = connection:query(sql)
  if res and #res > 0 then
    for i=1,#res do
      if type(res[i]) == "table" then
        for k,v in pairs(res[i]) do
          if k == 'created_at' or k == 'updated_at' then
            local resTmpe,err = connection:query('SELECT UNIX_TIMESTAMP(\"' .. v .. '\") AS tmp;')
            if resTmpe and resTmpe[1] then
              res[i][k] = tonumber(resTmpe[1]['tmp'])
            end
          elseif type(v) == "string" then
            local m = cjson_safe.decode(v)
            if type(m) == "table" then
              res[i][k] = m
            end
          end
        end
      end
    end
  end

  setkeepalive(connection)

  return res, err
end


function _mt:iterate(sql)
  local res, err = self:query(sql)
  if not res then
    return nil, err, partial, num_queries
  end

  if res == true then
    return iterator { true }
  end

  return iterator(res)
end


function _mt:reset()
  local user = self:escape_identifier(self.config.user)
  local ok, err = self:query(concat {
    "BEGIN;\n",
    "DROP SCHEMA IF EXISTS public CASCADE;\n",
    "CREATE SCHEMA IF NOT EXISTS public AUTHORIZATION " .. user .. ";\n",
    "GRANT ALL ON SCHEMA public TO " .. user .. ";\n",
    "COMMIT;\n",
  })

  if not ok then
    return nil, err
  end

  --[[
  -- Disabled for now because migrations will run from the old DAO.
  -- Additionally, the purpose of `reset()` is to clean the database,
  -- and leave it blank. Migrations will use it to reset the database,
  -- and migrations will also be responsible for creating the necessary
  -- tables.
  local graph = tsort.new()
  local hash  = {}

  for _, strategy in pairs(strategies) do
    local schema = strategy.schema
    local name   = schema.name
    local fields = schema.fields

    hash[name]   = strategy
    graph:add(name)

    for _, field in ipairs(fields) do
      if field.type == "foreign" then
        graph:add(field.schema.name, name)
      end
    end
  end

  local sorted_strategies = graph:sort()

  for _, name in ipairs(sorted_strategies) do
    ok, err = hash[name]:create()
    if not ok then
      return nil, err
    end
  end
  --]]

  return true
end


function _mt:truncate()
  local i, table_names = 0, {}

  for row in self:iterate(SQL_INFORMATION_SCHEMA_TABLES) do
    local table_name = row.table_name
    if table_name ~= "schema_migrations" then
      i = i + 1
      table_names[i] = self:escape_identifier(table_name)
    end
  end

  if i == 0 then
    return true
  end

  local truncate_statement = {
    "TRUNCATE TABLE ", concat(table_names, ", "), " RESTART IDENTITY CASCADE;"
  }

  local ok, err = self:query(truncate_statement)
  if not ok then
    return nil, err
  end

  return true
end


local _M = {}

function _M.new(kong_config)
  local config = {
    host = kong_config.mysql_host,
    port = kong_config.mysql_port,
    user = kong_config.mysql_user,
    password = kong_config.mysql_password,
    database = kong_config.mysql_database,
    max_packet_size=1024*1024
  }

  local db = mysql.new()

  return setmetatable({
    config            = config,
    escape_identifier = db.escape_identifier,
    escape_literal    = db.escape_literal,
  }, _mt)
end


return _M
