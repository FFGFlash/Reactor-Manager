return function(a, d)
  local View = {
    App = a,
    Data = d,
    Connections = {},
    Intervals = {},
    Manager = 1,
    SelectedManagerId = nil,
    SelectedManager = nil
  }

  function View:connect(event, callback, this) table.insert(self.Connections, self.App:connect(event, callback, this or self)) end
  function View:setInterval(callback, time, this, ...) table.insert(self.Intervals, self.App:setInterval(callback, time, this or self, ...)) end
  function View:handleResize() self.Width, self.Height = term.getSize() end
  function View:handleStop() self.Data:save() end
  function View:load(...) return self.App:load(...) end

  function View:destroy()
    for _, conn in ipairs(self.Connections) do self.App:disconnect(conn) end
    for _, intr in ipairs(self.Intervals) do self.App:clearInterval(intr) end
  end

  function View:build()
    self.Network = network(self.Data.Protocol)
    self.Managers = self:load(".managers")
    self.Button = { Width = 0, Height = 0}
    for _,manager in ipairs(self.Managers) do manager.Old = true end

    self:connect("stop", self.handleStop)
    self:connect("term_resize", self.handleResize)
    self:connect("rednet_message", self.Network.handler(self.handleNetworkEvent, self), self.Network)
    self:connect("mouse_click", self.handleClick)
    self:setInterval(self.update, 0.25)
    self:handleResize()

    term.clear()
    term.setCursorPos(1,1)
    term.writeCentered("Awaiting Network Connection")
    repeat sleep(1) until network:connect()

    self.Network()
    self.ManagerIds = self.Network:lookup()

    return self
  end

  function View:update()
    self.ManagerIds = self.Network:lookup()
  end

  function View:draw()
    self.Manager = math.clamp(self.Manager, 1, #self.ManagerIds)
    self.SelectedManagerId = self.ManagerIds[self.Manager]
    self.SelectedManager = self.Managers[self.SelectedManagerId + 1]

    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1,1)

    if not #self.ManagerIds == 0 then return term.writeCentered("Locating Managers")
    elseif next(self.Managers) == nil or not self.SelectedManager then return term.writeCentered("Awaiting Manager Data")
    end

    term.setBackgroundColor(colors.lightBlue)
    term.clearLine()
    term.write(" <")
    term.setCursorPos(self.Width - 2,1)
    term.write("> ")
    term.setCursorPos(1,1)
    term.writeCentered(self.SelectedManager.Hostname, nil, 1)
    term.setCursorPos(1,2)
    term.setBackgroundColor(colors.lightGray)

    local t = {
      { "Reactor", "Status", "Energy Prod. (rf/t)", "Energy (%)", "Fuel Con. (mb/t)", "Fuel (%)", "Waste (%)" }
    }
    for i,reactor in ipairs(self.SelectedManager.Reactors) do
      local info, controls = {
        "Reactor ."..i,
        reactor.Active and "Online" or "Offline",
        math.floor(reactor.Energy.ProducedLastTick * 100) / 100,
        math.floor(reactor.Energy.Stored / reactor.Energy.Capacity * 10000) / 100,
        math.floor(reactor.Fuel.ConsumedLastTick * 100) / 100,
        math.floor(reactor.Fuel.Amount / reactor.Fuel.Capacity * 10000) / 100,
        math.floor(reactor.Fuel.Waste / reactor.Fuel.Capacity * 10000) / 100
      }, {
        "",
        reactor.Active and "Turn Off" or "Turn On",
        "+1%",
        "+10%",
        "",
        "-10%",
        "-1%"
      }
      table.insert(t, info)
      table.insert(t, controls)
    end
    self.Button.Width, self.Button.Height = term.table(t)
  end

  function View:handleNetworkEvent(sender, event, ...)
    local args = { ... }
    if event == "update" then self.Managers[sender + 1] = { Old = false, Hostname = table.remove(args, 1), Reactors = table.remove(args, 1) }
    end
  end

  function View:handleClick(b, mx, my)
    if b ~= 1 then return end
    local reactorId = math.ceil(my / 2) - 1
    local reactor = self.SelectedManager.Reactors[reactorId]
    if not reactor then return end
    if my == 1 then
      if mx > 0 and mx <= 2 then self.Manager = self.Manager - 1
      elseif mx > self.Width - 2 and mx <= self.Width then self.Manager = self.Manager + 1
      end
    else
      if mx > self.Button.Width and mx <= self.Button.Width * 2 then self.Network:send(self.SelectedManagerId, reactor.Active and "stop" or "start", reactorId)
      elseif mx > self.Button.Width * 2 and mx <= self.Button.Width * 3 then self.Network:send(self.SelectedManagerId, "set_levels", reactorId, math.clamp(reactor.Levels[0] + 1, 0, 100))
      elseif mx > self.Button.Width * 3 and mx <= self.Button.Width * 4 then self.Network:send(self.SelectedManagerId, "set_levels", reactorId, math.clamp(reactor.Levels[0] + 10, 0, 100))
      elseif mx > self.Button.Width * 5 and mx <= self.Button.Width * 6 then self.Network:send(self.SelectedManagerId, "set_levels", reactorId, math.clamp(reactor.Levels[0] - 10, 0, 100))
      elseif mx > self.Button.Width * 6 and mx <= self.Button.Width * 7 then self.Network:send(self.SelectedManagerId, "set_levels", reactorId, math.clamp(reactor.Levels[0] - 1, 0, 100))
      end
    end
  end

  return View
end
