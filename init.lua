-- awesome-modalbind - modal keybindings for awesomewm

local awesome, client, mouse, screen, tag = awesome, client, mouse, screen, tag
local modalbind = {}
local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")

local defaults = {}

defaults.opacity = 1.0
defaults.height = 22
defaults.x_offset = 0
defaults.y_offset = 0
defaults.show_options = true
defaults.show_default_options = true
defaults.position = "bottom_left"
defaults.honor_padding = true
defaults.honor_workarea = true

-- Clone the defaults for the used settings
local settings = {}
for key, value in pairs(defaults) do
	settings[key] = value
end

local active_grabber = nil

local prev_layout = nil

local function layout_swap(new)
	if type(new) == "number" and new >= 0 and new <= 3 then
		prev_layout = awesome.xkb_get_layout_group()
		awesome.xkb_set_layout_group(new)
	end
end

local function layout_return()
	if prev_layout ~= nil then
		awesome.xkb_set_layout_group(prev_layout)
		prev_layout = nil
	end
end

function modalbind.init()
	local modewibox = wibox({
			ontop=true,
			visible=false,
			x=0,
			y=0,
			width=1,
			height=1,
			opacity=defaults.opacity,
			bg=beautiful.modebox_bg or
				beautiful.bg_normal,
			fg=beautiful.modebox_fg or
				beautiful.fg_normal,
			shape=gears.shape.round_rect,
			type="toolbar"
	})

	modewibox:setup({
			{
				id="text",
				align="left",
				font=beautiful.modalbind_font or
					beautiful.monospaced_font or
					beautiful.fontface or
					beautiful.font,
				widget=wibox.widget.textbox
			},
			id="margin",
			margins=beautiful.modebox_border_width or
				beautiful.border_width,
			color=beautiful.modebox_border or
				beautiful.border_focus,
			layout=wibox.container.margin,
	})

	awful.screen.connect_for_each_screen(function(s)
			s.modewibox = modewibox
	end)
end

local function show_box(s, map, name)
	local mbox = s.modewibox
	local mar = mbox:get_children_by_id("margin")[1]
	local txt = mbox:get_children_by_id("text")[1]
	mbox.screen = s

	local label = "<big><b>" .. name .. "</b></big>"
	if settings.show_options then
		for _, mapping in ipairs(map) do
			if mapping[1] == "separator" then
				label = label .. "\n\n<big>" .. mapping[2] .. "</big>"
			else
				label = label .. "\n<b>" .. table.concat(mapping[1], "+") ..
					(next(mapping[1]) ~= nil and "+" or "") .. mapping[2] .. "</b>\t" .. (mapping[4] or "???")
			end
		end

	end
	label = label .. '\n'  -- Ensure last entry is displayed.
	txt:set_markup(label)

	local x, y = txt:get_preferred_size(s)
	mbox.width = x + mar.left + mar.right
	mbox.height = math.max(settings.height, y + mar.top + mar.bottom)
	awful.placement.align(
		mbox,
		{
			position=settings.position,
			honor_padding=settings.honor_padding,
			honor_workarea=settings.honor_workarea,
			offset={x=settings.x_offset,
					y=settings.y_offset}
		}
	)
	mbox.opacity = settings.opacity

	mbox.visible = true
end

local function hide_box()
	screen[1].modewibox.visible = false
end

modalbind.default_keys = {
	{ "Escape", function() end, "Exit Modal", stay_in_mode = false},
	{ "Return", function() end, "Exit Modal", stay_in_mode = false}
}

