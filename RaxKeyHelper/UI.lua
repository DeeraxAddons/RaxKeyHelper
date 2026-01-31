-- UI.lua

local mainFrame = nil
local rowFrames = {}

function RaxKeyHelper:ShowSelectionWindow()
    if mainFrame then 
        mainFrame:Show()
        self:RefreshGUI()
        
        -- Only Request keys if in a valid 5-man party
        if IsInGroup() and not IsInRaid() and RaxKeyHelper.RequestKeys then 
            RaxKeyHelper:RequestKeys() 
        end
        return 
    end

    -- 1. Create Main Window
    local f = CreateFrame("Frame", "RaxKeyHelperMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(600, 360) 
    f:SetPoint("CENTER")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    f:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", 0, -12)
    f.title:SetText("Rax Key Helper")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    table.insert(UISpecialFrames, "RaxKeyHelperMainFrame") 

    -- [[ WARNING TEXT ]]
    f.warningText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.warningText:SetPoint("CENTER", 0, 0)
    -- Unified message for Solo, Raid, PVP, etc.
    f.warningText:SetText("You must be in a 5-man Party\nfor this addon to be useful.")
    f.warningText:SetTextColor(1, 0.5, 0)
    f.warningText:Hide()

    -- [[ TOOLBAR ROW (Y = -50) ]]
    local refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refreshBtn:SetSize(70, 22)
    refreshBtn:SetPoint("TOPLEFT", 20, -50)
    refreshBtn:SetText("Refresh")
    f.refreshBtn = refreshBtn 
    
    refreshBtn:SetScript("OnClick", function()
        RaxKeyHelper.partyKeys = {} 
        RaxKeyHelper:RefreshGUI()
        if IsInGroup() and not IsInRaid() and RaxKeyHelper.RequestKeys then 
            RaxKeyHelper:RequestKeys()
        end
    end)

    local voteStartBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    voteStartBtn:SetSize(80, 22)
    voteStartBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 10, 0)
    voteStartBtn:SetText("Let's Vote")
    f.voteStartBtn = voteStartBtn
    
    voteStartBtn:SetScript("OnClick", function()
        if UnitIsGroupLeader("player") then RaxKeyHelper:StartVote() else
        end
    end)

    local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cb:SetPoint("TOPRIGHT", -20, -50)
    cb.text:SetText("Leader Only")
    cb.text:ClearAllPoints()
    cb.text:SetPoint("RIGHT", cb, "LEFT", -5, 0)
    f.leaderCb = cb
    
    cb:SetScript("OnClick", function(self)
        if UnitIsGroupLeader("player") then
            RaxKeyHelper:SetLeaderMode(self:GetChecked())
        else
            self:SetChecked(RaxKeyHelper.leaderOnlyMode)
        end
    end)

    -- [[ LIST ROWS (Y = -90) ]]
    for i = 1, 6 do
        local row = CreateFrame("Frame", nil, f)
        row:SetSize(560, 30)
        row:SetPoint("TOPLEFT", 20, -90 - ((i-1)*35)) 
        
        row.btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.btn:SetSize(80, 22)
        row.btn:SetPoint("RIGHT", 0, 0)
        row.btn:SetText("Select")

        row.voteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.voteBtn:SetSize(50, 22)
        row.voteBtn:SetPoint("RIGHT", row.btn, "LEFT", -5, 0)
        row.voteBtn:SetText("Vote")
        
        row.voteCount = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        row.voteCount:SetPoint("RIGHT", row.btn, "LEFT", -15, 0)
        row.voteCount:SetTextColor(0, 1, 0) 

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", 0, 0)
        row.text:SetPoint("RIGHT", row.voteBtn, "LEFT", -10, 0) 
        row.text:SetJustifyH("LEFT")
        row.text:SetText("")
        
        rowFrames[i] = row
    end

    mainFrame = f
    self:RefreshGUI()
    
    if IsInGroup() and not IsInRaid() and RaxKeyHelper.RequestKeys then 
        RaxKeyHelper:RequestKeys() 
    end
