-- The stock stable window only builds four buttons. Slots 5-20 sit beside that window.
-- NUM_PET_STABLE_SLOTS stays at 4 until those buttons exist. ElvUI skins
-- 1..NUM_PET_STABLE_SLOTS on PLAYER_LOGIN, and a missing button errors the skin.
local COLUMNS = 4
local BUTTON = 37
local GAP = 6
local skinned = {}

local panel = CreateFrame("Frame", "InfinityQoLStableSlots", UIParent)
panel:SetSize((COLUMNS * BUTTON) + ((COLUMNS - 1) * GAP), (COLUMNS * BUTTON) + ((COLUMNS - 1) * GAP))
panel:SetFrameStrata("HIGH")
panel:Hide()

local function UpdateSlot(texture, _, g)
    if g ~= 1 then
        texture:SetTexture(0.8, 0.2, 0.2, 0.3)
    else
        texture:SetTexture(0, 0, 0, 0)
    end
end

local function ElvUISkins()
    if type(ElvUI) ~= "table" then
        return nil
    end

    local ok, E = pcall(unpack, ElvUI)
    if not ok or not E or not E.GetModule then
        return nil
    end

    local private = E.private
    local blizzard = private and private.skins and private.skins.blizzard
    if not blizzard or not blizzard.enable or not blizzard.stable then
        return nil
    end

    local skins = E:GetModule("Skins", true)
    if not skins or not skins.HandleItemButton then
        return nil
    end

    return skins
end

local function SkinButton(button)
    if skinned[button] then
        return
    end

    local skins = ElvUISkins()
    if not skins then
        return
    end

    skins:HandleItemButton(button, true)

    local icon = _G[button:GetName() .. "IconTexture"]
    if icon then
        icon:SetDrawLayer("OVERLAY")
    end

    local background = _G[button:GetName() .. "Background"]
    if background then
        background:SetDrawLayer("BORDER")
        if background.SetInside then
            background:SetInside()
        end
        if not background.InfinityQoLHooked then
            background.InfinityQoLHooked = true
            hooksecurefunc(background, "SetVertexColor", UpdateSlot)
        end
    end

    skinned[button] = true
end

local function CreateExtraButtons()
    for i = 5, 20 do
        local name = "PetStableStabledPet" .. i
        local button = _G[name]
        if not button then
            button = CreateFrame("CheckButton", name, panel, "PetStableSlotTemplate")
        end

        if not button then
            return false
        end

        button:SetParent(panel)
        button:SetID(i)
        button:SetSize(BUTTON, BUTTON)

        local index = i - 5
        local col = index % COLUMNS
        local row = math.floor(index / COLUMNS)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", col * (BUTTON + GAP), -row * (BUTTON + GAP))
    end

    if not _G["PetStableStabledPet20"] then
        return false
    end

    NUM_PET_STABLE_SLOTS = 20
    return true
end

local function EnsureButtons()
    if not CreateExtraButtons() then
        return false
    end

    for i = 5, NUM_PET_STABLE_SLOTS do
        local button = _G["PetStableStabledPet" .. i]
        if button then
            button:Show()
            SkinButton(button)
        end
    end

    return true
end

-- Build the buttons during addon load so ElvUI's login skin finds them.
CreateExtraButtons()

local function LayoutStableSlots()
    if not PetStableFrame or not EnsureButtons() then
        panel:Hide()
        return
    end

    panel:SetFrameLevel(PetStableFrame:GetFrameLevel() + 20)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", PetStableFrame, "TOPRIGHT", -16, -70)
    panel:Show()
end

local function HideStableSlots()
    panel:Hide()
end

local updateHooked = false

local function HookStableUpdate()
    if updateHooked or type(PetStable_Update) ~= "function" then
        return
    end

    updateHooked = true
    local original = PetStable_Update
    PetStable_Update = function()
        EnsureButtons()
        original()
        if PetStableFrame and PetStableFrame:IsShown() then
            LayoutStableSlots()
        end
    end
end

local function WatchStableFrame()
    if not PetStableFrame then
        return
    end

    HookStableUpdate()
    PetStableFrame:HookScript("OnShow", LayoutStableSlots)
    PetStableFrame:HookScript("OnHide", HideStableSlots)
    if PetStableFrame:IsShown() then
        LayoutStableSlots()
    end
end

if PetStableFrame then
    WatchStableFrame()
else
    local waiter = CreateFrame("Frame")
    waiter:SetScript("OnUpdate", function(self)
        if not PetStableFrame then
            return
        end
        WatchStableFrame()
        self:SetScript("OnUpdate", nil)
        self:Hide()
    end)
end
