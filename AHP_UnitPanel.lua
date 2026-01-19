include("InstanceManager");

local LYSEFJORD_DUMMY_ABILITY_TYPE          :string = "ABILITY_AHP_LYSEFJORD_PROMOTION";  -- The game doesn't actually handle this through ability. This is a made-up name for generic implementation
local REQUIRE_UPDATE_NATURAL_WONDER_ABILITY :string = "UPDATE_NWA";
local REQUIRE_UPDATE_LYSEFJORD_ICON         :string = "UPDATE_LYSEFJORD";
local REQUIRE_UPDATE_PROMOTION_ICON         :string = "UPDATE_PROMOTION";
local REQUIRE_UPDATE_EXP_MODIFIER_ICON      :string = "UPDATE_EXP_MODIFIER";
local REQUIRE_UPDATE_ALL                    :table  = {
    [REQUIRE_UPDATE_NATURAL_WONDER_ABILITY] = true,
    [REQUIRE_UPDATE_LYSEFJORD_ICON]         = true,
    [REQUIRE_UPDATE_PROMOTION_ICON]         = true,
    [REQUIRE_UPDATE_EXP_MODIFIER_ICON]      = true
};

local LYSEFJORD_MODIFIER_ID         :string = "LYSEFJORDEN_GRANT_NAVAL_UNIT_EXPERIENCE";  -- This is an official modifier
local PROMO_ICON_CONTAINER_WIDTH    :number = 36;
local HALF_PROMO_ICON_SIZE          :number = 18 / 2;
local NATURAL_WONDER_ABILITY_CONFIG :table  = {
    -- UnitAbilityType             = { FeatureType = FeatureType,                 ControlID = IconIDInXML }

    -- Land military units
    ABILITY_ALPINE_TRAINING        = { FeatureType = "FEATURE_MATTERHORN",        ControlID = "Icon_AlpineTraining" },
    ABILITY_SPEAR_OF_FIONN         = { FeatureType = "FEATURE_GIANTS_CAUSEWAY",   ControlID = "Icon_SpearOfFionn" },
    ABILITY_WATER_OF_LIFE          = { FeatureType = "FEATURE_FOUNTAIN_OF_YOUTH", ControlID = "Icon_WaterOfLife" },
    -- Naval military units
    ABILITY_MYSTERIOUS_CURRENTS    = { FeatureType = "FEATURE_BERMUDA_TRIANGLE",  ControlID = "Icon_MysteriousCurrents" },
    [LYSEFJORD_DUMMY_ABILITY_TYPE] = { FeatureType = "FEATURE_LYSEFJORDEN",       ControlID = "Icon_LysefjordPromotion" },
    -- Religious units
    ABILITY_ALTITUDE_TRAINING      = { FeatureType = "FEATURE_EVEREST",           ControlID = "Icon_AltitudeTraining" }
};
local EXP_MODIFIER_BUILDINGS        :table = {
    BARRACKS         = "BUILDING_BARRACKS",
    STABLE           = "BUILDING_STABLE",
    ARMORY           = "BUILDING_ARMORY",
    MILITARY_ACADEMY = "BUILDING_MILITARY_ACADEMY",
    LIGHTHOUSE       = "BUILDING_LIGHTHOUSE",
    SHIPYARD         = "BUILDING_SHIPYARD",
    SEAPORT          = "BUILDING_SEAPORT",
    HANGAR           = "BUILDING_HANGAR",
    AIRPORT          = "BUILDING_AIRPORT"
};
local ALL_EXP_MODIFIERS_AND_DESC    :table = {};  -- `{EXP_MODIFIER = DESCRIPTION}`. Populated in `Initialize()`.

local m_PromotionIconIM   = InstanceManager:new("PromotionIconInstance",   "PromotionIconRootControl",   Controls.PromotionIconContainer);
local m_PrereqLineIM      = InstanceManager:new("PrereqLineInstance",      "PrereqLineRootControl",      Controls.PromotionIconContainer);
local m_ExpModifierIconIM = InstanceManager:new("ExpModifierIconInstance", "ExpModifierIconRootControl", Controls.ExpModifierStack);

