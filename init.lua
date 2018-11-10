-- awesome-modalbind - modal keybindings for awesomewm

local awesome, client, mouse, screen, tag = awesome, client, mouse, screen, tag
local modalbind = {}
local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local nesting = 0
local verbose = false

--local functions

local defaults = {}

defaults.opacity = 1.0
defaults.height = 22
defaults.x_offset = 0
defaults.y_offset = 0
defaults.show_options = true
defaults.position = "bottom_left"
defaults.honor_padding = true
defaults.honor_workarea = true

-- Clone the defaults for the used settings
local settings = {}
for key, value in pairs(defaults) do
	settings[key] = value
end

local prev_layout = nil

local aliases = {}
aliases[" "] = "space"



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
				label = label .. "\n\n<big>" ..
					mapping[2] .. "</big>"
			elseif mapping[1] ~= "onClose" then
				label = label .. "\n<b>" .. mapping[1] ..
					"</b>\t" .. (mapping[3] or "???")
			end
		end

	end
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
	mar.opacity = settings.opacity

	mbox.visible = true
end

local function hide_box()
	screen[1].modewibox.visible = false
end

local function mapping_for(keymap, key)
	for _, mapping in ipairs(keymap) do
		if mapping[1] == key or
		(aliases[key] and mapping[1] == aliases[key]) then
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

function modalbind.grab(options)
	local keymap = options.keymap or {}
	local name = options.name
	local stay_in_mode = options.stay_in_mode or false
	local args = options.args
	local layout = options.layout

	layout_swap(layout)
	if name then
		show_box(mouse.screen, keymap, name)
		nesting = nesting + 1
	end
	call_key_if_present(keymap, "onOpen", args)

	keygrabber.run(function(mod, key, event)
		if key == "Escape" then
			call_key_if_present(keymap, "onClose", args)
			close_box()
			layout_return()
			return true
		end

		if event == "release" then return true end

		mapping = mapping_for(keymap, key)
		if mapping then
			keygrabber.stop()
			mapping[2](args)
			if stay_in_mode then
				modalbind.grab{keymap = keymap,
					name = name,
					stay_in_mode = true,
					args = args}
			else
				nesting = nesting - 1
				if nesting < 1 then hide_box() end
				layout_return()
				return true
			end
		else
			if verbose then
				print("Unmapped key: \"" .. key .. "\"")
			end
		end

		return true
	end)
end

function modalbind.grabf(keymap, name, stay_in_mode)
	return function() modalbind.grab(keymap, name, stay_in_mode) end
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

---  set key aliases table
function modalbind.set_aliases(t)
	aliases = t
end

return modalbind
