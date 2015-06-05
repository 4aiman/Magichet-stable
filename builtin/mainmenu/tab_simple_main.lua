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
    --favourites
local function image_column(tooltip, flagname)
      return "image," ..
             "tooltip=" .. core.formspec_escape(tooltip) .. "," ..
             "0=" .. core.formspec_escape(defaulttexturedir .. "blank.png") .. "," ..
             "1=" .. core.formspec_escape(defaulttexturedir .. "server_flags_" .. flagname .. ".png")
end

local function get_formspec(tabview, name, tabdata)
    local retval = ""
    retval = retval .. "bgcolor[#00000000;false]"
    retval = retval .. "image_button[2.5,1.0;7,1;multicraftbutton.png;btn_show_singleplayer;".. fgettext("Singleplayer") .. ";true;true;multicraftbutton.png]"
    retval = retval .. "image_button[2.5,2.4;7,1;multicraftbutton.png;btn_show_multiplayer;" .. fgettext("Multiplayer") .. ";true;true;multicraftbutton.png]"
    retval = retval .. "image_button[2.5,3.8;7,1;multicraftbutton.png;btn_show_options;"..      fgettext("Options") .. ";true;true;multicraftbutton.png]"
    retval = retval .. "image_button[2.5,5.2;7,1;multicraftbutton.png;btn_exit;".. fgettext("Exit") .. ";true;true;multicraftbutton.png]"
    return retval
end

--------------------------------------------------------------------------------

local function main_button_handler(tabview, fields, name, tabdata)
    local index = 0
    if fields["btn_show_singleplayer"] then  index = 1 end
    if fields["btn_show_multiplayer"]  then  index = 2 end
    if fields["btn_show_options"]      then  index = 3 end
    if fields["btn_exit"] then core.close() end

    --switch_to_tab(self, index)
end

--------------------------------------------------------------------------------
local function on_activate(type,old_tab,new_tab)
    if type == "LEAVE" then
        return
    end
    core.set_topleft_text('Multicraft II')
    if core.setting_getbool("public_serverlist") then
        asyncOnlineFavourites()
    else
        menudata.favorites = core.get_favorites("local")
    end
end

--------------------------------------------------------------------------------
tab_simple_main = {
    name = "main",
    caption = fgettext("Main"),
    cbf_formspec = get_formspec,
    cbf_button_handler = main_button_handler,
    on_change = on_activate
    }
