include("InstanceManager");

local LYSEFJORD_MODIFIER_ID         :string = "LYSEFJORDEN_GRANT_NAVAL_UNIT_EXPERIENCE";  -- This is an official modifier
local LYSEFJORD_DUMMY_ABILITY_TYPE  :string = "ABILITY_AHP_LYSEFJORD_PROMOTION";  -- The game doesn't actually handle this through ability. This is a made-up name for generic implementation

local m_NaturalWonderAbilitiesConfig = {
    -- UnitAbilityType = {
    --     FeatureType = FeatureType,
    --     ControlID = IconIDInXML
    -- }

    -- Land military units
    ABILITY_ALPINE_TRAINING = {
        FeatureType = "FEATURE_MATTERHORN",
        ControlID = "Icon_AlpineTraining"
    },
    ABILITY_SPEAR_OF_FIONN = {
        FeatureType = "FEATURE_GIANTS_CAUSEWAY",
        ControlID = "Icon_SpearOfFionn"
    },
    ABILITY_WATER_OF_LIFE = {
        FeatureType = "FEATURE_FOUNTAIN_OF_YOUTH",
        ControlID = "Icon_WaterOfLife"
    },
    -- Naval military units
    ABILITY_MYSTERIOUS_CURRENTS = {
        FeatureType = "FEATURE_BERMUDA_TRIANGLE",
        ControlID = "Icon_MysteriousCurrents"
    },
    [LYSEFJORD_DUMMY_ABILITY_TYPE] = {
        FeatureType = "FEATURE_LYSEFJORDEN",
        ControlID = "Icon_LysefjordPromotion"
    },
    -- Religious units
    ABILITY_ALTITUDE_TRAINING = {
        FeatureType = "FEATURE_EVEREST",
        ControlID = "Icon_AltitudeTraining"
    }
};

local m_PromotionIconIM = InstanceManager:new("PromotionIconInstance", "PromotionIconRootControl", Controls.PromotionIconContainer);

function UpdateAbilityHighlightsPanel(playerID:number, unitID:number)
    local pPlayer = Players[playerID];
    if pPlayer then
        local pUnit = pPlayer:GetUnits():FindID(unitID);
        local unitInfo:table = GameInfo.Units[pUnit:GetType()];
        if pUnit and unitInfo and IsValidForAbilityHighlightsPanelDisplay(unitInfo.FormationClass, unitInfo.ReligiousStrength) then
            Controls.AHP_Root:SetHide(false);
            UpdateNaturalWonderAbilityIcons(pUnit:GetAbility():GetAbilities());
            UpdateLysefjordPromotionIcon(playerID, unitID);  -- UpdateLysefjordPromotionIcon must execute after UpdateNaturalWonderAbilityIcons for the correct display of Icon_LysefjordPromotion
            UpdatePromotionIcons(unitInfo.PromotionClass, pUnit:GetExperience():GetPromotions());
        else
            Controls.AHP_Root:SetHide(true);
        end
    end
end

-- ===========================================================================
-- Check if the given unit belongs to one of the following groups:
-- 1. land combat units
-- 2. naval combat units
-- 3. air combat units
-- 4. religious units (Missionaries, Apostles, Gurus, and Inquisitors)
-- ===========================================================================
function IsValidForAbilityHighlightsPanelDisplay(formationClass:string, religiousStrength:number)
    return formationClass == "FORMATION_CLASS_LAND_COMBAT" or
           formationClass == "FORMATION_CLASS_NAVAL" or
           formationClass == "FORMATION_CLASS_AIR" or
           (religiousStrength and religiousStrength > 0);
end

-- ===========================================================================
-- Main update logic: check which natural wonder abilities have the selected
-- unit acquired and display the corresponding icons
-- `dataAbility` is an array of integers (Gemini)
-- ===========================================================================
function UpdateNaturalWonderAbilityIcons(dataAbility:table)
    local hasTheseNaturalWonderAbilities:table = {};  -- an array of `UnitAbilityType`

    -- Iterate through the unit's abilities and record the natural wonder
    -- abilities among them
    if dataAbility then
        for _, abilityIndex in ipairs(dataAbility) do
            local abilityDef:table = GameInfo.UnitAbilities[abilityIndex];

            if abilityDef and abilityDef.UnitAbilityType and m_NaturalWonderAbilitiesConfig[abilityDef.UnitAbilityType] then
                -- this is a natural wonder ability!
                hasTheseNaturalWonderAbilities[abilityDef.UnitAbilityType] = true;
            end
        end
    end

    -- Reveal or hide icons based on availability
    for unitAbilityType, config in pairs(m_NaturalWonderAbilitiesConfig) do
        Controls[config.ControlID]:SetHide(not hasTheseNaturalWonderAbilities[unitAbilityType]);
        -- TODO: (future) maybe show silhouette for acquirable abilities that are not gained yet
    end
