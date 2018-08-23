return {
  table = "snis",
  primary_key = {"id"},
  fields = {
    id = {
      type = "id",
      dao_insert_value = true,
      required = true,
    },
    certificate_id = { 
      type = "id", 
      dao_insert_value = true,
      required = true
    },
    name = { 
      type = "string",
      required = true,
      unique = true
    },
    created_at = { 
      type = "integer",
      timestamp = true,
      auto = true
    },
  },
  left_join = false,
  self_check = function(schema, config, dao, is_updating)
    return true
  end,
}