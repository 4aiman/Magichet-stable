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
local dd_filter_labels = {
        fgettext("No Filter"),
        fgettext("Bilinear Filter"),
        fgettext("Trilinear Filter")
}

local filters = {
        {dd_filter_labels[1]..","..dd_filter_labels[2]..","..dd_filter_labels[3]},
        {"", "bilinear_filter", "trilinear_filter"},
}

local dd_mipmap_labels = {
        fgettext("No Mipmap"),
        fgettext("Mipmap"),
        fgettext("Mipmap + Aniso. Filter")
}

local mipmap = {
        {dd_mipmap_labels[1]..","..dd_mipmap_labels[2]..","..dd_mipmap_labels[3]},
        {"", "mip_map", "anisotropic_filter"},
}

local function getFilterSettingIndex()
        if (core.setting_get(filters[2][3]) == "true") then
                return 3
        end
        if (core.setting_get(filters[2][3]) == "false" and core.setting_get(filters[2][2]) == "true") then
                return 2
        end
        return 1
end

local function getMipmapSettingIndex()
        if (core.setting_get(mipmap[2][3]) == "true") then
                return 3
        end
        if (core.setting_get(mipmap[2][3]) == "false" and core.setting_get(mipmap[2][2]) == "true") then
                return 2
        end
        return 1
end

local function video_driver_fname_to_name(selected_driver)
        local video_drivers = core.get_video_drivers()

        for i=1, #video_drivers do
                if selected_driver == video_drivers[i].friendly_name then
                        return video_drivers[i].name:lower()
                end
        end

        return ""
end
local function dlg_confirm_reset_formspec(data)
        local retval =
                "size[8,3]" ..
                "label[1,1;".. fgettext("Are you sure to reset your singleplayer world?") .. "]"..
                "image_button[1,2;2.6,0.8;"..mm_texture.basetexturedir.."menu_button.png;dlg_reset_singleplayer_confirm;"..
                                fgettext("Yes") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"..
                "image_button[4,2;2.8,0.8;"..mm_texture.basetexturedir.."menu_button.png;dlg_reset_singleplayer_cancel;"..
                                fgettext("No!!!") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"
        return retval
end

local function dlg_confirm_reset_btnhandler(this, fields, dialogdata)

        if fields["dlg_reset_singleplayer_confirm"] ~= nil then
                local worldlist = core.get_worlds()
                local found_singleplayerworld = false

                for i=1,#worldlist,1 do
                        if worldlist[i].name == "singleplayerworld" then
                                found_singleplayerworld = true
                                gamedata.worldindex = i
                        end
                end

                if found_singleplayerworld then
                        core.delete_world(gamedata.worldindex)
                end

                core.create_world("singleplayerworld", 1)

                worldlist = core.get_worlds()

                found_singleplayerworld = false

                for i=1,#worldlist,1 do
                        if worldlist[i].name == "singleplayerworld" then
                                found_singleplayerworld = true
                                gamedata.worldindex = i
                        end
                end
        end

        this.parent:show()
        this:hide()
        this:delete()
        return true
end

local function showconfirm_reset(tabview)
        local new_dlg = dialog_create("reset_spworld",
                dlg_confirm_reset_formspec,
                dlg_confirm_reset_btnhandler,
                nil)
        new_dlg:set_parent(tabview)
        tabview:hide()
        new_dlg:show()
end

local function gui_scale_to_scrollbar()

        local current_value = tonumber(core.setting_get("gui_scaling"))

        if (current_value == nil) or current_value < 0.25 then
                return 0
        end

        if current_value <= 1.25 then
                return ((current_value - 0.25)/ 1.0) * 700
        end

        if current_value <= 6 then
                return ((current_value -1.25) * 100) + 700
        end

        return 1000
end

local function scrollbar_to_gui_scale(value)

        value = tonumber(value)

        if (value <= 700) then
                return ((value / 700) * 1.0) + 0.25
        end

        if (value <=1000) then
                return ((value - 700) / 100) + 1.25
        end

        return 1
end

