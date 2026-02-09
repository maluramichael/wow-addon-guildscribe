local addonName, addon = ...
local GuildScribe = LibStub("AceAddon-3.0"):NewAddon(addon, addonName, "AceEvent-3.0", "AceConsole-3.0")
_G["GuildScribe"] = GuildScribe

-- Constants
local GUILD_NOTE_MAX_LENGTH = 31

local PROFESSION_ABBREVIATIONS = {
    ["Alchemy"] = "Alch",
    ["Blacksmithing"] = "BS",
    ["Enchanting"] = "Ench",
    ["Engineering"] = "Eng",
    ["Herbalism"] = "Herb",
    ["Jewelcrafting"] = "JC",
    ["Leatherworking"] = "LW",
    ["Mining"] = "Mine",
    ["Skinning"] = "Skin",
    ["Tailoring"] = "Tail",
}

local SECONDARY_SKILLS = {
    ["Cooking"] = true,
    ["First Aid"] = true,
    ["Fishing"] = true,
}

local SECONDARY_KEYS = {
    ["Cooking"] = "cooking",
    ["First Aid"] = "firstaid",
    ["Fishing"] = "fishing",
}

-- Defaults
local defaults = {
    profile = {
        formatString = "{prof1} {prof1_level} / {prof2} {prof2_level}",
        noteTarget = "public",
        updateOnLogin = true,
        updateOnSkillChange = true,
        updateDelay = 3,
        enabled = true,
        debugMode = false,
        minimap = {
            hide = false,
        },
    },
}

-- State
local professionData = { primaries = {}, secondaries = {} }
local waitingForRoster = false
local updateTimer = nil

-- Forward declarations
local ScanProfessions
local BuildNoteText
local UpdateGuildNote
local ScheduleUpdate
local FindPlayerGuildIndex

-------------------------------------------------------------------------------
-- Debug
-------------------------------------------------------------------------------
local function Debug(msg)
    if GuildScribe.db and GuildScribe.db.profile.debugMode then
        GuildScribe:Print("|cFF888888[debug]|r " .. msg)
    end
end

-------------------------------------------------------------------------------
-- Profession Scanning
-------------------------------------------------------------------------------
ScanProfessions = function()
    local data = {
        primaries = {},
        secondaries = {},
    }

    -- Expand all headers first so we can see all skill lines
    local headersToCollapse = {}
    for i = GetNumSkillLines(), 1, -1 do
        local skillName, isHeader = GetSkillLineInfo(i)
        if isHeader and skillName then
            ExpandSkillHeader(i)
            tinsert(headersToCollapse, skillName)
        end
    end

    for i = 1, GetNumSkillLines() do
        local skillName, isHeader, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank, isAbandonable = GetSkillLineInfo(i)

        if not isHeader and skillName then
            if isAbandonable then
                -- Primary profession
                if #data.primaries < 2 then
                    tinsert(data.primaries, {
                        name = skillName,
                        abbrev = PROFESSION_ABBREVIATIONS[skillName] or strsub(skillName, 1, 4),
                        level = skillRank or 0,
                        maxLevel = skillMaxRank or 0,
                    })
                end
            elseif SECONDARY_SKILLS[skillName] then
                data.secondaries[SECONDARY_KEYS[skillName]] = {
                    name = skillName,
                    abbrev = strsub(skillName, 1, 4),
                    level = skillRank or 0,
                    maxLevel = skillMaxRank or 0,
                }
            end
        end
    end

    -- Collapse headers back
    for i = GetNumSkillLines(), 1, -1 do
        local skillName, isHeader = GetSkillLineInfo(i)
        if isHeader then
            for _, name in ipairs(headersToCollapse) do
                if skillName == name then
                    CollapseSkillHeader(i)
                    break
                end
            end
        end
    end

    professionData = data
    Debug("Scanned professions: " .. #data.primaries .. " primary, " ..
        (data.secondaries.cooking and "cooking " or "") ..
        (data.secondaries.firstaid and "firstaid " or "") ..
        (data.secondaries.fishing and "fishing " or ""))

    return data
end