-- Arguments passed to `playerID`, `unitID`, and `pUnit` are guaranteed to not be `nil` 
function UpdateAbilityHighlightsPanel(playerID:number, unitID:number, pUnit, updateOptions:table)
    local unitDef:table = GameInfo.Units[pUnit:GetType()];
    if unitDef and IsValidForAbilityHighlightsPanelDisplay(unitDef.FormationClass, unitDef.ReligiousStrength) then
        Controls.AHP_Root:SetHide(false);
        local dataAbility:table   = pUnit:GetAbility():GetAbilities();
        local dataPromotion:table = pUnit:GetExperience():GetPromotions();
        if updateOptions[REQUIRE_UPDATE_NATURAL_WONDER_ABILITY] then UpdateNaturalWonderAbilityIcons(dataAbility); end
        if updateOptions[REQUIRE_UPDATE_LYSEFJORD_ICON]         then UpdateLysefjordPromotionIcon(playerID, unitID); end
        if updateOptions[REQUIRE_UPDATE_PROMOTION_ICON]         then UpdatePromotionIcons(unitDef.PromotionClass, dataPromotion); end
        if updateOptions[REQUIRE_UPDATE_EXP_MODIFIER_ICON]      then UpdateExpModifiers(unitDef, dataAbility); end
    else
        Controls.AHP_Root:SetHide(true);
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
-- Check which natural wonder abilities have the selected unit earned and
-- display the corresponding icons
-- `dataAbility` is an array of integers (Gemini)
-- ===========================================================================
function UpdateNaturalWonderAbilityIcons(dataAbility:table)
    local hasTheseNaturalWonderAbilities:table = {};  -- an array of `UnitAbilityType`

    -- Iterate through the unit's abilities and record the natural wonder
    -- abilities among them
    if dataAbility then
        for _, abilityIndex in ipairs(dataAbility) do
            local abilityDef:table = GameInfo.UnitAbilities[abilityIndex];

            if abilityDef then
                local unitAbilityType:string = abilityDef.UnitAbilityType;
                if NATURAL_WONDER_ABILITY_CONFIG[unitAbilityType] then
                    -- this is a natural wonder ability!
                    hasTheseNaturalWonderAbilities[unitAbilityType] = true;
                end
            end
        end
    end

    -- Reveal or hide icons based on availability
    for unitAbilityType, config in pairs(NATURAL_WONDER_ABILITY_CONFIG) do
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
    local iconControl = Controls[NATURAL_WONDER_ABILITY_CONFIG[LYSEFJORD_DUMMY_ABILITY_TYPE].ControlID];

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
    m_PrereqLineIM:ResetInstances();

    -- Table for O(1) lookup
    local hasThesePromotions:table = {};  -- UnitPromotionType: true
    for _, id in ipairs(dataPromotion) do
        hasThesePromotions[GameInfo.UnitPromotions[id].UnitPromotionType] = true;
    end

    local instanceLocation:table = {};
    local iconRenderQueue:table = {};

    -- Calculate attributes for promotion icons
    for row in GameInfo.UnitPromotions() do
        if row.PromotionClass == promotionClass and row.Column ~= 0 then
            local horizontalAnchor:string = "";
            local centerX         :number = 0;
            local offsetY         :number = (row.Level-1)*18-3;
            local centerY         :number = offsetY + HALF_PROMO_ICON_SIZE;
            if     row.Column == 1 then
                horizontalAnchor = "L";
                centerX = HALF_PROMO_ICON_SIZE;
            elseif row.Column == 2 then
                horizontalAnchor = "C";
                centerX = PROMO_ICON_CONTAINER_WIDTH / 2;
            elseif row.Column == 3 then
                horizontalAnchor = "R";
                centerX = PROMO_ICON_CONTAINER_WIDTH - HALF_PROMO_ICON_SIZE;
            end
            local textureOffsetY:number = 0;
            local unearnedHint:string = "";
            if hasThesePromotions[row.UnitPromotionType] then
                textureOffsetY = 108;
            else
                textureOffsetY = 36;
                unearnedHint = " [COLOR:Red](" .. Locale.Lookup("LOC_AHP_UNEARNED") .. ")[ENDCOLOR]";
            end

            instanceLocation[row.UnitPromotionType] = {X = centerX, Y = centerY};

            table.insert(iconRenderQueue, {
                Anchor = horizontalAnchor .. ",T",
                OffsetX = 0,
                OffsetY = offsetY,
                TextureOffsetX = 0,
                TextureOffsetY = textureOffsetY,
                ToolTipString = Locale.Lookup(row.Name) .. unearnedHint .. "[NEWLINE]" .. Locale.Lookup(row.Description)
            });
        end
    end

    -- Draw line segments (Prereqs)
    for row in GameInfo.UnitPromotionPrereqs() do
        if instanceLocation[row.UnitPromotion] then
            local prereqPromoLocation:table  = instanceLocation[row.PrereqUnitPromotion];
            local targetPromoLocation:table  = instanceLocation[row.UnitPromotion];
            local lineColor          :number = 0;
            if hasThesePromotions[row.PrereqUnitPromotion] and hasThesePromotions[row.UnitPromotion] then
                lineColor = 0xFF68C0E7;
            else
                lineColor = 0xFF888888;
            end

            local lineInstanceRootControl = m_PrereqLineIM:GetInstance().PrereqLineRootControl;
            lineInstanceRootControl:SetStartVal(prereqPromoLocation.X, prereqPromoLocation.Y);
            lineInstanceRootControl:SetEndVal(targetPromoLocation.X, targetPromoLocation.Y);
            lineInstanceRootControl:SetColor(lineColor);
        end
    end

    -- Draw nodes (Promotions)
    -- Note: In order to render icons on top of the prereq lines, do NOT combine this loop with the calculation loop
    for _, iconData in ipairs(iconRenderQueue) do
        local promotionIconInstanceRootControl = m_PromotionIconIM:GetInstance().PromotionIconRootControl;
        promotionIconInstanceRootControl:SetAnchor(iconData.Anchor);
        promotionIconInstanceRootControl:SetOffsetVal(iconData.OffsetX, iconData.OffsetY);
        promotionIconInstanceRootControl:SetTextureOffsetVal(iconData.TextureOffsetX, iconData.TextureOffsetY);
        promotionIconInstanceRootControl:SetToolTipString(iconData.ToolTipString);
    end
