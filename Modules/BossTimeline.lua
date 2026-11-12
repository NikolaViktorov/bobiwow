-- BobiWoW
-- Boss Timeline
-- Azeroth Survivors / WoW 1.12.1

local timeline = CreateFrame("Frame", "BobiWoWBossTimeline", UIParent)

local markers = {}
local elapsed = 0

local UPDATE_INTERVAL = 0.10

--------------------------------------------------
-- DIMENSIONS
--------------------------------------------------

local BAR_WIDTH = 280
local BAR_HEIGHT = 10

local TIMELINE_WIDTH = 320
local TIMELINE_HEIGHT = 50

--------------------------------------------------
-- MAIN FRAME
--------------------------------------------------

timeline:SetWidth(TIMELINE_WIDTH)
timeline:SetHeight(TIMELINE_HEIGHT)
timeline:SetPoint("TOP", UIParent, "TOP", 0, -10)
timeline:SetFrameStrata("HIGH")
timeline:SetFrameLevel(30)

--------------------------------------------------
-- CUSTOM BACKGROUND
--------------------------------------------------

local background = timeline:CreateTexture(nil, "BACKGROUND")

background:SetTexture(
    "Interface\\AddOns\\bobiwow\\Media\\BossTimeline_Background_512x64_RGBA.tga"
)

background:SetPoint("TOPLEFT", timeline, "TOPLEFT", 0, -4)
background:SetPoint("BOTTOMRIGHT", timeline, "BOTTOMRIGHT", 0, -4)
background:SetTexCoord(0, 1, 0, 1)
background:SetAlpha(1)

--------------------------------------------------
-- PROGRESS BAR
--------------------------------------------------

local bar = CreateFrame("StatusBar", nil, timeline)

bar:SetWidth(BAR_WIDTH)
bar:SetHeight(BAR_HEIGHT)
bar:SetPoint("CENTER", timeline, "CENTER", 0, 5)

bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
bar:SetStatusBarColor(0.90, 0.55, 0.16, 1)
bar:SetMinMaxValues(0, 1)
bar:SetValue(0)

local barBackground = bar:CreateTexture(nil, "BACKGROUND")

barBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
barBackground:SetVertexColor(0.12, 0.12, 0.12, 1)
barBackground:SetAllPoints(bar)

--------------------------------------------------
-- TIME TEXT
--------------------------------------------------

local timeText = timeline:CreateFontString(
    nil,
    "OVERLAY",
    "GameFontNormalSmall"
)

timeText:SetPoint("TOP", bar, "BOTTOM", 0, -12)
timeText:SetTextColor(1, 0.82, 0.45)

--------------------------------------------------
-- BOSS MARKER
--------------------------------------------------

local function CreateBossMarker()

    local marker = CreateFrame("Button", nil, UIParent)

    marker:SetWidth(20)
    marker:SetHeight(23)
    marker:SetFrameStrata("DIALOG")
    marker:SetFrameLevel(100)

    local icon = marker:CreateTexture(nil, "OVERLAY")

    icon:SetWidth(20)
    icon:SetHeight(23)
    icon:SetPoint("CENTER", marker, "CENTER", 0, 0)

    icon:SetTexture(
        "Interface\\AddOns\\bobiwow\\Media\\Skull_Silver.tga"
    )

    marker.icon = icon

    marker:SetScript("OnEnter", function()

        if not marker.boss then
            return
        end

        GameTooltip:SetOwner(marker, "ANCHOR_TOP")

        GameTooltip:AddLine(
            marker.boss.name or "Boss",
            1, 0.8, 0
        )

        local minutes = math.floor(marker.boss.at / 60)
        local seconds = math.mod(marker.boss.at, 60)

        GameTooltip:AddLine(
            string.format("Spawn: %d:%02d", minutes, seconds),
            1, 1, 1
        )

        if marker.boss.state == "dead" then

            GameTooltip:AddLine(
                "Defeated",
                1, 0.8, 0
            )

        elseif marker.boss.state == "up" then

            GameTooltip:AddLine(
                "Alive",
                1, 0.2, 0.2
            )

        else

            GameTooltip:AddLine(
                "Upcoming",
                0.7, 0.7, 0.7
            )

        end

        GameTooltip:Show()

    end)

    marker:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return marker

end

--------------------------------------------------
-- ORIGINAL HUD
--------------------------------------------------

