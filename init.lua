-- awesome-modalbind - modal keybindings for awesomewm

local modalbind = {}
local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local inited = false
local modewidget = {}
local modewibox = { screen = nil }
local nesting = 0

--local functions

local defaults = {}

defaults.opacity = 1.0
defaults.height = 22
defaults.x_offset = 0
defaults.y_offset = 0
defaults.show_options = true
defaults.x_position = "left"
defaults.y_position = "bottom"

-- Clone the defaults for the used settings
local settings = {}
for key, value in pairs(defaults) do
	settings[key] = value
end

local aliases = {}
aliases[" "] = "space"




local function getXOffset(s)
	local xpos = settings.x_position

	if type(xpos) == "number" then
		return xpos + s.geometry.x
	elseif xpos == "left" then
		return s.geometry.x + settings.x_offset
	elseif xpos == "right" then
		return s.geometry.x + s.geometry.width - modewibox[s].width - settings.x_offset
	elseif xpos == "center" then
		return s.geometry.x + s.geometry.width / 2 - modewibox[s].width / 2 + settings.x_offset
	end
	return 0
end


local function getYOffset(s)
	local ypos = settings.y_position

	if type(ypos) == "number" then
		return ypos + s.geometry.y
	elseif ypos == "top" then
		return s.geometry.y + settings.y_offset
	elseif ypos == "bottom" then
		return s.geometry.y + s.geometry.height - modewibox[s].height - settings.y_offset
	elseif ypos == "center" then
		return s.geometry.y + s.geometry.height / 2 - modewibox[s].height / 2 + settings.y_offset
	end
	return 0
end

local function calculate_position(s)
	local minwidth, minheight = modewidget[s]:fit({dpi=96}, s.geometry.width,
		s.geometry.height)
	modewibox[s].width = minwidth + 1;
	modewibox[s].height = math.max(settings.height, minheight)

	modewibox[s].x = getXOffset(s)
	modewibox[s].y = getYOffset(s)
end

local function update_settings()
	for s, value in pairs(modewibox) do
		calculate_position(s)
		value.opacity = settings.opacity
	end
end


function modalbind.init()
	awful.screen.connect_for_each_screen(function(s)
		modewidget[s] = wibox.widget.textbox()
		modewidget[s]:set_align("left")
		if beautiful.fontface then
			modewidget[s]:set_font(beautiful.fontface .. " " .. (beautiful.fontsize + 4))
		end

		modewibox[s] = wibox({
			fg = beautiful.modebox_fg or beautiful.fg_normal,
			bg = beautiful.modebox_bg or beautiful.bg_normal,
			border_width = beautiful.modebox_border_width or beautiful.border_width,
			border_color = beautiful.modebox_border or beautiful.border_focus,
			screen = s
		})

		local modelayout = {}
		modelayout[s] = wibox.layout.fixed.horizontal()
		modelayout[s]:add(modewidget[s])
		modewibox[s]:set_widget(modelayout[s]);
		calculate_position(s)
		modewibox[s].visible = false
		modewibox[s].ontop = true

		modewibox[s].widgets = {
			modewidget[s],
			layout = wibox.layout.fixed.horizontal
		}
	end)
end

local function show_box(s, map, name)
	modewibox.screen = s
	awful.screen.connect_for_each_screen(
	function(s)
		  if modewibox.screen ~= s then modewibox[s].visible = false end
	end)
	local label = "<big><b>" .. name .. "</b></big>"
	if settings.show_options then
		for _, mapping in ipairs(map) do
			if mapping[1] == "separator" then
				label = label .. "\n\n<big>" .. mapping[2] .. "</big>\n"
			elseif mapping[1] ~= "onClose" then
				label = label .. "\n<b>" .. mapping[1] .. "</b>\t" .. (mapping[3] or "???")
			end
		end

	end
	modewidget[s]:set_markup(label)
	modewibox[s].visible = true
	calculate_position(s)
end

local function hide_box()
       local s = modewibox.screen
       awful.screen.connect_for_each_screen(function(s)
		modewibox[s].visible = false
       end)
end

local function mapping_for(keymap, key)
	for _, mapping in ipairs(keymap) do
		if mapping[1] == key or (aliases[key] and mapping[1] == aliases[key]) then
			return mapping
		end
	end
	return nil
end

local function close_box()
	keygrabber.stop()
	nesting = 0
	hide_box();
end

local function call_key_if_present(keymap, key, args)
	local callback = mapping_for(keymap,key)
	if callback then callback[2](args) end
end

function modalbind.grab(keymap, name, stay_in_mode, args)
	if name then
		show_box(mouse.screen, keymap, name)
		nesting = nesting + 1
	end
	call_key_if_present(keymap, "onOpen", args)

	keygrabber.run(function(mod, key, event)
		if key == "Escape" then
			call_key_if_present(keymap, "onClose", args)
			close_box()
			return true
		end

		if event == "release" then return true end

		mapping = mapping_for(keymap, key)
		if mapping then
			keygrabber.stop()
			mapping[2](args)
			if stay_in_mode then
				modalbind.grab(keymap, name, true)
			else
				nesting = nesting - 1
				if nesting < 1 then hide_box() end
				return true
			end
		else
			print("Unmapped key: \"" .. key .. "\"")
		end

		return true
	end)
end

function modalbind.grabf(keymap, name, stay_in_mode)
	return function() modalbind.grab(keymap, name, stay_in_mode) end
end

--- Returns the wibox displaying the bound keys
function modalbind.modebox() return modewibox[mouse.screen] end

--- Change the opacity of the modebox.
-- @param amount opacity between 0.0 and 1.0, or nil to use default
function modalbind.set_opacity(amount)
	settings.opacity = amount or defaults.opacity
	update_settings()
end

--- Change min height of the modebox.
-- @param amount height in pixels, or nil to use default
function modalbind.set_minheight(amount)
	settings.height = amount or defaults.height
	update_settings()
end

--- Change horizontal offset of the modebox.
-- set location for the box with set_corner(). The box is shifted to the right
-- if it is in one of the left corners or to the left otherwise
-- @param amount horizontal shift in pixels, or nil to use default
function modalbind.set_x_offset (amount)
	settings.x_offset = amount or defaults.x_offset
	update_settings()
end

--- Change vertical offset of the modebox.
-- set location for the box with set_corner(). The box is shifted downwards if it
-- is in one of the upper corners or upwards otherwise.
-- @param amount vertical shift in pixels, or nil to use default
function modalbind.set_y_offset(amount)
	settings.y_offset = amount or defaults.y_offset
	update_settings()
end

--- Set the corner, where the modebox will be displayed
-- If a parameter is not a valid orientation (see below), the function returns
-- without doing anything
-- @param vertical either top or bottom
-- @param horizontal either left or right
function modalbind.set_location(horizontal, vertical)
	if (vertical ~= "top" and vertical ~= "bottom" and vertical ~= "center" and type(vertical) ~= "number") then
		return
	end
	if (horizontal ~= "left" and horizontal ~= "right" and horizontal ~= "center" and type(horizontal) ~= "number") then
		return
	end

	settings.x_position = horizontal
	settings.y_position = vertical
end

---  enable displaying bindings for current mode
function modalbind.show_options()
	settings.show_options = true
end
--
---  disable displaying bindings for current mode
function modalbind.hide_options()
	settings.show_options = false
end

return modalbind