-------------------------------------------------------------------------------
-- Note Building
-------------------------------------------------------------------------------
BuildNoteText = function(formatStr)
    if not formatStr then
        formatStr = GuildScribe.db.profile.formatString
    end

    local data = professionData
    local prof1 = data.primaries[1]
    local prof2 = data.primaries[2]

    local replacements = {
        -- Primary 1
        ["{prof1}"] = prof1 and prof1.abbrev or "",
        ["{prof1_name}"] = prof1 and prof1.name or "",
        ["{prof1_level}"] = prof1 and tostring(prof1.level) or "0",
        ["{prof1_max}"] = prof1 and tostring(prof1.maxLevel) or "0",
        -- Primary 2
        ["{prof2}"] = prof2 and prof2.abbrev or "",
        ["{prof2_name}"] = prof2 and prof2.name or "",
        ["{prof2_level}"] = prof2 and tostring(prof2.level) or "0",
        ["{prof2_max}"] = prof2 and tostring(prof2.maxLevel) or "0",
        -- Cooking
        ["{cooking}"] = data.secondaries.cooking and data.secondaries.cooking.abbrev or "",
        ["{cooking_level}"] = data.secondaries.cooking and tostring(data.secondaries.cooking.level) or "0",
        ["{cooking_max}"] = data.secondaries.cooking and tostring(data.secondaries.cooking.maxLevel) or "0",
        -- First Aid
        ["{firstaid}"] = data.secondaries.firstaid and data.secondaries.firstaid.abbrev or "",
        ["{firstaid_level}"] = data.secondaries.firstaid and tostring(data.secondaries.firstaid.level) or "0",
        ["{firstaid_max}"] = data.secondaries.firstaid and tostring(data.secondaries.firstaid.maxLevel) or "0",
        -- Fishing
        ["{fishing}"] = data.secondaries.fishing and data.secondaries.fishing.abbrev or "",
        ["{fishing_level}"] = data.secondaries.fishing and tostring(data.secondaries.fishing.level) or "0",
        ["{fishing_max}"] = data.secondaries.fishing and tostring(data.secondaries.fishing.maxLevel) or "0",
        -- Character info
        ["{name}"] = UnitName("player") or "",
        ["{level}"] = tostring(UnitLevel("player") or 0),
        ["{class}"] = select(1, UnitClass("player")) or "",
        -- PvP
        ["{honor}"] = tostring(GetHonorCurrency and GetHonorCurrency() or 0),
        ["{hks}"] = tostring(select(1, GetPVPLifetimeStats()) or 0),
        -- Economy
        ["{gold}"] = tostring(floor((GetMoney() or 0) / 10000)),
    }

    local result = formatStr
    for placeholder, value in pairs(replacements) do
        result = gsub(result, placeholder:gsub("[{}]", "%%%0"), value)
    end

    -- Clean up empty separators (e.g. " / " when prof2 is missing)
    result = gsub(result, "%s*/%s*$", "")
    result = strtrim(result)

    return result
end

-------------------------------------------------------------------------------
-- Guild Note Update
-------------------------------------------------------------------------------
FindPlayerGuildIndex = function()
    local playerName = UnitName("player")
    if not playerName then return nil end

    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name = GetGuildRosterInfo(i)
        if name then
            -- Strip realm name if present
            local shortName = strsplit("-", name)
            if shortName == playerName then
                return i
            end
        end
    end
    return nil
end

UpdateGuildNote = function()
    waitingForRoster = false

    if not IsInGuild() then
        Debug("Not in a guild, skipping update")
        return
    end

    local playerIndex = FindPlayerGuildIndex()
    if not playerIndex then
        Debug("Could not find player in guild roster")
        return
    end

    local noteText = BuildNoteText()
    local truncated = false

    if strlen(noteText) > GUILD_NOTE_MAX_LENGTH then
        noteText = strsub(noteText, 1, GUILD_NOTE_MAX_LENGTH)
        truncated = true
    end

    local target = GuildScribe.db.profile.noteTarget

    if target == "public" or target == "both" then
        local _, _, _, _, _, _, publicNote = GetGuildRosterInfo(playerIndex)
        if publicNote ~= noteText then
            GuildRosterSetPublicNote(playerIndex, noteText)
            Debug("Updated public note to: " .. noteText)
        else
            Debug("Public note unchanged, skipping")
        end
    end

    if target == "officer" or target == "both" then
        local _, _, _, _, _, _, _, officerNote = GetGuildRosterInfo(playerIndex)
        if officerNote ~= noteText then
            GuildRosterSetOfficerNote(playerIndex, noteText)
            Debug("Updated officer note to: " .. noteText)
        else
            Debug("Officer note unchanged, skipping")
        end
    end

    if truncated then
        GuildScribe:Print("|cFFFF6600Warning:|r Note was truncated to " .. GUILD_NOTE_MAX_LENGTH .. " characters.")
    end
end

ScheduleUpdate = function()
    if not GuildScribe.db.profile.enabled then
        Debug("Addon disabled, skipping update")
        return
    end

    if not IsInGuild() then
        Debug("Not in a guild, skipping update")
        return
    end

    -- Cancel any existing timer
    if updateTimer then
        updateTimer:Cancel()
        updateTimer = nil
    end

    local delay = GuildScribe.db.profile.updateDelay

    Debug("Scheduling update in " .. delay .. "s")

    updateTimer = C_Timer.NewTimer(delay, function()
        updateTimer = nil
        ScanProfessions()
        -- Request guild roster data, then update note when it arrives
        waitingForRoster = true
        C_GuildInfo.GuildRoster()
    end)
