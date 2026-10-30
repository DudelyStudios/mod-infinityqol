-- One ability bar for every pet the player controls.
-- Attack, follow, stay, and aggression stay on the normal pet bar and already reach every pet.
-- Left click casts. Right click toggles autocast when the spell allows it. Middle-drag moves this bar.

local BUTTON = 36
local GAP = 4
local buttons = {}
local consolidate = false
local hooksReady = false
local packing = false
local restorePending = false
local KEPT_SLOTS = { 1, 2, 3, 8, 9, 10 }
local HIDDEN_SLOTS = { 4, 5, 6, 7 }

local frame = CreateFrame("Frame", "InfinityQoLPetBar", UIParent)
frame:SetHeight(BUTTON)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("MiddleButton")
frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)
frame:Hide()

local function EnsureButton(index)
    local button = buttons[index]
    if button then
        return button
    end

    button = CreateFrame("Button", "InfinityQoLPetBarButton" .. index, frame)
    button:SetSize(BUTTON, BUTTON)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("MiddleButton")
    button:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    button:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon

    local autocast = button:CreateTexture(nil, "OVERLAY")
    autocast:SetTexture("Interface\\Buttons\\UI-AutoCastableOverlay")
    autocast:SetAllPoints(button)
    autocast:Hide()
    button.autocast = autocast

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    button.cooldown = cooldown

    button:SetScript("OnClick", function(self, mouseButton)
        if not self.spellId or type(SendAddonMessage) ~= "function" then
            return
        end
        if mouseButton == "RightButton" then
            if self.autocastMode ~= 2 then
                SendAddonMessage("IQOL", "PETAUTO:" .. self.spellId, "WHISPER", UnitName("player"))
            end
            return
        end
        SendAddonMessage("IQOL", "PETCAST:" .. self.spellId, "WHISPER", UnitName("player"))
    end)
    button:SetScript("OnEnter", function(self)
        if not self.spellId then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("spell:" .. self.spellId)
        if self.autocastMode ~= 2 then
            GameTooltip:AddLine("Right-click to toggle autocast.", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    if index == 1 then
        button:SetPoint("LEFT", frame, "LEFT", 0, 0)
    else
        button:SetPoint("LEFT", buttons[index - 1], "RIGHT", GAP, 0)
    end

    buttons[index] = button
    return button
end

local function ShowSpells(spells)
    if #spells == 0 then
        frame:Hide()
        return
    end

    frame:SetWidth((#spells * BUTTON) + ((#spells - 1) * GAP))

    for index, spell in ipairs(spells) do
        local button = EnsureButton(index)
        local _, _, icon = GetSpellInfo(spell.id)
        button.spellId = spell.id
        button.autocastMode = spell.mode
        button.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        if spell.mode == 2 then
            button.autocast:Hide()
        else
            button.autocast:Show()
            if spell.mode == 1 then
                button.autocast:SetVertexColor(1, 1, 1)
            else
                button.autocast:SetVertexColor(0.35, 0.35, 0.35)
            end
        end
        button:Show()
    end

    for index = #spells + 1, #buttons do
        buttons[index].spellId = nil
        buttons[index].autocastMode = nil
        buttons[index]:Hide()
    end

    frame:Show()
end

local function StartCooldown(spellId, seconds)
    if not seconds or seconds <= 0 then
        return
    end

    for _, button in ipairs(buttons) do
        if button.spellId == spellId and button:IsShown() then
            button.cooldown:SetCooldown(GetTime(), seconds)
        end
    end
end

local function ElvUIBars()
    if type(ElvUI) ~= "table" then
        return nil
    end

    local ok, E = pcall(unpack, ElvUI)
    if not ok or not E or not E.GetModule then
        return nil
    end

    local bars = E:GetModule("ActionBars", true)
    if not bars or not bars.db or not bars.db.barPet or not _G["ElvUI_BarPet"] then
        return nil
    end

    return E, bars
end

local function HideSpellSlots(useScale)
    for _, index in ipairs(HIDDEN_SLOTS) do
        local button = _G["PetActionButton" .. index]
        if button then
            if useScale then
                button:SetScale(0.0001)
            end
            button:SetAlpha(0)
            button:EnableMouse(false)
        end
    end
end

local function PackElvUIBar(E, bars)
    local db = bars.db.barPet
    local petBar = _G["ElvUI_BarPet"]
    if not db.enabled then
        return
    end

    local size = E:Scale(db.buttonsize)
    local buttonSpacing = E:Scale(db.buttonspacing)
    local backdropSpacing = E:Scale(db.backdropSpacing or db.buttonspacing)
    local point = db.point or "TOPRIGHT"
    local backdrop = db.backdrop == true
    local widthMult = db.widthMult or 1
    local heightMult = db.heightMult or 1
    if not backdrop then
        widthMult = 1
        heightMult = 1
    end

    local count = #KEPT_SLOTS
    local buttonsPerRow = db.buttonsPerRow or 1
    if buttonsPerRow < 1 then
        buttonsPerRow = 1
    end
    if buttonsPerRow > count then
        buttonsPerRow = count
    end

    local numColumns = math.ceil(count / buttonsPerRow)
    local padding = (backdrop and (E.Border + backdropSpacing) or E.Spacing) * 2
    local firstButtonSpacing = backdrop and (E.Border + backdropSpacing) or E.Spacing
    local barWidth = (size * (buttonsPerRow * widthMult))
        + ((buttonSpacing * (buttonsPerRow - 1)) * widthMult)
        + (buttonSpacing * (widthMult - 1))
        + padding
    local barHeight = (size * (numColumns * heightMult))
        + ((buttonSpacing * (numColumns - 1)) * heightMult)
        + (buttonSpacing * (heightMult - 1))
        + padding

    petBar:SetWidth(barWidth)
    petBar:SetHeight(barHeight)

    local horizontalGrowth = (point == "BOTTOMLEFT" or point == "TOPLEFT") and "RIGHT" or "LEFT"
    local verticalGrowth = (point == "TOPLEFT" or point == "TOPRIGHT") and "DOWN" or "UP"
    local alpha = db.alpha or 1

    HideSpellSlots(true)

    for order, index in ipairs(KEPT_SLOTS) do
        local button = _G["PetActionButton" .. index]
        if button then
            button:SetParent(petBar)
            button:SetScale(1)
            button:SetAlpha(alpha)
            button:EnableMouse(true)
            button:SetSize(size, size)
            button:ClearAllPoints()

            if order == 1 then
                local x, y
                if point == "BOTTOMLEFT" then
                    x, y = firstButtonSpacing, firstButtonSpacing
                elseif point == "TOPRIGHT" then
                    x, y = -firstButtonSpacing, -firstButtonSpacing
                elseif point == "TOPLEFT" then
                    x, y = firstButtonSpacing, -firstButtonSpacing
                else
                    x, y = -firstButtonSpacing, firstButtonSpacing
                end
                button:SetPoint(point, petBar, point, x, y)
            elseif (order - 1) % buttonsPerRow == 0 then
                local columnAnchor = _G["PetActionButton" .. KEPT_SLOTS[order - buttonsPerRow]]
                local y = -buttonSpacing
                local buttonPoint, anchorPoint = "TOP", "BOTTOM"
                if verticalGrowth == "UP" then
                    y = buttonSpacing
                    buttonPoint, anchorPoint = "BOTTOM", "TOP"
                end
                button:SetPoint(buttonPoint, columnAnchor, anchorPoint, 0, y)
            else
                local previous = _G["PetActionButton" .. KEPT_SLOTS[order - 1]]
                local x = buttonSpacing
                local buttonPoint, anchorPoint = "LEFT", "RIGHT"
                if horizontalGrowth == "LEFT" then
                    x = -buttonSpacing
                    buttonPoint, anchorPoint = "RIGHT", "LEFT"
                end
                button:SetPoint(buttonPoint, previous, anchorPoint, x, 0)
            end
        end
    end
end

local function PackDefaultBar()
    local first = _G["PetActionButton1"]
    local stay = _G["PetActionButton3"]
    if not first or not stay then
        return
    end

    local size = first:GetWidth()
    if not size or size < 1 then
        return
    end

    HideSpellSlots(false)

    local previous = stay
    for _, index in ipairs({ 8, 9, 10 }) do
        local button = _G["PetActionButton" .. index]
        if button then
            button:SetAlpha(1)
            button:EnableMouse(true)
            button:ClearAllPoints()
            button:SetPoint("LEFT", previous, "RIGHT", GAP, 0)
            previous = button
        end
    end

    local stock = _G["PetActionBarFrame"]
    if stock then
        stock:SetWidth((size * 6) + (GAP * 5))
    end
end

local function PackStockBar()
    if not consolidate or packing or InCombatLockdown() then
        return
    end

    packing = true
    local E, bars = ElvUIBars()
    if E then
        PackElvUIBar(E, bars)
    else
        PackDefaultBar()
    end
    packing = false
end

local function RestoreStockBar()
    consolidate = false
    if InCombatLockdown() then
        restorePending = true
        return
    end

    restorePending = false
    local _, bars = ElvUIBars()
    if bars and bars.PositionAndSizeBarPet then
        bars:PositionAndSizeBarPet()
        return
    end

    for _, index in ipairs(HIDDEN_SLOTS) do
        local button = _G["PetActionButton" .. index]
        if button then
            button:SetScale(1)
            button:SetAlpha(1)
            button:EnableMouse(true)
        end
    end
end

local function EnsureHooks()
    if hooksReady or type(hooksecurefunc) ~= "function" then
        return
    end
    hooksReady = true

    local _, bars = ElvUIBars()
    if bars and bars.PositionAndSizeBarPet then
        hooksecurefunc(bars, "PositionAndSizeBarPet", function()
            if consolidate then
                PackStockBar()
            end
        end)
    elseif type(PetActionBar_Update) == "function" then
        hooksecurefunc("PetActionBar_Update", function()
            if consolidate then
                PackStockBar()
            end
        end)
    end
end

local function HandleMessage(message)
    if type(message) ~= "string" then
        return
    end

    if message == "PETBAR:OFF" then
        RestoreStockBar()
        frame:Hide()
        return
    end

    local listed = string.match(message, "^PETBAR:(.*)$")
    if listed then
        consolidate = true
        EnsureHooks()
        PackStockBar()

        local spells = {}
        for id, mode in string.gmatch(listed, "(%d+):(%d+)") do
            table.insert(spells, { id = tonumber(id), mode = tonumber(mode) })
        end
        ShowSpells(spells)
        return
    end

    local spellId, milliseconds = string.match(message, "^PETCD:(%d+):(%d+)$")
    if spellId then
        StartCooldown(tonumber(spellId), tonumber(milliseconds) / 1000)
    end
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:RegisterEvent("PLAYER_REGEN_ENABLED")
listener:SetScript("OnEvent", function(_, event, prefix, message)
    if event == "PLAYER_REGEN_ENABLED" then
        if restorePending then
            RestoreStockBar()
        elseif consolidate then
            PackStockBar()
        end
        return
    end

    if prefix == "IQOL" then
        HandleMessage(message)
        return
    end

    if type(prefix) == "string" then
        local body = string.match(prefix, "^IQOL\t(.+)$")
        if body then
            HandleMessage(body)
        end
    end
end)