end

-- ===========================================================================
-- Check whether the given unit has acquired the free promotion from Lysefjord.
-- Note: the game treats the promotion gained from Lysefjord differently from
-- other natural wonder abilities. A "detour" is needed to retrieve that info.
-- ===========================================================================
function UpdateLysefjordPromotionIcon(playerID:number, unitID:number)
    local iconControl = Controls[m_NaturalWonderAbilitiesConfig[LYSEFJORD_DUMMY_ABILITY_TYPE].ControlID];

    local activeModifiers = GameEffects.GetModifiers();
    --    ^^^
    -- an array of integers (Gemini) representing
    -- the runtime IDs of all active modifier instances in the current game state

    for _, instID in ipairs(activeModifiers) do
        local definition = GameEffects.GetModifierDefinition(instID);
        --    ^^^
        -- a table representing the static database definition of the modifier instance (Gemini)
        -- definition.Id is of type `ModifierId`

        if definition and definition.Id == LYSEFJORD_MODIFIER_ID then
            local subjects = GameEffects.GetModifierSubjects(instID);
            --    ^^^
            -- an array of integers (Gemini) representing
            -- the runtime IDs of the objects being affected by this modifier instance

            if subjects then
                for _, subjectID in ipairs(subjects) do
                    if GameEffects.GetObjectsPlayerId(subjectID) == playerID then
                        -- Found an object that belongs to the player

                        -- Check if the found unit is the given unit
                        local subjectStr = GameEffects.GetObjectString(subjectID);
                        local foundUnitID = tonumber(string.match(subjectStr, "Unit: (%d+)"));

                        if foundUnitID == unitID then
                            iconControl:SetHide(false);
                            return; 
                        end
                    end
                end
            end
        end
    end

    iconControl:SetHide(true);
end

-- `dataPromotion` is an array of integers (Gemini)
function UpdatePromotionIcons(promotionClass:string, dataPromotion:table)
    m_PromotionIconIM:ResetInstances();

    -- Table for O(1) lookup
    local hasThesePromotions:table = {};
    for _, id in ipairs(dataPromotion) do
        hasThesePromotions[id] = true;
    end

    -- Display nodes (promotions)
    for row in GameInfo.UnitPromotions() do
        if row.PromotionClass == promotionClass and row.Column ~= 0 then
            local horizontalAnchor:string = "";
            if     row.Column == 1 then horizontalAnchor = "L";
            elseif row.Column == 2 then horizontalAnchor = "C";
            elseif row.Column == 3 then horizontalAnchor = "R";
            end
            local textureOffsetVal:number = 0;
            local unearnedHint:string = "";
            if hasThesePromotions[row.Index] then
                textureOffsetVal = 108;
            else
                textureOffsetVal = 36;
                unearnedHint = " [COLOR:Red](" .. Locale.Lookup("LOC_AHP_UNEARNED") .. ")[ENDCOLOR]"
            end

            local promotionIconInstance = m_PromotionIconIM:GetInstance();
            promotionIconInstance.PromotionIconRootControl:SetAnchor(horizontalAnchor .. ",T");
            promotionIconInstance.PromotionIconRootControl:SetOffsetVal(0, (row.Level-1)*18-3);
            promotionIconInstance.PromotionIconRootControl:SetTextureOffsetVal(0, textureOffsetVal);
            promotionIconInstance.PromotionIconRootControl:SetToolTipString(Locale.Lookup(row.Name) .. unearnedHint .. "[NEWLINE]" .. Locale.Lookup(row.Description));
        end
    end

    -- Display line segments (Prereqs)
end

