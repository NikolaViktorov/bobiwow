-- BobiWoW
-- Core
-- Version: 0.2.0

local logoFrame = CreateFrame("Frame", "BobiWoWLogo", UIParent)

logoFrame:SetWidth(240)
logoFrame:SetHeight(80)

logoFrame:SetPoint("TOP", Minimap, "BOTTOM", -30, -10)

logoFrame:SetFrameStrata("HIGH")

local logo = logoFrame:CreateTexture(nil, "ARTWORK")

logo:SetAllPoints(logoFrame)

logo:SetTexture(
    "Interface\\AddOns\\bobiwow\\Media\\BobiWoW_Logo_512.tga"
)

logo:SetTexCoord(0, 1, 0.168, 0.828)

logoFrame:Show()