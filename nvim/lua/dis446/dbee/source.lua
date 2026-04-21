local repo = require("dis446.dbee.repo")

local Source = {}

function Source:new()
  local instance = {
    display_name = "repo",
    root = nil,
    last_loaded = nil,
  }

  setmetatable(instance, self)
  self.__index = self

  return instance
end

function Source:name()
  return self.display_name
end

function Source:set_root(root)
  self.root = repo.find_root(root)
end

function Source:get_root()
  return self.root or repo.current_root()
end

function Source:load()
  self.last_loaded = repo.load_for_root(self:get_root())
  return self.last_loaded.connections
end

function Source:file()
  return repo.config_paths(self:get_root()).shared
end

return Source
