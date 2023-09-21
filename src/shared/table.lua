-- @author: 4c65736975, All Rights Reserved
-- @version: 1.0.0.0, 21|09|2023
-- @filename: table.lua

table.moveTo = table.moveTo or function (tab, value, pos)
  for a, b in pairs(tab) do
    if b == value then
      table.remove(tab, a)
      table.insert(tab, pos, value)

      break
    end
  end
end