-- BobiWoW
-- Guardian Lair Tracker
-- Azeroth Survivors / WoW 1.12.1

local updateFrame = CreateFrame("Frame", "BobiWoWLairTrackerUpdate", UIParent)

local markers = {}
local elapsed = 0

local UPDATE_INTERVAL = 0.20
local MARKER_SIZE = 14

local ZOOM_RADIUS = {
    [0] = 0.030,
    [1] = 0.020,
    [2] = 0.013,
    [3] = 0.009,
    [4] = 0.006,
    [5] = 0.004
}

local function CreateMarker()
    local marker = CreateFrame("Button", nil, Minimap)

    marker:SetWidth(MARKER_SIZE)
    marker:SetHeight(MARKER_SIZE)
    marker:SetFrameStrata("HIGH")
    marker:SetFrameLevel(Minimap:GetFrameLevel() + 25)

    local icon = marker:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints(marker)

    marker.icon = icon

    -- Respawn countdown
    local timer = marker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timer:SetPoint("CENTER", marker, "CENTER", 0, 0)
    timer:SetTextColor(1, 0.85, 0)
    timer:SetText("")
    marker.timer = timer

    marker:SetScript("OnEnter", function()
        if not marker.lair then return end

        GameTooltip:SetOwner(marker, "ANCHOR_RIGHT")
        GameTooltip:AddLine(marker.lair.name or "Guardian", 1, 0.5, 0)

        if marker.lair.state == "empty" then
            if marker.lair.left <= 0 then
                GameTooltip:AddLine("Respawn ready!", 1, 0.8, 0)
            else
                GameTooltip:AddLine(
                    "Respawn in: " .. math.ceil(marker.lair.left) .. "s",
                    1, 1, 1
                )
            end
        elseif marker.lair.state == "awake" then
            GameTooltip:AddLine("Guardian is active!", 1, 0.2, 0.2)
        else
            GameTooltip:AddLine("Guardian is waiting", 0.5, 1, 0.5)
        end

        GameTooltip:Show()
    end)

    marker:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return marker
end

local function UpdateMarkers()
    if not Minimap or not Minimap:IsVisible() then
        return
    end

    if type(AZS_GetPhase) == "function" then
        local phase = AZS_GetPhase()

        if phase ~= "playing" and
           phase ~= "choosing" and
           phase ~= "paused" then

            local i
            for i = 1, table.getn(markers) do
                markers[i]:Hide()
            end

            return
        end
    end

    if type(AZS_GetLairs) ~= "function" then
        return
    end

    local lairs = AZS_GetLairs()

    if type(lairs) ~= "table" then
        return
    end

    local playerX, playerY = GetPlayerMapPosition("player")

    if not playerX or not playerY or
       (playerX == 0 and playerY == 0) then
        return
    end

    local width = Minimap:GetWidth()
    local height = Minimap:GetHeight()

    local zoom = Minimap:GetZoom() or 0
    local radius = ZOOM_RADIUS[zoom] or ZOOM_RADIUS[0]

    local count = table.getn(lairs)
    local i

    for i = 1, count do
        local lair = lairs[i]

        if lair and lair.mx and lair.my and
           lair.mx >= 0 and lair.my >= 0 then

            if not markers[i] then
                markers[i] = CreateMarker()
            end

            local marker = markers[i]

            marker.lair = lair

            local dx = lair.mx - playerX
            local dy = lair.my - playerY

            local x = (dx / radius) * (width / 2)
            local y = -(dy / radius) * (height / 2)

            local nx = x / (width / 2)
            local ny = y / (height / 2)

            marker:ClearAllPoints()
            marker:SetPoint("CENTER", Minimap, "CENTER", x, y)

            if nx * nx + ny * ny <= 0.88 then

                if lair.state == "empty" then

                    -- Hide icon and show countdown
                    marker.icon:Hide()
                    marker.timer:Show()

                    if lair.left <= 0 then
                        marker.timer:SetText("READY!")
                        marker.timer:SetTextColor(1, 0.9, 0)
                    else
                        local seconds = math.max(0, math.ceil(lair.left))
                        local minutes = math.floor(seconds / 60)
                        local remainingSeconds = seconds - (minutes * 60)

                        marker.timer:SetText(
                            string.format("%d:%02d", minutes, remainingSeconds)
                        )   
                        marker.timer:SetTextColor(1, 0.85, 0)
                    end

                else

                    -- Show Guardian icon
                    marker.timer:Hide()
                    marker.icon:Show()

                    if lair.state == "awake" then
                        marker.icon:SetTexture(
                            "Interface\\AddOns\\bobiwow\\Media\\guardian_awake.tga"
                        )
                    else
                        marker.icon:SetTexture(
                            "Interface\\AddOns\\bobiwow\\Media\\guardian_idle.tga"
                        )
                    end

                end

                marker:Show()
            else
                marker:Hide()
            end
        elseif markers[i] then
            markers[i]:Hide()
        end
    end

    for i = count + 1, table.getn(markers) do
        markers[i]:Hide()
    end
end

updateFrame:RegisterEvent("CHAT_MSG_ADDON")
updateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

updateFrame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" and
       arg1 ~= "AZSLAIRS" and
       arg1 ~= "AZSUNITS" then
        return
    end

    UpdateMarkers()
end)

updateFrame:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1

    if elapsed < UPDATE_INTERVAL then
        return
    end

    elapsed = 0
    UpdateMarkers()
end)