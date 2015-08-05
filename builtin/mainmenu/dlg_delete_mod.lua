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

--------------------------------------------------------------------------------

local function delete_mod_formspec(dialogdata)

        dialogdata.mod = modmgr.global_mods:get_list()[dialogdata.selected]

        local retval =
                "size[16,11]"..
                "bgcolor[#00000070;true]"..
                "box[-100,8.5;200,10;#999999]" ..
                "box[-100,-10;200,12;#999999]" ..
                "label[6.5,4.5;" ..
                fgettext("Are you sure you want to delete \"$1\"?", dialogdata.mod.name) ..  ";]"..
                "image_button[4,5.7;4,0.8;"..mm_texture.basetexturedir.."menu_button.png;dlg_delete_mod_confirm;" .. fgettext("Yes").. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"..
                "image_button[8,5.7;4,0.8;"..mm_texture.basetexturedir.."menu_button.png;dlg_delete_mod_cancel;" .. fgettext("No") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"
        return retval
end

--------------------------------------------------------------------------------
local function delete_mod_buttonhandler(this, fields)
        if fields["dlg_delete_mod_confirm"] ~= nil then

                if this.data.mod.path ~= nil and
                        this.data.mod.path ~= "" and
                        this.data.mod.path ~= core.get_modpath() then
                        if not core.delete_dir(this.data.mod.path) then
                                gamedata.errormessage = fgettext("Modmgr: failed to delete \"$1\"", this.data.mod.path)
                        end
                        modmgr.refresh_globals()
                else
                        gamedata.errormessage = fgettext("Modmgr: invalid modpath \"$1\"", this.data.mod.path)
                end
                this:delete()
                return true
        end

        if fields["dlg_delete_mod_cancel"] then
                this:delete()
                return true
        end

        return false
end

--------------------------------------------------------------------------------
function create_delete_mod_dlg(selected_index)

        local retval = dialog_create("dlg_delete_mod",
                                        delete_mod_formspec,
                                        delete_mod_buttonhandler,
                                        nil)
        retval.data.selected = selected_index
        return retval
end
