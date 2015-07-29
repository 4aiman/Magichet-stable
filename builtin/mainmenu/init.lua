--Minetest
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

mt_color_grey  = "#AAAAAA"
mt_color_blue  = "#0000DD"
mt_color_green = "#00DD00"
mt_color_dark_green = "#003300"

--for all other colors ask sfan5 to complete his work!

local menupath = core.get_mainmenu_path()
local basepath = core.get_builtin_path()
defaulttexturedir = core.get_texturepath_share() .. DIR_DELIM .. "base" ..
                    DIR_DELIM .. "pack" .. DIR_DELIM

dofile(basepath .. DIR_DELIM .. "common" .. DIR_DELIM .. "async_event.lua")
dofile(basepath .. DIR_DELIM .. "common" .. DIR_DELIM .. "filterlist.lua")
dofile(basepath .. DIR_DELIM .. "fstk" .. DIR_DELIM .. "buttonbar.lua")
dofile(basepath .. DIR_DELIM .. "fstk" .. DIR_DELIM .. "dialog.lua")
dofile(basepath .. DIR_DELIM .. "fstk" .. DIR_DELIM .. "tabview.lua")
dofile(basepath .. DIR_DELIM .. "fstk" .. DIR_DELIM .. "ui.lua")
dofile(menupath .. DIR_DELIM .. "common.lua")
dofile(menupath .. DIR_DELIM .. "gamemgr.lua")
dofile(menupath .. DIR_DELIM .. "modmgr.lua")
dofile(menupath .. DIR_DELIM .. "store.lua")
dofile(menupath .. DIR_DELIM .. "dlg_config_world.lua")
dofile(menupath .. DIR_DELIM .. "tab_credits.lua")
dofile(menupath .. DIR_DELIM .. "tab_mods.lua")
dofile(menupath .. DIR_DELIM .. "tab_settings.lua")
dofile(menupath .. DIR_DELIM .. "tab_help.lua")
    dofile(menupath .. DIR_DELIM .. "dlg_create_world.lua")
    dofile(menupath .. DIR_DELIM .. "dlg_delete_mod.lua")
    dofile(menupath .. DIR_DELIM .. "dlg_delete_world.lua")
    dofile(menupath .. DIR_DELIM .. "dlg_rename_modpack.lua")
    dofile(menupath .. DIR_DELIM .. "dlg_add_server.lua")
    dofile(menupath .. DIR_DELIM .. "tab_multiplayer.lua")
    dofile(menupath .. DIR_DELIM .. "tab_server.lua")
    dofile(menupath .. DIR_DELIM .. "tab_singleplayer.lua")
    dofile(menupath .. DIR_DELIM .. "tab_texturepacks.lua")
    dofile(menupath .. DIR_DELIM .. "textures.lua")

--------------------------------------------------------------------------------
local function main_event_handler(tabview, event)
    if event == "MenuQuit" then
        core.close()
    end

    return true
end

--------------------------------------------------------------------------------
local function get_formspec2(tabview, name, tabdata)
    local retval = ""
    retval = retval .. "bgcolor[#00000000;false]"
    retval = retval .. "image_button[2.5,3.4;7,1;"..mm_texture.basetexturedir.."menu_button.png;btn_show_multiplayer;" .. fgettext("Multiplayer") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"
    retval = retval .. "image_button[2.5,4.8;7,1;"..mm_texture.basetexturedir.."menu_button.png;btn_show_options;"..      fgettext("Options") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"
    if PLATFORM=="Android" then
       retval = retval .. "image_button[8.5,4.8;1,1;"..mm_texture.basetexturedir.."menu_button.png;btn_show_help;?;true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"
    end
    -- modstore (broken)
    --retval = retval .. "image_button[7.5,4.8;1,1;"..mm_texture.basetexturedir.."menu_button.png;btn_show_modstore;M;true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"
    retval = retval .. "image_button[2.5,6.2;7,1;"..mm_texture.basetexturedir.."menu_button.png;btn_exit;".. fgettext("Exit") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"
    retval = retval .. "image_button[2.5,2.0;7,1;"..mm_texture.basetexturedir.."menu_button.png;btn_show_singleplayer;".. fgettext("Singleplayer") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"

    local si = core.get_screen_info()

    local ydiv = si.window_height/5.2
    local xdiv = si.window_width/12.5
    local ratio = xdiv/ydiv