end

function UpdateExpModifiers(unitDef:table, dataAbility:table)
    m_ExpModifierIconIM:ResetInstances();

    local unitType      :string = unitDef.UnitType;
    local formationClass:string = unitDef.FormationClass;
    local promotionClass:string = unitDef.PromotionClass;


    if promotionClass == "PROMOTION_CLASS_RECON" or
       promotionClass == "PROMOTION_CLASS_GIANT_DEATH_ROBOT" then
        Controls.ExpModifierStack:CalculateSize();
        return;
    end

    local relevantBuildings:table = {};
    if formationClass == "FORMATION_CLASS_LAND_COMBAT" then
        if unitType == "UNIT_MACEDONIAN_HETAIROI" then
            table.insert(relevantBuildings, "BARRACKS");
            table.insert(relevantBuildings, "STABLE");
        elseif promotionClass == "PROMOTION_CLASS_MELEE" or
               promotionClass == "PROMOTION_CLASS_RANGED" or
               promotionClass == "PROMOTION_CLASS_ANTI_CAVALRY" then
            table.insert(relevantBuildings, "BARRACKS");
        elseif promotionClass == "PROMOTION_CLASS_LIGHT_CAVALRY" or
               promotionClass == "PROMOTION_CLASS_HEAVY_CAVALRY" or
               promotionClass == "PROMOTION_CLASS_SIEGE" then
            table.insert(relevantBuildings, "STABLE");
        end
        table.insert(relevantBuildings, "ARMORY");
        table.insert(relevantBuildings, "MILITARY_ACADEMY");
    elseif formationClass == "FORMATION_CLASS_NAVAL" then
        table.insert(relevantBuildings, "LIGHTHOUSE");
        table.insert(relevantBuildings, "SHIPYARD");
        table.insert(relevantBuildings, "SEAPORT");
    elseif formationClass == "FORMATION_CLASS_AIR" then
        table.insert(relevantBuildings, "HANGAR");
        table.insert(relevantBuildings, "AIRPORT");
    end

    local hasTheseExpModifiers:table = {};
    if next(relevantBuildings) and dataAbility then
    -- ^^^
    -- no way that the unit has exp modifiers if there are no relevant buildings
        for _, abilityIndex in ipairs(dataAbility) do
            local abilityDef:table = GameInfo.UnitAbilities[abilityIndex];
            if abilityDef then
                local unitAbilityType:string = abilityDef.UnitAbilityType;
                if ALL_EXP_MODIFIERS_AND_DESC[unitAbilityType] then
                    hasTheseExpModifiers[unitAbilityType] = true;
                end
            end
        end
    end

    for _, building in ipairs(relevantBuildings) do
        local expModifier:string = GameInfo.AbilityHighlightsPanel_ExperienceModifiers[EXP_MODIFIER_BUILDINGS[building]].UnitAbilityType;
        local labelColor :number = 0;
        if hasTheseExpModifiers[expModifier] then
            labelColor = 0xFF68C0E7;
        else
            labelColor = 0xFF888888;
        end

        local expModifierIconInstance = m_ExpModifierIconIM:GetInstance();
        expModifierIconInstance.ExpModifierIconRootControl:SetToolTipString(Locale.Lookup(ALL_EXP_MODIFIERS_AND_DESC[expModifier]));
        expModifierIconInstance.Left:SetColor(labelColor);
        expModifierIconInstance.Right:SetColor(labelColor);
    end

    Controls.ExpModifierStack:CalculateSize();
end

