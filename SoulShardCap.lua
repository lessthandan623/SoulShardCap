--[[
  Soul Shard Cap  -  for World of Warcraft: Forever (Warlock)

  Your Soul Bag's size is your shard limit. 16-slot bag = 16 shards max.
  When a new shard goes over that limit, it is deleted on your NEXT key press
  (or when you click the on-screen button).

  Blizzard only lets addons delete items during a real key press or mouse
  click, one item per press, so no addon can stop the shard from landing
  in your bag.

  Slash commands:  /ssc  or  /soulshardcap
    /ssc            show status
    /ssc on | off   turn auto-delete on or off
    /ssc max 20     use a fixed limit instead of your Soul Bag size
    /ssc max auto   go back to using your Soul Bag size (default)
    /ssc button     show or hide the "Delete extra shard" button
    /ssc quiet      turn chat messages on or off
    /ssc debug      print a diagnostic report and turn on logging
    /ssc debug off  turn logging off
    /ssc debug clear  empty the log
]]

local ADDON_NAME = ...
local SHARD_ITEM_ID   = 6265   -- Soul Shard (Classic item ID)
local SOUL_BAG_FAMILY = 4      -- bag family flag for Soul Bags
-- Backpack (0), the four bag slots (1-4) and the extra bag slot (5).
-- On Forever the soul bag can sit in slot 5, the one the modern UI calls the
-- "Reagent Bag" slot, so we must scan it too.
local FIRST_BAG = 0
local LAST_BAG = math.max(5, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5)

-- Soul bag names, as a backup in case the game doesn't flag the bag as a soul bag.
local SOUL_BAG_NAME_PATTERNS = { "Soul", "Felcloth" }

local PREFIX = "|cff9482c9Soul Shard Cap:|r "
local LOG_MAX_LINES = 300
local db

-- Log lines are kept in SavedVariables, which the game writes to disk on
-- /reload or logout:  WTF\Account\<ACCOUNT>\SavedVariables\SoulShardCap.lua
local function Log(msg)
    if not (db and db.debug) then return end
    db.log = db.log or {}
    local clean = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    table.insert(db.log, date("%Y-%m-%d %H:%M:%S") .. "  " .. clean)
    while #db.log > LOG_MAX_LINES do table.remove(db.log, 1) end
end

local function Say(msg)
    print(PREFIX .. msg)
    Log(msg)
end

local function Debug(msg)
    if db and db.debug then
        print("|cffff8800SSC debug:|r " .. msg)
        Log("debug: " .. msg)
    end
end

local DEFAULTS = {
    enabled    = true,
    manualMax  = nil,   -- nil = use Soul Bag size
    showButton = true,
    verbose    = true,
    debug      = false,
}

local busy = false
local pending = false
local lastResult = "no delete attempted yet"
local keyPressesSeen = 0

-- True if 'flags' has the given bit set. Plain math, so it doesn't depend
-- on the 'bit' library being present in this client.
local function HasFlag(flags, flag)
    if type(flags) ~= "number" then return false end
    return math.floor(flags / flag) % 2 == 1
end

---------------------------------------------------------------------------
-- Bag scanning
---------------------------------------------------------------------------

local function GetBagName(bag)
    if C_Container.GetBagName then return C_Container.GetBagName(bag) end
    return nil
end

local function IsSoulBag(bag)
    if bag == 0 then return false end
    if (C_Container.GetContainerNumSlots(bag) or 0) == 0 then return false end
    local _, family = C_Container.GetContainerNumFreeSlots(bag)
    if HasFlag(family, SOUL_BAG_FAMILY) then return true end
    local name = GetBagName(bag)
    if type(name) == "string" then
        for _, pattern in ipairs(SOUL_BAG_NAME_PATTERNS) do
            if name:find(pattern) then return true end
        end
    end
    return false
end

local function GetCap()
    if db.manualMax then return db.manualMax, "your setting" end
    local cap = 0
    for bag = 1, LAST_BAG do
        if IsSoulBag(bag) then
            cap = cap + (C_Container.GetContainerNumSlots(bag) or 0)
        end
    end
    if cap > 0 then return cap, "Soul Bag size" end
    return nil
end

local function ScanShards()
    local total = 0
    local outsideBag, outsideSlot, soulBag, soulSlot
    for bag = FIRST_BAG, LAST_BAG do
        local soul = IsSoulBag(bag)
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            if C_Container.GetContainerItemID(bag, slot) == SHARD_ITEM_ID then
                local info = C_Container.GetContainerItemInfo(bag, slot)
                total = total + ((info and info.stackCount) or 1)
                if not (info and info.isLocked) then
                    if soul then
                        soulBag, soulSlot = bag, slot
                    else
                        outsideBag, outsideSlot = bag, slot
                    end
                end
            end
        end
    end
    if outsideBag then return total, outsideBag, outsideSlot end
    return total, soulBag, soulSlot
