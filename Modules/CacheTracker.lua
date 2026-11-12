-- BobiWoW
-- Cache Tracker
-- Azeroth Survivors / WoW 1.12.1 (Lua 5.0)

local updateFrame = CreateFrame("Frame", "BobiWoWCacheTrackerUpdate", UIParent)
local markers = {}
local elapsed = 0

local UPDATE_INTERVAL = 0.20
local MARKER_SIZE = 14

-- Approximate normalized map distance from the player
-- to the minimap edge for each zoom level.
local ZOOM_RADIUS = {
    [0] = 0.030,
    [1] = 0.020,
    [2] = 0.013,
    [3] = 0.009,
    [4] = 0.006,
    [5] = 0.004
}

local function HideAllMarkers()
    local i

    for i = 1, table.getn(markers) do
        markers[i]:Hide()
    end
end

local function CreateMarker()
    local marker = CreateFrame("Button", nil, Minimap)

    marker:SetWidth(MARKER_SIZE)
    marker:SetHeight(MARKER_SIZE)
    marker:SetFrameStrata("HIGH")
    marker:SetFrameLevel(Minimap:GetFrameLevel() + 20)

    local icon = marker:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\AddOns\\bobiwow\\Media\\cache_icon.tga")
    icon:SetAllPoints(marker)

    marker.icon = icon

    marker:SetScript("OnEnter", function()
        if not marker.cache then return end

        GameTooltip:SetOwner(marker, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Cache", 1, 0.82, 0)

        if marker.distance then
            GameTooltip:AddLine(
                string.format("Map distance: %.4f", marker.distance),
                1, 1, 1
            )
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
        HideAllMarkers()
        return
    end

    -- Only show markers during an active run.
    if type(AZS_GetPhase) == "function" then
        local phase = AZS_GetPhase()

        if phase ~= "playing"
            and phase ~= "choosing"
            and phase ~= "paused" then

            HideAllMarkers()
            return
        end
    end

    if type(AZS_CHESTS) ~= "table" then
        HideAllMarkers()
        return
    end

    local playerX, playerY = GetPlayerMapPosition("player")

    if not playerX or not playerY
        or (playerX == 0 and playerY == 0) then

        HideAllMarkers()
        return
    end

    local count = table.getn(AZS_CHESTS)

    local width = Minimap:GetWidth()
    local height = Minimap:GetHeight()

    local zoom = Minimap:GetZoom() or 0
    local radius = ZOOM_RADIUS[zoom] or ZOOM_RADIUS[0]

    local i

    for i = 1, count do

        local cache = AZS_CHESTS[i]

        if cache
            and cache.mx
            and cache.my
            and cache.mx >= 0
            and cache.my >= 0 then

            if not markers[i] then
                markers[i] = CreateMarker()
            end

            local dx = cache.mx - playerX
            local dy = cache.my - playerY

            -- Convert normalized map coordinates into minimap pixels.
            local x = (dx / radius) * (width / 2)
            local y = -(dy / radius) * (height / 2)

            local nx = x / (width / 2)
            local ny = y / (height / 2)

            local marker = markers[i]

            marker.cache = cache
            marker.distance = math.sqrt(dx * dx + dy * dy)

            -- Only display markers inside the minimap circle.
            if (nx * nx + ny * ny) <= 0.88 then

                marker:ClearAllPoints()

                marker:SetPoint(
                    "CENTER",
                    Minimap,
                    "CENTER",
                    x,
                    y
                )

                marker:Show()

            else
                marker:Hide()
            end

        elseif markers[i] then
            markers[i]:Hide()
        end
    end

    -- Hide markers left over after caches have been opened.
    for i = count + 1, table.getn(markers) do
        markers[i]:Hide()
    end
end

-- Events
updateFrame:RegisterEvent("CHAT_MSG_ADDON")
updateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

updateFrame:SetScript("OnEvent", function()

    if event == "CHAT_MSG_ADDON" and arg1 ~= "AZSCHESTS" then
        return
    end

    UpdateMarkers()
end)

-- Periodic update
updateFrame:SetScript("OnUpdate", function()

    elapsed = elapsed + arg1

    if elapsed < UPDATE_INTERVAL then
        return
    end

    elapsed = 0

    UpdateMarkers()
end)