local function formspec(tabview, name, tabdata)
        local video_drivers = core.get_video_drivers()
        local current_video_driver = core.setting_get("video_driver"):lower()

        local driver_formspec_string = ""
        local driver_current_idx = 0

        for i=2, #video_drivers do
                driver_formspec_string = driver_formspec_string .. video_drivers[i].friendly_name
                if i ~= #video_drivers then
                        driver_formspec_string = driver_formspec_string .. ","
                end

                if current_video_driver == video_drivers[i].name:lower() then
                        driver_current_idx = i - 1
                end
        end


        local tab_string =
                "size[16,11]"..
                "bgcolor[#00000070;true]"..
                "box[-100,8.5;200,10;#999999]" ..
                "box[-100,-10;200,12;#999999]" ..

                "box[0.75,2.5;4.5,3.9;#999999]" ..
                "checkbox[1.0,2.5;cb_smooth_lighting;".. fgettext("Smooth Lighting")
                                .. ";".. dump(core.setting_getbool("smooth_lighting")) .. "]"..
                "checkbox[1.0,3.0;cb_particles;".. fgettext("Enable Particles") .. ";"
                                .. dump(core.setting_getbool("enable_particles"))       .. "]"..
                "checkbox[1.0,3.5;cb_3d_clouds;".. fgettext("3D Clouds") .. ";"
                                .. dump(core.setting_getbool("enable_3d_clouds")) .. "]"..
                "checkbox[1.0,4.0;cb_fancy_trees;".. fgettext("Fancy Trees") .. ";"
                                .. dump(core.setting_getbool("new_style_leaves")) .. "]"..
                "checkbox[1.0,4.5;cb_opaque_water;".. fgettext("Opaque Water") .. ";"
                                .. dump(core.setting_getbool("opaque_water")) .. "]"..
                "checkbox[1.0,5.0;cb_connected_glass;".. fgettext("Connected Glass") .. ";"
                                .. dump(core.setting_getbool("connected_glass"))        .. "]"..
                "checkbox[1.0,5.5;cb_node_highlighting;".. fgettext("Node Highlighting") .. ";"
                                .. dump(core.setting_getbool("enable_node_highlighting")) .. "]"..


        "box[5.5,2.5;4,3.45;#999999]" ..
        "label[5.85,2.5;".. fgettext("Texturing:") .. "]"..
        "dropdown[5.85,3.05;3.85;dd_filters;" .. filters[1][1] .. ";"
                .. getFilterSettingIndex() .. "]" ..
        "dropdown[5.85,3.85;3.85;dd_mipmap;" .. mipmap[1][1] .. ";"
                .. getMipmapSettingIndex() .. "]" ..
        "label[5.85,4.65;".. fgettext("Rendering:") .. "]"..
        "dropdown[5.85,5.1;3.85;dd_video_driver;"
                                .. driver_formspec_string .. ";" .. driver_current_idx .. "]" ..
        "tooltip[dd_video_driver;" ..
                fgettext("Restart minetest for driver change to take effect") .. "]"




        if PLATFORM ~= "Android" then
                tab_string = tab_string ..
                "box[9.75,2.5;5.25,4;#999999]"..
                "checkbox[10,2.5;cb_shaders;".. fgettext("Shaders") .. ";"
                .. dump(core.setting_getbool("enable_shaders")) .. "]"..
                "image_button[0,9.55;4,0.8;"..mm_texture.basetexturedir.."menu_button.png;btn_change_keys;".. fgettext("Change keys") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"--..
--                "image_button[3.75,5;3.88,0.8;"..mm_texture.basetexturedir.."menu_button.png;btn_reset_singleplayer;".. fgettext("Reset singleplayer world") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"
        else
                --tab_string = tab_string ..
