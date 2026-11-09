-- BobiWoW Timer v1

-- Hide original game clock
if AZS_SetHudShown then
    AZS_SetHudShown("clock", false)
end


-- Timer frame
local timerFrame = CreateFrame("Frame", "BobiWoWTimer", UIParent)

timerFrame:SetWidth(240)
timerFrame:SetHeight(45)

timerFrame:SetPoint(
    "TOP",
    UIParent,
    "TOP",
    0,
    -77
)

timerFrame:SetFrameStrata("HIGH")

-- Main timer
local timerText = timerFrame:CreateFontString(nil, "OVERLAY")

timerText:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")

timerText:SetPoint("TOP", timerFrame, "TOP", 0, 0)

timerText:SetText("00:00")

timerText:SetTextColor(1, 0.82, 0.35)


-- Next boss timer
local bossText = timerFrame:CreateFontString(nil, "OVERLAY")

bossText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")

bossText:SetPoint("TOP", timerText, "BOTTOM", 0, -2)

bossText:SetText("Waiting for run...")

bossText:SetTextColor(0.85, 0.85, 0.85)


-- Update
timerFrame:SetScript("OnUpdate", function()

    if not AZS_GetPhase or AZS_GetPhase() ~= "playing" then
        timerText:SetText("00:00")
        bossText:SetText("Waiting for run...")
        return
    end

    -- Current run time
    local runtime = AZS_GetRunTime()

    if runtime then

        local minutes = math.floor(runtime / 60)
        local seconds = math.mod(math.floor(runtime), 60)

        timerText:SetText(
            string.format("%02d:%02d", minutes, seconds)
        )

    end

    -- Next boss
    local bosses = AZS_GetUpcomingBosses()

    if bosses and bosses[1] then

        local remaining = math.max(0, bosses[1].left)

        local minutes = math.floor(remaining / 60)
        local seconds = math.mod(math.floor(remaining), 60)

        bossText:SetText(
            "Next boss in " ..
            string.format("%02d:%02d", minutes, seconds)
        )

    else

        bossText:SetText("No upcoming boss")

    end

end)

timerFrame:Show()