local clockHidden = false

local function HideOriginalClock()

    if not clockHidden and
       type(AZS_SetHudShown) == "function" then

        AZS_SetHudShown("clock", false)
        clockHidden = true

    end

end

local function RestoreOriginalClock()

    if clockHidden and
       type(AZS_SetHudShown) == "function" then

        AZS_SetHudShown("clock", true)
        clockHidden = false

    end

end

--------------------------------------------------
-- UPDATE
--------------------------------------------------

local function UpdateTimeline()

    if type(AZS_GetPhase) ~= "function" then

        timeline:Hide()
        return

    end

    local phase = AZS_GetPhase()

    if phase ~= "playing" and
       phase ~= "choosing" and
       phase ~= "paused" then

        timeline:Hide()
        RestoreOriginalClock()

        return

    end

    HideOriginalClock()
    timeline:Show()

    local runTime = AZS_GetRunTime()
    local runLength = AZS_GetRunLength()

    if not runTime or
       not runLength or
       runLength <= 0 then

        return

    end

    --------------------------------------------------
    -- PROGRESS
    --------------------------------------------------

    local progress = runTime / runLength

    if progress > 1 then
        progress = 1
    end

    if progress < 0 then
        progress = 0
    end

    bar:SetValue(progress)

    --------------------------------------------------
    -- TIME
    --------------------------------------------------

    local currentMinutes = math.floor(runTime / 60)
    local currentSeconds = math.mod(math.floor(runTime), 60)

    local totalMinutes = math.floor(runLength / 60)
    local totalSeconds = math.mod(runLength, 60)

    timeText:SetText(
        string.format(
            "%d:%02d / %d:%02d",
            currentMinutes,
            currentSeconds,
            totalMinutes,
            totalSeconds
        )
    )

    --------------------------------------------------
    -- BOSSES
    --------------------------------------------------

    if type(AZS_SCHEDULE) ~= "table" then
        return
    end

    local visibleMarkers = {}

    for index, boss in pairs(AZS_SCHEDULE) do

        if boss and boss.at then

            if not markers[index] then
                markers[index] = CreateBossMarker()
            end

            local marker = markers[index]

            marker.boss = boss
            visibleMarkers[index] = true

            --------------------------------------------------
            -- MARKER POSITION
            --------------------------------------------------

            local position = boss.at / runLength

            if position < 0 then
                position = 0
            end

            if position > 1 then
                position = 1
            end

            local x = position * BAR_WIDTH

            marker:ClearAllPoints()

            marker:SetPoint(
                "BOTTOM",
                bar,
                "BOTTOMLEFT",
                x,
                5
            )

            --------------------------------------------------
            -- MARKER STATE
            --------------------------------------------------

            if boss.state == "dead" then

                marker.icon:SetTexture(
                    "Interface\\AddOns\\bobiwow\\Media\\Skull_Gold.tga"
                )

            elseif boss.state == "up" then

                marker.icon:SetTexture(
                    "Interface\\AddOns\\bobiwow\\Media\\Skull_Red.tga"
                )

            else

                marker.icon:SetTexture(
                    "Interface\\AddOns\\bobiwow\\Media\\Skull_Silver.tga"
                )

            end

            marker:Show()
            marker.icon:Show()

        end

    end

    --------------------------------------------------
    -- HIDE UNUSED MARKERS
    --------------------------------------------------

    for index, marker in pairs(markers) do

        if not visibleMarkers[index] then
            marker:Hide()
        end

    end

end

--------------------------------------------------
-- EVENTS
--------------------------------------------------

timeline:RegisterEvent("PLAYER_ENTERING_WORLD")
timeline:RegisterEvent("CHAT_MSG_ADDON")

timeline:SetScript("OnEvent", function()

    if event == "PLAYER_ENTERING_WORLD" then

        UpdateTimeline()

    elseif event == "CHAT_MSG_ADDON" then

        if arg1 == "AZSRUN" or
           arg1 == "AZSBOSSES" then

            UpdateTimeline()

        end

    end

end)

--------------------------------------------------
-- ON UPDATE
--------------------------------------------------

timeline:SetScript("OnUpdate", function()

    elapsed = elapsed + arg1

    if elapsed < UPDATE_INTERVAL then
        return
    end

    elapsed = 0

    UpdateTimeline()

end)