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

--------------------------------------------------------------------------------
local last_selected_server
local function get_formspec(tabview, name, tabdata)
        --print('last selected IN get_fs: '..dump(last_selected_server))
        local retval =
                "size[16,11]"..
                "box[-100,8.5;200,10;#999999]" ..
                "box[-100,-10;200,12;#999999]" ..
                "bgcolor[#00000070;true]"..

                "image_button[12,9.55;4,0.8;"..mm_texture.basetexturedir.."menu_button.png;cancel;".. fgettext("Cancel") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"..
                --"label[0,1.25;" .. fgettext("Address/Port") .. "]" ..
                "field[1000.25,5.25;5.5,0.5;te_address;;" ..
                core.formspec_escape(core.setting_get("address")) .. "]" ..
                "field[1005.75,5.25;2.25,0.5;te_port;;" ..
                core.formspec_escape(core.setting_get("remote_port")) .. "]" ..
                "checkbox[1000,3.6;cb_public_serverlist;" .. fgettext("Public Serverlist") .. ";" ..
                dump(core.setting_getbool("public_serverlist")) .. "]"..

                "label[7,1.5;" .. fgettext("Select Server:") .. "]" ..
                "label[0.2,0.8;Selected: "..core.formspec_escape(core.setting_get("address"))..":"..core.formspec_escape(core.setting_get("remote_port")).."]"
                


        --if not core.setting_getbool("public_serverlist") then
        if last_selected_server and last_selected_server.favourite then
                retval = retval ..
                "image_button[3.2,9.55;0.8,0.8;"..mm_texture.basetexturedir.."favourite_btn.png;btn_mp_favour;-;true;false;"..mm_texture.basetexturedir.."menu_button_b.png]"
        else
                retval = retval ..
                "image_button[3.2,9.55;0.8,0.8;"..mm_texture.basetexturedir.."favourite_btn.png;btn_mp_favour;+;true;false;"..mm_texture.basetexturedir.."menu_button_b.png]"
        end

        retval = retval ..
                "image_button[8,9.55;3.95,0.8;"..mm_texture.basetexturedir.."menu_button.png;btn_mp_connect;" .. fgettext("Connect") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"..
                "image_button[4,9.55;4,0.8;"..mm_texture.basetexturedir.."menu_button.png;add_server;" .. fgettext("Add") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"..
                

                "label[8,8;" .. fgettext("Name") .. ":]" ..
                "field[8.3,9;3.95,0.8;te_name;;" ..
                core.formspec_escape(core.setting_get("name")) .. "]" ..
                "label[12,8;" .. fgettext("Password") .. ":]" ..
                "pwdfield[12.3,9;4,0.8;te_pwd;]" ..
                "textarea[9.3,0;2.5,3.0;;"

        if tabdata.fav_selected ~= nil and
                menudata.favorites[tabdata.fav_selected] ~= nil and
                menudata.favorites[tabdata.fav_selected].description ~= nil then
                retval = retval ..
                        core.formspec_escape(menudata.favorites[tabdata.fav_selected].description,true)
        end

        retval = retval ..
                ";]"

        --favourites
        local function image_column(tooltip, flagname)
                local ret = "image," ..
                        "tooltip=" .. core.formspec_escape(tooltip) .. ","
      --                  if flagname ~= 'favourite' then
                           ret = ret .. "0=" .. core.formspec_escape(defaulttexturedir .. "blank.png") .. ","
