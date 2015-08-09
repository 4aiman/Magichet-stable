--Magichet
--Copyright (C) 2014 sapier
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

local function create_world_formspec(dialogdata)
        local mapgens = core.get_mapgen_names()

        local current_seed = core.setting_get("fixed_map_seed") or ""
        local current_mg   = core.setting_get("mg_name")

        local mglist = ""
        local selindex = 3
        local i = 1
        for k,v in pairs(mapgens) do
                mglist = mglist .. v .. ","
        end
        mglist = mglist:sub(1, -2)

        local gameid = core.setting_get("menu_last_game")

        local game, gameidx = nil , 0
        if gameid ~= nil then
                game, gameidx = gamemgr.find_by_gameid(gameid)

                if gameidx == nil then
                        gameidx = 1
                end
        end

        current_seed = core.formspec_escape(current_seed)
        print(selindex)
        local retval =
                "size[16,11]"..
                "bgcolor[#00000070;true]"..
                "box[-100,8.5;200,10;#999999]" ..
                "box[-100,-10;200,12;#999999]" ..

                "label[4,3;" .. fgettext("World name") .. "]"..
                "field[6.5,3.4;6,0.5;te_world_name;;]" ..

                "label[4,4;" .. fgettext("Seed") .. "]"..
                "field[6.5,4.4;6,0.5;te_seed;;".. current_seed .. "]" ..

                "label[4,5;" .. fgettext("Mapgen") .. "]"..
                "dropdown[6.2,5;6.3;dd_mapgen;" .. mglist .. ";" .. selindex .. "]" ..

                "label[4,6;" .. fgettext("Game") .. "]"..
                "dropdown[6.2,6;6.3;games;" .. gamemgr.gamelist() ..
                ";" .. gameidx .. "]" ..


        "image_button[8,9.55;3.95,0.8;"..minetest.formspec_escape(mm_texture.basetexturedir).."menu_button.png;world_create_confirm;".. fgettext("Create") .. ";true;true;"..minetest.formspec_escape(mm_texture.basetexturedir).."menu_button_b.png]"..
        "image_button[12,9.55;4,0.8;"..minetest.formspec_escape(mm_texture.basetexturedir).."menu_button.png;world_create_cancel;".. fgettext("Cancel") .. ";true;true;"..minetest.formspec_escape(mm_texture.basetexturedir).."menu_button_b.png]"

        if #gamemgr.games == 0 then
                retval = retval .. "box[4,7;8,1;#ff8800]label[4.25,7;" ..
                                fgettext("You have no subgames installed.") .. "]label[4.25,7.4;" ..
                                fgettext("Download one") .. "]"
        elseif #gamemgr.games == 1 and gamemgr.games[1].id == "minimal" then
                retval = retval .. "box[3.50,7;9,1;#ff8800]label[3.75,7;" ..
                                fgettext("Warning: The minimal development test is meant for developers.") .. "]label[3.75,7.4;" ..
                                fgettext("Download a subgame, such as magichet") .. "]"
        end

        return retval

end

local function create_world_buttonhandler(this, fields)

        if fields["world_create_cancel"] then
                this:delete()
                return true
        end

        if fields["world_create_confirm"] or
                fields["key_enter"] then

                local worldname = fields["te_world_name"]
                local gameindex
                for i,item in ipairs(gamemgr.games) do
                    if item.name == fields["games"] then
                       gameindex = i
                    end
                end
                if gameindex ~= nil and
                        worldname ~= "" then

                        local message = nil

                        if not menudata.worldlist:uid_exists_raw(worldname) then
                                core.setting_set("mg_name",fields["dd_mapgen"])
                                message = core.create_world(worldname,gameindex)
                        else
                                message = fgettext("A world named \"$1\" already exists", worldname)
                        end

                        core.setting_set("fixed_map_seed", fields["te_seed"])

                        if message ~= nil then
                                gamedata.errormessage = message
                        else
                                core.setting_set("menu_last_game",gamemgr.games[gameindex].id)
                                if this.data.update_worldlist_filter then
                                        menudata.worldlist:set_filtercriteria(gamemgr.games[gameindex].id)
                                    --    mm_texture.update("singleplayer", gamemgr.games[gameindex].id)
                                end
                                menudata.worldlist:refresh()
                                core.setting_set("mainmenu_last_selected_world",
                                                                        menudata.worldlist:raw_index_by_uid(worldname))
                        end
                else
                        gamedata.errormessage =
                                fgettext("No worldname given or no game selected")
                end
                this:delete()
                return true
        end

        if fields["games"] then
                return true
        end

        return false
end


function create_create_world_dlg(update_worldlistfilter)
        local retval = dialog_create("sp_create_world",
                                        create_world_formspec,
                                        create_world_buttonhandler,
                                        nil)
        retval.update_worldlist_filter = update_worldlistfilter

        return retval
end
