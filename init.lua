
local changes = {
  ["ai_access"] = "port/ai_access",
  ["ai_addattack"] = "port/ai_addattack",
  ["ai_assaultswitch"] = "port/ai_assaultswitch",
  ["ai_attacklimit"] = "port/ai_attacklimit",
  ["ai_attacktarget"] = "port/ai_attacktarget",
  ["ai_attackwave"] = "port/ai_attackwave",
  ["ai_buywood"] = "port/ai_buywood",
  ["ai_defense"] = "port/ai_defense",
  ["ai_demolish"] = "port/ai_demolish",
  ["ai_fix_crusader_archers_pitch"] = "port/ai_fix_crusader_archers_pitch",
  ["ai_fix_laddermen_with_enclosed_keep"] = "port/ai_fix_laddermen_with_enclosed_keep",
  ["ai_housing"] = "port/ai_housing",
  ["ai_nosleep"] = "port/ai_nosleep",
  ["ai_rebuild"] = "port/ai_rebuild",
  ["ai_recruitinterval"] = "port/ai_recruitinterval",
  ["ai_recruitstate_initialtimer"] = "port/ai_recruitstate_initialtimer",
  ["ai_resources_rebuy"] = "port/ai_resources_rebuy",
  ["ai_tethers"] = "port/ai_tethers",
  ["ai_towerengines"] = "port/ai_towerengines",
  ["fix_apple_orchard_build_size"] = "port/fix_apple_orchard_build_size",
  ["o_armory_marketplace_weapon_order_fix"] = "port/o_armory_marketplace_weapon_order_fix",
  ["o_change_siege_engine_spawn_position_catapult"] = "port/o_change_siege_engine_spawn_position_catapult",
  ["o_default_multiplayer_speed"] = "port/o_default_multiplayer_speed",
  ["o_disable_border_scrolling"] = "port/o_disable_border_scrolling",
  ["o_engineertent"] = "port/o_engineertent",
  ["o_fast_placing"] = "port/o_fast_placing",
  ["o_firecooldown"] = "port/o_firecooldown",
  ["o_fix_baker_disappear"] = "port/o_fix_baker_disappear",
  ["o_fix_fletcher_bug"] = "port/o_fix_fletcher_bug",
  ["o_fix_ladderclimb"] = "port/o_fix_ladderclimb",
  ["o_fix_map_sending"] = "port/o_fix_map_sending",
  ["o_fix_moat_digging_unit_disappearing"] = "port/o_fix_moat_digging_unit_disappearing",
  ["o_fix_rapid_deletion_bug"] = "port/o_fix_rapid_deletion_bug",
  ["o_freetrader"] = "port/o_freetrader",
  ["o_gamespeed"] = "port/o_gamespeed",
  ["o_healer"] = "port/o_healer",
  ["o_increase_path_update_tick_rate"] = "port/o_increase_path_update_tick_rate",
  ["o_keys"] = "port/o_keys",
  ["o_moatvisibility"] = "port/o_moatvisibility",
  ["o_onlyai"] = "port/o_onlyai",
  ["o_override_identity_menu"] = "port/o_override_identity_menu",
  ["o_playercolor"] = "port/o_playercolor",
  ["o_responsivegates"] = "port/o_responsivegates",
  ["o_restore_arabian_engineer_speech"] = "port/o_restore_arabian_engineer_speech",
  ["o_seed_modification_possibility_title"] = "port/o_seed_modification_possibility_title",
  ["o_shfy"] = "port/o_shfy",
  ["o_stop_player_keep_rotation"] = "port/o_stop_player_keep_rotation",
  ["o_xtreme"] = "port/o_xtreme",
  ["u_arabwall"] = "port/u_arabwall",
  ["u_arabxbow"] = "port/u_arabxbow",
  ["u_fireballistafix"] = "port/u_fireballistafix",
  ["u_fix_applefarm_blocking"] = "port/u_fix_applefarm_blocking",
  ["u_fix_lord_animation_stuck_movement"] = "port/u_fix_lord_animation_stuck_movement",
  ["u_laddermen"] = "port/u_laddermen",
  ["u_spearmen"] = "port/u_spearmen",
  ["u_spearmen_run"] = "port/u_spearmen_run",
  ["u_tanner_fix"] = "port/u_tanner_fix",
}

local function anyChildTrue(t)
  for k, v in pairs(t) do
    if type(v) == "table" then
        if v.enabled == true then
            return true
        end
    end
  end
  return false
end

return {

    enable = function(self, config)
    
        log(DEBUG, "loading ucp changes")

        local features = utils.OrderedTable:new()
        local persistentState = require('persistent-state').new()

        local sortedChanges = {}
        for change, opts in pairs(config) do
          table.insert(sortedChanges, change)
        end
        table.sort(sortedChanges)
        
        for _, change in pairs(sortedChanges) do
          local opts = config[change]
          if type(opts) ~= "table" then
            log(ERROR, "Legacy " .. change .. " settings must be a table.")
          elseif opts.enabled ~= nil and type(opts.enabled) ~= "boolean" then
            log(ERROR, "Legacy " .. change .. " enabled setting must be a boolean.")
          elseif opts.enabled == true or anyChildTrue(opts) then
            local path = changes[change]
            if path == nil then
              log(ERROR, "A change was requested '" .. change .. "' for which no file exists")
            else
              local ok, feature = pcall(require, path)
              if ok then
                features[change] = feature
                log(INFO, "Loaded " .. change)
              else
                log(ERROR, "Error when loading " .. change .. " error: " .. tostring(feature))
              end
            end
          end
        end
        
        for name, change in pairs(features) do
          log(DEBUG, "initializing: " .. name)
          change:init(config[name])
        end
        
        for name, change in pairs(features) do
          log(DEBUG, "enabling: " .. name)
          local ok, reason = pcall(change.enable, change, config[name], persistentState)
          if not ok then
            log(ERROR, "Legacy " .. name .. " is off: " .. tostring(reason))
          end
        end

        -- The existing save owner handles maps, saved games and replay starting
        -- worlds. No per-tick serialization or recorder-specific hook is needed.
        modules['map-extensions']:registerSection('ucp2-legacy', persistentState)
        self.simulationStateFormat = 1
        -- Read-only export for world snapshots that cannot invoke a native save
        -- (for example, a recorder running on a multiplayer client).
        self.serializeSimulationState = function(_, handle) persistentState:serialize(handle) end

    end,

    disable = function(self, config)
        return false, "not implemented"
    end,

}