--                        else                        
  --                         ret = ret .. "0=" .. core.formspec_escape(defaulttexturedir .. "server_flags_" .. flagname .. "_off.png") .. ","
    --                    end
                           ret = ret .. "1=" .. core.formspec_escape(defaulttexturedir .. "server_flags_" .. flagname .. ".png")
                return ret
        end
        retval = retval .. "tablecolumns[" ..
                        image_column("Favourite", "favourite") .. ",align=right;"..
                        "color,span=3;" ..                        
                        "text,align=right;" ..                -- clients
                        "text,align=center,padding=0.25;" ..  -- "/"
                        "text,align=right,padding=0.25;" ..   -- clients_max
                        image_column("Creative mode", "creative") .. ",padding=1;" ..
                        image_column("Damage enabled", "damage") .. ",padding=0.25;" ..
                        image_column("PvP enabled", "pvp") .. ",padding=0.25;" ..
                        image_column("No password allowed", "password") .. ",padding=0.25;" ..
                        "text,padding=1]"
                        

        retval = retval ..
                 "tableoptions[background=#00000000;border=false]"..
                 "table[0,2.2;16,6.25;favourites;"

        --if #menudata.favorites == 0 then
        --   asyncOnlineFavourites()
        --end


        if #menudata.favorites > 0 then
                retval = retval .. render_favorite(menudata.favorites[1])

                for i=2,#menudata.favorites,1 do
                    retval = retval .. "," .. render_favorite(menudata.favorites[i])
                end
        end
      --  retval = retval..','
        

        if tabdata.fav_selected ~= nil then
                retval = retval .. ";" .. tabdata.fav_selected .. "]"
        else
                retval = retval .. ";0]"
        end
--print(retval)
        return retval
end

