local Errors = require "kong.dao.errors"
local utils = require "kong.tools.utils"

local function check_host(host)
  if type(host) ~= "string" then
    return false, "must be a string"

  elseif utils.strip(host) == "" then
    return false, "host is empty"
  end

  local temp, count = host:gsub("%*", "abc")  -- insert valid placeholder for verification

  -- Validate regular request_host
  local normalized = utils.normalize_ip(temp)
  if (not normalized) or normalized.port then
    return false, "Invalid hostname"
  end

  if count == 1 then
    -- Validate wildcard request_host
    local valid
    local pos = host:find("%*")
    if pos == 1 then
      valid = host:match("^%*%.") ~= nil

    elseif pos == #host then
      valid = host:match(".%.%*$") ~= nil
    end

    if not valid then
      return false, "Invalid wildcard placement"
    end

  elseif count > 1 then
    return false, "Only one wildcard is allowed"
  end

  return true
end

return {
  table = "websites",
  primary_key = {"id"},
  fields = {
    id = {
      type = "id",
      dao_insert_value = true,
      required = true,
    },
    created_at = {
      type = "timestamp",
      immutable = true,
      dao_insert_value = true,
      required = true,
    },
    updated_at = {
      type = "timestamp",
      immutable = true,
      dao_insert_value = true,
      required = true,
    },
    name = {
      type = "string",
      unique = true,
      required = true,
      func = check_host
    },
    listen = {
      type = "number",
      default = 80,
    },
    root = {
      type = "string",
      default = '',
    },
    resolver = {
      type = "string",
      default = '',
    },
    locations = {
      type = "string",
      default = '',
    }
  },
  left_join = false,
  self_check = function(schema, config, dao, is_updating)
    return true
  end,
}