local writeCode = core.writeCode
local writeBytes = core.writeBytes
local AOBScan = core.AOBScan
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

--____NEW CHANGE: u_spearmen_run
return {

    init = function(self, config)
        -- 0055E064, the spearmen running decision; the je to remove is at +58. A module that changed
        -- this code first (Running Units, Rebalancer) leaves the match empty.
        local found, site = pcall(AOBScan, "66 39 BE ? ? ? ? 74 21 89 86 ? ? ? ? 66 83 BE ? ? ? ? 46 7E 3C 66 C7 86 ? ? ? ? FF FF 89 BE ? ? ? ? EB 32 66 39 BE ? ? ? ? 75 1C 66 39 BE ? ? ? ? 74 13 C7 86 ? ? ? ?  81 00 00 00 66 89 86 ? ? ? ? EB 0D 89 86 ? ? ? ? 66 89 BE")
        self.u_spearmen_run_edit = found and site and site + 58 or nil
    end,

    enable = function(self, config)
        if not self.u_spearmen_run_edit then
            log(WARNING, "u_spearmen_run: another module already changed spearmen running, this change is not applied")
            return
        end

        -- new DefaultHeader("u_spearmen_run")
        local code = {
            0x90, 0x90,  -- remove je
        }
        writeCode(self.u_spearmen_run_edit, code)
    end,

    disable = function(self, config)
        error("not implemented")
    end,

}
