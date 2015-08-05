--Magichet
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

tab_credits = {
        name = "credits",
        caption = fgettext("Credits"),
        cbf_formspec = function (tabview, name, tabdata)
                        local logofile = defaulttexturedir .. "logo.png"
                        return  "size[16,11]"..
                                "bgcolor[#00000070;true]"..
                                "box[-100,8.5;200,10;#999999]" ..
                                "box[-100,-10;200,12;#999999]" ..

                                "image_button[12,9.55;4,0.8;"..mm_texture.basetexturedir.."menu_button.png;btn_cancel;".. fgettext("OK") .. ";true;true;"..mm_texture.basetexturedir.."menu_button_b.png]"..
                                "label[2.5,9.55;Magichet 1.2]" ..
                                "image[0.25,8.7;2,2;"..core.formspec_escape(logofile).."]"..
                                "textlist[0,2.0;15.8,6.25;list_credits;" ..
                                "#FFFF00" .. fgettext("Core Developers") .."," ..
                                "       Perttu Ahola (celeron55) <celeron55@gmail.com>,"..
                                "       Ryan Kwolek (kwolekr) <kwolekr@minetest.net>,"..
                                "       kahrl <kahrl@gmx.net>,"..
                                "       proller <proler@gmail.com>,"..
                                "       PilzAdam <pilzadam@minetest.net>," ..
                                "       ShadowNinja <shadowninja@minetest.net>,"..
                                "       sfan5 <sfan5@live.de>,"..
                                "       ...,"..
                                --","..
                                "#FFFF00" .. fgettext("Active Contributors") .. "," ..
                                "       sapier,"..
                                "       Craig Robbins (Zeno) <craig.d.robbins@gmail.com>,"..
                                "       kilbith,"..
                                "       paramat,"..
                                "       ...,"..
                                --","..
                                "#FFFF00" .. fgettext("Magichet Developers") .. "," ..
                                "       4aiman Konsorumaniakku <4aiman@inbox.ru>,"..
                                "       ...,"..
                                --"," ..
                                "#FFFF00" .. fgettext("Previous Contributors") .. "," ..
                                "       Vanessa Ezekowitz (VanessaE) <vanessaezekowitz@gmail.com>,"..
                                "       Jurgen Doser (doserj) <jurgen.doser@gmail.com>,"..
                                "       Jeija <jeija@mesecons.net>,"..
                                "       MirceaKitsune <mirceakitsune@gmail.com>,"..
                                "       dannydark <the_skeleton_of_a_child@yahoo.co.uk>,"..
                                "       0gb.us <0gb.us@0gb.us>,"..
                                "       Ilya Zhuravlev (xyz) <xyz@minetest.net>,"..
                                "       Guiseppe Bilotta (Oblomov) <guiseppe.bilotta@gmail.com>,"..
                                "       Jonathan Neuschafer <j.neuschaefer@gmx.net>,"..
                                "       Nils Dagsson Moskopp (erlehmann) <nils@dieweltistgarnichtso.net>,"..
                                "       Constantin Wenger (SpeedProg) <constantin.wenger@googlemail.com>,"..
                                "       matttpt <matttpt@gmail.com>,"..
                                "       JacobF <queatz@gmail.com>,"..
                                "       ...,"..
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
