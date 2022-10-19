return function(a, d)
  local View = {
    App = a,
    Data = d,
    Connections = {},
    Structure = {
      { Name = "Protocol", Filter = "[^(%a| )]" },
      { Name = "Name", Filter = "[^(%a| )]" }
    }
  }

  function View:connect(event, callback, this) table.insert(self.Connections, self.App:connect(event, callback, this or self)) end
  function View:destroy() for _, conn in ipairs(self.Connections) do self.App:disconnect(conn) end end
  function View:moveCursor(c) self.Input.Index = math.clamp(self.Input.Index + c, 1, string.len(self.Input.Value)) end
  function View:handleResize() self.Width, self.Height = term.getSize() end

  function View:build()
    self.Struct = { Value = nil, Index = 0 }
    self.Input = { Value = "", Index = 0, Line = 1 }
    self:connect("char", self.handleInput)
    self:connect("paste", self.handleInput)
    self:connect("key", self.handleKeyPressed)
    self:connect("term_resize", self.handleResize)
    self:handleResize()
    self:next()
    return self
  end

  function View:draw()
    term.setCursorPos(1, self.Input.Line)
    term.clearLine()
    term.write(self.Struct.Value.Name.." > ")
    local x = term.getCursorX()
    term.write(self.Struct.Value.Replacer and string.gsub(self.Input.Value, ".", self.Struct.Value.Replacer) or self.Input.Value)
    term.setCursorPos(x + self.Input.Index, self.Input.Line)
  end

  function View:processInput()
    self.Input.Index = 0
    local w, h = term.getSize()
    if self.Input.Line + 1 > h then
      term.scroll(h - self.Input.Line)
      self.Input.Line = self.Input.Line - 1
    end
    self:draw()
    term.setCursorBlink(false)
    term.setCursorPos(1, self.Input.Line + 1)
    term.clearLine()
    if self.Struct.Value.Filter then
      local match = string.match(self.Input.Value, self.Struct.Value.Filter)
      if match then return term.writeNewline("Invalid Character '"..match.."' Found") end
    end
    self.Data[self.Struct.Value.Name] = self.Struct.Value.Passthrough and self.Struct.Value.Passthrough(self.Input.Value) or self.Input.Value
    self.Input.Value = ""
    _,self.Input.Line = term.getCursorPos()
    if self.Struct.Index >= #self.Structure then return self.App:activate(self.App.Main) end
    term.setCursorBlink(true)
    self:next()
  end

  function View:next()
    self.Struct.Index = self.Struct.Index + 1
    self.Struct.Value = self.Structure[self.Struct.Index]
    return self.Struct
  end

  function View:handleKeyPressed(key, held)
    if key == keys.backspace then self:handleInput(0)
    elseif key == keys.delete then self:handleInput(1)
    elseif not held then
      if key == keys.enter then self:processInput()
      elseif key == keys.left then self:moveCursor(-1)
      elseif key == keys.right then self:moveCursor(1)
      end
    end
  end

  function View:handleInput(c)
    if not c then return
    elseif type(c) == "number" then
      local p = self.Input.Index + c
      self.Input.Value = string.remove(self.Input.Value, self.Input.Index + c)
      if c <= 0 then self:moveCursor(c - 1) end
    else
      self.Input.Value = string.insert(self.Input.Value, self.Input.Index, c)
      self:moveCursor(string.len(c))
    end
  end

  return View
end