-- ===========================================================================
-- Generate the tooltip for each ability icon in player's game language
-- ===========================================================================
function InitAbilityTooltips()
    for unitAbilityType, config in pairs(NATURAL_WONDER_ABILITY_CONFIG) do
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

function SwapPlayerSpecificExpModifierBuildings()
    local playerID  :number = Game.GetLocalPlayer();
    local pPlayerConfig     = PlayerConfigurations[playerID];
    local civType   :string = pPlayerConfig:GetCivilizationTypeName();
    local leaderType:string = pPlayerConfig:GetLeaderTypeName();

    for building, buildingType in pairs(EXP_MODIFIER_BUILDINGS) do
        for row in GameInfo.BuildingReplaces() do
            if row.ReplacesBuildingType == buildingType then
                local uniqueBuildingType:string = row.CivUniqueBuildingType;
                local uniqueBuildingDef :table  = GameInfo.Buildings[uniqueBuildingType];
                if uniqueBuildingDef and HasTrait(uniqueBuildingDef.TraitType, civType, leaderType) then
                    EXP_MODIFIER_BUILDINGS[building] = uniqueBuildingType;
                end
            end
        end
    end
end

function HasTrait(traitType:string, civType:string, leaderType:string)
    if traitType then
        for row in GameInfo.CivilizationTraits() do
            if row.TraitType == traitType and row.CivilizationType == civType then
                return true;
            end
        end
        for row in GameInfo.LeaderTraits() do
            if row.TraitType == traitType and row.LeaderType == leaderType then
                return true;
            end
        end
    end
    return false
end

function PopulateAllPossibleExpModifiers()
    for row in GameInfo.AbilityHighlightsPanel_ExperienceModifiers() do
        local unitAbilityType:string = row.UnitAbilityType;
        ALL_EXP_MODIFIERS_AND_DESC[unitAbilityType] = GameInfo.UnitAbilities[unitAbilityType].Description;
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
    SwapPlayerSpecificExpModifierBuildings();
    PopulateAllPossibleExpModifiers();

    -- When a unit is selected
    -- update: natural wonder abilities; Icon_LysefjordPromotion; exp modifier; promo tree
    Events.UnitSelectionChanged.Add(function(playerID, unitID, locationX, locationY, locationZ, isSelected, isEditable)
        if isSelected then
            UpdateIfSelectedUnit(playerID, unitID, REQUIRE_UPDATE_ALL);
        end
    end);

    -- When a unit finishes moving
    -- update: natural wonder abilities; Icon_LysefjordPromotion;
    Events.UnitMoveComplete.Add(function(playerID, unitID, iX, iY)
        UpdateIfSelectedUnit(playerID, unitID, { [REQUIRE_UPDATE_NATURAL_WONDER_ABILITY] = true, [REQUIRE_UPDATE_LYSEFJORD_ICON] = true });
    end);

    -- When a unit is promoted
    -- update: promo tree
    Events.UnitPromoted.Add(function(playerID, unitID)
        UpdateIfSelectedUnit(playerID, unitID, { [REQUIRE_UPDATE_PROMOTION_ICON] = true });
    end);

    -- When a unit is upgraded
    -- update: Icon_LysefjordPromotion
    -- When a unit is combined with another unit to form Corps, Fleet, Army, or Armada
    -- update: natural wonder abilities; Icon_LysefjordPromotion; exp modifier; promo tree
    Events.UnitCommandStarted.Add(function(playerID, unitID, hCommand, iData1)
        UpdateIfSelectedUnit(playerID, unitID, REQUIRE_UPDATE_ALL);
    end);

    Controls.AbilityHighlightsPanelToggleButton:RegisterCallback(Mouse.eLClick, OnToggleAbilityHighlightsPanel);


    -- Initial Run
    local pUnit = UI.GetHeadSelectedUnit();
    if pUnit then
        UpdateAbilityHighlightsPanel(pUnit:GetOwner(), pUnit:GetID(), pUnit, REQUIRE_UPDATE_ALL);
    end
end

-- ===========================================================================
-- Helper Function: UpdateIfSelectedUnit
-- This functions acts as a filter. It receives the ID of a unit that changed,
-- checks if it matches the unit the player currently has selected, and 
-- triggers the UI update if they match.
-- ===========================================================================
function UpdateIfSelectedUnit(playerID:number, unitID:number, updateOptions:table)
    local pUnit = UI.GetHeadSelectedUnit();
    if pUnit and (pUnit:GetOwner() == playerID) and (pUnit:GetID() == unitID) then
        UpdateAbilityHighlightsPanel(playerID, unitID, pUnit, updateOptions);
    end
end


Events.LoadScreenClose.Add(Initialize);