--    print(xdiv..' x '..ydiv..' = '..ratio)

    math.randomseed(os.time())
    local rnd = 'image[6,0.5;9,1.5;'..mm_texture.basetexturedir..'ad_label'..tostring(math.random(1,17))..'.png]'

    return retval .. rnd
end

--------------------------------------------------------------------------------

local function main_button_handler2(tabview, fields, name, tabdata)
    local index = ''
    if fields["btn_show_singleplayer"] then  index = "server"       end
    if fields["btn_show_multiplayer"]  then  index = "multiplayer"  end
    if fields["btn_show_options"]      then  index = "settings"     end
    if fields["btn_show_help"]         then  index = "help"         end
    if fields["btn_show_modstore"]     then  index = "mods"         end
    if fields["btn_exit"] then core.close() end

    if index == '' then return end
    for name,def in pairs(tabview.tablist) do
       if index == def.name then
        local get_fs = function()
           local retval = def.get_formspec(tabview, name, tabdata)
           retval = 'size[12,5.2]'..retval
           return retval
        end
        local dlg = dialog_create(def.name, get_fs, def.button_handler, def.on_change)
        dlg:set_parent(tabview)
        tabview:hide()
        dlg:show()
        asyncOnlineFavourites()
        return dlg
       end
    end
   return false
end

--------------------------------------------------------------------------------
local function on_activate2(type,old_tab,new_tab)
    if type == "LEAVE" then
        return
    end
    if core.setting_getbool("public_serverlist") then
        asyncOnlineFavourites()
    else
        menudata.favorites = core.get_favorites("local")
    end
    mm_texture.clear("header")
    mm_texture.clear("footer")
    core.set_clouds(false)
    core.set_background("background",mm_texture.basetexturedir..'background.png')
    core.set_background("header",mm_texture.basetexturedir..'header.png')


end

--------------------------------------------------------------------------------
tab_main = {
    name = "main",
    caption = fgettext("Main"),
    cbf_formspec = get_formspec2,
    cbf_button_handler = main_button_handler2,
    on_change = on_activate2
    }

--------------------------------------------------------------------------------
local function init_globals()
    -- Init gamedata
    gamedata.worldindex = 0

    menudata.worldlist = filterlist.create(
        core.get_worlds,
        compare_worlds,
        -- Unique id comparison function
        function(element, uid)
            return element.name == uid
        end,
        -- Filter function
        function(element, gameid)
            return element.gameid == gameid
        end
    )

    menudata.worldlist:add_sort_mechanism("alphabetic", sort_worlds_alphabetic)
    menudata.worldlist:set_sortmode("alphabetic")

    if not core.setting_get("menu_last_game") then
        local default_game = core.setting_get("default_game") or "magichet"
        core.setting_set("menu_last_game", default_game )
    end

    mm_texture.init()


    -- Create main tabview
    local tv_main = tabview_create("maintab",{x=12,y=5.2},{x=0,y=0})

    tv_main:set_autosave_tab(false)
    --tv_main:add(tab_simple_main)
    tv_main:add(tab_main)
    tv_main:add(tab_singleplayer)
    tv_main:add(tab_multiplayer)
    tv_main:add(tab_server)
    tv_main:add(tab_settings)
    tv_main:add(tab_texturepacks)
    tv_main:add(tab_mods)
    tv_main:add(tab_help)
    tv_main:add(tab_credits)

    tv_main:set_global_event_handler(main_event_handler)
    tv_main:set_fixed_size(false)
    ui.set_default("main")

    tv_main:show()

    -- Create modstore ui
    if PLATFORM == "Android" then
        modstore.init({x=12, y=6}, 3, 2)
    else
        modstore.init({x=12, y=8}, 4, 3)
    end

    ui.update()

    core.sound_play("main_menu", true)

end

init_globals()
