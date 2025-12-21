local LYSEFJORD_MODIFIER_ID         :string = "LYSEFJORDEN_GRANT_NAVAL_UNIT_EXPERIENCE";
local LYSEFJORD_DUMMY_ABILITY_TYPE  :string = "ABILITY_UAH_LYSEFJORD_PROMOTION";  -- The game doesn't actually handle this through ability. This is a made-up name for generic implementation

local m_Controls:table = {};  -- Initialize empty table to store found controls
local m_WonderAbilitiesConfig = {
    -- UnitAbilityType =             { FeatureType = FeatTypeOfGrantingWonder,    ControlID = IconIDInXML }

    -- Land military units
    ABILITY_ALPINE_TRAINING =        { FeatureType = "FEATURE_MATTERHORN",        ControlID = "Icon_AlpineTraining" },
    ABILITY_SPEAR_OF_FIONN =         { FeatureType = "FEATURE_GIANTS_CAUSEWAY",   ControlID = "Icon_SpearOfFionn" },
    ABILITY_WATER_OF_LIFE =          { FeatureType = "FEATURE_FOUNTAIN_OF_YOUTH", ControlID = "Icon_WaterOfLife" },
    -- Naval military units
    ABILITY_MYSTERIOUS_CURRENTS =    { FeatureType = "FEATURE_BERMUDA_TRIANGLE",  ControlID = "Icon_MysteriousCurrents" },
    [LYSEFJORD_DUMMY_ABILITY_TYPE] = { FeatureType = "FEATURE_LYSEFJORDEN",       ControlID = "Icon_LysefjordPromotion" },
    -- Religious units
    ABILITY_ALTITUDE_TRAINING =      { FeatureType = "FEATURE_EVEREST",           ControlID = "Icon_AltitudeTraining" }
};

-- ===========================================================================
-- Generate the tooltip for each ability icon in player's game language
-- ===========================================================================
function InitAbilityTooltips()
    for unitAbilityType, config in pairs(m_WonderAbilitiesConfig) do
        local abilityDef = GameInfo.UnitAbilities[unitAbilityType];
        local featureDef = GameInfo.Features[config.FeatureType];

        if abilityDef and featureDef then
            local name  :string = Locale.Lookup(abilityDef.Name);
            local source:string = Locale.Lookup(featureDef.Name);
            local desc  :string = Locale.Lookup(abilityDef.Description);

            config.Tooltip = name .. " (" .. source .. ")[NEWLINE]" .. desc;
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
function UpdateWonderAbilityIcons()
    if not m_Controls["UAH_Root"] then
        return
    end

    local pUnit = UI.GetHeadSelectedUnit();
    if pUnit == nil then
        m_Controls["UAH_Root"]:SetHide(true);
        return;
    end

    local formationClass:string = GameInfo.Units[pUnit:GetUnitType()].FormationClass;
    if formationClass ~= "FORMATION_CLASS_LAND_COMBAT" and
       formationClass ~= "FORMATION_CLASS_NAVAL" and
       formationClass ~= "FORMATION_CLASS_AIR" then
        m_Controls["UAH_Root"]:SetHide(true);
        return
    end

    m_Controls.AHP_Root:SetHide(false);

    local dataAbility:table = pUnit:GetAbility():GetAbilities();  -- an array of integers (Gemini)
    local ownerID    :number = pUnit:GetOwner();
    local unitID     :number= pUnit:GetID();

    local hasTheseNaturalWonderAbilities:table = {};  -- an array of `UnitAbilityType`

    -- Iterate through the unit's abilities and record the natural wonder
    -- abilities among them
    if dataAbility then
        for _, abilityIndex in ipairs(dataAbility) do
            local abilityDef = GameInfo.UnitAbilities[abilityIndex];

            if abilityDef and abilityDef.UnitAbilityType and m_WonderAbilitiesConfig[abilityDef.UnitAbilityType] then
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
    for unitAbilityType, config in pairs(m_WonderAbilitiesConfig) do
        local control:string = m_Controls[config.ControlID];
        if hasTheseNaturalWonderAbilities[unitAbilityType] then
            control:SetHide(false);
            control:SetToolTipString(config.Tooltip);  -- setting every time for robustness
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
    local isHidden:boolean = m_Controls["UAH_Panel"]:IsHidden();
    if isHidden then
        m_Controls["UAH_Panel"]:SetHide(false);
        m_Controls["UAH_PanelToggleButton"]:SetTextureOffsetVal(0,22);
        m_Controls["UAH_PanelToggleButton"]:SetToolTipString("Collapse ability summary panel.");
    else
        m_Controls["UAH_Panel"]:SetHide(true);
        m_Controls["UAH_PanelToggleButton"]:SetTextureOffsetVal(0,0);
        m_Controls["UAH_PanelToggleButton"]:SetToolTipString("Expand ability summary panel.");
    end
end

-- ===========================================================================
-- Initialization
-- ===========================================================================
function Initialize()
    local rootPath:string = "/InGame/UnitPanel/UnitPanelAlpha/UnitPanelSlide/UnitPanelBaseContainer/UnitIcon/UAH_Root";
    m_Controls["UAH_Root"]              = ContextPtr:LookUpControl(rootPath);
    m_Controls["UAH_Panel"]             = ContextPtr:LookUpControl(rootPath .. "/UAH_Panel");
    m_Controls["UAH_PanelToggleButton"] = ContextPtr:LookUpControl(rootPath .. "/UAH_PanelToggleButton");
    local stackPath:string = rootPath .. "/UAH_Panel/WonderAbilityStack";
    for _, config in pairs(m_WonderAbilitiesConfig) do
        local controlID:string = config.ControlID;
        m_Controls[controlID] = ContextPtr:LookUpControl(stackPath .. "/" .. controlID);
    end

    if m_Controls["UAH_Root"] then
        InitAbilityTooltips();
        m_Controls["UAH_PanelToggleButton"]:RegisterCallback( Mouse.eLClick, onToggleAbilityHighlightsPanel );

        Events.UnitSelectionChanged.Add( UpdateWonderAbilityIcons );
    end
end


Events.LoadScreenClose.Add(Initialize);
