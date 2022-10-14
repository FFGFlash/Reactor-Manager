return function(a, d)
  local View = {
    App = a,
    Data = d,
    Connections = {},
    Intervals = {},
    Manager = 1,
    Reactor = 1,
    SelectedManagerId = nil,
    SelectedManager = nil,
    SelectedReactor = nil
  }

  function View:connect(event, callback, this) table.insert(self.Connections, self.App:connect(event, callback, this or self)) end
  function View:setInterval(callback, time, this, ...) table.insert(self.Intervals, self.App:setInterval(callback, time, this or self, ...)) end
  function View:handleResize() self.Width, self.Height = term.getSize() end
  function View:handleStop() self.Data:save() end

  function View:destroy()
    for _, conn in ipairs(self.Connections) do self.App:disconnect(conn) end
    for _, intr in ipairs(self.Intervals) do self.App:clearInterval(intr) end
  end

  function View:build()
    self.Network = network(self.Data.Protocol)
    self.Managers = self:load(".managers")
    self.Button = { Width = 0, Height = 0 }
    for _,manager in pairs(self.Managers) do manager.Old = true end

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
  end

  function View:update()
    self.ManagerIds = self.Network:lookup()
  end

  function View:draw()
    self.Manager = math.clamp(self.Manager, 1, #self.ManagerIds)
    self.SelectedManagerId = self.ManagerIds[self.Manager]
    self.SelectedManager = self.Managers[self.SelectedManagerId]

    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1,1)

    if not #ManagerIds == 0 then return term.writeCentered("Locating Managers")
    elseif next(Managers) == nil or not SelectedManager then return term.writeCentered("Awaiting Manager Data")
    end

    self.Reactor = math.clamp(self.Reactor, 1, #self.SelectedManager.Reactors)
    self.SelectedReactor = self.SelectedManager.Reactors[self.Reactor]

    term.setBackgroundColor(colors.lightBlue)
    term.clearLine()
    term.write(" <")
    term.setCursorPos(self.Width - 2,1)
    term.write("> ")
    term.setCursorPos(1,1)
    term.writeCentered(SelectedManager.Hostname, nil, 1)

    if not self.SelectedReactor then
      term.setCursorPos(1, term.getHeight())
      term.clearLine()
      return
    end

    term.setCursorPos(1,2)
    term.setBackgroundColor(colors.lightBlue)
    term.clearLine()
    term.write(" <")
    term.setCursorPos(self.Width - 2,2)
    term.write("> ")
    term.setCursorPos(1,2)
    term.writeCentered("Reactor ."..self.Reactor, nil, 1)

    term.setCursorPos(2,4)
    term.setBackgroundColor(colors.lightGray)

    term.writeNewline("Status: "..reactor.Active and "Online" or "Offline")
    term.writeNewline("Energy Produced: "..math.floor(reactor.Energy.ProducedLastTick * 100) / 100.."rf/t")
    term.writeNewline("Energy: %"..math.floor(reactor.Energy.Stored / reactor.Energy.Capacity * 10000) / 100)
    term.writeNewLine("Fuel Consumed: "..math.floor(reactor.Fuel.ConsumedLastTick * 100) / 100.."mb/t")
    term.writeNewLine("Fuel: %"..math.floor(reactor.Fuel.Amount / reactor.Fuel.Capacity * 10000) / 100)
    term.writeNewLine("Waste: %"..math.floor(reactor.Fuel.Waste / reactor.Fuel.Capacity * 10000) / 100)

    term.setBackgroundColor(colors.lightBlue)
    term.setCursorPos(1, term.getHeight())
    term.clearLine()
    self.Button.Width, self.Button.Height = term.table({
      "+1%",
      "+10%",
      reactor.Active and "Turn Off" or "Turn On",
      "-10%",
      "-1%"
    })
  end

  function View:handleNetworkEvent(sender, event, ...)
    local args = { ... }
    if event == "update" then self.Managers[sender] = { Old = false, Hostname = table.remove(args, 1), Reactors = table.remove(args, 1) }
    end
  end

  function View:handleClick(b, mx, my)
    if b ~= 1 then return end
    local reactor = self.SelectedManager.Reactors[self.Reactor]
    if not reactor then return end
    if my == self.Height then
      if mx > 0 and mx <= self.Button.Width * 1 then self.Network:send(self.SelectedManagerId, "set_levels", self.Reactor, math.clamp(reactor.Levels[0] + 1, 0, 100))
      elseif mx > self.Button.Width * 1 and mx <= self.Button.Width * 2 then self.Network:send(self.SelectedManagerId, "set_levels", self.Reactor, math.clamp(reactor.Levels[0] + 10, 0, 100))
      elseif mx > self.Button.Width * 2 and mx <= self.Button.Width * 3 then self.Network:send(self.SelectedManagerId, reactor.Active and "stop" or "start", reactorId)
      elseif mx > self.Button.Width * 3 and mx <= self.Button.Width * 4 then self.Network:send(self.SelectedManagerId, "set_levels", self.Reactor, math.clamp(reactor.Levels[0] - 10, 0, 100))
      elseif mx > self.Button.Width * 4 and mx <= self.Button.Width * 5 then self.Network:send(self.SelectedManagerId, "set_levels", self.Reactor, math.clamp(reactor.Levels[0] - 1, 0, 100))
      end
    elseif my == 1 then
      if mx > 0 and mx <= 2 then self.Manager = self.Manager - 1
      elseif mx > self.Width - 2, mx <= self.Width then self.Manager = self.Manager + 1
      end
    elseif my == 2 then
      if mx > 0 and mx <= 2 then self.Reactor = self.Reactor - 1
      elseif mx > self.Width - 2, mx <= self.Width then self.Reactor = self.Reactor + 1
      end
    end
  end

  return View
end
