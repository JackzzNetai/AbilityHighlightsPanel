local m_NaturalWonderPlots = {}; -- Stores {x, y} for every NW tile

-- Run this ONCE during Initialize()
function CacheNaturalWonders()
    local mapWidth, mapHeight = Map.GetGridSize();
    
    for iPlotIndex = 0, (mapWidth * mapHeight) - 1 do
        local pPlot = Map.GetPlotByIndex(iPlotIndex);
        local featureType = pPlot:GetFeatureType();

        if featureType ~= -1 then
            local featureInfo = GameInfo.Features[featureType];
            -- Check if this feature is a Natural Wonder
            if featureInfo and featureInfo.NaturalWonder then
                -- Store the plot index or coordinates
                table.insert(m_NaturalWonderPlots, {
                    Index = iPlotIndex,
                    FeatureType = featureInfo.FeatureType,
                    Name = featureInfo.Name -- "LOC_FEATURE_EVEREST_NAME"
                });
            end
        end
    end
end

function GetDiscoveredWonders(playerID)
    local pPlayerVisibility = Players[playerID]:GetVisibility();
    local discoveredWonders = {}; -- Key: FeatureType, Value: true

    for _, nwData in ipairs(m_NaturalWonderPlots) do
        -- Check if this specific tile is revealed to the player
        if pPlayerVisibility:IsRevealed(nwData.Index) then
            discoveredWonders[nwData.FeatureType] = true;
        end
    end

    return discoveredWonders;
end

function Initialize()
    CacheNaturalWonders(); -- Build the list of where things are
    
    -- Example usage:
    local playerID = Game.GetLocalPlayer();
    local knownWonders = GetDiscoveredWonders(playerID);

    if knownWonders["FEATURE_EVEREST"] then
        print("This player has found Mt. Everest!");
    end
end

                <Image ID="Icon_AlpineTraining"     Size="16,16" Icon="ICON_UNITOPERATION_RETRAIN"      IconSize="16" Hidden="1" />
                <Image ID="Icon_SpearOfFionn"       Size="16,16" Icon="ICON_UNIT_MACEDONIAN_HETAIROI"   IconSize="16" Hidden="1" />
                <Image ID="Icon_WaterOfLife"        Size="16,16" Icon="ICON_UNITOPERATION_HEAL"         IconSize="16" Hidden="1" />
                <Image ID="Icon_MysteriousCurrents" Size="16,16" Icon="ICON_UNITOPERATION_MOVE_TO"      IconSize="16" Hidden="1" />
                <Image ID="Icon_LysefjordPromotion" Size="16,16" Icon="ICON_UNITCOMMAND_PROMOTE"        IconSize="16" Hidden="1" />
                <Image ID="Icon_AltitudeTraining"   Size="16,16" Icon="ICON_UNITOPERATION_RETRAIN"      IconSize="16" Hidden="1" />