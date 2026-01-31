-- Alert.lua

local alertFrame = nil

function RaxKeyHelper:HideAlert()
    if alertFrame then 
        alertFrame:Hide() 
        if not InCombatLockdown() then
            alertFrame:SetAttribute("type", nil)
            alertFrame:SetAttribute("spell", nil)
        end
    end
    if RaxKeyHelperDB then RaxKeyHelperDB.activeAlert = nil end
end

function RaxKeyHelper:CreateAlertButton()
    local f = CreateFrame("Button", "RaxKeyHelperAlertFrame", UIParent, "SecureActionButtonTemplate")
    f:SetSize(800, 120) 
    f:SetPoint("TOP", 0, -150)
    
    f:RegisterForClicks("AnyDown") -- Catches all clicks immediately
    f:EnableMouse(true) 

    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetPoint("CENTER", 0, 5) 
    f.text:SetFont("Fonts\\FRIZQT__.TTF", 40, "THICKOUTLINE") 
    f.text:SetTextColor(1, 0.1, 0.1, 1) 
    f.text:SetShadowOffset(2, -2)
    f.text:SetShadowColor(0, 0, 0, 1)

    f.subText = f:CreateFontString(nil, "OVERLAY")
    f.subText:SetPoint("TOP", f.text, "BOTTOM", 0, -5)
    f.subText:SetFont("Fonts\\FRIZQT__.TTF", 12)
    f.subText:SetTextColor(0.8, 0.8, 0.8, 1)

    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.closeBtn:SetSize(120, 30)
    f.closeBtn:SetPoint("BOTTOM", 0, -40) 
    f.closeBtn:SetText("CLOSE")
    f.closeBtn:Hide()
    f.closeBtn:SetFrameLevel(f:GetFrameLevel() + 10) -- Ensure clickable over secure button
    
    f.closeBtn:SetScript("OnClick", function() RaxKeyHelper:HideAlert() end)

    f.ctrlTimer = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        if IsControlKeyDown() then
            self.ctrlTimer = self.ctrlTimer + elapsed
            if self.ctrlTimer >= 3 then self.closeBtn:Show() end
        else
            self.ctrlTimer = 0
            self.closeBtn:Hide()
        end
    end)
    
    f:Hide()
    return f
end

function RaxKeyHelper:ShowAlert(mapID, mapName, level)
    local currentZone = self:NormalizeName(GetRealZoneText())
    local targetZone = self:NormalizeName(mapName)
    local inInstance, _ = IsInInstance()

    if inInstance and currentZone ~= "" and targetZone ~= "" then
        if string.find(currentZone, targetZone, 1, true) or string.find(targetZone, currentZone, 1, true) then
            if alertFrame and alertFrame:IsShown() then 
                self:HideAlert()
            end
            return 
        end
    end

    if not alertFrame then alertFrame = self:CreateAlertButton() end
    
    self.currentAlertDungeonName = mapName
    alertFrame.text:SetText(mapName .. " +" .. level)
    
    local spellID = self.DungeonTeleports[mapID]
    
    if not InCombatLockdown() then
        if spellID then
            -- Enable Teleport
            alertFrame:SetAttribute("type", "spell")
            alertFrame:SetAttribute("spell", spellID)
        else
            -- Disable Teleport
            alertFrame:SetAttribute("type", nil)
            alertFrame:SetAttribute("spell", nil)
            alertFrame.subText:SetText("")
        end
    end

    alertFrame:Show()
    if RaxKeyHelperDB then
        RaxKeyHelperDB.activeAlert = { mapID = mapID, mapName = mapName, level = level }
    end
end

function RaxKeyHelper:RestoreAlert()
    if RaxKeyHelperDB and RaxKeyHelperDB.activeAlert then
        local data = RaxKeyHelperDB.activeAlert
        self:ShowAlert(data.mapID, data.mapName, data.level)
    end
end

function RaxKeyHelper:CheckZone()
    if not alertFrame or not alertFrame:IsShown() then return end
    if not self.currentAlertDungeonName then return end

    local currentZone = self:NormalizeName(GetRealZoneText())
    local targetZone = self:NormalizeName(self.currentAlertDungeonName)
    local inInstance, _ = IsInInstance()

    if inInstance and currentZone ~= "" and targetZone ~= "" then
        if string.find(currentZone, targetZone, 1, true) or string.find(targetZone, currentZone, 1, true) then
            self:HideAlert()
            print("|cFF00FF00RaxKeyHelper:|r Dungeon entered. Alert cleared.")
        end
    end
end