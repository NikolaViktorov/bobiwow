-- BobiWoW
-- Stats HUD
-- Azeroth Survivors / WoW 1.12.1

local stats = CreateFrame("Frame", "BobiWoWStatsHUD", UIParent)

if type(AZS_SetHudShown) == "function" then
    AZS_SetHudShown("tally", false)
end

--------------------------------------------------
-- CONFIGURATION
--------------------------------------------------

local UPDATE_INTERVAL = 0.20

local FRAME_WIDTH = 300
local FRAME_HEIGHT = 26

local elapsed = 0

--------------------------------------------------
-- FRAME
--------------------------------------------------

stats:SetWidth(FRAME_WIDTH)
stats:SetHeight(FRAME_HEIGHT)

stats:SetPoint("TOP", BobiWoWLogo, "BOTTOM", 0, -8)

stats:SetFrameStrata("HIGH")
stats:SetFrameLevel(20)


--------------------------------------------------
-- DRAG & SCREEN BOUNDARIES
--------------------------------------------------

stats:SetMovable(true)
stats:EnableMouse(true)
stats:RegisterForDrag("LeftButton")

stats:SetScript("OnDragStart", function()
    stats:StartMoving()
end)

stats:SetScript("OnDragStop", function()

    stats:StopMovingOrSizing()

    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()

    local frameWidth = stats:GetWidth()
    local frameHeight = stats:GetHeight()

    local left = stats:GetLeft() or 0
    local bottom = stats:GetBottom() or 0

    if left < 0 then
        left = 0
    end

    if bottom < 0 then
        bottom = 0
    end

    if left + (frameWidth / 2) > screenWidth then
        left = screenWidth - (frameWidth / 2)
    end

    if bottom - (frameHeight * 2) > screenHeight then
        bottom = screenHeight + (frameHeight * 2)
    end

    -- Apply corrected position
    stats:ClearAllPoints()

    stats:SetPoint(
        "BOTTOMLEFT",
        UIParent,
        "BOTTOMLEFT",
        left,
        bottom
    )

end)

stats:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = {
        left = 3,
        right = 3,
        top = 3,
        bottom = 3
    }
})

stats:SetBackdropColor(0.04, 0.035, 0.025, 0.90)
stats:SetBackdropBorderColor(0.65, 0.43, 0.16, 1)

--------------------------------------------------
-- COLORS
--------------------------------------------------

local GOLD_R = 1
local GOLD_G = 0.78
local GOLD_B = 0.30

local LABEL_R = 0.75
local LABEL_G = 0.65
local LABEL_B = 0.45

--------------------------------------------------
-- TEXT CREATION
--------------------------------------------------

local function CreateStat(label, x)

    local labelText = stats:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )

    labelText:SetPoint("LEFT", stats, "LEFT", x, 0)
    labelText:SetText(label)
    labelText:SetTextColor(
        LABEL_R,
        LABEL_G,
        LABEL_B
    )

    local valueText = stats:CreateFontString(
        nil,
        "OVERLAY"
    )

    valueText:SetFont(
        "Fonts\\FRIZQT__.TTF",
        11,
        "OUTLINE"
    )

    valueText:SetPoint(
        "LEFT",
        labelText,
        "RIGHT",
        5,
        0
    )

    valueText:SetTextColor(
        GOLD_R,
        GOLD_G,
        GOLD_B
    )

    valueText:SetText("0")

    return valueText
end

--------------------------------------------------
-- STAT ELEMENTS
--------------------------------------------------

local killsText = CreateStat("KILLS", 12)
local goldText = CreateStat("GOLD", 112)
local cacheText = CreateStat("CHEST", 205)

--------------------------------------------------
-- SEPARATORS
--------------------------------------------------

local function CreateSeparator(x)

    local separator = stats:CreateTexture(nil, "ARTWORK")

    separator:SetTexture("Interface\\Buttons\\WHITE8X8")
    separator:SetWidth(1)
    separator:SetHeight(16)

    separator:SetPoint("CENTER", stats, "LEFT", x, 0)

    separator:SetVertexColor(0.55, 0.38, 0.16, 0.65)

end

CreateSeparator(103)
CreateSeparator(196)

--------------------------------------------------
-- UPDATE
--------------------------------------------------

local function GetValue(value)

    if type(value) ~= "number" then
        return "0"
    end

    return tostring(math.floor(value + 0.5))

end

local function UpdateStats()

    if type(AZS_RUN) ~= "table" then
        return
    end

    killsText:SetText(
        GetValue(AZS_RUN.kills)
    )

    goldText:SetText(
        GetValue(AZS_RUN.gold)
    )

    cacheText:SetText(
        GetValue(AZS_RUN.chest)
    )

end

--------------------------------------------------
-- ON UPDATE
--------------------------------------------------

stats:SetScript("OnUpdate", function()

    elapsed = elapsed + arg1

    if elapsed < UPDATE_INTERVAL then
        return
    end

    elapsed = 0

    UpdateStats()

end)

stats:Show()