return {
  table        = "routes",
  primary_key = { "id" },

  fields = {
    id             = { type = "id", dao_insert_value = true, required = true },
    created_at     = { type = "timestamp", immutable = true, dao_insert_value = true, required = true },
    updated_at     = { type = "timestamp", immutable = true, dao_insert_value = true, required = true },
    protocols      = { type = "array" },
    methods        = { type = "array" },
    hosts          = { type = "array" },
    paths          = { type = "array" },
    regex_priority = { type = "integer", default = 0 },
    strip_path     = { type = "boolean", default = true },
    preserve_host  = { type = "boolean", default = false },
    service_id        = { type = "id", reference = "services", required = true },
  },

  self_check = function(schema, api_t, dao, is_update)
    return true
  end
}