--                "image_button[3.75,5;3.88,0.8;"..mm_texture.basetexturedir.."menu_button.png;btn_reset_singleplayer;".. fgettext("Reset singleplayer world") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"
        end

        tab_string = tab_string ..
        "image_button[4,9.55;3.95,0.8;"..mm_texture.basetexturedir.."menu_button.png;btn_show_textures;".. fgettext("Texturepacks") .. ";true;true;"..mm_texture.basetexturedir..
        "menu_button_b.png]"..
        "image_button[8,9.55;3.95,0.8;"..mm_texture.basetexturedir.."menu_button.png;btn_show_credits;".. fgettext("Credits") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"..
        "image_button[12,9.55;4,0.8;"..mm_texture.basetexturedir.."menu_button.png;btn_cancel;".. fgettext("OK") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"


        if PLATFORM == "Android" then
                tab_string = tab_string ..
                "box[9.75,2.5;5.25,2.5;#999999]" ..
                "checkbox[10,2.75;cb_touchscreen_target;".. fgettext("Touch free target") .. ";" .. dump(core.setting_getbool("touchtarget")) .. "]"..

                "box[0.75,6.8;14.25,1.35;#999999]" ..
                "label[1.5,6.8;" .. fgettext("GUI scale factor") .. "]"..
                "scrollbar[1.0,7.2;13.75,0.7;sb_gui_scaling;horizontal;" .. gui_scale_to_scrollbar() .. "]" ..
                "tooltip[sb_gui_scaling;" .. fgettext("Scaling factor applied to menu elements: ") .. dump(core.setting_get("gui_scaling")) .. "]"

              --  if core.setting_get("touchscreen_threshold") ~= nil then
                   tab_string = tab_string ..
                                "label[10,3.5;" .. fgettext("Touchthreshold (px)") .. "]" ..
                                "dropdown[10,4.0;5.18;dd_touchthreshold;0,10,20,30,40,50;" .. ((tonumber(core.setting_get("touchscreen_threshold") or 20)/10)+1) .. "]"
              --  end

        else
            tab_string = tab_string ..
                "box[0.75,6.8;14.25,1.35;#999999]" ..
                "label[1.5,6.8;" .. fgettext("GUI scale factor") .. "]"..
                "scrollbar[1.0,7.5;13.75,0.4;sb_gui_scaling;horizontal;" .. gui_scale_to_scrollbar() .. "]" ..
                "tooltip[sb_gui_scaling;" .. fgettext("Scaling factor applied to menu elements: ") .. dump(core.setting_get("gui_scaling")) .. "]"
        end

        if PLATFORM ~= "Android" then
           if core.setting_getbool("enable_shaders") then
                tab_string = tab_string ..
                                "checkbox[10,3.0;cb_bumpmapping;".. fgettext("Bumpmapping") .. ";"
                                                .. dump(core.setting_getbool("enable_bumpmapping")) .. "]"..
                                "checkbox[10,3.5;cb_generate_normalmaps;".. fgettext("Generate Normalmaps") .. ";"
                                                .. dump(core.setting_getbool("generate_normalmaps")) .. "]"..
                                "checkbox[10,4.0;cb_parallax;".. fgettext("Parallax Occlusion") .. ";"
                                                .. dump(core.setting_getbool("enable_parallax_occlusion")) .. "]"..
                                "checkbox[10,4.5;cb_waving_water;".. fgettext("Waving Water") .. ";"
                                                .. dump(core.setting_getbool("enable_waving_water")) .. "]"..
                                "checkbox[10,5.0;cb_waving_leaves;".. fgettext("Waving Leaves") .. ";"
                                                .. dump(core.setting_getbool("enable_waving_leaves")) .. "]"..
                                "checkbox[10,5.5;cb_waving_plants;".. fgettext("Waving Plants") .. ";"
                                                .. dump(core.setting_getbool("enable_waving_plants")) .. "]"
           else
                tab_string = tab_string ..
                                "textlist[10.3,3.2;4,1;;#888888" .. fgettext("Bumpmapping") .. ";0;true]" ..
                                "textlist[10.3,3.7;4,1;;#888888" .. fgettext("Generate Normalmaps") .. ";0;true]" ..
                                "textlist[10.3,4.2;4,1;;#888888" .. fgettext("Parallax Occlusion") .. ";0;true]" ..
                                "textlist[10.3,4.7;4,1;;#888888" .. fgettext("Waving Water") .. ";0;true]" ..
                                "textlist[10.3,5.2;4,1;;#888888" .. fgettext("Waving Leaves") .. ";0;true]" ..
                                "textlist[10.3,5.7;4,1;;#888888" .. fgettext("Waving Plants") .. ";0;true]"
           end
        end
        return tab_string
end

