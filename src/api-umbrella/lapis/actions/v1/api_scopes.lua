local ApiScope = require "api-umbrella.lapis.models.api_scope"
local api_scope_policy = require "api-umbrella.lapis.policies.api_scope_policy"
local capture_errors_json = require("api-umbrella.utils.lapis_helpers").capture_errors_json
local dbify_json_nulls = require "api-umbrella.utils.dbify_json_nulls"
local json_params = require("lapis.application").json_params
local lapis_datatables = require "api-umbrella.utils.lapis_datatables"
local lapis_json = require "api-umbrella.utils.lapis_json"
local respond_to = require("lapis.application").respond_to

local _M = {}

function _M.index(self)
  return lapis_datatables.index(self, ApiScope, {
    where = {
      api_scope_policy.authorized_query_scope(self.current_admin),
    },
    search_fields = {
      "name",
      "host",
      "path_prefix",
    },
  })
end

function _M.show(self)
  self.api_scope:authorize()
  local response = {
    api_scope = self.api_scope:as_json(),
  }

  return lapis_json(self, response)
end

function _M.create(self)
  local api_scope = assert(ApiScope:authorized_create(_M.api_scope_params(self)))
  local response = {
    api_scope = api_scope:as_json(),
  }

  self.res.status = 201
  return lapis_json(self, response)
end

function _M.update(self)
  self.api_scope:authorized_update(_M.api_scope_params(self))

  return { status = 204 }
end

function _M.destroy(self)
  self.api_scope:authorize()
  assert(self.api_scope:delete())

  return { status = 204 }
end

function _M.api_scope_params(self)
  local params = {}
  if self.params and self.params["api_scope"] then
    local input = self.params["api_scope"]
    params = dbify_json_nulls({
      name = input["name"],
      host = input["host"],
      path_prefix = input["path_prefix"],
    })
  end

  return params
end

return function(app)
  app:match("/api-umbrella/v1/api_scopes/:id(.:format)", respond_to({
    before = function(self)
      self.api_scope = ApiScope:find(self.params["id"])
      if not self.api_scope then
        self:write({"Not Found", status = 404})
      end
    end,
    GET = capture_errors_json(_M.show),
    POST = capture_errors_json(json_params(_M.update)),
    PUT = capture_errors_json(json_params(_M.update)),
    DELETE = capture_errors_json(_M.destroy),
  }))

  app:get("/api-umbrella/v1/api_scopes(.:format)", capture_errors_json(_M.index))
  app:post("/api-umbrella/v1/api_scopes(.:format)", capture_errors_json(json_params(_M.create)))
end
