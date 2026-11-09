-- BobiWoW CombatText v1
-- Smart Scrolling Combat Text
-- Groups rapid hits by spell and target.

local frame = CreateFrame("Frame")

local elapsed = 0
local cursor = nil
local registered = false

-- Aggregation settings
local GROUP_WINDOW = 0.30
local MAX_GROUPS = 100

-- Visual settings
local DISPLAY_DURATION = 3.0
local FADE_DURATION = 0.5
local MOVE_DISTANCE = 260
local MAX_ENTRIES = 25
local SPAWN_INTERVAL = 0.28
local MAX_PENDING = 25

local groups = {}
local pending = {}

local rows = {}
local spawnElapsed = 0

local function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffcc33BobiWoW:|r " .. tostring(message)
        )
    end
end

-- Create visual rows.
for i = 1, MAX_ENTRIES do
    local row = CreateFrame("Frame", nil, UIParent)

    row:SetWidth(180)
    row:SetHeight(24)
    row:SetFrameStrata("HIGH")
    row:SetAlpha(0)
    row:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(20)
    row.icon:SetHeight(20)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)

    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.text:SetWidth(150)
    row.text:SetJustifyH("LEFT")

    row.active = false
    row.elapsed = 0
    row.startY = 210

    rows[i] = row
end

-- Build a grouping key from spell and target.
local function GetGroupKey(event)
    local spellKey = tostring(
        event.spellId or event.abilityName or event.icon or "unknown"
    )

    local targetKey = tostring(
        event.targetId or event.targetName or "unknown"
    )

    return spellKey .. ":" .. targetKey
end

-- Add an event to the aggregation system.
local function AddDamageEvent(event)
    if event.kind ~= "damage" then
        return
    end

    if type(event.amount) ~= "number" then
        return
    end

    local key = GetGroupKey(event)
    local group = groups[key]

    if not group then
        -- Prevent unlimited aggregation groups.
        local count = 0

        for _ in pairs(groups) do
            count = count + 1
        end

        if count >= MAX_GROUPS then
            return
        end

        group = {
            key = key,
            spellId = event.spellId,
            abilityName = event.abilityName,
            icon = event.icon,

            totalDamage = 0,
            hitCount = 0,
            hasCritical = false,

            elapsed = 0
        }

        groups[key] = group
    end

    group.totalDamage = group.totalDamage + event.amount
    group.hitCount = group.hitCount + 1
    group.elapsed = 0

    if event.critical then
        group.hasCritical = true
    end

    if event.icon then
        group.icon = event.icon
    end
end

-- Move completed groups into a small bounded pending list.
local function FinalizeGroup(group)
    if table.getn(pending) >= MAX_PENDING then
        -- Prefer preserving critical groups.
        local removeIndex = nil

        for i = 1, table.getn(pending) do
            if not pending[i].hasCritical then
                removeIndex = i
                break
            end
        end

        if not removeIndex then
            removeIndex = 1
        end

        table.remove(pending, removeIndex)
    end

    table.insert(pending, group)
end

-- Update aggregation timers.
local function UpdateGroups(delta)
    for key, group in pairs(groups) do
        group.elapsed = group.elapsed + delta

        if group.elapsed >= GROUP_WINDOW then
            FinalizeGroup(group)
            groups[key] = nil
        end
    end
end

-- Find an unused visual row.
local function GetAvailableRow()
    for i = 1, MAX_ENTRIES do
        if not rows[i].active then
            return rows[i]
        end
    end

    return nil
end

-- Start one scrolling damage entry.
local function SpawnDamage(group)
    local row = GetAvailableRow()

    if not row then
        return false
    end

    local damage = math.floor(group.totalDamage + 0.5)

    row.icon:SetTexture(group.icon or "")
    row.text:SetText(tostring(damage))

    if group.hasCritical then
        row.text:SetTextColor(1, 0.82, 0.1)
    else
        row.text:SetTextColor(1, 1, 1)
    end

    row.elapsed = 0
    row.startY = 210
    row.active = true

    row:ClearAllPoints()
    row:SetPoint(
        "RIGHT",
        UIParent,
        "RIGHT",
        -35,
        row.startY
    )

    row:SetAlpha(1)
    row:Show()

    return true
end

-- Update scrolling animations.
local function UpdateAnimations(delta)
    for i = 1, MAX_ENTRIES do
        local row = rows[i]

        if row.active then
            row.elapsed = row.elapsed + delta

            local progress = row.elapsed / DISPLAY_DURATION

            if progress >= 1 then
                row.active = false
                row:SetAlpha(0)
                row:Hide()
            else
                local y = row.startY - MOVE_DISTANCE * progress

                row:ClearAllPoints()
                row:SetPoint(
                    "RIGHT",
                    UIParent,
                    "RIGHT",
                    -35,
                    y
                )

                local fadeStart =
                    1 - (FADE_DURATION / DISPLAY_DURATION)

                if progress > fadeStart then
                    local fadeProgress =
                        (progress - fadeStart) / (1 - fadeStart)

                    row:SetAlpha(1 - fadeProgress)
                else
                    row:SetAlpha(1)
                end
            end
        end
    end
end

-- Process pending visual entries at a controlled rate.
local function UpdatePending(delta)
    spawnElapsed = spawnElapsed + delta

    if spawnElapsed < SPAWN_INTERVAL then
        return
    end

    if table.getn(pending) == 0 then
        spawnElapsed = 0
        return
    end

    local group = pending[1]

    if SpawnDamage(group) then
        table.remove(pending, 1)
        spawnElapsed = 0
    end
end

-- Required camera frame handler.
local function CameraFrameHandler()
end

frame:SetScript("OnUpdate", function()
    local delta = arg1 or 0.016

    UpdateAnimations(delta)
    UpdateGroups(delta)
    UpdatePending(delta)

    if not AZS_GetPhase or AZS_GetPhase() ~= "playing" then
        return
    end

    -- Register native frame handler.
    if not registered then
        local ok, result, failure = pcall(
            AZS_RegisterCombatTextFrameHandler,
            CameraFrameHandler
        )

        if not ok or result == false or failure ~= nil then
            return
        end

        registered = true
        Print("Combat Text initialized!")
    end

    -- Read native event stream.
    elapsed = elapsed + delta

    if elapsed < 0.1 then
        return
    end

    elapsed = 0

    local ok, result = pcall(
        AZS_GetCombatTextEvents,
        cursor,
        256
    )

    if not ok or type(result) ~= "table" then
        return
    end

    if type(result.cursor) == "string" then
        cursor = result.cursor
    end

    if type(result.events) ~= "table" then
        return
    end

    for _, event in ipairs(result.events) do
        if type(event) == "table" then
            AddDamageEvent(event)
        end
    end
end)