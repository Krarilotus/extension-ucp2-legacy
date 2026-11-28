local writeCode = core.writeCode
local writeBytes = core.writeBytes
local compile = core.compile
local calculateCodeSize = core.calculateCodeSize
local allocate = core.allocate
local allocateCode = core.allocateCode
local getRelativeAddress = core.getRelativeAddress
local relTo = core.relTo
local relToLabel = core.relToLabel
local byteRelTo = core.byteRelTo
local readInteger = core.readInteger

local itob = utils.itob
local smallIntegerToBytes = utils.smallIntegerToBytes

-- Fix ladder climbing behaviour
--____NEW CHANGE: o_fix_ladderclimb
return {

    init = function(self, config)
        self.bindingError = nil
        for _, binding in ipairs({
            -- Start past the seven-byte entry detour used by Smarter Buildings.
            {"o_fix_ladderclimb_pre_edit", "unit destination entry", "8B D0 69 D2 90 04 00 00 53 55 8B 6C 24 18 56 8D 34 0A", 2},
            {"o_fix_ladderclimb_edit", "destination capture", "50 52 B9 ? ? ? ? E8 ? ? ? ? 66 3B C3 66 89 86 BC 08 00 00 74", 12},
            {"o_fix_ladderclimb_2_edit", "destination update", "66 89 8C 37 00 07 00 00 66 89 94 37 02 07 00 00", 0},
            {"o_fix_ladderclimb_3_edit", "ladder destination flag", "53 8B 5C 24 08 8B C3 55 69 C0", 0},
            {"o_fix_ladderclimb_4_edit", "destination restore", "0F BF 96 02 07 00 00 0F BF 86 00 07 00 00 66 8B 8E 8A 09 00 00", 0},
        }) do
            local ok, address = pcall(core.AOBScan, binding[3])
            if not ok then
                self.bindingError = binding[2] .. " not found"
                return
            end
            self[binding[1]] = address + binding[4]
        end
    end,

    enable = function(self, config, persistentState)
        if self.bindingError then
            log(ERROR, "Ladder climbing fix is off: " .. self.bindingError .. ".")
            return
        end
        local currentUnitMoved = allocate(4)
        local code = {
            0xE9, function(address, index, labels)
                local hook = {
                    0x89, 0x15, itob(currentUnitMoved),  -- mov [currentUnitMoved],edx
                    0x69, 0xD2, 0x90, 0x04, 0x00, 0x00,  -- imul edx,edx,00000490
                    0xe9, relTo(self.o_fix_ladderclimb_pre_edit + 6, -4)
                }
                local hookSize = calculateCodeSize(hook)
                local hookAddress = allocateCode(hookSize)
                writeCode(hookAddress, hook)
                return itob(getRelativeAddress(address, hookAddress, -4))
            end,
            0x90
        }
        writeCode(self.o_fix_ladderclimb_pre_edit, code)
        -- Three dwords per unit, up to 10,000 units in Extreme.
        local savedUnitDestinationForClimbing = persistentState:allocate('ladder-destinations', 120000)
        local code = {
            0xE9, function(address, index, labels)
                local hook = {
                    0x50,  -- push eax
                    0xA1, itob(currentUnitMoved),  -- mov eax,[currentUnitMoved]
                    0x83, 0xF8, 0x00,  -- cmp eax,00
                    0x74, 0x20,  -- je short 20
                    0x48,  -- dec eax
                    0x6B, 0xC0, 0x0C,  -- imul eax,eax,0C
                    0x89, 0xA8, itob(savedUnitDestinationForClimbing),  -- mov [eax+savedUnitDestinationForClimbing],ebp
                    0x83, 0xC0, 0x04,  -- add eax,04
                    0x89, 0xB8, itob(savedUnitDestinationForClimbing),  -- mov [eax+savedUnitDestinationForClimbing],edi
                    0x83, 0xC0, 0x04,  -- add eax,04
                    0xC7, 0x80, itob(savedUnitDestinationForClimbing), 0x01, 0x00, 0x00, 0x00,  -- mov [eax+savedUnitDestinationForClimbing],01
                    0x58,  -- pop eax
                    0x66, 0x39, 0xD8,  -- cmp ax,bx
                    0x66, 0x89, 0x86, 0xBC, 0x08, 0x00, 0x00,  -- mov [esi+8BC],ax
                    0xe9, relTo(self.o_fix_ladderclimb_edit + 10, -4)
                }
                local hookSize = calculateCodeSize(hook)
                local hookAddress = allocateCode(hookSize)
                writeCode(hookAddress, hook)
                return itob(getRelativeAddress(address, hookAddress, -4))
            end,
            0x90, 0x90, 0x90, 0x90, 0x90
        }
        writeCode(self.o_fix_ladderclimb_edit, code)
        local exit = self.o_fix_ladderclimb_2_edit + 16
        local code = {
            0xE9, function(address, index, labels)
                local hook = {
                    0x50,  -- push eax
                    0x8B, 0xC3,  -- mov eax,ebx
                    0x48,  -- dec eax
                    0x6B, 0xC0, 0x0C,  -- imul eax,eax,0C
                    0x83, 0xC0, 0x08,  -- add eax,08
                    0x83, 0xB8, itob(savedUnitDestinationForClimbing), 0x00,  -- cmp dword ptr [eax+savedUnitDestinationForClimbing],00
                    0x75, 0x16,  -- jne short 0x16
                    0x58,  -- pop eax
                    0x66, 0x89, 0x8C, 0x3E, 0x00, 0x07, 0x00, 0x00,  -- mov [esi+edi+00000700],cx
                    0x66, 0x89, 0x94, 0x3E, 0x02, 0x07, 0x00, 0x00,  -- mov [esi+edi+00000702],dx
                    0xE9, function(index) return itob(getRelativeAddress(index, exit, -4)) end,  -- jmp exit
                    0xC7, 0x80, itob(savedUnitDestinationForClimbing), 0x00, 0x00, 0x00, 0x00,  -- mov [eax+savedUnitDestinationForClimbing],00000000
                    0x58,  -- pop eax
                    0xe9, relTo(self.o_fix_ladderclimb_2_edit + 16, -4)
                }
                local hookSize = calculateCodeSize(hook)
                local hookAddress = allocateCode(hookSize)
                writeCode(hookAddress, hook)
                return itob(getRelativeAddress(address, hookAddress, -4))
            end,
            0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90
        }
        writeCode(self.o_fix_ladderclimb_2_edit, code)
        local code = {
            0xE9, function(address, index, labels)
                local hook = {
                    0x50,  -- push eax
                    0x8B, 0xC3,  -- mov eax,ebx
                    0x48,  -- dec eax
                    0x6B, 0xC0, 0x0C,  -- imul eax,eax,0C
                    0x83, 0xC0, 0x08,  -- add eax,08,
                    0xC7, 0x80, itob(savedUnitDestinationForClimbing), 0x01, 0x00, 0x00, 0x00,  -- mov [eax+savedUnitDestinationForClimbing],00000000
                    0x58,  -- pop eax
                    0x53,  -- push ebx
                    0x8B, 0x5C, 0x24, 0x08,  -- mov ebx,[esp+08]
                    0xe9, relTo(self.o_fix_ladderclimb_3_edit + 5, -4)
                }
                local hookSize = calculateCodeSize(hook)
                local hookAddress = allocateCode(hookSize)
                writeCode(hookAddress, hook)
                return itob(getRelativeAddress(address, hookAddress, -4))
            end,
        }
        writeCode(self.o_fix_ladderclimb_3_edit, code)
        local code = {
            0xE9, function(address, index, labels)
                local hook = {
                    0x57,  -- push edi
                    0x31, 0xFF,  -- xor edi,edi
                    0x66, 0x8B, 0x7C, 0x24, 0x18,  -- mov di,[esp+18]
                    0x4F,  -- dec edi
                    0x6B, 0xFF, 0x0C,  -- imul edi,edi,0C
                    0x8B, 0x87, itob(savedUnitDestinationForClimbing),  -- mov eax,[edi+savedUnitDestinationForClimbing]
                    0x83, 0xC7, 0x04,  -- add edi,04
                    0x8B, 0x97, itob(savedUnitDestinationForClimbing),  -- mov edx,[edi+savedUnitDestinationForClimbing]
                    0x89, 0x86, 0x00, 0x07, 0x00, 0x00,  -- mov [esi+00000700],eax
                    0x89, 0x96, 0x02, 0x07, 0x00, 0x00,  -- mov [esi+00000702],edx
                    0x0F, 0xBF, 0x96, 0x02, 0x07, 0x00, 0x00,  -- movsx edx,word ptr [esi+00000702]
                    0x0F, 0xBF, 0x86, 0x00, 0x07, 0x00, 0x00,  -- movsx edx,word ptr [esi+00000702]
                    0x5F,  -- pop edi
                    0xe9, relTo(self.o_fix_ladderclimb_4_edit + 14, -4)
                }
                local hookSize = calculateCodeSize(hook)
                local hookAddress = allocateCode(hookSize)
                writeCode(hookAddress, hook)
                return itob(getRelativeAddress(address, hookAddress, -4))
            end,
            0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90
        }
        writeCode(self.o_fix_ladderclimb_4_edit, code)
    end,

    disable = function(self, config)
        error("not implemented")
    end,

}
