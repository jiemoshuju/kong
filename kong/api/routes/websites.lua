local crud    = require "kong.api.crud_helpers"
local utils   = require "kong.tools.utils"

return {
  ["/websites/"] = {
    GET = function(self, dao_factory)
      crud.paginated_set(self, dao_factory.websites)
    end,

    PUT = function(self, dao_factory)
      crud.put(self.params, dao_factory.websites)
    end,

    POST = function(self, dao_factory)
      crud.post(self.params, dao_factory.websites)
    end
  },

  ["/websites/:website_name_or_id"] = {
    before = function(self, dao_factory, helpers)
      crud.find_website_by_name_or_id(self, dao_factory, helpers)
    end,

    GET = function(self, dao_factory, helpers)
      return helpers.responses.send_HTTP_OK(self.website)
    end,

    PATCH = function(self, dao_factory)
      crud.patch(self.params, dao_factory.websites, self.website)
    end,

    DELETE = function(self, dao_factory)
      crud.delete(self.website, dao_factory.websites)
    end
  }
}