-- ===========================================================================
-- Generate the tooltip for each ability icon in player's game language
-- ===========================================================================
function InitAbilityTooltips()
    for unitAbilityType, config in pairs(m_NaturalWonderAbilitiesConfig) do
        local abilityDef:table = GameInfo.UnitAbilities[unitAbilityType];
        local featureDef:table = GameInfo.Features[config.FeatureType];

        if abilityDef and featureDef then
            local name  :string = Locale.Lookup(abilityDef.Name);
            local source:string = Locale.Lookup(featureDef.Name);
            local desc  :string = Locale.Lookup(abilityDef.Description);

            Controls[config.ControlID]:SetToolTipString(name .. " (" .. source .. ")[NEWLINE]" .. desc);
        end
    end
end

-- ===========================================================================
-- UI handlers
-- ===========================================================================
function OnToggleAbilityHighlightsPanel()
    local isHidden:boolean = Controls.AbilityHighlightsPanel:IsHidden();
    if isHidden then
        Controls.AbilityHighlightsPanel:SetHide(false);
        Controls.AbilityHighlightsPanelToggleButton:SetTextureOffsetVal(0, 22);
        Controls.AbilityHighlightsPanelToggleButton:SetToolTipString("Collapse ability highlights panel.");
    else
        Controls.AbilityHighlightsPanel:SetHide(true);
        Controls.AbilityHighlightsPanelToggleButton:SetTextureOffsetVal(0, 0);
        Controls.AbilityHighlightsPanelToggleButton:SetToolTipString("Expand ability highlights panel.");
    end
end

-- ===========================================================================
-- Initialization / Injection
-- ===========================================================================
function Initialize()
    print("Initializing Ability Highlights Panel...");

    local targetPath = "/InGame/UnitPanel/UnitPanelAlpha/UnitPanelSlide/UnitPanelBaseContainer/UnitIcon";
    local targetControl = ContextPtr:LookUpControl(targetPath);
    if targetControl then
        Controls.AHP_Root:ChangeParent(targetControl);
    else
        print("AHP Error: Could not find " .. targetPath .. ". Abort.");
        return;
    end


    InitAbilityTooltips();

    -- When a unit is selected
    -- update: natural wonder abilities; Icon_LysefjordPromotion; exp modifier; promo tree
    Events.UnitSelectionChanged.Add(function(playerID, unitID, locationX, locationY, locationZ, isSelected, isEditable)
        if isSelected then
            UpdateIfSelectedUnit(playerID, unitID);
        end
    end);

    -- When a unit finishes moving
    -- update: natural wonder abilities
    Events.UnitMoveComplete.Add(function(playerID, unitID, iX, iY) UpdateIfSelectedUnit(playerID, unitID); end);

    -- When a unit is promoted
    -- update: promo tree
    Events.UnitPromoted.Add(function(playerID, unitID) UpdateIfSelectedUnit(playerID, unitID); end);  -- TODO: 是否有必要单独列出还是已被UnitCommandStarted涵盖

    -- When a unit is upgraded
    -- update: Icon_LysefjordPromotion
    -- When a unit is combined with another unit to form Corps, Fleet, Army, or Armada
    -- update: natural wonder abilities; Icon_LysefjordPromotion; exp modifier; promo tree
    Events.UnitCommandStarted.Add(function(playerID, unitID, hCommand, iData1) UpdateIfSelectedUnit(playerID, unitID); end);

    Controls.AbilityHighlightsPanelToggleButton:RegisterCallback(Mouse.eLClick, OnToggleAbilityHighlightsPanel);


    -- Initial Run
    local pUnit = UI.GetHeadSelectedUnit();
    if pUnit then
        UpdateAbilityHighlightsPanel(pUnit:GetOwner(), pUnit:GetID());
    end
end

-- ===========================================================================
-- Helper Function: UpdateIfSelectedUnit
-- This functions acts as a filter. It receives the ID of a unit that changed,
-- checks if it matches the unit the player currently has selected, and 
-- triggers the UI update if they match.
-- ===========================================================================
function UpdateIfSelectedUnit(playerID:number, unitID:number)
    local pSelectedUnit = UI.GetHeadSelectedUnit();

    if pSelectedUnit and (pSelectedUnit:GetOwner() == playerID) and (pSelectedUnit:GetID() == unitID) then
        UpdateAbilityHighlightsPanel(playerID, unitID);
    end
end


Events.LoadScreenClose.Add(Initialize);
