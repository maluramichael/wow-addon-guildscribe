local addonName, addon = ...
local GuildScribe = addon

function GuildScribe:GetOptionsTable()
    return {
        type = "group",
        name = "GuildScribe",
        args = {
            general = {
                name = "General",
                type = "group",
                order = 1,
                inline = true,
                args = {
                    enabled = {
                        name = "Enable GuildScribe",
                        desc = "Enable or disable automatic guild note updates",
                        type = "toggle",
                        order = 1,
                        width = "full",
                        get = function() return self.db.profile.enabled end,
                        set = function(_, val) self.db.profile.enabled = val end,
                    },
                    noteTarget = {
                        name = "Note Target",
                        desc = "Which guild note to update",
                        type = "select",
                        order = 2,
                        values = {
                            public = "Public Note",
                            officer = "Officer Note",
                            both = "Both",
                        },
                        get = function() return self.db.profile.noteTarget end,
                        set = function(_, val) self.db.profile.noteTarget = val end,
                    },
                    minimapIcon = {
                        name = "Show Minimap Button",
                        desc = "Toggle the minimap button",
                        type = "toggle",
                        order = 3,
                        get = function() return not self.db.profile.minimap.hide end,
                        set = function(_, val)
                            self.db.profile.minimap.hide = not val
                            if val then
                                LibStub("LibDBIcon-1.0"):Show("GuildScribe")
                            else
                                LibStub("LibDBIcon-1.0"):Hide("GuildScribe")
                            end
                        end,
                    },
                },
            },
            format = {
                name = "Format String",
                type = "group",
                order = 2,
                inline = true,
                args = {
                    formatString = {
                        name = "Format",
                        desc = "Format string for the guild note. Use {placeholders} for dynamic values.",
                        type = "input",
                        order = 1,
                        width = "full",
                        get = function() return self.db.profile.formatString end,
                        set = function(_, val) self.db.profile.formatString = val end,
                    },
                    variables = {
                        name = "|cFFFFD100Professions:|r\n" ..
                            "  {prof1} / {prof2} - Abbreviation (e.g. Alch, Herb)\n" ..
                            "  {prof1_name} / {prof2_name} - Full name\n" ..
                            "  {prof1_level} / {prof2_level} - Current level\n" ..
                            "  {prof1_max} / {prof2_max} - Max level\n" ..
                            "\n|cFFFFD100Secondary Skills:|r\n" ..
                            "  {cooking} / {cooking_level} / {cooking_max}\n" ..
                            "  {firstaid} / {firstaid_level} / {firstaid_max}\n" ..
                            "  {fishing} / {fishing_level} / {fishing_max}\n" ..
                            "\n|cFFFFD100Character:|r\n" ..
                            "  {name} - Character name\n" ..
                            "  {level} - Character level\n" ..
                            "  {class} - Class name\n" ..
                            "\n|cFFFFD100PvP:|r\n" ..
                            "  {honor} - Current honor points\n" ..
                            "  {hks} - Lifetime honorable kills\n" ..
                            "\n|cFFFFD100Economy:|r\n" ..
                            "  {gold} - Gold (whole number)",
                        type = "description",
                        order = 2,
                        fontSize = "medium",
                    },
                    preview = {
                        name = function()
                            local noteText = self:GetNotePreview(self.db.profile.formatString)
                            local len = strlen(noteText)
                            local maxLen = self:GetMaxNoteLength()
                            local colorCode = len > maxLen and "|cFFFF0000" or "|cFF00FF00"

                            local result = "\n|cFFFFD100Result:|r |cFFFFFFFF" .. noteText .. "|r\n"
                            result = result .. "|cFFFFD100Length:|r " .. colorCode .. len .. "/" .. maxLen .. "|r"

                            if len > maxLen then
                                result = result .. "\n|cFFFF6600Note will be truncated!|r"
                            end

                            return result
                        end,
                        type = "description",
                        order = 3,
                        fontSize = "medium",
                    },
                },
            },
            triggers = {
                name = "Auto-Update Triggers",
                type = "group",
                order = 3,
                inline = true,
                args = {
                    updateOnLogin = {
                        name = "Update on Login",
                        desc = "Automatically update guild note when logging in or reloading",
                        type = "toggle",
                        order = 1,
                        width = "full",
                        get = function() return self.db.profile.updateOnLogin end,
                        set = function(_, val) self.db.profile.updateOnLogin = val end,
                    },
                    updateOnSkillChange = {
                        name = "Update on Skill Change",
                        desc = "Automatically update guild note when a profession level changes",
                        type = "toggle",
                        order = 2,
                        width = "full",
                        get = function() return self.db.profile.updateOnSkillChange end,
                        set = function(_, val) self.db.profile.updateOnSkillChange = val end,
                    },
                    updateDelay = {
                        name = "Update Delay (seconds)",
                        desc = "Delay before updating the guild note. Batches rapid skill changes.",
                        type = "range",
                        order = 3,
                        min = 2,
                        max = 10,
                        step = 1,
                        get = function() return self.db.profile.updateDelay end,
                        set = function(_, val) self.db.profile.updateDelay = val end,
                    },
                },
            },
            actions = {
                name = "Actions",
                type = "group",
                order = 4,
                inline = true,
                args = {
                    forceUpdate = {
                        name = "Force Update Now",
                        desc = "Immediately scan professions and update guild note",
                        type = "execute",
                        order = 1,
                        func = function() self:ForceUpdate() end,
                    },
                    showPreview = {
                        name = "Show Preview",
                        desc = "Show the formatted note text in chat",
                        type = "execute",
                        order = 2,
                        func = function() self:ShowPreview() end,
                    },
                },
            },
            commands = {
                name = "Slash Commands",
                type = "group",
                order = 5,
                inline = true,
                args = {
                    info = {
                        name = "|cFFFFD100/gs|r - Open this options panel\n" ..
                            "|cFFFFD100/gs update|r - Force update guild note\n" ..
                            "|cFFFFD100/gs preview|r - Show formatted note in chat\n" ..
                            "|cFFFFD100/gs toggle|r - Enable/disable the addon\n" ..
                            "|cFFFFD100/gs debug|r - Toggle debug messages",
                        type = "description",
                        order = 1,
                        fontSize = "medium",
                    },
                },
            },
        },
    }
end
