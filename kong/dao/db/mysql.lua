local mysql = require "kong.tools.mysql"
local Errors = require "kong.dao.errors"
local utils = require "kong.tools.utils"
local cjson = require "cjson"

local get_phase = ngx.get_phase
local timer_at = ngx.timer.at
local tostring = tostring
local ngx_log = ngx.log
local concat = table.concat
local ipairs = ipairs
local pairs = pairs
local match = string.match
local type = type
local find = string.find
local uuid = utils.uuid
local ceil = math.ceil
local fmt = string.format
local ERR = ngx.ERR

local TTL_CLEANUP_INTERVAL = 60 -- 1 minute

local function log(lvl, ...)
  return ngx_log(lvl, "[mysql] ", ...)
end

local _M = require("kong.dao.db").new_db("mysql")

_M.dao_insert_values = {
  id = function()
    return uuid()
  end
}

_M.additional_tables = {"ttls"}

function _M.new(kong_config)
  local self = _M.super.new()

  self.query_options = {
    host = kong_config.mysql_host,
    port = kong_config.mysql_port,
    user = kong_config.mysql_user,
    password = kong_config.mysql_password,
    database = kong_config.mysql_database,
    max_packet_size=1024*1024
  }

  return self
end

function _M:infos()
  return {
    db_name = "Mysql",
    desc = "database",
    name = self:clone_query_options().database,
    version = '5.5' or "unknown",
  }
end

local do_clean_ttl

function _M:init_worker()
  local ok, err = timer_at(TTL_CLEANUP_INTERVAL, do_clean_ttl, self)
  if not ok then
    log(ERR, "could not create TTL timer: ", err)
  end
 
  return true
end

--- TTL utils
-- @section ttl_utils

local cached_columns_types = {}

local function retrieve_primary_key_type(self, schema, table_name)
  local col_type = cached_columns_types[table_name]

  if not col_type then
    local query = fmt([[
      SELECT data_type,character_maximum_length
      FROM information_schema.columns
      WHERE table_name = '%s'
        and column_name = '%s'
      LIMIT 1]], table_name, schema.primary_key[1])

    local res, err = self:query(query)
    if not res then return nil, err
    elseif #res > 0 then
      local dtype = (res[1].data_type~=nil and res[1].data_type) or res[1].DATA_TYPE
      if dtype=="varchar" then
          local fieldLen = (res[1].character_maximum_length~=nil  and res[1].character_maximum_length) or res[1].CHARACTER_MAXIMUM_LENGTH
          dtype=(fieldLen==50 and "uuid") or "text"
      end
      col_type = dtype
      cached_columns_types[table_name] = col_type
    end
  end

  return col_type
end

local function ttl(self, tbl, table_name, schema, ttl)
  if not schema.primary_key or #schema.primary_key ~= 1 then
    return nil, "cannot set a TTL if the entity has no primary key, or has more than one primary key"
  end

  local primary_key_type, err = retrieve_primary_key_type(self, schema, table_name)
  if not primary_key_type then return nil, err end

  -- get current server time, in milliseconds, but with SECOND precision
  local query = [[
    SELECT UNIX_TIMESTAMP()*1000 as `timestamp`;
  ]]
  local res, err = self:query(query)
  if not res then return nil, err end

  -- the expiration is always based on the current time
  local expire_at = res[1].timestamp + (ttl * 1000)

  local query = fmt([[
    SELECT upsert_ttl('%s', %s, '%s', '%s', FROM_UNIXTIME(%d/1000) )
  ]], tbl[schema.primary_key[1]],
      primary_key_type == "uuid" and "'"..tbl[schema.primary_key[1]].."'" or "NULL",
      schema.primary_key[1], table_name, expire_at)
  local res, err = self:query(query)
  if not res then return nil, err end
  return true
end

local function clear_expired_ttl(self)
  local query = [[
    SELECT * FROM ttls WHERE expire_at < CURRENT_TIMESTAMP(0)
  ]]
  local res, err = self:query(query)
  if not res then return nil, err end

  for _, v in ipairs(res) do
    local delete_entity_query = fmt("DELETE FROM %s WHERE %s='%s'", v.table_name,
                                    v.primary_key_name, v.primary_key_value)
    local res, err = self:query(delete_entity_query)
    if not res then return nil, err end

    local delete_ttl_query = fmt([[
      DELETE FROM ttls
      WHERE primary_key_value='%s'
        AND table_name='%s']], v.primary_key_value, v.table_name)
    res, err = self:query(delete_ttl_query)
    if not res then return nil, err end
  end

  return true