--------------------------------------------------------------------------------
local function handle_settings_buttons(this, fields, tabname, tabdata)
        if fields["cb_fancy_trees"] then
                core.setting_set("new_style_leaves", fields["cb_fancy_trees"])
                return true
        end
        if fields["cb_smooth_lighting"] then
                core.setting_set("smooth_lighting", fields["cb_smooth_lighting"])
                return true
        end
        if fields["cb_3d_clouds"] then
                core.setting_set("enable_3d_clouds", fields["cb_3d_clouds"])
                return true
        end
        if fields["cb_opaque_water"] then
                core.setting_set("opaque_water", fields["cb_opaque_water"])
                return true
        end
        if fields["cb_mipmapping"] then
                core.setting_set("mip_map", fields["cb_mipmapping"])
                return true
        end
        if fields["cb_anisotrophic"] then
                core.setting_set("anisotropic_filter", fields["cb_anisotrophic"])
                return true
        end
        if fields["cb_bilinear"] then
                core.setting_set("bilinear_filter", fields["cb_bilinear"])
                return true
        end
        if fields["cb_trilinear"] then
                core.setting_set("trilinear_filter", fields["cb_trilinear"])
                return true
        end
        if fields["cb_shaders"] then
                if (core.setting_get("video_driver") == "direct3d8" or core.setting_get("video_driver") == "direct3d9") then
                        core.setting_set("enable_shaders", "false")
                        gamedata.errormessage = fgettext("To enable shaders the OpenGL driver needs to be used.")
                else
                        core.setting_set("enable_shaders", fields["cb_shaders"])
                end
                return true
        end
        if fields["cb_connected_glass"] then
                core.setting_set("connected_glass", fields["cb_connected_glass"])
                return true
        end
        if fields["cb_particles"] then
                core.setting_set("enable_particles", fields["cb_particles"])
                return true
        end
        if fields["cb_bumpmapping"] then
                core.setting_set("enable_bumpmapping", fields["cb_bumpmapping"])
        end
        if fields["cb_generate_normalmaps"] then
                core.setting_set("generate_normalmaps", fields["cb_generate_normalmaps"])
        end
        if fields["cb_parallax"] then
                core.setting_set("enable_parallax_occlusion", fields["cb_parallax"])
                return true
        end
        if fields["cb_waving_water"] then
                core.setting_set("enable_waving_water", fields["cb_waving_water"])
                return true
        end
        if fields["cb_waving_leaves"] then
                core.setting_set("enable_waving_leaves", fields["cb_waving_leaves"])
        end
        if fields["cb_waving_plants"] then
                core.setting_set("enable_waving_plants", fields["cb_waving_plants"])
                return true
        end
        if fields["btn_change_keys"] ~= nil then
                core.show_keys_menu()
                return true
        end

        if fields["sb_gui_scaling"] then
                local event = core.explode_scrollbar_event(fields["sb_gui_scaling"])

                if event.type == "CHG" then
                        local tosave = string.format("%.2f",scrollbar_to_gui_scale(event.value))
                        core.setting_set("gui_scaling",tosave)
                        return true
                end
        end
        if fields["cb_touchscreen_target"] then
                core.setting_set("touchtarget", fields["cb_touchscreen_target"])
                return true
        end
        if fields["btn_reset_singleplayer"] then
                showconfirm_reset(this)
                return true
        end

    if fields["btn_cancel"] ~= nil then
    this:hide()
    this.parent:show()
       return true
    end


    local index = ''
    if fields["btn_show_textures"] then  index = "texturepacks" end
    if fields["btn_show_credits"]  then  index = "credits"      end

    for name,def in pairs(this.parent.tablist) do
       if index == def.name then
        local get_fs = function()
           local retval = def.get_formspec(this.parent, name, tabdata)
           retval = 'size[12,5.2]'..retval
           return retval
        end
        local dlg = dialog_create(def.name, get_fs, def.button_handler, def.on_change)
        dlg:set_parent(this)
        this:hide()
        dlg:show()
        return dlg
       end
    end

    --Note dropdowns have to be handled LAST!
    local ddhandled = false

    if fields["dd_touchthreshold"] then
        core.setting_set("touchscreen_threshold",fields["dd_touchthreshold"])
        ddhandled = true
    end

    if fields["dd_video_driver"] then
        core.setting_set("video_driver",
            video_driver_fname_to_name(fields["dd_video_driver"]))
        ddhandled = true
    end
    if fields["dd_filters"] == dd_filter_labels[1] then
        core.setting_set("bilinear_filter", "false")
        core.setting_set("trilinear_filter", "false")
        ddhandled = true
    end
    if fields["dd_filters"] == dd_filter_labels[2] then
        core.setting_set("bilinear_filter", "true")
        core.setting_set("trilinear_filter", "false")
        ddhandled = true
    end
    if fields["dd_filters"] == dd_filter_labels[3] then
        core.setting_set("bilinear_filter", "false")
        core.setting_set("trilinear_filter", "true")
        ddhandled = true
    end
    if fields["dd_mipmap"] == dd_mipmap_labels[1] then
        core.setting_set("mip_map", "false")
        core.setting_set("anisotropic_filter", "false")
        ddhandled = true
    end
    if fields["dd_mipmap"] == dd_mipmap_labels[2] then
        core.setting_set("mip_map", "true")
        core.setting_set("anisotropic_filter", "false")
        ddhandled = true
    end
    if fields["dd_mipmap"] == dd_mipmap_labels[3] then
        core.setting_set("mip_map", "true")
        core.setting_set("anisotropic_filter", "true")
        ddhandled = true
    end

    return ddhandled
end

tab_settings = {
        name = "settings",
        caption = fgettext("Settings"),
        cbf_formspec = formspec,
        cbf_button_handler = handle_settings_buttons
        }
