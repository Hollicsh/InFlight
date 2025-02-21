-- GLOBALS -> LOCAL
local _G = getfenv(0)
local GetNumRoutes, GetTaxiMapID, GetTime, NumTaxiNodes, TaxiGetNodeSlot, TaxiNodeGetType, TaxiNodeName, UnitOnTaxi
    = GetNumRoutes, GetTaxiMapID, GetTime, NumTaxiNodes, TaxiGetNodeSlot, TaxiNodeGetType, TaxiNodeName, UnitOnTaxi
local abs, floor, format, gsub, ipairs, pairs, print, strjoin, strfind
    = abs, floor, format, gsub, ipairs, pairs, print, strjoin, strfind
local gtt = GameTooltip


-- WARNING if InFlight_Load is still present.
if C_AddOns.IsAddOnLoaded("InFlight_Load") then
  print("|cffff0000\"InFlight_Load\" is no longer required for \"InFlight\". You can disable or remove it.|r")
  C_AddOns.DisableAddOn("InFlight_Load")

  -- Undo InFlight_Load.
  InFlight = nil
end


local InFlight = CreateFrame("Frame", "InFlight")  -- no parent is intentional


-- LIBRARIES
local smed = LibStub("LibSharedMedia-3.0")

-- LOCALIZATION
local L = LibStub("AceLocale-3.0"):GetLocale("InFlight", not debug)
InFlight.L = L



InFlight.newPlayerSaveData = {}

InFlight.debug = false

-- LOCAL VARIABLES
local debug = InFlight.debug
local Print, PrintD = InFlight.Print, InFlight.PrintD
local vars, db                        -- addon databases
local taxiSrc, taxiSrcName, taxiDst, taxiDstName, endTime  -- location data
local porttaken, takeoff, inworld, outworld, ontaxi        -- flags
local ratio, endText = 0, "??"                             -- cache variables
local sb, spark, timeText, locText, bord                   -- frame elements
local totalTime, startTime, elapsed, throt = 0, 0, 0, 0    -- throttle vars
local oldTakeTaxiNode





InFlight:SetScript("OnEvent", function(this, event, ...) this[event](this, ...) end)
InFlight:RegisterEvent("ADDON_LOADED")

-----------------------------------------
function InFlight:ADDON_LOADED()
-----------------------------------------
  self:RegisterEvent("TAXIMAP_OPENED")
  self:SetupInFlight()
  self:LoadBulk()
  self:UnregisterEvent("ADDON_LOADED")
end


-------------------------------------
function InFlight:TAXIMAP_OPENED(...)
-------------------------------------
  local uiMapSystem = ...
  local isTaxiMap = uiMapSystem == Enum.UIMapSystem.Taxi
  self:InitSource(isTaxiMap)
end






-- Support for flightpaths that are started by gossip options.
local t = {
  [L["Amber Ledge"]]                = {{ find = L["AmberLedgeGossip"],        s = "Amber Ledge",                d = "Transitus Shield (Scenic Route)" }},
  [L["Argent Tournament Grounds"]]  = {{ find = L["ArgentTournamentGossip"],  s = "Argent Tournament Grounds",  d = "Return" }},
  [L["Blackwind Landing"]]          = {{ find = L["BlackwindLandingGossip"],  s = "Blackwind Landing",          d = "Skyguard Outpost" }},
  [L["Caverns of Time"]]            = {{ find = L["CavernsOfTimeGossip"],     s = "Caverns of Time",            d = "Nozdormu's Lair" }},
  [L["Expedition Point"]]           = {{ find = L["ExpeditionPointGossip"],   s = "Expedition Point",           d = "Shatter Point" }},
  [L["Hellfire Peninsula"]]         = {{ find = L["HellfirePeninsulaGossip"], s = "Honor Point",                d = "Shatter Point" }},
  [L["Nighthaven"]]                 = {{ find = L["NighthavenGossipA"],       s = "Nighthaven",                 d = "Rut'theran Village" },
                                      {  find = L["NighthavenGossipH"],       s = "Nighthaven",                 d = "Thunder Bluff" }},
  [L["Old Hillsbrad Foothills"]]    = {{ find = L["OldHillsbradGossip"],      s = "Old Hillsbrad Foothills",    d = "Durnholde Keep" }},
  [L["Reaver's Fall"]]              = {{ find = L["Reaver'sFallGossip"],      s = "Reaver's Fall",              d = "Spinebreaker Post" }},
  [L["Ring of Transference"]]       = {{ find = L["ToBastionGossip1"],        s = "Oribos",                     d = "Bastion" },
                                      {  find = L["ToBastionGossip2"],        s = "Oribos",                     d = "Bastion" }},
  [L["Shatter Point"]]              = {{ find = L["ShatterPointGossip"],      s = "Shatter Point",              d = "Honor Point" }},
  [L["Skyguard Outpost"]]           = {{ find = L["SkyguardOutpostGossip"],   s = "Skyguard Outpost",           d = "Blackwind Landing" }},
  [L["Stormwind City"]]             = {{ find = L["StormwindCityGossip"],     s = "Stormwind City",             d = "Return" }},
  [L["Sun's Reach Harbor"]]         = {{ find = L["SSSAGossip"],              s = "Shattered Sun Staging Area", d = "Return" },
                                      {  find = L["SSSAGossip2"],             s = "Shattered Sun Staging Area", d = "The Sin'loren" }},
  [L["The Sin'loren"]]              = {{ find = L["TheSin'lorenGossip"],      s = "The Sin'loren",              d = "Shattered Sun Staging Area" }},
  [L["Valgarde"]]                   = {{ find = L["ValgardeGossip"],          s = "Valgarde",                   d = "Explorers' League Outpost" }},
}


local function PrepareMiscFlight(buttonText)
  if not buttonText or buttonText == "" then
    return
  end

  local subzone = GetMinimapZoneText()
  local tsz = t[subzone]
  if not tsz then
    return
  end

  local source, destination
  for _, sz in ipairs(tsz) do
    if strfind(buttonText, sz.find, 1, true) then
      source = sz.s
      destination = sz.d
      break
    end
  end

  if source and destination then
    InFlight:StartMiscFlight(source, destination)
  end
