local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local InputContainer = require("ui/widget/container/inputcontainer")
local MovableContainer = require("ui/widget/container/movablecontainer")
local NumberPickerWidget = require("ui/widget/numberpickerwidget")
local Size = require("ui/size")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local Screen = Device.screen
local T = require("ffi/util").template

local SpinWidget = InputContainer:new{
    title_text = "",
    info_text = nil,
    width = nil,
    width_factor = nil, -- number between 0 and 1, factor to the smallest of screen width and height
    height = nil,
    value_table = nil,
    value_index = nil,
    value = 1,
    value_min = 0,
    value_max = 20,
    value_step = 1,
    value_hold_step = 4,
    precision = nil, -- default "%02d" in NumberPickerWidget
    wrap = false,
    cancel_text = _("Close"),
    ok_text = _("Apply"),
    ok_always_enabled = false, -- set to true to enable OK button for unchanged value
    cancel_callback = nil,
    callback = nil,
    close_callback = nil,
    keep_shown_on_apply = false,
    -- Set this to add upper default button that restores number to its default value
    default_value = nil,
    default_text = nil,
    -- Optional extra button
    extra_text = nil,
    extra_callback = nil,
    -- Optional extra button above ok/cancel buttons row
    option_text = nil,
    option_callback = nil,
}

function SpinWidget:init()
    -- used to enable ok_button, self.value may be changed in extra callback
    self.original_value = self.value_table and self.value_table[self.value_index or 1] or self.value

    self.screen_width = Screen:getWidth()
    self.screen_height = Screen:getHeight()
    if not self.width then
        if not self.width_factor then
            self.width_factor = 0.6 -- default if no width speficied
        end
        self.width = math.floor(math.min(self.screen_width, self.screen_height) * self.width_factor)
    end
    if Device:hasKeys() then
        self.key_events = {
            Close = { {"Back"}, doc = "close spin widget" }
        }
    end
    if Device:isTouchDevice() then
        self.ges_events = {
            TapClose = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{
                        w = self.screen_width,
                        h = self.screen_height,
                    }
                },
            },
         }
    end

    -- Actually the widget layout
    self:update()
end

function SpinWidget:update(numberpicker_value, numberpicker_value_index)
    local value_widget = NumberPickerWidget:new{
        show_parent = self,
        value = numberpicker_value or self.value,
        value_table = self.value_table,
        value_index = numberpicker_value_index or self.value_index,
        value_min = self.value_min,
        value_max = self.value_max,
        value_step = self.value_step,
        value_hold_step = self.value_hold_step,
        precision = self.precision,
        wrap = self.wrap,
        picker_updated_callback = function(value, value_index)
            self:update(value, value_index)
        end,
    }
    local value_group = HorizontalGroup:new{
        align = "center",
        value_widget,
    }

    local title_bar = TitleBar:new{
        width = self.width,
        align = "left",
        with_bottom_line = true,
        title = self.title_text,
        title_shrink_font_to_fit = true,
        info_text = self.info_text,
        show_parent = self,
    }

    local buttons = {}
    if self.default_value then
        table.insert(buttons, {
            {
                text = self.default_text or T(_("Default value: %1"),
                    self.precision and string.format(self.precision, self.default_value) or self.default_value),
                callback = function()
                    value_widget.value = self.default_value
                    value_widget:update()
                end,
            },
        })
    end

    local extra_button = {
        text = self.extra_text,
        callback = function()
            if self.extra_callback then
                self.value, self.value_index = value_widget:getValue()
                self.extra_callback(self)
            end
            if not self.keep_shown_on_apply then -- assume extra wants it same as ok
                self:onClose()
            end
        end,
    }
    local option_button = {
        text = self.option_text,
        callback = function()
            if self.option_callback then
                self.value, self.value_index = value_widget:getValue()
                self.option_callback(self)
            end
            if not self.keep_shown_on_apply then -- assume option wants it same as ok
                self:onClose()
            end
        end,
    }
    if self.extra_text and not self.option_text then
        table.insert(buttons, {extra_button})
    elseif self.option_text and not self.extra_text then
        table.insert(buttons, {option_button})
    elseif self.extra_text and self.option_text then
        table.insert(buttons, {extra_button, option_button})
    end
    table.insert(buttons, {
        {
            text = self.cancel_text,
            callback = function()
                if self.cancel_callback then
                    self.cancel_callback()
                end
                self:onClose()
            end,
        },
        {
            text = self.ok_text,
            enabled = self.ok_always_enabled or self.original_value ~= value_widget:getValue(),
            callback = function()
                self.value, self.value_index = value_widget:getValue()
                self.original_value = self.value
                if self.callback then
                    self.callback(self)
                end
                if self.keep_shown_on_apply then
                    self:update()
                else
                    self:onClose()
                end
            end,
        },
    })

    local ok_cancel_buttons = ButtonTable:new{
        width = self.width - 2 * Size.padding.default,
        buttons = buttons,
        zero_sep = true,
        show_parent = self,
    }

    local vgroup = VerticalGroup:new{
        align = "left",
        title_bar,
    }
    table.insert(vgroup, CenterContainer:new{
        dimen = Geom:new{
            w = self.width,
            h = value_group:getSize().h + 4 * Size.padding.large,
        },
        value_group
    })
    table.insert(vgroup, CenterContainer:new{
        dimen = Geom:new{
            w = self.width,
            h = ok_cancel_buttons:getSize().h,
        },
        ok_cancel_buttons
    })
    self.spin_frame = FrameContainer:new{
        radius = Size.radius.window,
        padding = 0,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        vgroup,
    }
    self.movable = MovableContainer:new{
        self.spin_frame,
    }
    self[1] = WidgetContainer:new{
        align = "center",
        dimen =Geom:new{
            x = 0, y = 0,
            w = self.screen_width,
            h = self.screen_height,
        },
        self.movable,
    }
    UIManager:setDirty(self, function()
        return "ui", self.spin_frame.dimen
    end)
end

function SpinWidget:hasMoved()
    local offset = self.movable:getMovedOffset()
    return offset.x ~= 0 or offset.y ~= 0
end

function SpinWidget:onCloseWidget()
    UIManager:setDirty(nil, function()
        return "ui", self.spin_frame.dimen
    end)
end

function SpinWidget:onShow()
    UIManager:setDirty(self, function()
        return "ui", self.spin_frame.dimen
    end)
    return true
end

function SpinWidget:onAnyKeyPressed()
    self:onClose()
    return true
end

function SpinWidget:onTapClose(arg, ges_ev)
    if ges_ev.pos:notIntersectWith(self.spin_frame.dimen) then
        self:onClose()
    end
    return true
end

function SpinWidget:onClose()
    UIManager:close(self)
    if self.close_callback then
        self.close_callback()
    end
    return true
end

return SpinWidget
