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

local function add_server_formspec(dialogdata)
        local retval =
                "size[16,11]"..
                "bgcolor[#00000070;true]"..
                "box[-100,8.5;200,10;#999999]" ..
                "box[-100,-10;200,12;#999999]" ..

                "label[4,3;" .. fgettext("Address") .. "]"..
                "field[6.5,3.4;6,0.5;te_address;;]" ..

                "label[4,4;" .. fgettext("Port") .. "]"..
                "field[6.5,4.4;6,0.5;te_port;;30000]" ..

                "label[4,5;" .. fgettext("Name") .. "]"..
                "field[6.5,5.4;6,0.5;te_servername;;]" ..

                "label[4,6;" .. fgettext("Description") .. "]"..
                "field[6.5,6.4;6,0.5;te_desc;;Added on ".. os.date() .."]" ..


        "image_button[8,9.54;3.95,0.8;"..minetest.formspec_escape(mm_texture.basetexturedir).."menu_button.png;server_add_confirm;".. fgettext("Add") .. ";true;true;"..minetest.formspec_escape(mm_texture.basetexturedir).."menu_button_b.png]"..
        "image_button[12,9.55;4,0.8;"..minetest.formspec_escape(mm_texture.basetexturedir).."menu_button.png;server_add_cancel;".. fgettext("Cancel") .. ";true;true;"..minetest.formspec_escape(mm_texture.basetexturedir).."menu_button_b.png]"

        return retval
end

local function add_server_buttonhandler(this, fields)

        if fields["server_add_cancel"] then
                this:delete()
                return true
        end

        if fields["server_add_confirm"]
        or fields["key_enter"] then
           if fields["te_address"] and fields["te_port"] then           

----------------------
		   local path = core.get_modpath('')..'/../client/'..core.formspec_escape(core.setting_get("serverlist_file"))
		   local favourites
		   if path then
			  local input,err,errcode = io.open(path, "r")
			  if input then
				 favourites = input:read("*all")
				 io.close(input)
			  --else
				 --gamedata.errormessage = err..' ('..errcode..')'
			  end
		   if favourites then
			  favourites = core.parse_json(favourites)
		   end
		   if not favourites or not favourites.list then     
			  favourites = {["list"]={}}
		   end
              local servername = fields["te_servername"]              
              if not servername or servername == "" then servername = fields["te_address"] end

                 table.insert(favourites.list,{
                                            ["address"] = fields["te_address"],
                                            ["description"] = "Saved at ".. os.date(),
                                            ["name"] = servername,
                                            ["port"] = fields["te_port"],
                                            ["favourite"]      = true,
                                           }
                          )

                 favourites = core.write_json(favourites)

                 local output = io.open(path, "w")
                 if output then
                    output:write(favourites or '')
                    io.close(output)
                 else
                    gamedata.errormessage = err..' ('..errcode..')'
                 end
              end
----------------------
        
           --   this:hide()           
              this.parent:show()
              this:delete()
              asyncOnlineFavourites()
           end
           return true
        end

        return false
end


function create_add_server_dlg(update_worldlistfilter)
        local retval = dialog_create("add_server_dlg",
                                        add_server_formspec,
                                        add_server_buttonhandler,
                                        nil)
        return retval
end