end

-- for tests
_M.clear_expired_ttl = clear_expired_ttl

do_clean_ttl = function(premature, self)
  if premature then return end

  local ok, err = clear_expired_ttl(self)
  if not ok then
    log(ERR, "could not cleanup TTLs: ", err)
  end

  ok, err = timer_at(TTL_CLEANUP_INTERVAL, do_clean_ttl, self)
  if not ok then
    log(ERR, "could not create TTL timer: ", err)
  end
end

--- Query building
-- @section query_building

-- @see pgmoon
local function escape_identifier(ident)
  return '`' .. (tostring(ident):gsub('"', '""')) .. '`'
end

-- @see pgmoon
local function escape_literal(val, field)
  local t_val = type(val)
  if t_val == "number" then
    return tostring(val)
  elseif t_val == "string" then
    return "'" .. tostring((val:gsub("'", "''"))) .. "'"
  elseif t_val == "boolean" then
    return val and "TRUE" or "FALSE"
  elseif t_val == "table" and field and (field.type == "table" or field.type == "array") then
    return escape_literal(cjson.encode(val))
  end
  error("don't know how to escape value: " .. tostring(val))
end

local function get_where(tbl)
  local where = {}

  for col, value in pairs(tbl) do
    where[#where+1] = fmt("%s = %s",
                          escape_identifier(col),
                          escape_literal(value))
  end

  return concat(where, " AND ")
end