--------------------------------------------------------------------------------
local function main_button_handler(tabview, fields, name, tabdata)
        --print('fields in btn_handler: '..dump(fields)) 
        if not tabdata then tabdata = {} end

        if fields["add_server"] ~= nil then
                local add_server_dlg = create_add_server_dlg(true)
                add_server_dlg:set_parent(tabview)
                add_server_dlg:show()
                tabview:hide()
                return true
        end

        if fields["te_name"] ~= nil then
                gamedata.playername = fields["te_name"]
                core.setting_set("name", fields["te_name"])
        end        
        
        if fields["favourites"] ~= nil then
                local event = core.explode_table_event(fields["favourites"])
                --print('Event dumo (btn handler): '..dump(event))
                if event.type == "DCL" then
                   if menudata.favorites[event.row] ~= nil then                   
                        if event.row <= #menudata.favorites then
                                gamedata.address    = menudata.favorites[event.row].address
                                gamedata.port       = menudata.favorites[event.row].port
                                gamedata.playername = fields["te_name"]
                                if fields["te_pwd"] ~= nil then
                                        gamedata.password               = fields["te_pwd"]
                                end
                                gamedata.selected_world = 0

                                if menudata.favorites ~= nil then
                                        gamedata.servername        = menudata.favorites[event.row].name
                                        gamedata.serverdescription = menudata.favorites[event.row].description
                                end

                                if gamedata.address ~= nil and
                                        gamedata.port ~= nil then
                                        core.setting_set("address",gamedata.address)
                                        core.setting_set("remote_port",gamedata.port)
                                     --   core.start()
                                end
                        end
                        return true
                   end
                end

                if event.type == "CHG" then
                   last_selected_server = menudata.favorites[event.row]                                 
                   --print('last selected in CHG:  '..dump(last_selected_server))
                        if event.row <= #menudata.favorites then                           
                                local address = menudata.favorites[event.row].address
                                local port    = menudata.favorites[event.row].port                                   
                                
                                if address ~= nil and
                                        port ~= nil then
                                        core.setting_set("address",address)
                                        core.setting_set("remote_port",port)
                                end

                                tabdata.fav_selected = event.row
                        end
                    
                        return true
                end
        end

        if fields["key_up"] ~= nil or
                fields["key_down"] ~= nil then

                local fav_idx = core.get_table_index("favourites")

                if fav_idx ~= nil then
                        if fields["key_up"] ~= nil and fav_idx > 1 then
                                fav_idx = fav_idx -1
                        else if fields["key_down"] and fav_idx < #menudata.favorites then
                                fav_idx = fav_idx +1
                        end end
                else
                        fav_idx = 1
                end

                if menudata.favorites == nil or
                        menudata.favorites[fav_idx] == nil then
                        tabdata.fav_selected = 0
                        return true
                end

                local address = menudata.favorites[fav_idx].address
                local port    = menudata.favorites[fav_idx].port

                if address ~= nil and
                        port ~= nil then
                        core.setting_set("address",address)
                        core.setting_set("remote_port",port)
                end

                tabdata.fav_selected = fav_idx
                return true
        end

        if fields["cb_public_serverlist"] ~= nil then
                core.setting_set("public_serverlist", fields["cb_public_serverlist"])
                asyncOnlineFavourites()
                tabdata.fav_selected = nil
                return true
        end

        if fields["btn_mp_favour"] ~= nil then
		   local current_favourite = core.get_table_index("favourites")
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
			  favourites = minetest.parse_json(favourites)
		   end
		   if not favourites or not favourites.list then     
			  favourites = {["list"]={}}
		   end
		   
 		   local servername = menudata.favorites[current_favourite].name
           
           if last_selected_server and last_selected_server.favourite then 
              local favs = {}
              local count = 0
              for i,v in ipairs(favourites.list) do                  
                  if  (last_selected_server.name == v.name or servername == v.name)
                  and (last_selected_server.address == v.address or last_selected_server.name == v.address)
                  and (last_selected_server.port == v.port)
                  then
                      print('Removing "'.. v.name ..'" from favourites')  
                  else
                     count = count +1
                     table.insert(favs,count,v)
                  end
              end       
              favourites.list = favs    
             -- last_selected_server.favourite = nil
           else              
			  table.insert(favourites.list,{
											["address"]        = fields["te_address"],
											["description"]    = "Saved on ".. os.date(),
											["name"]           = servername or last_selected_server.name,
											["playername"]     = fields["te_name"],
											["playerpassword"] = fields["te_pwd"],
											["port"]           = fields["te_port"],
											["creative"]       = last_selected_server.creative,
											["pvp"]            = last_selected_server.pvp,
											["password"]       = last_selected_server.password,
											["clients_max"]    = last_selected_server.clients_max,
											["damage"]         = last_selected_server.damage,
											["favourite"]      = true,
										   }
						  )				  
			  print('Adding "'.. (servername or last_selected_server.name) ..'" to favourites')  
		   end
              favourites = minetest.write_json(favourites)
				  local output,err,errcode = io.open(path, "w")
				  if output then
					 output:write(favourites or '')
					 io.close(output)
				  else
					 --gamedata.errormessage = fgettext("Can't write to serverlist_file! ("..path..')')
					 gamedata.errormessage = err..' ('..errcode..')'
				  end
			   end
			   asyncOnlineFavourites()
           
        end

        if fields["btn_delete_favorite"] ~= nil then
                local current_favourite = core.get_table_index("favourites")
                if current_favourite == nil then return end
                if current_favourite > #core.get_favorites('offline') then return end
                core.delete_favorite(current_favourite)
                tabdata.fav_selected = nil
                asyncOnlineFavourites()


                core.setting_set("address","")
                core.setting_set("remote_port","30000")

                return true
        end

        if fields["btn_mp_connect"] ~= nil or
                fields["key_enter"] ~= nil then

                gamedata.playername     = fields["te_name"]
                gamedata.password       = fields["te_pwd"]
                gamedata.address        = fields["te_address"]
                gamedata.port           = fields["te_port"]

                local fav_idx = core.get_table_index("favourites")
                if fav_idx ~= nil and fav_idx <= #menudata.favorites and
                        menudata.favorites[fav_idx].address == fields["te_address"] and
                        menudata.favorites[fav_idx].port    == fields["te_port"] then
                else
                        gamedata.servername        = ""
                        gamedata.serverdescription = ""
                end

                gamedata.selected_world = 0

                core.setting_set("address",    fields["te_address"])
                core.setting_set("remote_port",fields["te_port"])

                core.start()
                return true
        end

        if fields["cancel"] ~= nil then
           tabview:hide()
           tabview.parent:show()
           return true
        end

        return false
end

local function on_change(type,old_tab,new_tab)
   if type == "LEAVE" then
      return
   end
end

--------------------------------------------------------------------------------
tab_multiplayer = {
        name = "multiplayer",
        caption = fgettext("Client"),
        cbf_formspec = get_formspec,
        cbf_button_handler = main_button_handler,
        --on_change = on_change
        }