local function merge_default_keys(keymap)
	local result = {}
	for _, default_binding in ipairs(modalbind.default_keys) do
		local no_add = false
		for _, map_binding in ipairs(keymap) do
			if default_binding[1] ~= "separator" and
				(#map_binding == 3 and default_binding[1] == map_binding[1]) or
				(#map_binding == 4 and next(map_binding[1]) == nil and default_binding[1] == map_binding[2])
				then
				no_add = true
				break
			end
		end
		if not no_add then
			table.insert(result, default_binding)
		end
	end
	for _,m in ipairs(keymap) do
		table.insert(result, m)
	end
	return result
end

local function isupper(s) return string.match(s, "%u*") == s end

--- Make adjustments to the keymap, so it works with the keygrabber
--
-- Adds an empty modifier table if necessary, makes sure Shift is combined with
-- an uppercase letter, and passes common arguments to functions.
--
-- @param keymap The keymap given to modalbind
local function adapt_to_keygrabber(keymap, case_insensitive, args)
	local added_bindings = {}
	for _, binding in ipairs(keymap) do
		if type(binding[1]) ~= "table" then
			if binding[1] == 'separator' then
				-- ignore separators
			elseif case_insensitive then
				binding[1] = string.lower(binding[1])
				table.insert(binding, 1, {} )
				table.insert(added_bindings, {{'Shift'}, string.upper(binding[1]), binding[2], binding[3]})
			elseif isupper(binding[1]) then
				binding[1] = string.lower(binding[1])
				table.insert(binding, 1, {'Shift'} )
			else
				table.insert(binding, 1, {} )
			end
		elseif gears.table.hasitem(binding[1], 'Shift') and #binding[2] == 1 then
			binding[2] = string.upper(binding[2])
		end
	end
	local all = gears.table.join(keymap, added_bindings)
	if args then
		for _, binding in ipairs(all) do
			local origfunc = binding[3]
			binding[3] = function() origfunc(args) end
		end
	end
	return all
end

local function generate_stop_keys(keymap, stay_in_mode)
	stop_keys = {}
	for _, binding in ipairs(keymap) do
		if (not stay_in_mode and not binding.stay_in_mode)
			or (stay_in_mode and binding.stay_in_mode == false) then
			table.insert(stop_keys, binding[2])
		end
	end
	if next(stop_keys) == nil then
		stop_keys = {"Escape"}
	end
	return stop_keys
end

local function without_separators(keymap)
	local clean = {}
	for k, v in pairs(keymap) do
		if not (type(v) == 'table' and v[1] == "separator") then
			clean[k] = v
		end
	end
	return clean
end

function modalbind.grab(options)
	local keymap = merge_default_keys(options.keymap or {})
	local name = options.name
	local args = options.args
	local layout = options.layout
	local use_lower = options.case_insensitive or false
	local onOpen = options.onOpen
	local onClose = options.onClose

	keymap = adapt_to_keygrabber(keymap)

	layout_swap(layout)

	if name then
		if settings.show_default_options then
			show_box(mouse.screen, keymap, name)
		else
			show_box(mouse.screen, options.keymap, name)
		end
	end

	if onOpen ~= nil then
		onOpen(args)
	end

	keymap = without_separators(keymap)

	stop_keys = generate_stop_keys(keymap, options.stay_in_mode or false)

	grabber = awful.keygrabber {
    keybindings = keymap,
		stop_key = stop_keys,
		stop_event = 'release',
		stop_callback = function(self)
			if active_grabber.name == self.name then
				if onClose ~= nil then
					onClose(args)
				end
				layout_return()
				hide_box()
				active_grabber = nil
			else
				active_grabber()
			end
		end,
	}
	grabber.name = name
	active_grabber = grabber
	grabber()
end

function modalbind.grabf(options)
	return function() modalbind.grab(options) end
end

--- Returns the wibox displaying the bound keys
function modalbind.modebox() return mouse.screen.modewibox end

--- Change the opacity of the modebox.
-- @param amount opacity between 0.0 and 1.0, or nil to use default
function modalbind.set_opacity(amount)
	settings.opacity = amount or defaults.opacity
end

--- Change min height of the modebox.
-- @param amount height in pixels, or nil to use default
function modalbind.set_minheight(amount)
	settings.height = amount or defaults.height
end

--- Change horizontal offset of the modebox.
-- set location offset for the box. The box is shifted to the right
-- @param amount horizontal shift in pixels, or nil to use default
function modalbind.set_x_offset(amount)
	settings.x_offset = amount or defaults.x_offset
end

--- Change vertical offset of the modebox.
-- set location offset for the box. The box is shifted downwards.
-- @param amount vertical shift in pixels, or nil to use default
function modalbind.set_y_offset(amount)
	settings.y_offset = amount or defaults.y_offset
end

--- Set the position, where the modebox will be displayed
-- Allowed options are listed on page
-- https://awesomewm.org/apidoc/libraries/awful.placement.html#align
-- @param position of the widget
function modalbind.set_location(position)
	settings.position = position
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
--
---  enable displaying bindings for current mode
function modalbind.show_default_options()
	settings.show_default_options = true
end
--
---  disable displaying bindings for current mode
function modalbind.hide_default_options()
	settings.show_default_options = false
end

return modalbind