end


-- For Immersion addon.
if C_AddOns.IsAddOnLoaded("Immersion") then
  local immersionHookFrame = CreateFrame("Frame")
  immersionHookFrame:SetScript("OnEvent", function(_, event)
    if ImmersionFrame and ImmersionFrame.TitleButtons then
      local children = {ImmersionFrame.TitleButtons:GetChildren()}
      for i, child in ipairs(children) do
        if not child.inFlightHook then
          child:HookScript("OnClick", function(this)
            PrepareMiscFlight(this:GetText())
          end)
          child.inFlightHook = true
        end
      end
    end
  end)
  immersionHookFrame:RegisterEvent("GOSSIP_SHOW")
  immersionHookFrame:RegisterEvent("QUEST_GREETING")
  immersionHookFrame:RegisterEvent("QUEST_PROGRESS")

-- Without Immersion addon.
else
  hooksecurefunc(_G.GossipOptionButtonMixin, "OnClick", function(this)
    local elementData = this:GetElementData()
    if elementData.buttonType ~= _G.GOSSIP_BUTTON_TYPE_OPTION then
      return
    end
    PrepareMiscFlight(this:GetText())
  end)
end






function InFlight:SetupInFlight()

  SlashCmdList.INFLIGHT = function(arg1)

    if arg1 == "export" then
      self:ExportDB()
    else
      self:ShowOptions()
    end

  end
  SLASH_INFLIGHT1 = "/inflight"

  local panel = CreateFrame("Frame")
  panel.name = "InFlight"
  panel:SetScript("OnShow", function(this)
    if InFlight.SetLayout then
      InFlight:SetLayout(this)
    end
  end)


  -- InterfaceOptions_AddCategory(panel)
  local category = Settings.RegisterCanvasLayoutCategory(panel, "InFlight")
  Settings.RegisterAddOnCategory(category)

  InFlight.SetupInFlight = nil
end



-- LOCAL FUNCTIONS
local function FormatTime(secs)  -- simple time format
  if not secs then
    return "??"
  end

  return format(TIMER_MINUTES_DISPLAY, secs / 60, secs % 60)
end

local function ShortenName(name)  -- shorten name to lighten saved vars and display
  return gsub(name, L["DestParse"], "")
end

local function GetNodeID(slot)
  local taximapNodes = C_TaxiMap.GetAllTaxiNodes(GetTaxiMapID())
  for _, taxiNodeData in ipairs(taximapNodes) do
    if (slot == taxiNodeData.slotIndex) then
      return taxiNodeData.nodeID
    end
  end
end

local function SetPoints(f, lp, lrt, lrp, lx, ly, rp, rrt, rrp, rx, ry)
  f:ClearAllPoints()
  f:SetPoint(lp, lrt, lrp, lx, ly)
  if rp then
    f:SetPoint(rp, rrt, rrp, rx, ry)
  end
end

local function SetToUnknown()  -- setup bar for flights with unknown time
  sb:SetMinMaxValues(0, 1)
  sb:SetValue(1)
  sb:SetStatusBarColor(db.unknowncolor.r, db.unknowncolor.g, db.unknowncolor.b, db.unknowncolor.a)
  spark:Hide()
end

