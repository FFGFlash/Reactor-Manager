return function(a, d)
  local View = {
    App = a,
    Data = d,
    Connections = {},
    Intervals = {},
    Reactors = {}
  }

  function View:connect(event, callback, this) table.insert(self.Connections, self.App:connect(event, callback, this or self)) end
  function View:setInterval(callback, time, this, ...) table.insert(self.Intervals, self.App:setInterval(callback, time, this or self, ...)) end
  function View:handleResize() self.Width, self.Height = term.getSize() end
  function View:handleStop() self.Data:save() end

  function View:destroy()
    for _, conn in ipairs(self.Connections) do self.App:disconnect(conn) end
    for _, intr in ipairs(self.Intervals) do self.App:clearInterval(intr) end
  end

  function View:buildReactor(peripheral)
    local reactor = {
      NumberOfControlRods = 0,
      Active = false,
      Levels = {},
      Energy = {},
      Fuel = {}
    }
    reactor.__index = reactor

    function reactor:__call()
      local energy = peripheral.getEnergyStats()
      local fuel = peripheral.getFuelStats()

      self.NumberOfControlRods = peripheral.getNumberOfControlRods()
      self.Active = peripheral.getActive()
      self.Levels = peripheral.getControlRodsLevels()

      for name, value in pairs(energy) do
        pcall(function() value = math.floor(tonumber(value) * 100) / 100 end)
        self.Energy[string.sub(name, 7)] = value
      end

      for name, value in pairs(fuel) do
        pcall(function() value = math.floor(tonumber(value) * 100) / 100 end)
        self.Fuel[string.sub(name, 5)] = value
      end

      self.Fuel.Waste = self.Fuel.eAmount
      self.Fuel.eAmount = nil

      return self
    end

    function Reactor:start() peripheral.setActive(true) end
    function Reactor:stop() peripheral.setActive(false) end
    function Reactor:setLevel(id, level) peripheral.setControlRodLevel(id, level) end

    function Reactor:setLevels(level)
      for i = 1, self.NumberOfControlRods, 1 do self:setLevel(i - 1, level) end
    end

    return setmetatable(reactor, reactor)
  end

  function View:getReactors()
    local reactors, peripherals = {}, { peripheral.find("BigReactors-Reactor") }
    for i,p in ipairs(peripherals) do table.insert(reactors, self:buildReactor(p)()) end
    return reactors
  end

  function View:build()
    self.Network = network(self.Data.Protocol)
    self.Reactors = self:getReactors()

    self:connect("stop", self.handleStop)
    self:connect("term_resize", self.handleResize)
    self:connect("rednet_message", self.Network.handler(self.handleNetworkEvent, self), self.Network)
    self:setInterval(self.update, 0.25)
    self:handleResize()

    term.clear()
    term.setCursorPos(1,1)
    term.writeCentered("Awaiting Network Connection")
    repeat sleep(1) until network:connect()

    self.Network(self.Data.Name.."#"..os.getComputerID())

    return self
  end

  function View:update()
    for _, reactor in ipairs(self.Reactors) do reactor() end
    self.Network:broadcast("update", self.Network.Hostname, self.Reactors)
  end

  function View:draw()
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1,1)
    term.setBackgroundColor(colors.lightBlue)
    term.clearLine()
    term.writeCentered(self.Network.Hostname, nil, 1)
    term.setCursorPos(1,2)
    term.setBackgroundColor(colors.lightGray)
    local t = {
      { "Reactor", "Status", "Energy Prod. (rf/t)", "Energy (%)", "Fuel Con. (mb/t)", "Fuel (%)", "Waste (%)" }
    }
    for i,reactor in ipairs(self.Reactors) do
      local info = {
        "Reactor ."..i,
        reactor.Active and "Online" or "Offline",
        math.floor(reactor.Energy.ProducedLastTick * 100) / 100,
        math.floor(reactor.Energy.Stored / reactor.Energy.Capacity * 10000) / 100,
        math.floor(reactor.Fuel.ConsumedLastTick * 100) / 100,
        math.floor(reactor.Fuel.Amount / reactor.Fuel.Capacity * 10000) / 100,
        math.floor(reactor.Fuel.Waste / reactor.Fuel.Capacity * 10000) / 100
      }
      table.insert(t, info)
    end
    term.table(t)
  end

  function View:handleNetworkEvent(sender, event, ...)
    local args = { ... }
    local s, reactor = pcall(function() return self.Reactors[table.remove(args, 1)] end)
    if not s or not reactor then return end
    if event == "start" then reactor:start()
    elseif event == "stop" then reactor:stop()
    elseif event == "set_levels" then reactor:setLevels(table.unpack(args))
    elseif event == "set_level" then reactor:setLevel(table.unpack(args))
    end
  end

  return View
end
