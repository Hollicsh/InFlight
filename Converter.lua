local folderName = ...
local L = InFlight.L




local scrollBoxWidth = 600
local scrollBoxHeight = 500
local singleLineBoxHeight = 20

local outerFrame = CreateFrame("Frame")
outerFrame:SetSize(scrollBoxWidth + 80, scrollBoxHeight + 3*singleLineBoxHeight)

local linkFrame1Border = CreateFrame("Frame", nil, outerFrame, "TooltipBackdropTemplate")
linkFrame1Border:SetPoint("TOP", outerFrame, "TOP", 0, -5)
linkFrame1Border:SetSize(scrollBoxWidth + 34, singleLineBoxHeight + 2)
local linkFrame1 = CreateFrame("EditBox", nil, outerFrame, "InputBoxScriptTemplate")
linkFrame1:SetPoint("CENTER", linkFrame1Border, "CENTER", 0, 0)
linkFrame1:SetAutoFocus(false)
linkFrame1:SetFontObject(ChatFontNormal)
linkFrame1:SetSize(scrollBoxWidth + 22, singleLineBoxHeight)

local linkFrame2Border = CreateFrame("Frame", nil, outerFrame, "TooltipBackdropTemplate")
linkFrame2Border:SetPoint("TOP", linkFrame1Border, "BOTTOM", 0, 3)
linkFrame2Border:SetSize(scrollBoxWidth + 34, singleLineBoxHeight + 2)
local linkFrame2 = CreateFrame("EditBox", nil, outerFrame, "InputBoxScriptTemplate")
linkFrame2:SetPoint("CENTER", linkFrame2Border, "CENTER", 0, 0)
linkFrame2:SetAutoFocus(false)
linkFrame2:SetFontObject(ChatFontNormal)
linkFrame2:SetSize(scrollBoxWidth + 22, singleLineBoxHeight)

local linkFrame3Border = CreateFrame("Frame", nil, outerFrame, "TooltipBackdropTemplate")
linkFrame3Border:SetPoint("TOP", linkFrame2Border, "BOTTOM", 0, 3)
linkFrame3Border:SetSize(scrollBoxWidth + 34, singleLineBoxHeight + 2)
local linkFrame3 = CreateFrame("EditBox", nil, outerFrame, "InputBoxScriptTemplate")
linkFrame3:SetPoint("CENTER", linkFrame3Border, "CENTER", 0, 0)
linkFrame3:SetAutoFocus(false)
linkFrame3:SetFontObject(ChatFontNormal)
linkFrame3:SetSize(scrollBoxWidth + 22, singleLineBoxHeight)


local borderFrame = CreateFrame("Frame", nil, outerFrame, "TooltipBackdropTemplate")
borderFrame:SetSize(scrollBoxWidth + 34, scrollBoxHeight + 10)
borderFrame:SetPoint("TOP", linkFrame3Border, "BOTTOM", 0, -5)

local scrollFrame = CreateFrame("ScrollFrame", nil, outerFrame, "UIPanelScrollFrameTemplate")
-- scrollFrame:SetPoint("CENTER", -10, 0)
scrollFrame:SetPoint("TOP", borderFrame, "TOP", -10, -5)
scrollFrame:SetSize(scrollBoxWidth, scrollBoxHeight)

local editbox = CreateFrame("EditBox", nil, scrollFrame, "InputBoxScriptTemplate")
editbox:SetMultiLine(true)
editbox:SetAutoFocus(false)
editbox:SetFontObject(ChatFontNormal)
editbox:SetWidth(scrollBoxWidth)
scrollFrame:SetScrollChild(editbox)




local popupName = "INFLIGHT_EXPORT"
StaticPopupDialogs[popupName] = {
  text = L["ExportMessage"],
  button1 = L["Dismiss"],
  button2 = L["Select All"],
  OnCancel =
    function()
      editbox:HighlightText()
      editbox:SetFocus()
      -- Prevent from hiding!
      return true
    end,

  OnShow =
    function(self)

      local textFrame = self.text
      C_Timer.After(0.001, function()
        textFrame:SetWidth(scrollBoxWidth)

        linkFrame1:SetText("https://www.curseforge.com/wow/addons/inflight-taxi-timer/comments")
        linkFrame2:SetText("https://www.wowinterface.com/forums/showthread.php?t=18997")
        linkFrame3:SetText("https://www.github.com/LudiusMaximus/InFlight/issues/1")
      end)

      editbox:HighlightText()
      editbox:SetFocus()
    end,

  hideOnEscape = true,
}









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