end

function RaxKeyHelper:RefreshGUI()
    if not mainFrame or not mainFrame:IsShown() then return end
    
    -- [[ 1. CHECK VALID STATE (Party Only, No Raid, No Solo) ]]
    if not IsInGroup() or IsInRaid() then
        -- INVALID STATE: Hide controls, show warning
        mainFrame.warningText:Show()
        mainFrame.refreshBtn:Hide()
        mainFrame.voteStartBtn:Hide()
        mainFrame.leaderCb:Hide()
        for i = 1, 6 do rowFrames[i]:Hide() end
        return 
    else
        -- VALID STATE: Show controls
        mainFrame.warningText:Hide()
        mainFrame.refreshBtn:Show()
        mainFrame.voteStartBtn:Show()
        mainFrame.leaderCb:Show()
    end

    -- 2. Update Controls
    if mainFrame.leaderCb then
        mainFrame.leaderCb:SetChecked(self.leaderOnlyMode)
        if UnitIsGroupLeader("player") then
            mainFrame.leaderCb:Enable()
            mainFrame.voteStartBtn:Enable()
        else
            mainFrame.leaderCb:Disable()
            mainFrame.voteStartBtn:Disable()
        end
    end

    -- 3. Build List
    local displayList = {}
    for uniqueID, info in pairs(self.partyKeys) do
        table.insert(displayList, {
            isRandom = false, id = uniqueID, displayName = info.displayName or uniqueID,
            mapName = info.mapName, level = info.level, mapID = info.mapID
        })
    end
    table.insert(displayList, {
        isRandom = true, id = "RANDOM", displayName = "Random Key",
        mapName = "Roll the dice!", level = ""
    })
    
    -- 4. Tally Votes
    local voteCounts = {}
    local myID = self:GetPlayerID()
    local myCurrentVote = self.votes[myID] 

    for _, target in pairs(self.votes) do
        voteCounts[target] = (voteCounts[target] or 0) + 1
    end

    -- 5. Render
    for i = 1, 6 do
        local row = rowFrames[i]
        local data = displayList[i]
        
        if data then
            row:Show()
            
            if data.isRandom then
                row.text:SetText("|cFF00FFFF" .. data.displayName .. "|r") 
            else
                local keyText = (data.mapName or "Unknown") .. " (+" .. (data.level or 0) .. ")"
                row.text:SetText(data.displayName .. " - " .. keyText)
            end

            if not self.votingOpen then
                row.voteBtn:Hide()
                row.voteCount:SetText("")
                row.text:SetPoint("RIGHT", row.btn, "LEFT", -10, 0) 
            else
                if myCurrentVote then
                    row.voteBtn:Hide()
                    local count = voteCounts[data.id] or 0
                    row.voteCount:SetText(count > 0 and ("[" .. count .. "]") or "")
                    row.text:SetPoint("RIGHT", row.btn, "LEFT", -40, 0) 
                else
                    row.voteBtn:Show()
                    row.voteCount:SetText("")
                    row.text:SetPoint("RIGHT", row.voteBtn, "LEFT", -10, 0) 
                    row.voteBtn:SetScript("OnClick", function() RaxKeyHelper:SendVote(data.id) end)
                end
            end

            if self.leaderOnlyMode and not UnitIsGroupLeader("player") then
                row.btn:Disable()
            else
                row.btn:Enable()
            end
            
            row.btn:SetScript("OnClick", function()
                if data.isRandom then
                    local candidates = {}
                    for _, k in pairs(self.partyKeys) do table.insert(candidates, k) end
                    if #candidates > 0 then
                        local pick = candidates[math.random(1, #candidates)]
                        print("|cFF00FF00RaxKeyHelper:|r Rolled: " .. pick.mapName)
                        RaxKeyHelper:BroadcastAlert(pick.mapID, pick.mapName, pick.level)
                    end
                else
                    RaxKeyHelper:BroadcastAlert(data.mapID, data.mapName, data.level)
                end
            end)
        else
            row:Hide()
        end
    end
end