return {

    init = function(self, config)
        -- The jump to remove is at +58 in the spearmen running decision.
        local ok, site = pcall(core.AOBScan, "66 39 BE ? ? ? ? 74 21 89 86 ? ? ? ? 66 83 BE ? ? ? ? 46 7E 3C 66 C7 86 ? ? ? ? FF FF 89 BE ? ? ? ? EB 32 66 39 BE ? ? ? ? 75 1C 66 39 BE ? ? ? ? 74 13 C7 86 ? ? ? ? 81 00 00 00 66 89 86 ? ? ? ? EB 0D 89 86 ? ? ? ? 66 89 BE")
        self.u_spearmen_run_edit = ok and site + 58 or nil
    end,

    enable = function(self, config)
        if not self.u_spearmen_run_edit then
            log(ERROR, "Legacy running spearmen is off: run decision not found.")
            return
        end

        local code = {
            0x90, 0x90,  -- remove je
        }
        core.writeCode(self.u_spearmen_run_edit, code)
    end,

    disable = function(self, config)
        error("not implemented")
    end,

}
