-- Shared by the generated native +/- branches. Presentation only; the existing
-- keyboard guards still decide when and who may change speed.
local M = {
  values = {10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95,
    100, 125, 150, 175, 200, 300, 500, 1000, 1100},
}

-- The returned list contains opcodes, immediate bytes and relative jumps.
-- core.insertCode resolves those jumps when it writes the native code.
function M.code(direction, speedAddress, notify, unchanged)
  assert(direction == 1 or direction == -1)
  local increasing = direction == 1
  local code = {}
  for index = 1, #M.values do
    local value = M.values[increasing and index or #M.values - index + 1]
    code[#code + 1] = 0x3d -- cmp eax, value
    code[#code + 1] = utils.itob(value)
    code[#code + 1] = increasing and 0x7d or 0x7e -- jge / jle past mov, store and jmp (15 bytes)
    code[#code + 1] = 15
    code[#code + 1] = 0xb8 -- mov eax, value
    code[#code + 1] = utils.itob(value)
    code[#code + 1] = 0xa3 -- mov [speedAddress], eax
    code[#code + 1] = utils.itob(speedAddress)
    code[#code + 1] = 0xe9 -- jmp notify
    code[#code + 1] = core.relTo(notify, -4)
  end
  code[#code + 1] = 0xe9 -- jmp unchanged
  code[#code + 1] = core.relTo(unchanged, -4)
  return code
end

return M