end

---------------------------------------------------------------------------
-- On-screen button (fallback, and works as /click SoulShardCapButton)
---------------------------------------------------------------------------

local button = CreateFrame("Button", "SoulShardCapButton", UIParent, "UIPanelButtonTemplate")
button:SetSize(190, 26)
button:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
button:SetText("Delete extra Soul Shard")
button:SetMovable(true)
button:SetClampedToScreen(true)
button:RegisterForDrag("LeftButton")
button:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
button:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
button:Hide()

---------------------------------------------------------------------------
-- Key-press listener (passes every key straight through to the game)
---------------------------------------------------------------------------

local keyListener = CreateFrame("Frame", "SoulShardCapKeyListener", UIParent)
keyListener:SetAllPoints(UIParent)
keyListener:SetFrameStrata("TOOLTIP")

local function SetListening(on)
    if InCombatLockdown() then return end
    local ok, err = pcall(function()
        keyListener:EnableKeyboard(on)
        keyListener:SetPropagateKeyboardInput(true)
    end)
    if not ok then Debug("Could not turn key listener " .. (on and "on" or "off") .. ": " .. tostring(err)) end
end

---------------------------------------------------------------------------
-- Core logic
---------------------------------------------------------------------------

local function UpdateState()
    local cap = GetCap()
    local total = ScanShards()
    pending = db.enabled and cap ~= nil and total > cap
    Debug(("Update: %d shards, limit %s, over limit = %s"):format(total, tostring(cap), tostring(pending)))

    if not InCombatLockdown() then
        SetListening(pending)
        button:SetShown(pending and db.showButton)
    end
end

local function TryDeleteOne(source)
    if not pending then return end
    Debug("Delete attempt from " .. source)
    if busy then lastResult = "skipped: still waiting on previous delete"; Debug(lastResult) return end
    if not db.enabled then lastResult = "skipped: addon is off"; Debug(lastResult) return end
    if InCombatLockdown() then lastResult = "skipped: in combat"; Debug(lastResult) return end
    if GetCursorInfo() then lastResult = "skipped: something is on your cursor"; Debug(lastResult) return end

    local cap = GetCap()
    if not cap then lastResult = "skipped: no limit (no Soul Bag found)"; Debug(lastResult) return end
    local total, bag, slot = ScanShards()
    if total <= cap then UpdateState() return end
    if not bag then lastResult = "skipped: every shard is locked"; Debug(lastResult) return end

    C_Container.PickupContainerItem(bag, slot)
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or itemID ~= SHARD_ITEM_ID then
        lastResult = ("pickup failed (bag %d slot %d, cursor had %s %s)"):format(bag, slot, tostring(kind), tostring(itemID))
        Debug(lastResult)
        ClearCursor()
        return
    end

    busy = true
    C_Timer.After(1, function() busy = false end)
    DeleteCursorItem()
    if GetCursorInfo() then
        lastResult = "the game refused the delete (shard was still on the cursor, put it back)"
        Debug(lastResult)
        ClearCursor()
        busy = false
        return
    end
    lastResult = ("deleted a shard from bag %d slot %d"):format(bag, slot)
    if db.verbose then
        Say(("Deleted 1 extra Soul Shard (%d/%d)."):format(total - 1, cap))
    end
end

keyListener:SetScript("OnKeyDown", function(_, key)
    keyPressesSeen = keyPressesSeen + 1
    if keyPressesSeen <= 3 then Debug("Key listener saw a key press: " .. tostring(key)) end
    TryDeleteOne("key " .. tostring(key))
end)
button:SetScript("OnClick", function() TryDeleteOne("button click") end)

---------------------------------------------------------------------------
-- Diagnostic report
---------------------------------------------------------------------------

local function ItemNameFromLink(link)
    if type(link) ~= "string" then return nil end
    return link:match("%[(.-)%]")
end

