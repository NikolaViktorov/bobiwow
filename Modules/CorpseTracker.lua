-- BobiWoW CorpseTracker v6.0

local UPDATE_INTERVAL = 0.25
local PANEL_WIDTH = 255
local ROW_HEIGHT = 43

local elapsed = 0
local ownCorpseX = nil
local ownCorpseY = nil
local rows = {}
local rowPool = {}
local headingModel = nil

local GOLD_R = 1
local GOLD_G = 0.72
local GOLD_B = 0.18

-- Basic helpers
local function IsNumber(value)
    return type(value) == "number" and value == value
end

local function ReadMapPosition(unit)
    if type(GetPlayerMapPosition) ~= "function" then
        return nil
    end

    local ok, x, y = pcall(GetPlayerMapPosition, unit)

    if not ok or not IsNumber(x) or not IsNumber(y) then
        return nil
    end

    if x == 0 and y == 0 then
        return nil
    end

    return x, y
end

-- Player heading
local function FindHeadingModel()
    if not Minimap or not Minimap.GetChildren then
        return nil
    end

    local children = { Minimap:GetChildren() }
    local index

    for index = 1, table.getn(children) do
        local child = children[index]

        if child and child.GetModel and child.GetFacing then
            local ok, path = pcall(child.GetModel, child)

            if ok and type(path) == "string" then
                path = string.gsub(
                    string.lower(path),
                    "/",
                    "\\"
                )

                if string.find(
                    path,
                    "\\minimaparrow",
                    1,
                    true
                ) and not string.find(
                    path,
                    "\\rotating-minimaparrow",
                    1,
                    true
                ) then
                    return child
                end
            end
        end
    end

    for index = 1, 9 do
        local child = children[index]

        if not child
            or not child.GetObjectType
            or child:GetObjectType() ~= "Model" then

            return nil
        end
    end

    local candidate = children[9]

    if candidate and candidate.GetFacing then
        return candidate
    end

    return nil
end

local function ReadHeading()
    if not headingModel then
        headingModel = FindHeadingModel()
    end

    if headingModel and headingModel.GetFacing then
        local ok, facing = pcall(
            headingModel.GetFacing,
            headingModel
        )

        if ok and IsNumber(facing) then
            return facing
        end
    end

    headingModel = nil
    return nil
end

-- Direction calculations
local function Atan2(y, x)
    if x > 0 then
        return math.atan(y / x)

    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi

    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi

    elseif x == 0 and y > 0 then
        return math.pi / 2

    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end

    return 0
end

local function GetDirectionIndex(angle)
    local normalized = angle

    while normalized < 0 do
        normalized = normalized + math.pi * 2
    end

    while normalized >= math.pi * 2 do
        normalized = normalized - math.pi * 2
    end

    local index = math.floor(
        (normalized + math.pi / 8) / (math.pi / 4)
    ) + 1

    if index > 8 then
        index = 1
    end

    return index
end

local function DirectionName(angle)
    local names = {
        "N", "NW", "W", "SW",
        "S", "SE", "E", "NE"
    }

    return names[GetDirectionIndex(angle)]
end

local function ArrowSymbol(angle)
    local symbols = {
        "^",       -- N
        "<^",      -- NW
        "<",       -- W
        "<v",      -- SW
        "v",       -- S
        "v>",      -- SE
        ">",       -- E
        "^>"       -- NE
    }

    return symbols[GetDirectionIndex(angle)]
end

-- Main panel
local panel = CreateFrame(
    "Frame",
    "BobiWoWCorpseHUD",
    UIParent
)

panel:SetWidth(PANEL_WIDTH)
panel:SetHeight(50)
panel:SetPoint("TOP", UIParent, "TOP", 0, -145)

panel:SetFrameStrata("DIALOG")
panel:SetFrameLevel(100)

panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")

panel:SetScript("OnDragStart", function()
    panel:StartMoving()
end)

panel:SetScript("OnDragStop", function()
    panel:StopMovingOrSizing()

    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()

    local panelWidth = panel:GetWidth()
    local panelHeight = panel:GetHeight()

    local left = panel:GetLeft() or 0
    local bottom = panel:GetBottom() or 0

    if left < 0 then
        left = 0
    end

    if bottom < 0 then
        bottom = 0
    end

    if left + panelWidth > screenWidth then
        left = screenWidth - panelWidth
    end

    if bottom + panelHeight > screenHeight then
        bottom = screenHeight - panelHeight
    end

    -- Apply corrected position.
    panel:ClearAllPoints()

    panel:SetPoint(
        "BOTTOMLEFT",
        UIParent,
        "BOTTOMLEFT",
        left,
        bottom
    )
end)

panel:Hide()

-- Panel bg
panel:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = {
        left = 4,
        right = 4,
        top = 4,
        bottom = 4
    }
})

panel:SetBackdropColor(0.025, 0.018, 0.012, 1)
panel:SetBackdropBorderColor(
    GOLD_R,
    GOLD_G,
    GOLD_B,
    0.95
)

