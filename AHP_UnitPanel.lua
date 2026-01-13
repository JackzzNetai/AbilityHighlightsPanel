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

-- ===========================================================================
-- Generate the tooltip for each ability icon in player's game language
-- ===========================================================================
function InitAbilityTooltips()
    for unitAbilityType, config in pairs(m_NaturalWonderAbilitiesConfig) do
        local abilityDef = GameInfo.UnitAbilities[unitAbilityType];
        local featureDef = GameInfo.Features[config.FeatureType];

        if abilityDef and featureDef then
            local name  :string = Locale.Lookup(abilityDef.Name);
            local source:string = Locale.Lookup(featureDef.Name);
            local desc  :string = Locale.Lookup(abilityDef.Description);

            Controls[config.ControlID]:SetToolTipString(name .. " (" .. source .. ")[NEWLINE]" .. desc);
        end
    end
end

-- ===========================================================================
-- Helper function to check whether the given unit has acquired the free
-- promotion from Lysefjord.
-- Note: the game treats the promotion gained from Lysefjord differently from
-- other natural wonder abilities. A "detour" is needed to retrieve that info.
-- ===========================================================================
function hasAcquiredLysefjordPromotion(ownerID, givenUnitID)
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
                    if GameEffects.GetObjectsPlayerId(subjectID) == ownerID then
                        -- Found an object that belongs to the player

                        -- Check if the found unit is the given unit
                        local subjectStr = GameEffects.GetObjectString(subjectID);
                        local foundUnitID = tonumber(string.match(subjectStr, "Unit: (%d+)"));

                        if foundUnitID == givenUnitID then
                            return true; 
                        end
                    end
                end
            end
        end
    end

    return false
end

-- ===========================================================================
-- Main update logic: check which natural wonder abilities have the selected
-- unit acquired and display the corresponding icons
-- ===========================================================================
function UpdateNaturalWonderAbilityIcons()
    local pUnit = UI.GetHeadSelectedUnit();
    if pUnit == nil then
        Controls.AHP_Root:SetHide(true);
        return;
    end

    Controls.AHP_Root:SetHide(false);

    local dataAbility:table  = pUnit:GetAbility():GetAbilities();  -- an array of integers (Gemini)
    local ownerID    :number = pUnit:GetOwner();
    local unitID     :number = pUnit:GetID();

    local hasTheseNaturalWonderAbilities:table = {};  -- an array of `UnitAbilityType`

    -- Iterate through the unit's abilities and record the natural wonder
    -- abilities among them
    if dataAbility then
        for _, abilityIndex in ipairs(dataAbility) do
            local abilityDef = GameInfo.UnitAbilities[abilityIndex];

            if abilityDef and abilityDef.UnitAbilityType and m_NaturalWonderAbilitiesConfig[abilityDef.UnitAbilityType] then
                -- this is a natural wonder ability!
                hasTheseNaturalWonderAbilities[abilityDef.UnitAbilityType] = true;
            end
        end
    end

    -- Special care to the promotion gained from Lysefjord
    if hasAcquiredLysefjordPromotion(ownerID, unitID) then
        hasTheseNaturalWonderAbilities[LYSEFJORD_DUMMY_ABILITY_TYPE] = true;
    end

    -- Reveal or hide icons based on availability
    for unitAbilityType, config in pairs(m_NaturalWonderAbilitiesConfig) do
        local control = Controls[config.ControlID];
        if hasTheseNaturalWonderAbilities[unitAbilityType] then
            control:SetHide(false);
        else
            control:SetHide(true);
            -- TODO: (future) maybe show silhouette for acquirable abilities that are not gained yet
        end
    end
end

-- ===========================================================================
-- UI handlers
-- ===========================================================================
function onToggleAbilityHighlightsPanel()
    local isHidden:boolean = Controls.AbilityHighlightsPanel:IsHidden();
    if isHidden then
        Controls.AbilityHighlightsPanel:SetHide(false);
        Controls.AbilityHighlightsPanelToggleButton:SetTextureOffsetVal(0,22);
        Controls.AbilityHighlightsPanelToggleButton:SetToolTipString("Collapse ability summary panel.");
    else
        Controls.AbilityHighlightsPanel:SetHide(true);
        Controls.AbilityHighlightsPanelToggleButton:SetTextureOffsetVal(0,0);
        Controls.AbilityHighlightsPanelToggleButton:SetToolTipString("Expand ability summary panel.");
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
    Controls.AbilityHighlightsPanelToggleButton:RegisterCallback( Mouse.eLClick, onToggleAbilityHighlightsPanel );
end


Events.LoadScreenClose.Add( Initialize );
Events.UnitSelectionChanged.Add( UpdateNaturalWonderAbilityIcons );
Events.UnitPromoted.Add( UpdateNaturalWonderAbilityIcons );