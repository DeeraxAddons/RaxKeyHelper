-- Core.lua
RaxKeyHelper = {}
RaxKeyHelper.COMM_PREFIX = "RaxKeyHelper"

-- State
RaxKeyHelper.partyKeys = {} 
RaxKeyHelper.votes = {} 
RaxKeyHelper.votingOpen = false 
RaxKeyHelper.leaderOnlyMode = false 

-- Centralized Event Handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("GROUP_LEFT") 
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
C_ChatInfo.RegisterAddonMessagePrefix(RaxKeyHelper.COMM_PREFIX)

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == "RaxKeyHelper" then RaxKeyHelper:OnInitialize() end

    elseif event == "CHAT_MSG_ADDON" then
        RaxKeyHelper:OnCommReceived(...)

    elseif event == "GROUP_ROSTER_UPDATE" then
        -- [[ CHANGED: Raid check added here ]]
        if IsInRaid() then
            -- Treat Raid like "Solo" mode: Clear data and stop broadcasting
            RaxKeyHelper.partyKeys = {} 
            RaxKeyHelper.votes = {} 
            RaxKeyHelper.votingOpen = false 
            if RaxKeyHelper.HideAlert then RaxKeyHelper:HideAlert() end
        else
            -- Normal 5-man behavior
            RaxKeyHelper:BroadcastMyKey()
        end
        if RaxKeyHelper.RefreshGUI then RaxKeyHelper:RefreshGUI() end

    elseif event == "GROUP_LEFT" then
        -- Reset State
        RaxKeyHelper.partyKeys = {} 
        RaxKeyHelper.votes = {} 
        RaxKeyHelper.votingOpen = false 
        if RaxKeyHelper.HideAlert then RaxKeyHelper:HideAlert() end
        if RaxKeyHelper.RefreshGUI then RaxKeyHelper:RefreshGUI() end

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        if RaxKeyHelper.CheckZone then RaxKeyHelper:CheckZone(...) end
    end
end)

function RaxKeyHelper:OnInitialize()
    RaxKeyHelperDB = RaxKeyHelperDB or {}
    
    SLASH_RAXKEYHELPER1 = "/rkh"
    SLASH_RAXKEYHELPER2 = "/raxkey"
    SlashCmdList["RAXKEYHELPER"] = function(msg)
        self:ShowSelectionWindow()
        self:BroadcastMyKey()
    end
    
    if self.RestoreAlert then self:RestoreAlert() end
end

-- [[ UTILITIES ]] --

function RaxKeyHelper:GetPlayerID()
    local name = UnitName("player")
    local realm = GetRealmName()
    if not name or not realm then return nil end
    return name .. "-" .. realm:gsub("%s+", "")
end

function RaxKeyHelper:NormalizeName(name)
    if not name then return "" end
    name = string.lower(name)
    local simpleName = strsplit(":", name)
    simpleName = strsplit(",", simpleName)
    simpleName = simpleName:gsub("^the%s+", "") 
    return strtrim(simpleName)
end