-- ###########################################################################################################
-- ########## Identify flight points in Khaz Algar to handle "Khaz Algar Flight Master" speed boost. #########
-- ###########################################################################################################

-- https://warcraft.wiki.gg/wiki/API_C_Map.GetMapInfo
-- https://warcraft.wiki.gg/wiki/UiMapID

local function GetKhazAlgarNodes()

  local khazAlgarNodes = {}

  local khazAlgarMapId = 2274
  local cosmicMapId = 947

  local function GetFinalParent(uiMapID)
    local mapInfo = C_Map.GetMapInfo(uiMapID)
    -- print(uiMapID, mapInfo.mapID, mapInfo.name, mapInfo.parentMapID)
    if mapInfo.parentMapID == 0 or mapInfo.parentMapID == cosmicMapId then
      return mapInfo.mapID
    else
      return GetFinalParent(mapInfo.parentMapID)
    end
  end

  -- Go through all map IDs.
  for uiMapID = 1, 2500 do

    local mapInfo = C_Map.GetMapInfo(uiMapID)
    if mapInfo and mapInfo.mapID and GetFinalParent(mapInfo.mapID) == khazAlgarMapId then
      -- print("----------", mapInfo.mapID, mapInfo.name, mapInfo.parentMapID, GetFinalParent(uiMapID))

      local taxiNodes = C_TaxiMap.GetTaxiNodesForMap(mapInfo.mapID)
      if taxiNodes and #taxiNodes > 0 then

        -- print("+++++", mapInfo.mapID, mapInfo.name, #taxiNodes)
        for _, v in pairs(taxiNodes) do
          -- print("    ", v.nodeID, v.name)
          khazAlgarNodes[v.nodeID] = true
        end
      end
    end
  end  -- Go through all map IDs.

  return khazAlgarNodes
end

local khazAlgarNodes = GetKhazAlgarNodes()

function InFlight:KhazAlgarFlightMasterFactor(nodeID)
  -- print("KhazAlgarFlightMasterFactor", nodeID)
  if khazAlgarNodes[nodeID] then
    -- https://www.wowhead.com/achievement=40430/khaz-algar-flight-master
    local _, _, _, completed = GetAchievementInfo(40430)
    if not completed then
      -- print("multiply by 1.25")
      return 1.25
    end
  end

  -- print("multiply by 1")
  return 1
end




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
local function GetExportText(variableName, taxiNodes, indent)

  if not indent then indent = "" end

  local exportText = indent .. variableName .. " = {\n"

  for faction, factionNodes in pairs(taxiNodes) do

    exportText = exportText .. indent .. "  [\"" .. faction .. "\"] = {\n"

    -- Sort keys.
    local sortedSourceKeys = SortKeys(factionNodes)
    for _, sourceNodeId in pairs(sortedSourceKeys) do
      local destNodes = factionNodes[sourceNodeId]

      if type(sourceNodeId) ~= "number" then
        exportText = exportText .. indent .. "    [\"" .. sourceNodeId .. "\"] = {   -- Flightpath started by gossip option.\n"
      else
        exportText = exportText .. indent .. "    [" .. sourceNodeId .. "] = {\n"
        -- When exporting InFlightDB, there might not be a name field.
        if destNodes["name"] then
          exportText = exportText .. indent .. "      [\"name\"] = \"" .. destNodes["name"] .. "\",\n"
        end
      end


      -- Sort keys.
      local sortedDestKeys = SortKeys(destNodes)
      for _, destNodeId in pairs(sortedDestKeys) do

        local flightTime = destNodes[destNodeId]

        if destNodeId ~= "name" then
          if type(destNodeId) == "number" then
            -- Get rid of redundand 0 entries.
            if tonumber(flightTime) > 0 then
              exportText = exportText .. indent .. "      [" .. destNodeId .. "] = " .. flightTime .. ",\n"
            end
          else
            exportText = exportText .. indent .. "      [\"" .. destNodeId .. "\"] = " .. flightTime .. ",\n"
          end
        end

      end
      exportText = exportText .. indent .. "    },\n"
    end
    exportText = exportText .. indent .. "  },\n"
  end
  exportText = exportText .. indent .. "}\n"

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






-- ############################################################
-- ########## Merge old faction format into unified. ##########
-- ############################################################
-- It was a nice idea, but there are in fact different flight times between the same nodes (at least in classic):
-- https://classictinker.com/flight-master/?fromLoc=Ratchet%2C%20The%20Barrens&toLoc=Marshal%27s%20Refuge%2C%20Un%27Goro%20Crater&faction=alliance  (6 min)
-- https://classictinker.com/flight-master/?fromLoc=Ratchet%2C%20The%20Barrens&toLoc=Marshal%27s%20Refuge%2C%20Un%27Goro%20Crater&faction=horde     (8 min)
-- TODO: Do a unification for all node IDs in ranges where we know it is only unified expansions?


local function MergeFactions(input)

  local output = {}

  -- Copy all Alliance into output.
  for src, destNodes in pairs(input["Alliance"]) do
    for dst, dTimeOrName in pairs(destNodes) do
      output[src] = output[src] or {}
      output[src][dst] = dTimeOrName
    end
  end

  -- Merge Horde into Alliance!
  for src, destNodes in pairs(input["Horde"]) do
    for dst, dTimeOrName in pairs(destNodes) do
      if not output[src] or not output[src][dst] then
        output[src] = output[src] or {}
        output[src][dst] = dTimeOrName
      else
        if dst == "name" then
          if output[src][dst] ~= dTimeOrName then
            print("Got different names for Alliance", output[src][dst], "and Horde", dTimeOrName)
          end
        else
          if abs(output[src][dst] - dTimeOrName) > 2 then
            print("Got different times for", output[src] and output[src]["name"] or "<unknown>", "to", output[dst] and output[dst]["name"] or "<unknown>", "Alliance", output[src][dst], "and Horde", dTimeOrName)
          end
        end
      end
    end
  end

  return output
end








-- ####################################################
-- ########## Import data uploaded by users. ##########
-- ####################################################


-- Paste uploaded user data here and uncomment ImportUserUpload(defaults, myImport, false) below.
local myImport = {}




local function ImportUserUpload(defaults, import, ignoreNames)
  local updated = 0

  for faction, factionNodes in pairs(import) do
    for src, destNodes in pairs(factionNodes) do
      if not defaults[faction][src] then
        defaults[faction][src] = destNodes
        updated = updated + #destNodes
        if ignoreNames then
          defaults[faction][src]["name"] = nil
          updated = updated - 1
        end
      else
        for dst, dtimeOrName in pairs(destNodes) do
          if not defaults[faction][src][dst] then
            if dst ~= "name" or not ignoreNames then
              defaults[faction][src][dst] = dtimeOrName
              updated = updated + 1
            end
          else
            if dst == "name" then
              if defaults[faction][src][dst] ~= dtimeOrName and not ignoreNames then
                print("Got a different name", faction, defaults[faction][src] and defaults[faction][src]["name"] or "<unknown>", src, "to", defaults[faction][dst] and defaults[faction][dst]["name"] or "<unknown>", dst, "is now", dtimeOrName, "but has so far been", defaults[faction][src][dst])
                defaults[faction][src][dst] = dtimeOrName
              end
            elseif abs(defaults[faction][src][dst] - dtimeOrName) > 2 then
              print("Got a different time", faction, defaults[faction][src] and defaults[faction][src]["name"] or "<unknown>", src, "to", defaults[faction][dst] and defaults[faction][dst]["name"] or "<unknown>", dst, "is now", dtimeOrName, "has so far been", defaults[faction][src][dst])
              defaults[faction][src][dst] = dtimeOrName
            end
          end
        end
      end
    end
  end

  print("Updated", updated)
end


local defaults = InFlight.defaults.global


-- Uncomment to get new default data.
-- Set third argument to true, for imports that are not english.

-- ImportUserUpload(defaults, myImport, false)
-- local exportText = GetExportText("global", defaults, "  ")
-- editbox:SetText(exportText)
-- StaticPopup_Show(popupName, nil, nil, nil, outerFrame)







function InFlight:ExportDB()
  local exportText = ""

  local buildVersion, buildNumber = GetBuildInfo()
  exportText = exportText .. "-- Export by " .. UnitName("player") .. "-" .. GetRealmName() .. "-" .. GetCurrentRegionName() .. "\n"
  exportText = exportText .. "-- " .. date("%Y-%m-%d %H:%M:%S", time()) .. "\n"
  exportText = exportText .. "-- WoW-Client " .. buildVersion .. " " .. buildNumber ..  " " .. GetLocale() .. "\n"
  exportText = exportText .. "-- " .. folderName .. " " .. C_AddOns.GetAddOnMetadata(folderName, "Version") .. "\n\n"

  exportText = exportText .. GetExportText("myExport", InFlight.newPlayerSaveData)

  editbox:SetText(exportText)
  StaticPopup_Show(popupName, nil, nil, nil, outerFrame)
end