local function get_select_fields(schema)
  local fields = {}
  for k, v in pairs(schema.fields) do
    if v.type == "timestamp" then
      fields[#fields+1] = fmt(" UNIX_TIMESTAMP(%s)*1000 as `%s`", k, k)
    else
      fields[#fields+1] = '`' .. k .. '`'
    end
  end
  return concat(fields, ", ")
end

local function select_query(self, select_clause, schema, table, where, offset, limit)
  local query

  local join_ttl = schema.primary_key and #schema.primary_key == 1
  if join_ttl then
    local primary_key_type, err = retrieve_primary_key_type(self, schema, table)
    if not primary_key_type then return nil, err end

    query = fmt([[
      SELECT %s FROM %s
      LEFT OUTER JOIN ttls ON (%s.%s = ttls.primary_%s_value)
      WHERE (ttls.primary_key_value IS NULL
       OR (ttls.table_name = '%s' AND expire_at > CURRENT_TIMESTAMP(0) ))
    ]], select_clause, table, table, schema.primary_key[1],
        primary_key_type == "uuid" and "uuid" or "key", table)
  else
    query = fmt("SELECT %s FROM %s", select_clause, table)
  end

  if where then
    query = query .. (join_ttl and " AND " or " WHERE ") .. where
  end
  if limit then
    query = query .. " LIMIT " .. limit
  end
  if offset and offset > 0 then
    query = query .. " OFFSET " .. offset
  end
  return query
end

--- Querying
-- @section querying

local function parse_error(err_str)
  local err
  if find(err_str, "Key .* already exists") then
    local col, value = match(err_str, "%((.+)%)=%((.+)%)")
    if col then
      err = Errors.unique {[col] = value}
    end
  elseif find(err_str, "violates foreign key constraint") then
    local col, value = match(err_str, "%((.+)%)=%((.+)%)")
    if col then
      err = Errors.foreign {[col] = value}
    end
  end

  return err or Errors.db(err_str)
end

local function deserialize_rows(rows, schema)
  for i, row in ipairs(rows) do
    for col, value in pairs(row) do
      if  schema.fields[col].type=="boolean"  then
         
        rows[i][col] =  (value==1 and true) or false
      elseif type(value) == "string" and schema.fields[col] and
        (schema.fields[col].type == "table" or schema.fields[col].type == "array") then
        rows[i][col] = cjson.decode(value)
      end
      if  (value~=nil and cjson.encode(value)=="null" ) then
          rows[i][col]=nil
        end
    end
  end
end


function _M:query(query, schema)
  local conn_opts = self:clone_query_options()
  local my,err
  
    my, err = mysql:new()
    if not my then
          return nil,Errors.db(err)
    end
  my:set_timeout(3000) -- 3 sec
  local ok, err = my:connect(conn_opts)
  if not ok then
      return nil,Errors.db(err)
  end

  local  queryres  
  local  queryerr

  local query_type = type(query)
  if query_type == "table" then
    for sql_key, sql_value in pairs(query) do
       queryres, queryerr = my:query(sql_value,10)
      if queryres == nil and queryerr ~=nil then
          return nil, parse_error(queryerr)
      end
    end
  else
      queryres, queryerr = my:query(query,10)
  end
   
  if ngx and get_phase() ~= "init" then
      my:set_keepalive(10000, 10)
  else
      my:close()
  end
 
  if queryres == nil and queryerr ~=nil then
    return nil, parse_error(queryerr)

  elseif schema ~= nil and queryres ~=nil then
    deserialize_rows(queryres, schema)
  end

  if queryres==nil then
    queryres={}
  end
  return queryres
end

local function deserialize_timestamps(self, row, schema)
  local result = row
 if result ~=nil then
       
      for k, v in pairs(schema.fields) do
        if v.type == "timestamp" and result[k] then
        --  log(ERR,result[k])
        --  log(ERR,k)
          local query = fmt("SELECT   UNIX_TIMESTAMP('%s')*1000 as `%s`;", result[k], k)
          local res, err = self:query(query)
          if not res then return nil, err
          elseif #res > 0 then
            result[k] = res[1][k]
          end
        end
      end
  end
  return result
end

local function serialize_timestamps(self, tbl, schema)
  local result = tbl
  for k, v in pairs(schema.fields) do
    if v.type == "timestamp" and result[k] then
      local query = fmt([[
        SELECT FROM_UNIXTIME(%d/1000)  as `%s`;
      ]], result[k], k)
      local res, err = self:query(query)
      if not res then return nil, err
      elseif #res <= 1 then
        result[k] = res[1][k]
      end
    end
  end
  return result
end

function _M:insert(table_name, schema, model, _, options)
  options = options or {}

  local values, err = serialize_timestamps(self, model, schema)
  if err then return nil, err end

  local cols, args = {}, {}
  for col, value in pairs(values) do
    cols[#cols+1] = escape_identifier(col)
    args[#args+1] = escape_literal(value, schema.fields[col])
  end

 local tid = values.id
  local query = fmt("INSERT INTO %s(%s) VALUES(%s) ",
                    table_name,
                    concat(cols, ", "),
                    concat(args, ", "))
  local res, err = self:query(query, schema)
  if not res then 
    return nil, err
  end

  if tid ~= nil then
      res,err = self:query(fmt("select * from %s where id='%s'",table_name,tid))    
  end

  if not res then return nil, err
  elseif #res > 0 then
    res, err = deserialize_timestamps(self, res[1], schema)
    if err then return nil, err
    else
      -- Handle options
      if options.ttl then
        local ok, err = ttl(self, res, table_name, schema, options.ttl)
        if not ok then return nil, err end
      end
      return res
    end
  end
end

function _M:find(table_name, schema, primary_keys)
  local where = get_where(primary_keys)
  local query = select_query(self, get_select_fields(schema), schema, table_name, where)
  local rows, err = self:query(query, schema)
  if not rows then       return nil, err
  elseif #rows <= 1 then return rows[1]
  else                   return nil, "bad rows result" end
end

function _M:find_all(table_name, tbl, schema)
   local where
    if tbl then
      where = get_where(tbl)
    end
    local query = select_query(self, get_select_fields(schema), schema, table_name, where)
    if query ~=nil then
      return   self:query(query,schema) 
    else
     return {}
    end 
end

function _M:find_page(table_name, tbl, page, page_size, schema)
  page = page or 1

  local total_count, err = self:count(table_name, tbl, schema)
  if not total_count then return nil, err end

  local total_pages = ceil(total_count/page_size)
  local offset = page_size * (page - 1)

  local where
  if tbl then
    where = get_where(tbl)
  end

  local query = select_query(self, get_select_fields(schema), schema, table_name, where, offset, page_size)
  local rows, err = self:query(query, schema)
  if not rows then return nil, err end

  if rows==nil then
   rows={}
  end 
 local next_page = page + 1
  return rows, nil, (next_page <= total_pages and next_page or nil)
end

function _M:count(table_name, tbl, schema)
  local where
  if tbl then
    where = get_where(tbl)
  end

  local query = select_query(self, "COUNT(*) as count", schema, table_name, where)
  local res, err = self:query(query)
  if not res then       return nil, err
  elseif #res <= 1 then return tonumber(res[1].count)
  else                  return nil, "bad rows result" end
end

function _M:update(table_name, schema, _, filter_keys, values, nils, full, _, options)
  options = options or {}

  local args = {}
  local values, err = serialize_timestamps(self, values, schema)
  if not values then return nil, err end

  for col, value in pairs(values) do
    args[#args+1] = fmt("%s = %s",
                        escape_identifier(col),
                        escape_literal(value, schema.fields[col]))
  end

  if full then
    for col in pairs(nils) do
      args[#args+1] = escape_identifier(col) .. " = NULL"
    end
  end

  local where = get_where(filter_keys)
  local query = fmt("UPDATE %s SET %s WHERE %s ",
                    table_name,
                    concat(args, ", "),
                    where)

  local res, err = self:query(query, schema)
  if not res then return nil, err
  elseif res.affected_rows == 1 then
    res, err = deserialize_timestamps(self, res[1], schema)
    if not res then return nil, err
    elseif options.ttl then
      local ok, err = ttl(self, res, table_name, schema, options.ttl)
      if not ok then return nil, err end
    end
    return res
  end
end

function _M:delete(table_name, schema, primary_keys)
  local where = get_where(primary_keys)
  local beforeSql =fmt ("SELECT * FROM %s WHERE %s",table_name, where)
  local qryres, qryerr = self:query(beforeSql, schema)

  local query = fmt("DELETE FROM %s WHERE %s ",
                    table_name, where)
  local res, err = self:query(query, schema)
  if not res then return nil, err
  elseif res.affected_rows == 1 then
    return deserialize_timestamps(self, qryres[1], schema)
  end
end

--- Migrations
-- @section migrations

function _M:queries(queries)
  -- if ngx and get_phase() ~= "init" then
    if utils.strip(queries) ~= "" then
      local res, err = self:query(queries)
      if not res then return err end
    end
 -- end
end

function _M:drop_table(table_name)
  local res, err = self:query("DROP TABLE "..table_name.." CASCADE")
  if not res then return nil, err end
  return true
end

function _M:truncate_table(table_name)
  local res, err = self:query("TRUNCATE "..table_name.." CASCADE")
  if not res then return nil, err end
  return true
end

function _M:current_migrations()

 
      local conn_opts =  self.query_options 
      local querysql= fmt( "select table_name as to_regclass from `information_schema`.TABLES where table_schema='%s' and table_name='schema_migrations'",conn_opts.database )
      local rows, err = self:query(querysql)
      if err then
        return nil, err
      end

      if #rows > 0 and rows[1].to_regclass == "schema_migrations" then
        return self:query "SELECT * FROM schema_migrations"
      else
        return {}
      end
end

function _M:record_migration(id, name)
    if ngx and get_phase() ~= "init" then
      local res, err = self:query(fmt(
        [[
          DROP FUNCTION IF EXISTS upsert_schema_migrations;
          CREATE  function upsert_schema_migrations(identifier varchar(100), migration_name varchar(10000)) RETURNS INT  
          BEGIN
            
              IF EXISTS(SELECT * FROM schema_migrations WHERE id = identifier) then
              
                 IF NOT EXISTS (SELECT * FROM schema_migrations WHERE id = identifier and LOCATE(migration_name,migrations)>-0)  then
                    UPDATE schema_migrations SET migrations =concat(left(migrations,length(migrations)-1),',',migration_name,'}')  WHERE id = identifier;
                 END IF;
                 
              ELSE
                 INSERT INTO schema_migrations(id, migrations) VALUES(identifier, concat('{',migration_name,'}'));
              END IF;
             
              RETURN 1;
          END;

          SELECT upsert_schema_migrations('%s', %s)"]], id, escape_literal(name)))
     
      if not res then return nil, err end 
 end

  return true
end


function _M:reachable()
  local conn_opts = self:clone_query_options()
  local my,err
  
    my, err = mysql:new()
    if not my then
          return nil,Errors.db(err)
    end
  my:set_timeout(3000) -- 3 sec
  local ok, err = my:connect(conn_opts)
  if not ok then
      return nil,Errors.db(err)
  end

  my:set_keepalive(10000, 10)

  return true
end

return _M