-- Header
local header = panel:CreateTexture(
    nil,
    "ARTWORK"
)

header:SetPoint("TOPLEFT", panel, "TOPLEFT", 7, -7)
header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -7, -7)
header:SetHeight(23)
header:SetTexture(0.20, 0.035, 0.025, 0.95)

local title = panel:CreateFontString(nil, "OVERLAY")

title:SetFont(
    "Fonts\\FRIZQT__.TTF",
    13,
    "OUTLINE"
)

title:SetPoint("TOPLEFT", panel, "TOPLEFT", 13, -12)
title:SetText("BobiWoW - Corpse Tracker")
title:SetTextColor(1, 0.78, 0.20)

local countText = panel:CreateFontString(nil, "OVERLAY")

countText:SetFont(
    "Fonts\\FRIZQT__.TTF",
    10,
    "OUTLINE"
)

countText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -13, -13)
countText:SetTextColor(1, 0.9, 0.55)

-- Decorative header
local headerLine = panel:CreateTexture(
    nil,
    "ARTWORK"
)

headerLine:SetTexture(
    GOLD_R,
    GOLD_G,
    GOLD_B,
    0.9
)

headerLine:SetHeight(1)
headerLine:SetPoint(
    "TOPLEFT",
    panel,
    "TOPLEFT",
    9,
    -34
)

headerLine:SetPoint(
    "TOPRIGHT",
    panel,
    "TOPRIGHT",
    -9,
    -34
)

-- Row creation
local function CreateRow()
    local row = CreateFrame(
        "Frame",
        nil,
        panel
    )

    row:SetWidth(PANEL_WIDTH - 18)
    row:SetHeight(ROW_HEIGHT)

    -- Row bg
    row:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = {
            left = 2,
            right = 2,
            top = 2,
            bottom = 2
        }
    })

    row:SetBackdropColor(0.035, 0.028, 0.022, 1)

    row:SetBackdropBorderColor(
        0.48,
        0.34,
        0.12,
        0.85
    )

    -- Arrow badge
    row.arrowBackground = row:CreateTexture(
        nil,
        "ARTWORK"
    )

    row.arrowBackground:SetWidth(32)
    row.arrowBackground:SetHeight(32)

    row.arrowBackground:SetPoint(
        "LEFT",
        row,
        "LEFT",
        5,
        0
    )

    row.arrowBackground:SetTexture(
        0.12,
        0.075,
        0.025,
        1
    )

    row.arrow = row:CreateFontString(
        nil,
        "OVERLAY"
    )

    row.arrow:SetFont(
        "Fonts\\FRIZQT__.TTF",
        20,
        "OUTLINE"
    )

    row.arrow:SetWidth(32)

    row.arrow:SetPoint(
        "CENTER",
        row.arrowBackground,
        "CENTER",
        0,
        0
    )

    row.arrow:SetJustifyH("CENTER")
    row.arrow:SetTextColor(1, 0.78, 0.15)

    -- Player name
    row.name = row:CreateFontString(
        nil,
        "OVERLAY"
    )

    row.name:SetFont(
        "Fonts\\FRIZQT__.TTF",
        12,
        "OUTLINE"
    )

    row.name:SetPoint(
        "TOPLEFT",
        row,
        "TOPLEFT",
        49,
        -7
    )

    row.name:SetWidth(105)
    row.name:SetJustifyH("LEFT")
    row.name:SetTextColor(1, 0.92, 0.78)

    -- Skull icon
    row.skull = row:CreateTexture(nil, "ARTWORK")

    row.skull:SetWidth(15)
    row.skull:SetHeight(15)

    row.skull:SetPoint(
        "TOPLEFT",
        row,
        "TOPLEFT",
        49,
        -22
    )

    row.skull:SetTexture(
        "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
    )

    -- Dead status
    row.status = row:CreateFontString(nil, "OVERLAY")

    row.status:SetFont(
        "Fonts\\FRIZQT__.TTF",
        9,
        "OUTLINE"
    )

    row.status:SetPoint(
        "LEFT",
        row.skull,
        "RIGHT",
        5,
        0
    )

    row.status:SetText("DEAD")
    row.status:SetTextColor(1, 0.15, 0.12)

-- Separator
row.separator = row:CreateTexture(nil, "ARTWORK")

row.separator:SetWidth(1)
row.separator:SetPoint(
    "TOPLEFT",
    row,
    "TOPLEFT",
    158,
    -6
)

row.separator:SetPoint(
    "BOTTOMLEFT",
    row,
    "BOTTOMLEFT",
    158,
    6
)

row.separator:SetTexture(
    GOLD_R,
    GOLD_G,
    GOLD_B,
    0.65
)

-- Dist
row.distance = row:CreateFontString(nil, "OVERLAY")

row.distance:SetFont(
    "Fonts\\FRIZQT__.TTF",
    12,
    "OUTLINE"
)

row.distance:SetPoint(
    "TOPLEFT",
    row,
    "TOPLEFT",
    164,
    -8
)

row.distance:SetWidth(65)
row.distance:SetJustifyH("CENTER")
row.distance:SetTextColor(1, 0.76, 0.12)

