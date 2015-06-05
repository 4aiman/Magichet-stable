--Minetest
--Copyright (C) 2013 sapier
--
--This program is free software; you can redistribute it and/or modify
--it under the terms of the GNU Lesser General Public License as published by
--the Free Software Foundation; either version 2.1 of the License, or
--(at your option) any later version.
--
--This program is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--GNU Lesser General Public License for more details.
--
--You should have received a copy of the GNU Lesser General Public License along
--with this program; if not, write to the Free Software Foundation, Inc.,
--51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

--------------------------------------------------------------------------------

local function get_formspec(data)

        local mod = data.list:get_list()[data.selected_mod]

        local retval =
                "size[16,11]"..
                "bgcolor[#00000070;true]"..
                "box[-100,8.5;200,10;#999999]" ..
                "box[-100,-10;200,12;#999999]" ..

                "label[1, 2.5;" .. fgettext("World:") .. "]" ..
                "label[2.75,2.5;" .. data.worldspec.name .. "]"

        if data.hide_gamemods then
                retval = retval .. "checkbox[1,7.55;cb_hide_gamemods;" .. fgettext("Hide Game") .. ";true]"
        else
                retval = retval .. "checkbox[1,7.55;cb_hide_gamemods;" .. fgettext("Hide Game") .. ";false]"
        end

        if data.hide_modpackcontents then
                retval = retval .. "checkbox[4,7.55;cb_hide_mpcontent;" .. fgettext("Hide mp content") .. ";true]"
        else
                retval = retval .. "checkbox[4,7.55;cb_hide_mpcontent;" .. fgettext("Hide mp content") .. ";false]"
        end

        if mod == nil then
                mod = {name=""}
        end

        retval = retval ..
                "label[1,3;" .. fgettext("Mod:") .. "]" ..
                "label[2.75,3;" .. mod.name .. "]" ..
                "label[8,3;" .. fgettext("Depends:") .. "]" ..
                "textlist[8,3.5;7,4.0;world_config_depends;" ..
                modmgr.get_dependencies(mod.path) .. ";0]" ..
                "image_button[8,9.55;3.95,0.8;"..mm_texture.basetexturedir.."menu_button.png;btn_config_world_save;" .. fgettext("Save") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"..
                "image_button[12,9.55;4,0.8;"..mm_texture.basetexturedir.."menu_button.png;btn_config_world_cancel;".. fgettext("Cancel") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"

        if mod ~= nil and mod.name ~= "" and mod.typ ~= "game_mod" then
                if mod.is_modpack then
                        local rawlist = data.list:get_raw_list()

                        local all_enabled = true
                        for j=1,#rawlist,1 do
                                if rawlist[j].modpack == mod.name and
                                        rawlist[j].enabled ~= true then
                                                all_enabled = false
                                                break
                                end
                        end

                        if all_enabled == false then
                                retval = retval .. "image_button[8,7.55;3.5,0.8;"..mm_texture.basetexturedir.."menu_button.png;btn_mp_enable;" .. fgettext("Enable MP") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"
                        else
                                retval = retval .. "image_button[8,7.85;3.5,0.8;"..mm_texture.basetexturedir.."menu_button.png;btn_mp_disable;" .. fgettext("Disable MP") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"
                        end
                else
                        if mod.enabled then
                                retval = retval .. "checkbox[8.25,7.55;cb_mod_enable;" .. fgettext("enabled") .. ";true]"
                        else
                                retval = retval .. "checkbox[8.25,7.55;cb_mod_enable;" .. fgettext("enabled") .. ";false]"
                        end
                end
        end

        retval = retval ..
                "image_button[11.75,7.55;3.5,0.8;"..mm_texture.basetexturedir.."menu_button.png;btn_all_mods;" .. fgettext("Enable all") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"..
                "textlist[1,3.5;6,4.0;world_config_modlist;"
                --"textlist[5.5,0.5;5.5,5.75;world_config_modlist;"

        retval = retval .. modmgr.render_modlist(data.list)
        retval = retval .. ";" .. data.selected_mod .."]"

        return retval
end

local function enable_mod(this, toset)
        local mod = this.data.list:get_list()[this.data.selected_mod]

        if mod.typ == "game_mod" then
                -- game mods can't be enabled or disabled
        elseif not mod.is_modpack then
                if toset == nil then
                        mod.enabled = not mod.enabled
                else
                        mod.enabled = toset
                end
        else
                local list = this.data.list:get_raw_list()
                for i=1,#list,1 do
                        if list[i].modpack == mod.name then
                                if toset == nil then
                                        toset = not list[i].enabled
                                end
                                list[i].enabled = toset
                        end
                end
        end
end


