-- Comm.lua

-- [[ 1. HELPER: Dynamic Channel Selection ]]
local function GetCommChannel()
    -- If in Raid, we disable communication (Addon is for 5-man only)
    if IsInRaid() then
        return nil
    elseif IsInGroup() then
        return "PARTY"
    end
    return nil -- Solo
end

-- [[ 2. HELPER: Sender Normalization ]]
local function GetNormalizedSender(sender)
    if not sender then return nil end
    if string.find(sender, "-") then
        return sender 
    end
    return sender .. "-" .. GetRealmName():gsub("%s+", "")
end

function RaxKeyHelper:BroadcastMyKey()
    local channel = GetCommChannel()
    if not channel then return end

    local mapID, level, mapName = self:GetMyKeyInfo()
    if mapID then
        local msg = string.format("REPORT_KEY|%d|%d|%s", mapID, level, mapName)
        C_ChatInfo.SendAddonMessage(self.COMM_PREFIX, msg, channel)
    end
end

function RaxKeyHelper:StartVote()
    local channel = GetCommChannel()
    if not channel then return end

    if not UnitIsGroupLeader("player") then 
        return 
    end
    C_ChatInfo.SendAddonMessage(self.COMM_PREFIX, "START_VOTE", channel)
end

function RaxKeyHelper:SendVote(targetKey)
    local channel = GetCommChannel()
    if not channel then return end

    local msg = "CAST_VOTE|" .. (targetKey or "NIL")
    C_ChatInfo.SendAddonMessage(self.COMM_PREFIX, msg, channel)
    
    local myID = self:GetPlayerID()
    self.votes[myID] = targetKey
    self:RefreshGUI()
end

function RaxKeyHelper:RequestKeys()
    local channel = GetCommChannel()
    if not channel then return end

    C_ChatInfo.SendAddonMessage(self.COMM_PREFIX, "REQUEST_KEYS", channel)
    
    if UnitIsGroupLeader("player") then
        local state = self.leaderOnlyMode and "1" or "0"
        C_ChatInfo.SendAddonMessage(self.COMM_PREFIX, "SET_LEADER_MODE|"..state, channel)
    end
    
    local myID = self:GetPlayerID()
    if self.votes[myID] then
        C_ChatInfo.SendAddonMessage(self.COMM_PREFIX, "CAST_VOTE|"..self.votes[myID], channel)
    end
end

function RaxKeyHelper:SetLeaderMode(enabled)
    local channel = GetCommChannel()
    if not channel or not UnitIsGroupLeader("player") then return end
    
    self.leaderOnlyMode = enabled
    local state = enabled and "1" or "0"
    C_ChatInfo.SendAddonMessage(self.COMM_PREFIX, "SET_LEADER_MODE|"..state, channel)
end

function RaxKeyHelper:BroadcastAlert(targetMapID, targetMapName, targetLevel)
    local channel = GetCommChannel()
    if self.leaderOnlyMode and not UnitIsGroupLeader("player") then
        return
    end
    if channel then
        local msg = string.format("TRIGGER_ALERT|%d|%d|%s", targetMapID, targetLevel, targetMapName)
        C_ChatInfo.SendAddonMessage(self.COMM_PREFIX, msg, channel)
    end
    self:ShowAlert(targetMapID, targetMapName, targetLevel)
end

function RaxKeyHelper:OnCommReceived(prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)
    if prefix ~= self.COMM_PREFIX then return end
    
    local uniqueSenderID = GetNormalizedSender(sender)
    
    local cmd, arg1, arg2, arg3 = strsplit("|", text)
    local senderNameDisplay = strsplit("-", sender) 

    if cmd == "REPORT_KEY" then
        self.partyKeys[uniqueSenderID] = { 
            mapID = tonumber(arg1), 
            level = tonumber(arg2), 
            mapName = arg3,
            displayName = senderNameDisplay
        }
        self:RefreshGUI()
        
    elseif cmd == "TRIGGER_ALERT" then
        self:ShowAlert(tonumber(arg1), arg3, tonumber(arg2))
    
    elseif cmd == "REQUEST_KEYS" then
        self:BroadcastMyKey()
        
        if UnitIsGroupLeader("player") then
            local state = self.leaderOnlyMode and "1" or "0"
            local respChannel = GetCommChannel() 
            if respChannel then
                C_ChatInfo.SendAddonMessage(self.COMM_PREFIX, "SET_LEADER_MODE|"..state, respChannel)
            end
        end
        
        local myID = self:GetPlayerID()
        if self.votes[myID] then
            local respChannel = GetCommChannel()
            if respChannel then
                C_ChatInfo.SendAddonMessage(self.COMM_PREFIX, "CAST_VOTE|"..self.votes[myID], respChannel)
            end
        end

    elseif cmd == "SET_LEADER_MODE" then
        self.leaderOnlyMode = (arg1 == "1")
        self:RefreshGUI() 
        
    elseif cmd == "CAST_VOTE" then
        self.votes[uniqueSenderID] = arg1
        self:RefreshGUI()

    elseif cmd == "START_VOTE" then
        self.votes = {}
        self.votingOpen = true
        self:RefreshGUI()
    end
end