-- Compassa dir
row.direction = row:CreateFontString(nil, "OVERLAY")

row.direction:SetFont(
    "Fonts\\FRIZQT__.TTF",
    11,
    "OUTLINE"
)

row.direction:SetPoint(
    "TOPLEFT",
    row,
    "TOPLEFT",
    164,
    -27
)

row.direction:SetWidth(65)
row.direction:SetJustifyH("CENTER")
row.direction:SetTextColor(1, 0.92, 0.72)

    row:Hide()

    return row
end

-- Row pool
local function AcquireRow(key)
    if rows[key] then
        return rows[key]
    end

    local row = table.remove(rowPool)

    if not row then
        row = CreateRow()
    end

    rows[key] = row

    return row
end

-- Draw player
local function DrawRow(
    key,
    name,
    playerX,
    playerY,
    targetX,
    targetY,
    heading,
    seen,
    displayOrder
)
    local east = targetX - playerX
    local north = playerY - targetY

    local distance = math.sqrt(
        east * east + north * north
    )

    local bearing = Atan2(-east, north)

    local relative = bearing

    if heading then
        relative = bearing - heading
    end

    local row = AcquireRow(key)

    row.arrow:SetText(
        ArrowSymbol(relative)
    )

    row.name:SetText(
        name or "Unknown"
    )

    row.status:SetText("DEAD")

    row.distance:SetText(
        string.format("%.4f", distance)
    )

    row.direction:SetText(
        DirectionName(bearing)
    )

    row:Show()

    seen[key] = true

    table.insert(displayOrder, key)
end

-- Hide unsed rows
local function HideUnusedRows(seen)
    local key, row

    for key, row in pairs(rows) do
        if not seen[key] then
            row:Hide()

            rows[key] = nil

            table.insert(rowPool, row)
        end
    end
end

-- Group units
local function GetGroupUnits()
    local units = {}
    local count = 0
    local i

    if type(GetNumRaidMembers) == "function" then
        count = GetNumRaidMembers() or 0

        if count > 0 then
            for i = 1, count do
                table.insert(units, "raid" .. i)
            end

            return units
        end
    end

    if type(GetNumPartyMembers) == "function" then
        count = GetNumPartyMembers() or 0

        for i = 1, count do
            table.insert(units, "party" .. i)
        end
    end

    return units
end

-- Update hud
local function UpdateHUD()
    local playerX, playerY = ReadMapPosition("player")

    local seen = {}
    local displayOrder = {}

    if not playerX then
        HideUnusedRows(seen)
        panel:Hide()
        return
    end

    local heading = ReadHeading()

    -- Own cropse
    if ownCorpseX
        and ownCorpseY
        and UnitIsDead("player") then

        DrawRow(
            "own",
            UnitName("player") or "Your corpse",
            playerX,
            playerY,
            ownCorpseX,
            ownCorpseY,
            heading,
            seen,
            displayOrder
        )

    elseif not UnitIsDead("player") then
        ownCorpseX = nil
        ownCorpseY = nil
    end

    -- Party corpse
    local units = GetGroupUnits()
    local i

    for i = 1, table.getn(units) do
        local unit = units[i]
        local name = UnitName(unit)

        if name and UnitIsDead(unit) then
            local x, y = ReadMapPosition(unit)

            if x then
                DrawRow(
                    "group_" .. name,
                    name,
                    playerX,
                    playerY,
                    x,
                    y,
                    heading,
                    seen,
                    displayOrder
                )
            end
        end
    end

    -- Remove revived players
    HideUnusedRows(seen)

    -- Update panel
    local count = table.getn(displayOrder)

    if count > 0 then
        panel:SetHeight(
            43 + count * ROW_HEIGHT + 8
        )

        countText:SetText(
            tostring(count) .. " fallen"
        )

        local i

        for i = 1, count do
            local key = displayOrder[i]
            local row = rows[key]

            if row then
                row:ClearAllPoints()

                row:SetPoint(
                    "TOPLEFT",
                    panel,
                    "TOPLEFT",
                    9,
                    -40 - ((i - 1) * ROW_HEIGHT)
                )
            end
        end

        panel:Show()
    else
        panel:Hide()
    end
end

-- Events
local frame = CreateFrame(
    "Frame",
    "BobiWoWCorpseTracker"
)

frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("RAID_ROSTER_UPDATE")

frame:SetScript("OnEvent", function()
    if event == "PLAYER_DEAD" then
        ownCorpseX, ownCorpseY =
            ReadMapPosition("player")

    elseif event == "PLAYER_ALIVE"
        or event == "PLAYER_UNGHOST" then

        ownCorpseX = nil
        ownCorpseY = nil
    end

    headingModel = nil

    UpdateHUD()
end)

-- Update loop
frame:SetScript("OnUpdate", function()
    elapsed = elapsed + (arg1 or 0)

    if elapsed < UPDATE_INTERVAL then
        return
    end

    elapsed = 0

    UpdateHUD()
end)

frame:Show()