local function handle_buttons(this, fields)

        if fields["world_config_modlist"] ~= nil then
                local event = core.explode_textlist_event(fields["world_config_modlist"])
                this.data.selected_mod = event.index
                core.setting_set("world_config_selected_mod", event.index)

                if event.type == "DCL" then
                        enable_mod(this)
                end

                return true
        end

        if fields["key_enter"] ~= nil then
                enable_mod(this)
                return true
        end

        if fields["cb_mod_enable"] ~= nil then
                local toset = core.is_yes(fields["cb_mod_enable"])
                enable_mod(this,toset)
                return true
        end

        if fields["btn_mp_enable"] ~= nil or
                fields["btn_mp_disable"] then
                local toset = (fields["btn_mp_enable"] ~= nil)
                enable_mod(this,toset)
                return true
        end

        if fields["cb_hide_gamemods"] ~= nil or
                fields["cb_hide_mpcontent"] ~= nil then
                local current = this.data.list:get_filtercriteria()

                if current == nil then
                        current = {}
                end

                if fields["cb_hide_gamemods"] ~= nil then
                        if core.is_yes(fields["cb_hide_gamemods"]) then
                                current.hide_game = true
                                this.data.hide_gamemods = true
                                core.setting_set("world_config_hide_gamemods", "true")
                        else
                                current.hide_game = false
                                this.data.hide_gamemods = false
                                core.setting_set("world_config_hide_gamemods", "false")
                        end
                end

                if fields["cb_hide_mpcontent"] ~= nil then
                        if core.is_yes(fields["cb_hide_mpcontent"]) then
                                current.hide_modpackcontents = true
                                this.data.hide_modpackcontents = true
                                core.setting_set("world_config_hide_modpackcontents", "true")
                        else
                                current.hide_modpackcontents = false
                                this.data.hide_modpackcontents = false
                                core.setting_set("world_config_hide_modpackcontents", "false")
                        end
                end

                this.data.list:set_filtercriteria(current)
                return true
        end

        if fields["btn_config_world_save"] then

                local filename = this.data.worldspec.path ..
                                DIR_DELIM .. "world.mt"

                local worldfile = Settings(filename)
                local mods = worldfile:to_table()

                local rawlist = this.data.list:get_raw_list()

                local i,mod
                for i,mod in ipairs(rawlist) do
                        if not mod.is_modpack and
                                        mod.typ ~= "game_mod" then
                                if mod.enabled then
                                        worldfile:set("load_mod_"..mod.name, "true")
                                else
                                        worldfile:set("load_mod_"..mod.name, "false")
                                end
                                mods["load_mod_"..mod.name] = nil
                        end
                end

                -- Remove mods that are not present anymore
                for key,value in pairs(mods) do
                        if key:sub(1,9) == "load_mod_" then
                                worldfile:remove(key)
                        end
                end

                if not worldfile:write() then
                        core.log("error", "Failed to write world config file")
                end

                this:delete()
                return true
        end

        if fields["btn_config_world_cancel"] then
                this:delete()
                return true
        end

        if fields["btn_all_mods"] then
                local list = this.data.list:get_raw_list()

                for i=1,#list,1 do
                        if list[i].typ ~= "game_mod" and
                                not list[i].is_modpack then
                                list[i].enabled = true
                        end
                end
                return true
        end

        return false
end

function create_configure_world_dlg(worldidx)

        local dlg = dialog_create("sp_config_world",
                                        get_formspec,
                                        handle_buttons,
                                        nil)

        dlg.data.hide_gamemods = core.setting_getbool("world_config_hide_gamemods")
        dlg.data.hide_modpackcontents = core.setting_getbool("world_config_hide_modpackcontents")
        dlg.data.selected_mod = tonumber(core.setting_get("world_config_selected_mod"))
        if dlg.data.selected_mod == nil then
                dlg.data.selected_mod = 0
        end

        dlg.data.worldspec = core.get_worlds()[worldidx]
        if dlg.data.worldspec == nil then dlg:delete() return nil end

        dlg.data.worldconfig = modmgr.get_worldconfig(dlg.data.worldspec.path)

        if dlg.data.worldconfig == nil or dlg.data.worldconfig.id == nil or
                        dlg.data.worldconfig.id == "" then

                dlg:delete()
                return nil
        end

        dlg.data.list = filterlist.create(
                        modmgr.preparemodlist, --refresh
                        modmgr.comparemod, --compare
                        function(element,uid) --uid match
                                        if element.name == uid then
                                                return true
                                        end
                                end,
                                function(element,criteria)
                                        if criteria.hide_game and
                                                element.typ == "game_mod" then
                                                        return false
                                        end

                                        if criteria.hide_modpackcontents and
                                                element.modpack ~= nil then
                                                        return false
                                                end
                                        return true
                                end, --filter
                                { worldpath= dlg.data.worldspec.path,
                                  gameid = dlg.data.worldspec.gameid }
                        )


        if dlg.data.selected_mod > dlg.data.list:size() then
                dlg.data.selected_mod = 0
        end

        dlg.data.list:set_filtercriteria(
                {
                        hide_game=dlg.data.hide_gamemods,
                        hide_modpackcontents= dlg.data.hide_modpackcontents
                })
        dlg.data.list:add_sort_mechanism("alphabetic", sort_mod_list)
        dlg.data.list:set_sortmode("alphabetic")

        return dlg
end
