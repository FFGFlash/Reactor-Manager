local App = app()

function App:constructor(...)
  local args = { ... }
  self.Views = { List = {}, Active = nil }
  local reactor, initialized = self:load(".reactor")
  self.Reactor = reactor
  self.Main = table.has(args, "--server") and "server" or "client"
  self.Pocket = pocket ~= nil

  self:disconnectAll("terminate")
  self:connect("terminate", self.handleTerminate)

  if self.Main == "server" and self.Pocket then self:stop()
  elseif self.Pocket then self.Main = "pocket_client"
  end

  for _, view in ipairs(self:list("views")) do
    local name = string.match(fs.getName(view), "([^\.]+)")
    self.Views.List[name] = self:require("views/"..name)(self, self.Reactor)
  end

  self:activate(not initialized and "setup" or self.Main)
end

function App:handleTerminate()
  self.Reactor:save()
  self:stop()
end

function App:activate(name, ...)
  term.setTextColor(system:getColor("nekos.text_color"))
  term.setBackgroundColor(system:getColor("nekos.background_color"))
  if self.Views.Active then self.Views.Active:destroy() end
  if self.Views.List[name] then self.Views.Active = self.Views.List[name]:build(...) end
  return self.Views.Active
end

function App:draw()
  if not self.Views.Active then return end
  term.setTextColor(system:getColor("nekos.text_color"))
  term.setBackgroundColor(system:getColor("nekos.background_color"))
  term.clear()
  term.setCursorPos(1,1)
  self.Views.Active:draw()
end

return App
