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

tab_help = {
        name = "help",
        caption = fgettext("Help"),
        cbf_formspec = function (tabview, name, tabdata)
                        local logofile = defaulttexturedir .. "logo.png"
                        return  "size[16,11]"..
                                "bgcolor[#00000070;true]"..
                                "box[-100,8.5;200,10;#999999]" ..
                                "box[-100,-10;200,12;#999999]" ..

                                "image_button[12,9.55;4,0.8;"..mm_texture.basetexturedir.."menu_button.png;btn_cancel;".. fgettext("OK") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"..
                                "label[2.5,9.55;Magichet 1.2]" ..
                                "image[0.25,9;2,2;"..core.formspec_escape(logofile).."]"..

                                "textlist[0,2;15.8,6.25;list_help;" ..
                                "#FFFF00How to begin to play (ENG)," ..
                                "       - Press and hold to dig a block,"..
                                "       - Doubletap to place a block,"..
                                "       - To split a stack 'long pess' on it and,"..
                                "         w/o releasing it tap a separate inventory cell,"..
                                ","..
                                "#FFFF00Как начать играть (RUS)," ..
                                "       - Долгое нажатие = сломать блок,"..
                                "       - Двойное нажатие = поставить блок,"..
                                "       - Для разделения стака на части,"..
                                "         нажмите на стак и удерживая его,"..
                                "         нажмите вторым пальцем на свободной,"..
                                "         ячейке интвентаря"..
                                ";0;true]"
                        end,
        cbf_button_handler = function(tabview, fields, name, tabdata)
               if fields["btn_cancel"] ~= nil then
                  tabview:hide()
                  tabview.parent:show()
                  return true
               end
        return false
        end
        }
