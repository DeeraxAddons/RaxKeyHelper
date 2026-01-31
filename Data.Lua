-- Data.lua

function RaxKeyHelper:GetMyKeyInfo()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()

    if mapID then
        local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
        return mapID, level, mapName
    end

    return nil, 0, "No Key Found"
end

-- Teleport Spell Database (Moved here to clean up Alert.lua)
RaxKeyHelper.DungeonTeleports = {
    --[TWW S3]
    [499] = 445444,  -- Priory of the Sacred Flame
    [542] = 1237215, -- Eco-Dome Al'dani
    [378] = 354465,  -- Halls of Atonement
    [525] = 1216786, -- Operation Floodgate
    [503] = 445417,  -- Ara-Kara
    [392] = 367416,  -- Happy Gambit
    [391] = 367416,  -- Sad Street
    [505] = 445414,  -- DawnBreaker
}