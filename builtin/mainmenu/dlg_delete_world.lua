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


local function delete_world_formspec(dialogdata)

        local retval =
                "size[16,11]"..
                "bgcolor[#00000070;true]"..
                "box[-100,8.5;200,10;#999999]" ..
                "box[-100,-10;200,12;#999999]" ..
                "label[6.5,4.5;" ..
                fgettext("Delete World \"$1\"?", dialogdata.delete_name) .. "]"..
                "image_button[4,5.7;4,0.8;"..mm_texture.basetexturedir.."menu_button.png;world_delete_confirm;" .. fgettext("Yes").. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"..
                "image_button[8,5.7;4,0.8;"..mm_texture.basetexturedir.."menu_button.png;world_delete_cancel;" .. fgettext("No") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"
        return retval
end

local function delete_world_buttonhandler(this, fields)
        if fields["world_delete_confirm"] then

                if this.data.delete_index > 0 and
                        this.data.delete_index <= #menudata.worldlist:get_raw_list() then
                        core.delete_world(this.data.delete_index)
                        menudata.worldlist:refresh()
                end
                this:delete()
                return true
        end

        if fields["world_delete_cancel"] then
                this:delete()
                return true
        end

        return false
end


function create_delete_world_dlg(name_to_del,index_to_del)

        assert(name_to_del ~= nil and type(name_to_del) == "string" and name_to_del ~= "")
        assert(index_to_del ~= nil and type(index_to_del) == "number")

        local retval = dialog_create("delete_world",
                                        delete_world_formspec,
                                        delete_world_buttonhandler,
                                        nil)
        retval.data.delete_name  = name_to_del
        retval.data.delete_index = index_to_del

        return retval
end
