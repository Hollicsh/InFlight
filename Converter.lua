



-- Sort mixed keys (numbers and strings).
local function SortKeys(tableToSort)

  local sortedKeys = {}
  for k, _ in pairs(tableToSort) do
    table.insert(sortedKeys, k)
  end
  table.sort(sortedKeys, function(a, b)
    local typeA = type(a)
    local typeB = type(b)

    if typeA == "number" and typeB ~= "number" then
      return true  -- Numbers come before strings
    elseif typeA ~= "number" and typeB == "number" then
      return false -- Strings come after numbers
    elseif typeA == "number" and typeB == "number" then
      return a < b -- Sort numbers numerically
    else -- Both are strings
      return tostring(a) < tostring(b) -- Sort strings lexicographically
    end
  end)

  return sortedKeys
end







local scrollBoxWidth = 600
local scrollBoxHeight = 500

local outerFrame = CreateFrame("Frame")
outerFrame:SetSize(scrollBoxWidth + 80, scrollBoxHeight + 20)

local borderFrame = CreateFrame("Frame", nil, outerFrame, "TooltipBackdropTemplate")
borderFrame:SetSize(scrollBoxWidth + 34, scrollBoxHeight + 10)
borderFrame:SetPoint("CENTER")

local scrollFrame = CreateFrame("ScrollFrame", nil, outerFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("CENTER", -10, 0)
scrollFrame:SetSize(scrollBoxWidth, scrollBoxHeight)


local editbox = CreateFrame("EditBox", nil, scrollFrame, "InputBoxScriptTemplate")
editbox:SetMultiLine(true)
editbox:SetAutoFocus(false)
editbox:SetFontObject(ChatFontNormal)
editbox:SetWidth(scrollBoxWidth)
scrollFrame:SetScrollChild(editbox)




local popupName = "INFLIGHT_EXPORT"
StaticPopupDialogs[popupName] = {
    text = "Copy this to clipboard\n(CTRL-C)",
    button1 = "Dismiss",
    button2 = "Select All",
    OnCancel =
      function(_, data)
        editbox:HighlightText()
        editbox:SetFocus()
        -- Prevent from hiding!
        return true
      end,

    OnShow =
      function()
        editbox:HighlightText()
        editbox:SetFocus()
      end,
}











-- ##############################################################
-- ########## Convert names (InFlight Classic) to IDs. ##########
-- ##############################################################

-- Function used by InFlight.
local function ShortenName(name)
	return gsub(name, ", .+", "")
end




function GetNameToId()

  local nameToId = {}

  -- Go through all map IDs.
  for uiMapID = 1, 2500 do

    local mapInfo = C_Map.GetMapInfo(uiMapID)

    -- If this is a map.
    if mapInfo and mapInfo.mapID and mapInfo.mapID == uiMapID then

      -- Get all taxi nodes.
      local taxiNodes = C_TaxiMap.GetTaxiNodesForMap(mapInfo.mapID)
      if taxiNodes and #taxiNodes > 0 then

        -- print(mapInfo.mapID, mapInfo.name, #taxiNodes)

        -- Go through all nodes.
        for _, v in pairs(taxiNodes) do

          -- InFlight Classic used short names.
          local shortName = ShortenName(v.name)

          -- print("    ", v.nodeID, shortName, v.name, mapInfo.name)

          -- We already have an entry.
          if nameToId[shortName] then


            -- We already have at least two entries.
            if type(nameToId[shortName]) == "table" then

              -- Check if this ID is already there.
              local alreadyInTable = nil
              for _, v2 in pairs(nameToId[shortName]) do
                if v2 == v.nodeID then
                  alreadyInTable = true
                  break
                end
              end

              if not alreadyInTable then
                tinsert(nameToId[shortName], v.nodeID)
                -- print("!!!!", v.nodeID, shortName, "has more than two IDs")
              end

            -- We already have one entry.
            else

              if nameToId[shortName] ~= v.nodeID then
                nameToId[shortName] = {nameToId[shortName], v.nodeID}
                -- print("----", v.nodeID, shortName, "has more than one ID")
              end

            end

          -- We have no entry yet.
          else

            nameToId[shortName] = v.nodeID

          end

        end   -- Go through all nodes.

      end

    end

  end  -- Go through all map IDs.

  return nameToId
end





local function NodeNameToId(name, faction, nameToId)

  -- To check if the node of that name has the same ID in retail.
  local referenceTable = InFlight.defaults.global


  if not nameToId[name] then
    print("!!!!!!!!!!!!!!!!!!", name, faction, "has no ID")
    return -1
  end


  if type(nameToId[name]) == "table" then

    -- Check in retail nodes.
    for sourceNodeId, data in pairs(referenceTable[faction]) do

      if data.name and data.name == name then

        -- Check if we got the same ID in nameToId.
        for _, v in pairs(nameToId[name]) do
          if sourceNodeId == v then
            -- print("+++++++++ Identified", name, faction, "to be", sourceNodeId)
            return sourceNodeId
          end
        end

        print("!!!!!!!!!!!!!!!!!!", name, faction, "has no ID")
        return -2

      end

    end

    -- print("!!!!!!!!!!!!!!!!!!", name, faction, "has no ID. Got to fall back to names as keys.")
    return -3

  else

    return nameToId[name]

  end

end





-- Convert table of nodes with node names to a table of nodes with node IDs,
-- as given by the nameToId table.
local function ReplaceNodeNamesWithIDs(nodesWithNames, nameToId)

  local nodesWithIDs = {}
  nodesWithIDs["Alliance"] = {}
  nodesWithIDs["Horde"] = {}

  for faction, factionNodes in pairs(nodesWithNames) do

    for sourceNodeName, destNodes in pairs(factionNodes) do

      local sourceNodeId = NodeNameToId(sourceNodeName, faction, nameToId)
      if sourceNodeId == -3 then
        sourceNodeId = sourceNodeName
      end

      -- print(sourceNodeName, "to", sourceNodeId)

      nodesWithIDs[faction][sourceNodeId] = {}
      nodesWithIDs[faction][sourceNodeId]["name"] = sourceNodeName

      for destNodeName, flightTime in pairs(destNodes) do

        local destNodeId = NodeNameToId(destNodeName, faction, nameToId)
        if sourceNodeId == sourceNodeName then
          destNodeId = destNodeName
        end

        nodesWithIDs[faction][sourceNodeId][destNodeId] = flightTime

      end

    end

  end

  return nodesWithIDs
end





-- Print taxi nodes variable in a sorted manner.
local function GetExportText(variableName, taxiNodes)

  local exportText = variableName .. " = {\n"

  for faction, factionNodes in pairs(taxiNodes) do

    exportText = exportText .. "  [\"" .. faction .. "\"] = {\n"

    -- Sort keys.
    local sortedSourceKeys = SortKeys(factionNodes)
    for _, sourceNodeId in pairs(sortedSourceKeys) do
      local destNodes = factionNodes[sourceNodeId]

      if type(sourceNodeId) ~= "number" then
        exportText = exportText .. "    [\"" .. sourceNodeId .. "\"] = {   -- Flightpath started by gossip option.\n"
      else
        exportText = exportText .. "    [" .. sourceNodeId .. "] = {\n"
        exportText = exportText .. "      [\"name\"] = \"" .. destNodes["name"] .. "\",\n"
      end


      -- Sort keys.
      local sortedDestKeys = SortKeys(destNodes)
      for _, destNodeId in pairs(sortedDestKeys) do

        local flightTime = destNodes[destNodeId]

        if destNodeId ~= "name" then
          if type(destNodeId) == "number" then
            exportText = exportText .. "      [" .. destNodeId .. "] = " .. flightTime .. ",\n"
          else
            exportText = exportText .. "      [\"" .. destNodeId .. "\"] = " .. flightTime .. ",\n"
          end
        end

      end
      exportText = exportText .. "    },\n"
    end
    exportText = exportText .. "  },\n"
  end
  exportText = exportText .. "}\n"

  return exportText
end





-- Use data from Defaults.lua of InFlight_Classic_Era-1.15.002.
-- Delete "Revantusk", which seemed to be a duplicated of "Revantusk Village".
-- local oldClassicNodes = {
-- ...

-- local nameToId = GetNameToId()
-- local newClassicNodes = ReplaceNodeNamesWithIDs(oldClassicNodes, nameToId)
-- local exportText = GetExportText("global_classic", newClassicNodes)
-- editbox:SetText(exportText)
-- StaticPopup_Show(popupName, nil, nil, nil, outerFrame)



local exportText = GetExportText("global", InFlight.defaults.global)
editbox:SetText(exportText)
StaticPopup_Show(popupName, nil, nil, nil, outerFrame)