local function GetEstimatedTime(slot)  -- estimates flight times based on hops
  local numRoutes = GetNumRoutes(slot)
  if numRoutes < 2 then
    return
  end

  local taxiNodes = {[1] = taxiSrc, [numRoutes + 1] = GetNodeID(slot)}
  for hop = 2, numRoutes, 1 do
    taxiNodes[hop] = GetNodeID(TaxiGetNodeSlot(slot, hop, true))
  end

  local etimes = { 0 }
  local prevNode = {}
  local nextNode = {}
  local srcNode = 1
  local dstNode = #taxiNodes - 1
  PrintD("|cff208080New Route:|r", taxiSrcName.."("..taxiSrc..") -->", ShortenName(TaxiNodeName(slot)).."("..taxiNodes[#taxiNodes]..") -", #taxiNodes, "hops")
  while srcNode and srcNode < #taxiNodes do
    while dstNode and dstNode > srcNode do
      PrintD("|cff208080Node:|r", taxiNodes[srcNode].."("..srcNode..") -->", taxiNodes[dstNode].."("..dstNode..")")
      if vars[taxiNodes[srcNode]] then
        if not etimes[dstNode] and vars[taxiNodes[srcNode]][taxiNodes[dstNode]] then
          etimes[dstNode] = etimes[srcNode] + vars[taxiNodes[srcNode]][taxiNodes[dstNode]] * InFlight:KhazAlgarFlightMasterFactor(taxiNodes[dstNode])
          PrintD(taxiNodes[dstNode].."("..dstNode..") time:", FormatTime(etimes[srcNode]), "+", FormatTime(vars[taxiNodes[srcNode]][taxiNodes[dstNode]]), "=", FormatTime(etimes[dstNode]))
          nextNode[srcNode] = dstNode - 1
          prevNode[dstNode] = srcNode
          srcNode = dstNode
          dstNode = #taxiNodes
        else
          dstNode = dstNode - 1
        end
      else
        srcNode = prevNode[srcNode]
        dstNode = nextNode[srcNode]
      end
    end

    if not etimes[#taxiNodes] then
      PrintD("<<")
      srcNode = prevNode[srcNode]
      dstNode = nextNode[srcNode]
    end
  end

  PrintD(".")
  return etimes[#taxiNodes]
end

local function addDuration(flightTime, estimated)
  if flightTime > 0 then
    gtt:AddLine(L["Duration"]..(estimated and "~" or "")..FormatTime(flightTime), 1, 1, 1)
  else
    gtt:AddLine(L["Duration"].."-:--", 0.8, 0.8, 0.8)
  end

  gtt:Show()
end

local function postTaxiNodeOnButtonEnter(button) -- adds duration info to taxi node tooltips
  local id = button:GetID()
  if TaxiNodeGetType(id) ~= "REACHABLE" then
    return
  end

  local tmpTaxiDst = GetNodeID(id)
  local duration = vars[taxiSrc] and vars[taxiSrc][tmpTaxiDst]
  if duration then
    addDuration(duration * InFlight:KhazAlgarFlightMasterFactor(tmpTaxiDst))
  else
    addDuration(GetEstimatedTime(id) or 0, true)
  end
end

local function postFlightNodeOnButtonEnter(button) -- adds duration info to flight node tooltips
  -- if button.taxiNodeData.state == Enum.FlightPathState.Current and GetTaxiMapID() ~= 994 then -- TEST
     -- gtt:AddLine("NodeID: "..button.taxiNodeData.nodeID, 0.2, 0.8, 0.2)
     -- gtt:Show()
     -- return
  -- end

  if button.taxiNodeData.state ~= Enum.FlightPathState.Reachable or GetTaxiMapID() == 994 then
    return
  end

  local tmpTaxiDst = button.taxiNodeData.nodeID
  local duration = vars[taxiSrc] and vars[taxiSrc][tmpTaxiDst]
  if duration then
    -- gtt:AddLine("NodeID: "..button.taxiNodeData.nodeID, 0.2, 0.8, 0.2) -- TEST
    addDuration(duration * InFlight:KhazAlgarFlightMasterFactor(tmpTaxiDst))
  else
    -- gtt:AddLine("NodeID: "..button.taxiNodeData.nodeID, 0.2, 0.8, 0.2) -- TEST
    addDuration(GetEstimatedTime(button.taxiNodeData.slotIndex) or 0, true)
  end
end

----------------------------
function InFlight.Print(...)  -- prefix chat messages
----------------------------
  print("|cff0040ffIn|cff00aaffFlight|r:", ...)
end
Print = InFlight.Print

-----------------------------
function InFlight.PrintD(...)  -- debug print
-----------------------------
  if debug then
    print("|cff00ff40In|cff00aaffFlight|r:", ...)
  end
end
PrintD = InFlight.PrintD

----------------------------------
function InFlight:GetDestination()
----------------------------------
  return taxiDstName
end

---------------------------------
function InFlight:GetFlightTime()
---------------------------------
  return endTime
end

----------------------------
function InFlight:LoadBulk()
----------------------------
  InFlightDB = InFlightDB or {}

  -- Convert old saved variables
  if not InFlightDB.version then
    InFlightDB.perchar = nil
    InFlightDB.dbinit = nil
    InFlightDB.upload = nil
    local tempDB = InFlightDB
    InFlightDB = { profiles = { Default = tempDB }}
  end




  -- Flag to clear player save data, if corrupted data has been introduced into the
  -- player save data from a bug in the game or this addon, and therefore the player
  -- save data needs to be reset.
  -- Duplicates of updated default data will be automatically removed from the player
  -- save data by the metatable
  local resetDB = false

  -- post-cata
  if select(4, GetBuildInfo()) >= 40000 then

    if InFlightDB.dbinit ~= 920 then
      resetDB = true
      InFlightDB.dbinit = 920
    end

    -- Check that this is the right version of the database to avoid corruption
    if InFlightDB.version ~= "post-cata" then
      -- Used to be called "retail", so we only reset flight points if it was anything else.
      if InFlightDB.version ~= "retail" then
        resetDB = true
      end
      InFlightDB.version = "post-cata"
    end

  -- pre-cata
  else

    if InFlightDB.dbinit ~= 1150 then
      resetDB = true
      InFlightDB.dbinit = 1150
    end

    -- Check that this is the right version of the database to avoid corruption
    if InFlightDB.version ~= "pre-cata" then
      -- Used to be called "classic" or "classic-era", so we only reset flight points if it was anything else.
      if InFlightDB.version ~= "classic" and InFlightDB.version ~= "classic-era" then
        resetDB = true
      end
      InFlightDB.version = "pre-cata"
    end

  end

  if resetDB and not debug then
    InFlightDB.global = nil
    InFlightDB.upload = nil
  end


  if debug then
    for faction, t in pairs(self.defaults.global) do
      local count = 0
      for src, dt in pairs(t) do
        for dst, dtime in pairs(dt) do
          if dst ~= "name" then
            count = count + 1
          end
        end
      end

      PrintD(faction, "|cff208020-|r", count, "|cff208020flights|r")
    end
  end



  -- If player save data (InFlightDB.global) is (almost, +/- 3) the same as stock default data (self.defaults.global),
  -- remove player save data by setting it to the corresponsing stock default.
  if InFlightDB.global then
    local defaults = self.defaults.global

    for faction, t in pairs(InFlightDB.global) do
      for src, dt in pairs(t) do
        if defaults[faction][src] then
          for dst, dtime in pairs(dt) do
            if dst ~= "name" and defaults[faction][src][dst] and abs(dtime - defaults[faction][src][dst]) < 3 then
              InFlightDB.global[faction][src][dst] = defaults[faction][src][dst]
            end
          end
        end
      end
    end


    -- Store new player save data for export.
    local found = 0
    local newPlayerSaveData = InFlight.newPlayerSaveData
    for faction, factionNodes in pairs(InFlightDB.global) do
      for src, destNodes in pairs(factionNodes) do
        for dst, dtime in pairs(destNodes) do
          if (dst ~= "name" and (not defaults[faction][src] or not defaults[faction][src][dst] or abs(dtime - defaults[faction][src][dst]) > 2)) or
             (dst == "name" and (not defaults[faction][src] or not defaults[faction][src][dst] or dtime ~= defaults[faction][src][dst])) then
            newPlayerSaveData[faction] = newPlayerSaveData[faction] or {}
            newPlayerSaveData[faction][src] = newPlayerSaveData[faction][src] or {}
            newPlayerSaveData[faction][src][dst] = dtime
            if dst ~= "name" then
              found = found + 1
            end
          end
        end
      end
    end

    if found > 0 and (not InFlightDB.upload or InFlightDB.upload < time()) then
      Print(format("|cff208020- "..L["FlightTimeContribute"].."|r", "|r"..found.."|cff208020"))
      InFlightDB.upload = time() + 604800  -- 1 week in seconds (60 * 60 * 24 * 7)
    end

  end


  -- Create profile and flight time databases
  local faction = UnitFactionGroup("player")
  if not debug then
    self.defaults.global[faction == "Alliance" and "Horde" or "Alliance"] = nil
  end
  self.db = LibStub("AceDB-3.0"):New("InFlightDB", self.defaults, true)
  db = self.db.profile
  vars = self.db.global[faction]

  oldTakeTaxiNode = TakeTaxiNode
  TakeTaxiNode = function(slot)
    if TaxiNodeGetType(slot) ~= "REACHABLE" then
      return
    end

    -- TODO: Why?
    -- Don't show timer or record times for Argus map
    if GetTaxiMapID() == 994 then
      return oldTakeTaxiNode(slot)
    end

    -- Attempt to get source flight point if another addon auto-takes the taxi
    -- which can cause this function to run before the TAXIMAP_OPENED function
    if not taxiSrc then
      for i = 1, NumTaxiNodes(), 1 do
        if TaxiNodeGetType(i) == "CURRENT" then
          taxiSrcName = ShortenName(TaxiNodeName(i))
          taxiSrc = GetNodeID(i)
          break
        end
      end

      if not taxiSrc then
        oldTakeTaxiNode(slot)
        return
      end
    end

    taxiDstName = ShortenName(TaxiNodeName(slot))
    taxiDst = GetNodeID(slot)
    local t = vars[taxiSrc]
    if t and t[taxiDst] and t[taxiDst] > 0 then  -- saved variables lookup
      endTime = t[taxiDst] * InFlight:KhazAlgarFlightMasterFactor(taxiDst)
      endText = FormatTime(endTime)
    else
      endTime = GetEstimatedTime(slot)
      endText = (endTime and "~" or "")..FormatTime(endTime)
    end

    if db.confirmflight then  -- confirm flight
      StaticPopupDialogs.INFLIGHTCONFIRM = StaticPopupDialogs.INFLIGHTCONFIRM or {
        button1 = OKAY, button2 = CANCEL,
        OnAccept = function(this, data) InFlight:StartTimer(data) end,
        timeout = 0, exclusive = 1, hideOnEscape = 1,
      }
      StaticPopupDialogs.INFLIGHTCONFIRM.text = format(L["ConfirmPopup"], "|cffffff00"..taxiDstName..(endTime and " ("..endText..")" or "").."|r")

      local dialog = StaticPopup_Show("INFLIGHTCONFIRM")
      if dialog then
        dialog.data = slot
      end
    else  -- just take the flight
      self:StartTimer(slot)
    end
  end

  -- function hooks to detect if a user took a summon
  hooksecurefunc("TaxiRequestEarlyLanding", function()
    porttaken = true
    PrintD("|cffff8080Taxi Early|cff208080, porttaken -|r", porttaken)
  end)

  hooksecurefunc("AcceptBattlefieldPort", function(index, accept)
    porttaken = accept and true
    PrintD("|cffff8080Battlefield port|cff208080, porttaken -|r", porttaken)
  end)

  hooksecurefunc(C_SummonInfo, "ConfirmSummon", function()
    porttaken = true
    PrintD("|cffff8080Summon|cff208080, porttaken -|r", porttaken)
  end)

  hooksecurefunc("CompleteLFGRoleCheck", function(bool)
    porttaken = bool
    PrintD("|cffff8080LFG Role|cff208080, porttaken -|r", porttaken)
  end)

  hooksecurefunc("CompleteLFGReadyCheck", function(bool)
    porttaken = bool
    PrintD("|cffff8080LFG Ready|cff208080, porttaken -|r", porttaken)
  end)

  self:Hide()
  self.LoadBulk = nil
end

---------------------------------------
function InFlight:InitSource(isTaxiMap)  -- cache source location and hook tooltips
---------------------------------------
  taxiSrcName = nil
  taxiSrc = nil

  if isTaxiMap then
    for i = 1, NumTaxiNodes(), 1 do
      local tb = _G["TaxiButton"..i]
      if tb and not tb.inflighted then
        tb:HookScript("OnEnter", postTaxiNodeOnButtonEnter)
        tb.inflighted = true
      end

      if TaxiNodeGetType(i) == "CURRENT" then
        taxiSrcName = ShortenName(TaxiNodeName(i))
        taxiSrc = GetNodeID(i)
      end
    end
  elseif FlightMapFrame and FlightMapFrame.pinPools and FlightMapFrame.pinPools.FlightMap_FlightPointPinTemplate then
    local tb = FlightMapFrame.pinPools.FlightMap_FlightPointPinTemplate
    if tb then
      for flightnode in tb:EnumerateActive() do
        if not flightnode.inflighted then
          flightnode:HookScript("OnEnter", postFlightNodeOnButtonEnter)
          flightnode.inflighted = true
        end

        if flightnode.taxiNodeData.state == Enum.FlightPathState.Current then
          taxiSrcName = ShortenName(flightnode.taxiNodeData.name)
          taxiSrc = flightnode.taxiNodeData.nodeID
        end
      end
    end
  end

  -- TODO: Still needed?
  -- Workaround for Blizzard bug on OutLand Flight Map
  if not taxiSrc and GetTaxiMapID() == 1467 and GetMinimapZoneText() == L["Shatter Point"] then
    taxiSrcName = L["Shatter Point"]
    taxiSrc = "Shatter Point"
  end
end

----------------------------------
function InFlight:StartTimer(slot)  -- lift off
----------------------------------
  Dismount()
  if CanExitVehicle() == 1 then
    VehicleExit()
  end

  -- create the timer bar
  if not sb then
    self:CreateBar()
  end

  -- start the timers and setup statusbar
  if endTime then
    sb:SetMinMaxValues(0, endTime)
    sb:SetValue(db.fill and 0 or endTime)
    spark:SetPoint("CENTER", sb, "LEFT", db.fill and 0 or db.width, 0)
  else
    SetToUnknown()
  end

  InFlight:UpdateLook()
  timeText:SetFormattedText("%s / %s", FormatTime(0), endText)
  sb:Show()
  self:Show()

  porttaken = nil
  elapsed, totalTime, startTime = 0, 0, GetTime()
  takeoff, inworld = true, true
  throt = min(0.2, (endTime or 50) / (db.width or 1))  -- increases updates for short flights

  self:RegisterEvent("LFG_PROPOSAL_DONE")
  self:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
  self:RegisterEvent("PLAYER_CONTROL_GAINED")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("PLAYER_LEAVING_WORLD")

  if slot then
    oldTakeTaxiNode(slot)
  end
end

-------------------------------------------
function InFlight:StartMiscFlight(src, dst)  -- called from InFlight_Load for special flights
-------------------------------------------
  taxiSrcName = L[src]
  taxiSrc = src
  taxiDstName = L[dst]
  taxiDst = dst
  endTime = vars[src] and vars[src][dst]
  if endTime then
     endTime = endTime * self:KhazAlgarFlightMasterFactor(taxiSrc)
  end
  endText = FormatTime(endTime)
  self:StartTimer()
end

do  -- timer bar
  local bdrop = { edgeSize = 16, insets = {}, }
  local bdi = bdrop.insets
  -----------------------------
  function InFlight:CreateBar()
  -----------------------------
    sb = CreateFrame("StatusBar", "InFlightBar", UIParent)
    sb:Hide()
    sb:SetPoint(db.p, UIParent, db.rp, db.x, db.y)
    sb:SetMovable(true)
    sb:EnableMouse(true)
    sb:SetClampedToScreen(true)
    sb:SetScript("OnMouseUp", function(this, a1)
      if a1 == "RightButton" then
        InFlight:ShowOptions()
      elseif a1 == "LeftButton" and IsControlKeyDown() then
        ontaxi, porttaken = nil, true
      end
    end)
    sb:RegisterForDrag("LeftButton")
    sb:SetScript("OnDragStart", function(this)
      if IsShiftKeyDown() then
        this:StartMoving()
      end
    end)
    sb:SetScript("OnDragStop", function(this)
      this:StopMovingOrSizing()
      local a,b,c,d,e = this:GetPoint()
      db.p, db.rp, db.x, db.y = a, c, floor(d + 0.5), floor(e + 0.5)
    end)
    sb:SetScript("OnEnter", function(this)
      gtt:SetOwner(this, "ANCHOR_RIGHT")
      gtt:SetText("InFlight", 1, 1, 1)
      gtt:AddLine(L["TooltipOption1"], 0, 1, 0)
      gtt:AddLine(L["TooltipOption2"], 0, 1, 0)
      gtt:AddLine(L["TooltipOption3"], 0, 1, 0)
      gtt:Show()
    end)
    sb:SetScript("OnLeave", function() gtt:Hide() end)

    timeText = sb:CreateFontString(nil, "OVERLAY")
    locText = sb:CreateFontString(nil, "OVERLAY")

    spark = sb:CreateTexture(nil, "OVERLAY")
    spark:Hide()
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetWidth(16)
    spark:SetBlendMode("ADD")

    bord = CreateFrame("Frame", nil, sb, BackdropTemplateMixin and "BackdropTemplate")  -- border/background
    SetPoints(bord, "TOPLEFT", sb, "TOPLEFT", -5, 5, "BOTTOMRIGHT", sb, "BOTTOMRIGHT", 5, -5)
    bord:SetFrameStrata("LOW")

    local function onupdate(this, a1)
      elapsed = elapsed + a1
      if elapsed < throt then
        return
      end

      totalTime = GetTime() - startTime
      elapsed = 0

      if takeoff then  -- check if actually in flight after take off (doesn't happen immediately)
        if UnitOnTaxi("player") then
          takeoff, ontaxi = nil, true
          elapsed, totalTime, startTime = throt - 0.01, 0, GetTime()
        elseif totalTime > 5 then
          sb:Hide()
          this:Hide()
        end

        return
      end

      if ontaxi and not inworld then
        return
      end

      if not UnitOnTaxi("player") then  -- event bug fix
        ontaxi = nil
      end

      if not ontaxi then  -- flight ended
        PrintD("|cff208080porttaken -|r", porttaken)
        if not porttaken and taxiSrc then

          local newPlayerSaveData = InFlight.newPlayerSaveData
          local defaults = self.defaults.global
          local faction = UnitFactionGroup("player")
          if not defaults[faction][taxiSrc] or not defaults[faction][taxiSrc]["name"] then
            -- print("Adding", taxiSrcName, "as new node/new name")
            newPlayerSaveData[faction] = newPlayerSaveData[faction] or {}
            newPlayerSaveData[faction][taxiSrc] = newPlayerSaveData[faction][taxiSrc] or {}
            newPlayerSaveData[faction][taxiSrc]["name"] = taxiSrcName
          end

          vars[taxiSrc] = vars[taxiSrc] or { name = taxiSrcName }
          local oldTime = vars[taxiSrc][taxiDst]
          if oldTime then
            oldTime = oldTime * InFlight:KhazAlgarFlightMasterFactor(taxiDst)
          end
          local newTime = floor(totalTime + 0.5)


          local msg = strjoin(" ", taxiSrcName..(debug and "("..taxiSrc..")" or ""), db.totext, taxiDstName..(debug and "("..taxiDst..")" or ""), "|cff208080")
          if not oldTime then
            msg = msg..L["FlightTimeAdded"].."|r "..FormatTime(newTime)

          elseif abs(newTime - oldTime) > 2 then
            msg = msg..L["FlightTimeUpdated"].."|r "..FormatTime(oldTime).." |cff208080"..db.totext.."|r "..FormatTime(newTime)

          else
            newTime = oldTime
            msg = nil
          end

          if not defaults[faction][taxiSrc] or not defaults[faction][taxiSrc][taxiDst] or abs(newTime - defaults[faction][taxiSrc][taxiDst]) > 2 then
            -- print("Updating ", newTime, "as new time for", taxiSrcName)
            newPlayerSaveData[faction] = newPlayerSaveData[faction] or {}
            newPlayerSaveData[faction][taxiSrc] = newPlayerSaveData[faction][taxiSrc] or {}
            newPlayerSaveData[faction][taxiSrc][taxiDst] = newTime
          end

          vars[taxiSrc][taxiDst] = floor(newTime / InFlight:KhazAlgarFlightMasterFactor(taxiDst) + 0.5)


          if msg and db.chatlog then
            Print(msg)
          end
        end

        taxiSrcName = nil
        taxiSrc = nil
        taxiDstName = nil
        taxiDst = nil
        endTime = nil
        endText = FormatTime(endTime)
        sb:Hide()
        this:Hide()

        return
      end

      if endTime then  -- update statusbar if destination time is known
        if totalTime - 2 > endTime then   -- in case the flight is longer than expected
          SetToUnknown()
          endTime = nil
          endText = FormatTime(endTime)
        else
          local curTime = totalTime
          if curTime > endTime then
            curTime = endTime
          elseif curTime < 0 then
            curTime = 0
          end

          local value = db.fill and curTime or (endTime - curTime)
          sb:SetValue(value)
          spark:SetPoint("CENTER", sb, "LEFT", value * ratio, 0)

          value = db.countup and curTime or (endTime - curTime)
          timeText:SetFormattedText("%s / %s", FormatTime(value), endText)
        end
      else  -- destination time is unknown, so show that it's timing
        timeText:SetFormattedText("%s / %s", FormatTime(totalTime), endText)
      end
    end

    function self:LFG_PROPOSAL_DONE()
      porttaken = true
      PrintD("|cffff8080Proposal Done|cff208080, porttaken -|r", porttaken)
    end

    function self:LFG_PROPOSAL_SUCCEEDED()
      porttaken = true
      PrintD("|cffff8080Proposal Succeeded|cff208080, porttaken -|r", porttaken)
    end

    function self:PLAYER_LEAVING_WORLD()
      PrintD('PLAYER_LEAVING_WORLD')
      inworld = nil
      outworld = GetTime()
    end

    function self:PLAYER_ENTERING_WORLD()
      PrintD('PLAYER_ENTERING_WORLD')
      inworld = true
      if outworld then
        startTime = startTime - (outworld - GetTime())
      end

      outworld = nil
    end

    function self:PLAYER_CONTROL_GAINED()
      PrintD('PLAYER_CONTROL_GAINED')
      if not inworld then
        return
      end

      if self:IsShown() then
        ontaxi = nil
        onupdate(self, 3)
      end

      self:UnregisterEvent("LFG_PROPOSAL_DONE")
      self:UnregisterEvent("LFG_PROPOSAL_SUCCEEDED")
      self:UnregisterEvent("PLAYER_ENTERING_WORLD")
      self:UnregisterEvent("PLAYER_LEAVING_WORLD")
      self:UnregisterEvent("PLAYER_CONTROL_GAINED")
    end

    self:SetScript("OnUpdate", onupdate)
    self.CreateBar = nil
  end

  ------------------------------
  function InFlight:UpdateLook()
  ------------------------------
    if not sb then
      return
    end

    sb:SetWidth(db.width)
    sb:SetHeight(db.height)

    local texture = smed:Fetch("statusbar", db.texture)
    local inset = (db.border=="Textured" and 2) or 4
    bdrop.bgFile = texture
    bdrop.edgeFile = smed:Fetch("border", db.border)
    bdi.left, bdi.right, bdi.top, bdi.bottom = inset, inset, inset, inset
    bord:SetBackdrop(bdrop)
    bord:SetBackdropColor(db.backcolor.r, db.backcolor.g, db.backcolor.b, db.backcolor.a)
    bord:SetBackdropBorderColor(db.bordercolor.r, db.bordercolor.g, db.bordercolor.b, db.bordercolor.a)
    sb:SetStatusBarTexture(texture)
    if sb:GetStatusBarTexture() then
      sb:GetStatusBarTexture():SetHorizTile(false)
      sb:GetStatusBarTexture():SetVertTile(false)
    end

    spark:SetHeight(db.height * 2.4)
    if endTime then  -- in case we're in flight
      ratio = db.width / endTime
      sb:SetStatusBarColor(db.barcolor.r, db.barcolor.g, db.barcolor.b, db.barcolor.a)
      if db.spark then
        spark:Show()
      else
        spark:Hide()
      end
    else
      SetToUnknown()
    end

    locText:SetFont(smed:Fetch("font", db.font), db.fontsize, db.outline and "OUTLINE" or nil)
    locText:SetShadowColor(0, 0, 0, db.fontcolor.a)
    locText:SetShadowOffset(1, -1)
    locText:SetTextColor(db.fontcolor.r, db.fontcolor.g, db.fontcolor.b, db.fontcolor.a)

    timeText:SetFont(smed:Fetch("font", db.font), db.fontsize, db.outlinetime and "OUTLINE" or nil)
    timeText:SetShadowColor(0, 0, 0, db.fontcolor.a)
    timeText:SetShadowOffset(1, -1)
    timeText:SetTextColor(db.fontcolor.r, db.fontcolor.g, db.fontcolor.b, db.fontcolor.a)

    if db.inline then
      timeText:SetJustifyH("RIGHT")
      timeText:SetJustifyV("MIDDLE")
      SetPoints(timeText, "RIGHT", sb, "RIGHT", -4, 0)
      locText:SetJustifyH("LEFT")
      locText:SetJustifyV("MIDDLE")
      SetPoints(locText, "LEFT", sb, "LEFT", 4, 0, "RIGHT", timeText, "LEFT", -2, 0)
      locText:SetText(taxiDstName or "??")
    elseif db.twolines then
      timeText:SetJustifyH("CENTER")
      timeText:SetJustifyV("MIDDLE")
      SetPoints(timeText, "CENTER", sb, "CENTER", 0, 0)
      locText:SetJustifyH("CENTER")
      locText:SetJustifyV("BOTTOM")
      SetPoints(locText, "TOPLEFT", sb, "TOPLEFT", -24, db.fontsize*2.5, "BOTTOMRIGHT", sb, "TOPRIGHT", 24, (db.border=="None" and 1) or 3)
      locText:SetFormattedText("%s %s\n%s", taxiSrcName or "??", db.totext, taxiDstName or "??")
    else
      timeText:SetJustifyH("CENTER")
      timeText:SetJustifyV("MIDDLE")
      SetPoints(timeText, "CENTER", sb, "CENTER", 0, 0)
      locText:SetJustifyH("CENTER")
      locText:SetJustifyV("BOTTOM")
      SetPoints(locText, "TOPLEFT", sb, "TOPLEFT", -24, db.fontsize*2.5, "BOTTOMRIGHT", sb, "TOPRIGHT", 24, (db.border=="None" and 1) or 3)
      locText:SetFormattedText("%s %s %s", taxiSrcName or "??", db.totext, taxiDstName or "??")
    end
  end
end

---------------------------------
function InFlight:SetLayout(this)  -- setups the options in the default interface options
---------------------------------
  local t1 = this:CreateFontString(nil, "ARTWORK")
  t1:SetFontObject(GameFontNormalLarge)
  t1:SetJustifyH("LEFT")
  t1:SetJustifyV("TOP")
  t1:SetPoint("TOPLEFT", 16, -16)
  t1:SetText("|cff0040ffIn|cff00aaffFlight|r")
  this.tl = t1

  local t2 = this:CreateFontString(nil, "ARTWORK")
  t2:SetFontObject(GameFontHighlight)
  t2:SetJustifyH("LEFT")
  t2:SetJustifyV("TOP")
  SetPoints(t2, "TOPLEFT", t1, "BOTTOMLEFT", 0, -8, "RIGHT", this, "RIGHT", -32, 0)
  t2:SetNonSpaceWrap(true)
  local function GetInfo(field)
    return C_AddOns.GetAddOnMetadata("InFlight", field) or "N/A"
  end

  t2:SetFormattedText("|cff00aaffAuthor:|r %s\n|cff00aaffVersion:|r %s\n\n%s|r", GetInfo("Author"), GetInfo("Version"), GetInfo("Notes"))

  local b = CreateFrame("Button", nil, this, "UIPanelButtonTemplate")
  b:SetText(_G.GAMEOPTIONS_MENU)
  b:SetWidth(max(120, b:GetTextWidth() + 20))
  b:SetScript("OnClick", InFlight.ShowOptions)
  b:SetPoint("TOPLEFT", t2, "BOTTOMLEFT", -2, -8)

  this:SetScript("OnShow", nil)

  self.SetLayout = nil
end

-- options table
smed:Register("border", "Textured", "\\Interface\\None")  -- dummy border
local InFlightDD, offsetvalue, offsetcount, lastb
local info = { }
-------------------------------
function InFlight.ShowOptions()
-------------------------------
  if not InFlightDD then
    InFlightDD = CreateFrame("Frame", "InFlightDD", InFlight)
    InFlightDD.displayMode = "MENU"

    hooksecurefunc("ToggleDropDownMenu", function(...) lastb = select(8, ...) end)
    local function Exec(b, k, value)
      if k == "totext" then
        StaticPopupDialogs["InFlightToText"] = StaticPopupDialogs["InFlightToText"] or {
          text = L["Enter your 'to' text."],
          button1 = ACCEPT, button2 = CANCEL,
          hasEditBox = 1, maxLetters = 12,
          OnAccept = function(self)
            db.totext = strtrim(self.editBox:GetText())
            InFlight:UpdateLook()
          end,

          OnShow = function(self)
            self.editBox:SetText(db.totext)
            self.editBox:SetFocus()
          end,

          OnHide = function(self)
            self.editBox:SetText("")
          end,

          EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            db.totext = strtrim(parent.editBox:GetText())
            parent:Hide()
            InFlight:UpdateLook()
          end,

          EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
          end,

          timeout = 0, exclusive = 1, whileDead = 1, hideOnEscape = 1,
        }
        StaticPopup_Show("InFlightToText")
      elseif (k == "less" or k == "more") and lastb then
        local off = (k == "less" and -8) or 8
        if offsetvalue == value then
          offsetcount = offsetcount + off
        else
          offsetvalue, offsetcount = value, off
        end

        local tb = _G[gsub(lastb:GetName(), "ExpandArrow", "")]
        CloseDropDownMenus(b:GetParent():GetID())
        ToggleDropDownMenu(b:GetParent():GetID(), tb.value, nil, nil, nil, nil, tb.menuList, tb)
      elseif k == "resetoptions" then
        InFlight.db:ResetProfile()
        if InFlight.db:GetCurrentProfile() ~= "Default" then
          db.perchar = true
        end
      elseif k == "resettimes" then
        InFlightDB.dbinit = nil
        InFlightDB.global = {}
        ReloadUI()
      elseif k == "exporttimes" then
        InFlight:ExportDB()
      end
    end

    local function Set(b, k)
      if not k then
        return
      end

      db[k] = not db[k]
      if k == "perchar" then
        local charKey = UnitName("player").." - "..GetRealmName()
        if db[k] then
          db[k] = false
          InFlight.db:SetProfile(charKey)
          InFlight.db:CopyProfile("Default")
          db = InFlight.db.profile
          db[k] = true
        else
          InFlight.db:SetProfile("Default")
          db = InFlight.db.profile
          InFlight.db:DeleteProfile(charKey)
        end
      end

      InFlight:UpdateLook()
    end

    local function SetSelect(b, a1)
      db[a1] = tonumber(b.value) or b.value
      local level, num = strmatch(b:GetName(), "DropDownList(%d+)Button(%d+)")
      level, num = tonumber(level) or 0, tonumber(num) or 0
      for i = 1, UIDROPDOWNMENU_MAXBUTTONS, 1 do
        local b = _G["DropDownList"..level.."Button"..i.."Check"]
        if b then
          b[i == num and "Show" or "Hide"](b)
        end
      end

      InFlight:UpdateLook()
    end

    local function SetColor(a1)
      local dbc = db[UIDROPDOWNMENU_MENU_VALUE]
      if not dbc then
        return
      end

      if a1 then
        dbc.r, dbc.g, dbc.b, dbc.a = ColorPickerFrame:GetPreviousValues()
      else
        dbc.r, dbc.g, dbc.b = ColorPickerFrame:GetColorRGB()
        dbc.a = ColorPickerFrame:GetColorAlpha()
      end

      InFlight:UpdateLook()
    end

    local function AddButton(lvl, text, keepshown)
      info.text = text
      info.keepShownOnClick = keepshown
      UIDropDownMenu_AddButton(info, lvl)
      wipe(info)
    end

    local function AddToggle(lvl, text, value)
      info.arg1 = value
      info.func = Set
      info.checked = db[value]
      info.isNotRadio = true
      AddButton(lvl, text, true)
    end

    local function AddExecute(lvl, text, arg1, arg2)
      info.arg1 = arg1
      info.arg2 = arg2
      info.func = Exec
      info.notCheckable = 1
      AddButton(lvl, text, true)
    end

    local function AddColor(lvl, text, value)
      local dbc = db[value]
      if not dbc then
        return
      end

      info.padding = 5
      info.hasColorSwatch = true
      info.hasOpacity = 1
      info.r, info.g, info.b, info.opacity = dbc.r, dbc.g, dbc.b, dbc.a
      info.swatchFunc, info.opacityFunc, info.cancelFunc = SetColor, SetColor, SetColor
      info.value = value
      info.notCheckable = 1
      info.func = UIDropDownMenuButton_OpenColorPicker
      AddButton(lvl, text)
    end

    local function AddList(lvl, text, value)
      info.value = value
      info.hasArrow = true
      info.notCheckable = 1
      AddButton(lvl, text, true)
    end

    local function AddSelect(lvl, text, arg1, value)
      info.arg1 = arg1
      info.func = SetSelect
      info.value = value
      if tonumber(value) and tonumber(db[arg1] or "blah") then
        if floor(100 * tonumber(value)) == floor(100 * tonumber(db[arg1])) then
          info.checked = true
        end
      else
        info.checked = (db[arg1] == value)
      end

      AddButton(lvl, text, true)
    end

    local function AddFakeSlider(lvl, value, minv, maxv, step, tbl)
      local cvalue = 0
      local dbv = db[value]
      if type(dbv) == "string" and tbl then
        for i, v in ipairs(tbl) do
          if dbv == v then
            cvalue = i
            break
          end
        end
      else
        cvalue = dbv or ((maxv - minv) / 2)
      end

      local adj = (offsetvalue == value and offsetcount) or 0
      local starti = max(minv, cvalue - (7 - adj) * step)
      local endi = min(maxv, cvalue + (8 + adj) * step)
      if starti == minv then
        endi = min(maxv, starti + 16 * step)
      elseif endi == maxv then
        starti = max(minv, endi - 16 * step)
      end

      if starti > minv then
        AddExecute(lvl, "--", "less", value)
      end

      if tbl then
        for i = starti, endi, step do
          AddSelect(lvl, tbl[i], value, tbl[i])
        end
      else
        local fstring = (step >= 1 and "%d") or (step >= 0.1 and "%.1f") or "%.2f"
        for i = starti, endi, step do
          AddSelect(lvl, format(fstring, i), value, i)
        end
      end

      if endi < maxv then
        AddExecute(lvl, "++", "more", value)
      end
    end

    InFlightDD.initialize = function(self, lvl)
      if lvl == 1 then
        info.isTitle = true
        info.notCheckable = 1
        AddButton(lvl, "|cff0040ffIn|cff00aaffFlight|r")
        AddList(lvl, L["BarOptions"], "frame")
        AddList(lvl, L["TextOptions"], "text")
        AddList(lvl, _G.OTHER, "other")
      elseif lvl == 2 then
        local sub = UIDROPDOWNMENU_MENU_VALUE
        if sub == "frame" then
          AddToggle(lvl, L["CountUp"], "countup")
          AddToggle(lvl, L["FillUp"], "fill")
          AddToggle(lvl, L["ShowSpark"], "spark")
          AddList(lvl, L["Height"], "height")
          AddList(lvl, L["Width"], "width")
          AddList(lvl, L["Texture"], "texture")
          AddList(lvl, L["Border"], "border")
          AddColor(lvl, L["BackgroundColor"], "backcolor")
          AddColor(lvl, L["BarColor"], "barcolor")
          AddColor(lvl, L["UnknownColor"], "unknowncolor")
          AddColor(lvl, L["BorderColor"], "bordercolor")
        elseif sub == "text" then
          AddToggle(lvl, L["CompactMode"], "inline")
                    AddToggle(lvl, L["TwoLines"], "twolines")
          AddExecute(lvl, L["ToText"], "totext")
          AddList(lvl, L["Font"], "font")
          AddList(lvl, _G.FONT_SIZE, "fontsize")
          AddColor(lvl, L["FontColor"], "fontcolor")
          AddToggle(lvl, L["OutlineInfo"], "outline")
          AddToggle(lvl, L["OutlineTime"], "outlinetime")
        elseif sub == "other" then
          AddToggle(lvl, L["ShowChat"], "chatlog")
          AddToggle(lvl, L["ConfirmFlight"], "confirmflight")
          AddToggle(lvl, L["PerCharOptions"], "perchar")
          AddExecute(lvl, L["ResetOptions"], "resetoptions")
          AddExecute(lvl, L["ResetFlightTimes"], "resettimes")
          AddExecute(lvl, L["ExportFlightTimes"], "exporttimes")
        end
      elseif lvl == 3 then
        local sub = UIDROPDOWNMENU_MENU_VALUE
        if sub == "texture" or sub == "border" or sub == "font" then
          local t = smed:List(sub == "texture" and "statusbar" or sub)
          AddFakeSlider(lvl, sub, 1, #t, 1, t)
        elseif sub == "width" then
          AddFakeSlider(lvl, sub, 40, 500, 5)
        elseif sub == "height" then
          AddFakeSlider(lvl, sub, 4, 100, 1)
        elseif sub == "fontsize" then
          AddFakeSlider(lvl, sub, 4, 30, 1)
        end
      end
    end
  end

  ToggleDropDownMenu(1, nil, InFlightDD, "cursor")
end