end

-------------------------------------------------------------------------------
-- Addon Lifecycle
-------------------------------------------------------------------------------
function GuildScribe:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("GuildScribeDB", defaults, true)

    -- Register options
    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, self:GetOptionsTable())
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "GuildScribe")

    -- Minimap button
    local ldb = LibStub("LibDataBroker-1.1")
    local dataObj = ldb:NewDataObject("GuildScribe", {
        type = "launcher",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        OnClick = function(_, button)
            if button == "LeftButton" then
                self:ForceUpdate()
            elseif button == "RightButton" then
                self:OpenConfig()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cFF00D1FFGuildScribe|r")
            tooltip:AddLine(" ")

            if #professionData.primaries > 0 then
                for _, prof in ipairs(professionData.primaries) do
                    tooltip:AddDoubleLine(prof.name, prof.level .. "/" .. prof.maxLevel, 1, 1, 1, 1, 0.82, 0)
                end
            else
                tooltip:AddLine("No professions detected", 0.5, 0.5, 0.5)
            end

            if professionData.secondaries then
                for _, key in ipairs({"cooking", "firstaid", "fishing"}) do
                    local sec = professionData.secondaries[key]
                    if sec then
                        tooltip:AddDoubleLine(sec.name, sec.level .. "/" .. sec.maxLevel, 1, 1, 1, 0.7, 0.7, 0.7)
                    end
                end
            end

            tooltip:AddLine(" ")
            tooltip:AddLine("|cFFFFFFFFLeft-click:|r Force update", 0.5, 0.5, 0.5)
            tooltip:AddLine("|cFFFFFFFFRight-click:|r Options", 0.5, 0.5, 0.5)
        end,
    })

    local icon = LibStub("LibDBIcon-1.0")
    icon:Register("GuildScribe", dataObj, self.db.profile.minimap)

    -- Slash commands
    self:RegisterChatCommand("gs", "SlashCommand")
    self:RegisterChatCommand("guildscribe", "SlashCommand")
end

function GuildScribe:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("SKILL_LINES_CHANGED")
    self:RegisterEvent("GUILD_ROSTER_UPDATE")

    -- Initial scan
    ScanProfessions()
end

-------------------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------------------
function GuildScribe:PLAYER_ENTERING_WORLD()
    ScanProfessions()

    if self.db.profile.updateOnLogin then
        ScheduleUpdate()
    end
end

function GuildScribe:SKILL_LINES_CHANGED()
    if self.db.profile.updateOnSkillChange then
        ScheduleUpdate()
    end
end

function GuildScribe:GUILD_ROSTER_UPDATE()
    if waitingForRoster then
        UpdateGuildNote()
    end
end

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
function GuildScribe:SlashCommand(input)
    input = strtrim(strlower(input or ""))

    if input == "update" then
        self:ForceUpdate()
    elseif input == "preview" then
        self:ShowPreview()
    elseif input == "toggle" then
        self.db.profile.enabled = not self.db.profile.enabled
        self:Print("GuildScribe " .. (self.db.profile.enabled and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
    elseif input == "debug" then
        self.db.profile.debugMode = not self.db.profile.debugMode
        self:Print("Debug mode " .. (self.db.profile.debugMode and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
    else
        self:OpenConfig()
    end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------
function GuildScribe:ForceUpdate()
    if not IsInGuild() then
        self:Print("You are not in a guild.")
        return
    end

    ScanProfessions()
    waitingForRoster = true
    GuildRoster()
    self:Print("Forcing guild note update...")
end

function GuildScribe:ShowPreview()
    ScanProfessions()
    local text = BuildNoteText()
    local len = strlen(text)
    local colorCode = len > GUILD_NOTE_MAX_LENGTH and "|cFFFF0000" or "|cFF00FF00"

    self:Print("Preview: |cFFFFFFFF" .. text .. "|r")
    self:Print("Length: " .. colorCode .. len .. "/" .. GUILD_NOTE_MAX_LENGTH .. "|r")
end

function GuildScribe:OpenConfig()
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory("GuildScribe")
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory("GuildScribe")
        InterfaceOptionsFrame_OpenToCategory("GuildScribe")
    end
end

function GuildScribe:GetProfessionData()
    return professionData
end

function GuildScribe:GetNotePreview(formatStr)
    ScanProfessions()
    return BuildNoteText(formatStr)
end

function GuildScribe:GetMaxNoteLength()
    return GUILD_NOTE_MAX_LENGTH
end
