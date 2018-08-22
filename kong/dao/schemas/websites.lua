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
    server_name = {
      type = "string",
      unique = true,
      required = true,
    },
    listen = {
      -- weight in the loadbalancer algorithm.
      -- to disable an entry, set the weight to 0
      type = "number",
      default = 80,
    },
    root = {
      type = "string",
    }
  },
  self_check = function(schema, config, dao, is_updating)
    return true
  end,
}