local function Report()
    Say("|cffffff00---- Diagnostic report (please copy or screenshot all of this) ----|r")
    local version, build, _, iface = GetBuildInfo()
    local addonVersion = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "?"
    Say(("Game %s build %s, interface %s. Addon %s"):format(tostring(version), tostring(build), tostring(iface), tostring(addonVersion)))
    Say(("Enabled: %s | manual limit: %s | in combat: %s"):format(
        tostring(db.enabled), tostring(db.manualMax), tostring(InCombatLockdown())))

    local shardIDs = {} -- itemID -> {name=, count=}
    for bag = FIRST_BAG, LAST_BAG do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        local name = GetBagName(bag) or "?"
        Say(("Bag %d: %s | %d slots | %s free | family %s | soul bag: %s"):format(
            bag, tostring(name), slots, tostring(free), tostring(family), IsSoulBag(bag) and "YES" or "no"))
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                local itemName = ItemNameFromLink(info.hyperlink) or info.itemName or "?"
                if itemName:find("Shard") or itemName:find("Soul") then
                    local id = info.itemID or C_Container.GetContainerItemID(bag, slot) or 0
                    local e = shardIDs[id] or { name = itemName, count = 0 }
                    e.count = e.count + (info.stackCount or 1)
                    shardIDs[id] = e
                end
            end
        end
    end

    local found = false
    for id, e in pairs(shardIDs) do
        found = true
        Say(("Item named '%s' has item ID %d, you have %d%s"):format(
            e.name, id, e.count, id == SHARD_ITEM_ID and " (this is the ID the addon looks for)" or ""))
    end
    if not found then Say("No item with 'Shard' or 'Soul' in its name found in your bags.") end

    local cap, source = GetCap()
    local total = ScanShards()
    Say(("Addon counts %d shards. Limit: %s (%s). Over limit: %s"):format(
        total, tostring(cap), tostring(source or "none"), tostring(pending)))
    Say(("Key listener on: %s | key presses it has seen: %d | button showing: %s"):format(
        tostring(keyListener:IsKeyboardEnabled()), keyPressesSeen, tostring(button:IsShown())))
    Say("Last delete attempt: " .. lastResult)
    Say("|cffffff00---- end of report ----|r")
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("ADDON_ACTION_BLOCKED")
events:RegisterEvent("ADDON_ACTION_FORBIDDEN")

events:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        SoulShardCapDB = SoulShardCapDB or {}
        db = SoulShardCapDB
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        self:UnregisterEvent("ADDON_LOADED")
        return
    end
    if not db then return end

    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if arg1 == ADDON_NAME then
            lastResult = ("the game BLOCKED %s (%s)"):format(tostring(arg2), event)
            Say("|cffff4444" .. lastResult .. "|r")
        end
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        SetListening(false)
        button:Hide()
        return
    end

    if event == "BAG_UPDATE_DELAYED" then busy = false end
    UpdateState()
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function Status()
    local cap, source = GetCap()
    local total = ScanShards()
    Say(("Auto-delete is %s."):format(db.enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    if cap then
        Say(("You have %d Soul Shards. Limit: %d (%s)."):format(total, cap, source))
    else
        Say(("You have %d Soul Shards. No Soul Bag found, so nothing will be deleted."):format(total))
        Say("Equip a Soul Bag, or set a limit with /ssc max <number>.")
    end
end

SLASH_SOULSHARDCAP1 = "/ssc"
SLASH_SOULSHARDCAP2 = "/soulshardcap"
SlashCmdList.SOULSHARDCAP = function(input)
    local cmd, arg = (input or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "on" then
        db.enabled = true;  Say("Auto-delete ON.")
    elseif cmd == "off" then
        db.enabled = false; Say("Auto-delete OFF.")
    elseif cmd == "max" then
        local n = tonumber(arg)
        if arg == "auto" or arg == "" then
            db.manualMax = nil; Say("Limit now follows your Soul Bag size.")
        elseif n and n >= 0 and n == math.floor(n) then
            db.manualMax = n;   Say(("Limit set to %d shards."):format(n))
        else
            Say("Usage: /ssc max <number>   or   /ssc max auto")
        end
    elseif cmd == "button" then
        db.showButton = not db.showButton
        Say("Button " .. (db.showButton and "shown when needed (Shift+drag to move)." or "hidden."))
    elseif cmd == "quiet" then
        db.verbose = not db.verbose
        Say("Chat messages " .. (db.verbose and "ON." or "OFF."))
    elseif cmd == "debug" and arg == "off" then
        db.debug = false
        Say("Debug logging OFF.")
    elseif cmd == "debug" and arg == "clear" then
        db.log = {}
        Say("Log cleared.")
    elseif cmd == "debug" then
        db.debug = true
        UpdateState()
        Report()
        Say("Debug logging is ON (stays on after /reload). Turn off with /ssc debug off.")
        Say("Log file is saved on /reload or logout: WTF\\Account\\<your account>\\SavedVariables\\SoulShardCap.lua")
        return
    else
        Status()
        Say("Commands: /ssc on | off | max <n> | max auto | button | quiet | debug | debug off")
    end
    UpdateState()
end
