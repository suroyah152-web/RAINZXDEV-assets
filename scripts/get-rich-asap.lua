--[[====================================================================
    MEGA EMPIRE AUTO FARM - PUCKUI EDITION
    Intended for testing/automation inside your own Roblox experience.

    PLACE:
      StarterPlayer > StarterPlayerScripts > LocalScript

    UI:
      Shared RAINZXDEV interface based on CleanStandaloneUI.
      Preferred Studio path: ReplicatedStorage > PuckUI (ModuleScript).
      Loader/executor path: shared GitHub PuckUI.lua.

    INCLUDED SYSTEMS:
      - Lemonade Stand
      - Garage Sale
      - Food Truck
      - Supermarket
      - Gas Station
      - Tech Company
      - Clothing Manufacturer
      - Logistics
      - Bank
      - Global Asset Manager
      - Real Estate / Property Empire (if PropertyEvents exist)

    MAIN FEATURES:
      - Master farm
      - Individual business farms
      - Automatic business buying
      - Automatic cash collection
      - Automatic upgrades
      - Automatic optimal price/rate/fee
      - Auto travel + proximity prompt hold
      - Clothing production presets
      - Global Asset Manager client automation
      - Upgrade strategies
      - Cash reserve
      - Adjustable loop speeds
      - Live business status
      - Manual action buttons
      - Shared RAINZXDEV sections/tabs
======================================================================]]

--======================================================================
-- SERVICES
--======================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Lua/Luau compatibility helpers.
local unpackValues = table.unpack or unpack
local packValues = table.pack or function(...)
	return { n = select("#", ...), ... }
end

--======================================================================
-- SHARED rainzxdev UI
--======================================================================

local PUCK_UI_URL =
    "https://raw.githubusercontent.com/RAINZXDEV/Puck-Loader/main/ui/PuckUI.lua"

local UI_BACKEND = "PuckUI Shared v1.1"

local function loadPuckUI()
    -- Studio-friendly option: place the same PuckUI.lua source in a
    -- ModuleScript named PuckUI under ReplicatedStorage.
    local packaged = ReplicatedStorage:FindFirstChild("PuckUI")
    if packaged and packaged:IsA("ModuleScript") then
        local ok, result = pcall(require, packaged)
        if ok and type(result) == "table" then
            UI_BACKEND = "PuckUI Shared v" .. tostring(result.Version or "local")
            return result
        end
    end

    -- Normal RAINZXDEV loader/executor path.
    if type(loadstring) == "function" then
        local ok, result = pcall(function()
            local source = game:HttpGet(PUCK_UI_URL)
            local chunk, compileError = loadstring(source)
            if not chunk then
                error("PuckUI compile failed: " .. tostring(compileError))
            end
            return chunk()
        end)

        if ok and type(result) == "table" then
            UI_BACKEND = "PuckUI Shared v" .. tostring(result.Version or "remote")
            return result
        end
    end

    error(
        "PuckUI could not be loaded. Upload ui/PuckUI.lua to RAINZXDEV/Puck-Loader "
        .. "or add a ReplicatedStorage.PuckUI ModuleScript in Studio."
    )
end

local PuckUI = loadPuckUI()

--======================================================================
-- OPTIONAL SHARED MODULES
--======================================================================

local BusinessCostUtil = nil

do
	local object = ReplicatedStorage:FindFirstChild("BusinessCostUtil")
	if object and object:IsA("ModuleScript") then
		local ok, result = pcall(require, object)
		if ok then
			BusinessCostUtil = result
		end
	end
end

local BusinessUnlockEvents = ReplicatedStorage:FindFirstChild("BusinessUnlockEvents")
local UnlockRequestStatus = BusinessUnlockEvents and BusinessUnlockEvents:FindFirstChild("RequestStatus")
local UnlockBuyBusiness = BusinessUnlockEvents and BusinessUnlockEvents:FindFirstChild("BuyBusiness")

--======================================================================
-- WINDOW (PUCKUI)
--======================================================================

local Window = PuckUI:CreateWindow({
	Name = "RAINZXDEV | Get Rich ASAP",
	ToggleUIKeybind = "K",
})

--======================================================================
-- GLOBAL SETTINGS
--======================================================================

local Settings = {
	MasterFarm = false,

	AutoBuyBusinesses = true,
	AutoCollect = true,
	AutoUpgrades = true,
	AutoOptimalPrice = true,
	AutoTravelOnPurchase = false,
	AutoInteractOnTravel = true,

	CashReserve = 0,
	MinimumCollect = 1,

	MainLoopDelay = 0.35,
	BusinessDelay = 0.06,
	ActionCooldown = 0.35,
	UpgradeCooldown = 0.75,
	PriceCooldown = 1.5,
	PurchaseCooldown = 2.0,
	TravelHeight = 3,

	UpgradeStrategy = "Cheapest",
	ClothingPreset = "Max Income",
	AssetRisk = "Aggressive",
	AssetGoal = "Growth",
	AssetAutoHire = true,

	Notifications = true,
}

--======================================================================
-- BUSINESS DEFINITIONS
--======================================================================

local Businesses = {
	{
		Key = "Lemonade",
		Name = "Lemonade Stand",
		Icon = "glass-water",
		ConfigName = "LemonadeStandConfig",
		EventsName = "LemonadeStandEvents",
		OwnedAttribute = "LemonadeStandOwned",
		PurchaseMode = "PerformAction",
		PriceAction = "SetPrice",
		PriceField = "CupPrice",
		OptimalField = "OptimalPrice",
		PromptNames = {"lemonadestandbusiness"},
	},
	{
		Key = "GarageSale",
		Name = "Garage Sale",
		Icon = "tag",
		ConfigName = "GarageSaleConfig",
		EventsName = "GarageSaleEvents",
		OwnedAttribute = "GarageSaleOwned",
		PurchaseMode = "PerformAction",
		PriceAction = "SetPrice",
		PriceField = "ItemPrice",
		OptimalField = "OptimalPrice",
		PromptNames = {"garagesalebuss"},
	},
	{
		Key = "FoodTruck",
		Name = "Food Truck",
		Icon = "truck",
		ConfigName = "FoodTruckConfig",
		EventsName = "FoodTruckEvents",
		OwnedAttribute = "FoodTruckOwned",
		PurchaseMode = "PerformAction",
		PriceAction = "SetPrice",
		PriceField = "MenuPrice",
		OptimalField = "OptimalPrice",
		PromptNames = {"FOODTRUCKBUSINESS"},
	},
	{
		Key = "Supermarket",
		Name = "Supermarket",
		Icon = "shopping-cart",
		ConfigName = "SupermarketConfig",
		EventsName = "SupermarketEvents",
		OwnedAttribute = "SupermarketOwned",
		PurchaseMode = "PerformAction",
		PriceAction = "SetPrice",
		PriceField = "ItemPrice",
		OptimalField = "OptimalPrice",
		PromptNames = {"Supermarketbusiness"},
	},
	{
		Key = "GasStation",
		Name = "Gas Station",
		Icon = "fuel",
		ConfigName = "GasStationConfig",
		EventsName = "GasStationEvents",
		OwnedAttribute = "GasStationOwned",
		PurchaseMode = "PerformAction",
		PriceAction = "SetPrice",
		PriceField = "FuelPrice",
		OptimalField = "OptimalPrice",
		PromptNames = {"gasstationgui"},
	},
	{
		Key = "TechCompany",
		Name = "Tech Company",
		Icon = "laptop",
		ConfigName = "TechCompanyConfig",
		EventsName = "TechCompanyEvents",
		OwnedAttribute = "TechCompanyOwned",
		PurchaseMode = "PerformAction",
		PriceAction = "SetPrice",
		PriceField = "LicensePrice",
		OptimalField = "OptimalPrice",
		PromptNames = {"TECHCOMPANYCOMPUTER"},
	},
	{
		Key = "Clothing",
		Name = "Clothing Manufacturer",
		Icon = "shirt",
		ConfigName = "ClothingManufacturerConfig",
		EventsName = "ClothingManufacturerEvents",
		OwnedAttribute = "ClothingManufacturerOwned",
		PurchaseMode = "PerformAction",
		PromptNames = {"CLOTHINGFACTORYGUI"},
		Special = "Clothing",
	},
	{
		Key = "Logistics",
		Name = "Logistics",
		Icon = "warehouse",
		ConfigName = "LogisticsConfig",
		EventsName = "LogisticsEvents",
		OwnedAttribute = "LogisticsBusinessOwned",
		PurchaseMode = "BusinessUnlock",
		BusinessId = "Logistics",
		PriceAction = "SetFreightRate",
		PriceField = "FreightRate",
		OptimalField = "OptimalFreight",
		PromptNames = {"Logisticsjob", "logisticsjob2", "logisticsjob3"},
	},
	{
		Key = "Bank",
		Name = "Bank",
		Icon = "landmark",
		ConfigName = "BankConfig",
		EventsName = "BankEvents",
		OwnedAttribute = "BankOwned",
		PurchaseMode = "PerformAction",
		PriceAction = "SetServiceFee",
		PriceField = "ServiceFee",
		OptimalField = "OptimalFee",
		PromptNames = {"BANKBUSINESS"},
	},
	{
		Key = "GlobalAssetManager",
		Name = "Global Asset Manager",
		Icon = "briefcase-business",
		ConfigName = "GlobalAssetManagerConfig",
		EventsName = "GlobalAssetManagerEvents",
		OwnedAttribute = "GlobalAssetManagerOwned",
		PurchaseMode = "PerformAction",
		PromptNames = {"Globalassetmanagerbusiness"},
		Special = "AssetManager",
	},
	{
		Key = "RealEstate",
		Name = "Property Empire",
		Icon = "house",
		ConfigName = "PropertyConfigs",
		EventsName = "PropertyEvents",
		OwnedAttribute = "RealEstateOwned",
		PurchaseMode = "BusinessUnlock",
		BusinessId = "RealEstate",
		PriceAction = "SetRentRate",
		PriceField = "RentRate",
		OptimalField = "OptimalRent",
		PromptNames = {"PropertyManagerComputer"},
		Optional = true,
	},
}

--======================================================================
-- STATE
--======================================================================

local Runtime = {}
local BusinessState = {}
local BusinessLabels = {}

local LastAction = {}
local LastUpgrade = {}
local LastPrice = {}
local LastPurchase = {}
local LastTravel = {}

local TotalCollectedCalls = 0
local TotalUpgradePurchases = 0
local TotalBusinessPurchases = 0

local Alive = true

for _, def in ipairs(Businesses) do
	BusinessState[def.Key] = {
		Enabled = true,
		LastData = nil,
		LastMessage = "Waiting",
		LastError = nil,
	}
end

--======================================================================
-- HELPERS
--======================================================================

local function now()
	return os.clock()
end

local function formatNumber(n)
	n = tonumber(n) or 0

	local negative = n < 0
	n = math.abs(n)

	local suffix = ""
	local divisor = 1

	if n >= 1e15 then
		suffix = "Q"
		divisor = 1e15
	elseif n >= 1e12 then
		suffix = "T"
		divisor = 1e12
	elseif n >= 1e9 then
		suffix = "B"
		divisor = 1e9
	elseif n >= 1e6 then
		suffix = "M"
		divisor = 1e6
	elseif n >= 1e3 then
		suffix = "K"
		divisor = 1e3
	end

	local value = n / divisor

	local result
	if suffix == "" then
		result = string.format("%.0f", value)
	elseif value >= 100 then
		result = string.format("%.0f%s", value, suffix)
	elseif value >= 10 then
		result = string.format("%.1f%s", value, suffix)
	else
		result = string.format("%.2f%s", value, suffix)
	end

	if negative then
		return "-" .. result
	end

	return result
end

local function getCashObject()
	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end

	return leaderstats:FindFirstChild("Cash")
end

local function getCash()
	local cash = getCashObject()
	return cash and tonumber(cash.Value) or 0
end

local function getCharacterRoot()
	local character = LocalPlayer.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function notify(title, content, image)
	if not Settings.Notifications then
		return
	end

	pcall(function()
		PuckUI:Notify({
			Title = title,
			Content = content,
			Duration = 4,
			Image = image or "circle-dollar-sign",
		})
	end)
end

local function setLabel(label, text)
	if not label then
		return
	end

	pcall(function()
		label:Set(text)
	end)
end

local function canRun(lastTable, key, cooldown)
	local t = lastTable[key] or 0
	if now() - t < cooldown then
		return false
	end

	lastTable[key] = now()
	return true
end

local function safeRequire(name)
	local module = ReplicatedStorage:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end

	local ok, result = pcall(require, module)
	if ok then
		return result
	end

	return nil
end

local function safeInvoke(remote, ...)
	if not remote or not remote:IsA("RemoteFunction") then
		return false, nil, "RemoteFunction missing"
	end

	local args = packValues(...)

	local ok, a, b, c = pcall(function()
		return remote:InvokeServer(unpackValues(args, 1, args.n))
	end)

	if not ok then
		return false, nil, tostring(a)
	end

	return true, a, b, c
end

local function purchasedSet(data)
	local result = {}

	if type(data) ~= "table" then
		return result
	end

	local list = data.PurchasedUpgrades

	if type(list) == "table" then
		for _, id in pairs(list) do
			result[id] = true
		end
	end

	return result
end

local function getDiscountedCost(value)
	value = tonumber(value) or 0

	if BusinessCostUtil and type(BusinessCostUtil.GetDiscountedCost) == "function" then
		local ok, result = pcall(
			BusinessCostUtil.GetDiscountedCost,
			LocalPlayer,
			value
		)

		if ok and tonumber(result) then
			return tonumber(result)
		end
	end

	return value
end

local function benefitScore(upgrade)
	if type(upgrade) ~= "table" then
		return 0
	end

	local score = 0

	score = score + (tonumber(upgrade.IncomeAddPerSecond) or 0)
	score = score + (tonumber(upgrade.IncomeMultAdd) or 0) * 10000000
	score = score + (tonumber(upgrade.ProductionMultAdd) or 0) * 8000000
	score = score + (tonumber(upgrade.TrafficMultAdd) or 0) * 4000000
	score = score + (tonumber(upgrade.DemandMultAdd) or 0) * 4000000
	score = score + (tonumber(upgrade.TrafficAdd) or 0) * 10000
	score = score + (tonumber(upgrade.RatingAdd) or 0) * 100000
	score = score + (tonumber(upgrade.OptimalPriceAdd) or 0) * 100000
	score = score + (tonumber(upgrade.OptimalFeeAdd) or 0) * 100000
	score = score + (tonumber(upgrade.OptimalFreightAdd) or 0) * 100000
	score = score + (tonumber(upgrade.VaultCapacityAdd) or 0) * 0.01
	score = score + (tonumber(upgrade.VaultBonusAdd) or 0) * 5000000
	score = score + (tonumber(upgrade.RiskReduce) or 0) * 100000

	return score
end

local function sortedUpgrades(def, data)
	local rt = Runtime[def.Key]

	if not rt or not rt.Config then
		return {}
	end

	local upgrades = rt.Config.Upgrades
	if type(upgrades) ~= "table" then
		return {}
	end

	local owned = purchasedSet(data)
	local list = {}

	for _, upgrade in pairs(upgrades) do
		if type(upgrade) == "table" and not owned[upgrade.Id] then
			table.insert(list, upgrade)
		end
	end

	table.sort(list, function(a, b)
		local costA = getDiscountedCost(a.Cost)
		local costB = getDiscountedCost(b.Cost)

		if Settings.UpgradeStrategy == "Most Expensive" then
			return costA > costB
		elseif Settings.UpgradeStrategy == "Best Benefit/Cost" then
			local ratioA = benefitScore(a) / math.max(costA, 1)
			local ratioB = benefitScore(b) / math.max(costB, 1)

			if math.abs(ratioA - ratioB) > 1e-9 then
				return ratioA > ratioB
			end

			return costA < costB
		end

		return costA < costB
	end)

	return list
end

--======================================================================
-- DISCOVER EACH BUSINESS
--======================================================================

local function discover(def)
	local rt = {
		Available = false,
		Config = nil,
		Events = nil,
		RequestData = nil,
		PerformAction = nil,
	}

	rt.Config = safeRequire(def.ConfigName)
	rt.Events = ReplicatedStorage:FindFirstChild(def.EventsName)

	if rt.Events then
		rt.RequestData = rt.Events:FindFirstChild("RequestData")
		rt.PerformAction = rt.Events:FindFirstChild("PerformAction")
	end

	rt.Available =
		rt.Config ~= nil
		and rt.Events ~= nil
		and rt.RequestData ~= nil
		and rt.PerformAction ~= nil

	Runtime[def.Key] = rt

	return rt
end

for _, def in ipairs(Businesses) do
	discover(def)
end

--======================================================================
-- DATA / OWNERSHIP
--======================================================================

local function requestData(def)
	local rt = Runtime[def.Key]

	if not rt or not rt.RequestData then
		return nil
	end

	local ok, data = safeInvoke(rt.RequestData)

	if ok and type(data) == "table" then
		BusinessState[def.Key].LastData = data
		return data
	end

	return nil
end

local function requestUnlockStatus(def)
	if def.PurchaseMode ~= "BusinessUnlock" then
		return nil
	end

	if not UnlockRequestStatus then
		return nil
	end

	local ok, status = safeInvoke(
		UnlockRequestStatus,
		def.BusinessId
	)

	if ok and type(status) == "table" then
		return status
	end

	return nil
end

local function isOwned(def, data)
	if LocalPlayer:GetAttribute(def.OwnedAttribute) == true then
		return true
	end

	if type(data) == "table" then
		if data.Owned == true then
			return true
		end

		if data.BusinessOwned == true then
			return true
		end

		if def.Key == "Logistics" and data.CanAccess == true then
			local status = requestUnlockStatus(def)
			if status and status.Owned == true then
				return true
			end
		end
	end

	if def.PurchaseMode == "BusinessUnlock" then
		local status = requestUnlockStatus(def)
		if status and status.Owned == true then
			return true
		end
	end

	return false
end

local function businessPrice(def, data)
	if def.PurchaseMode == "BusinessUnlock" then
		local status = requestUnlockStatus(def)

		if status then
			return tonumber(status.Price) or 0
		end
	end

	if type(data) == "table" and tonumber(data.BusinessPrice) then
		return tonumber(data.BusinessPrice)
	end

	local rt = Runtime[def.Key]

	if rt and rt.Config then
		return tonumber(rt.Config.BusinessPrice) or 0
	end

	return 0
end

--======================================================================
-- TELEPORT / INTERACTION
--======================================================================

local function findPromptPart(def)
	for _, name in ipairs(def.PromptNames or {}) do
		local object = Workspace:FindFirstChild(name, true)

		if object then
			if object:IsA("BasePart") then
				return object
			end

			local part = object:FindFirstChildWhichIsA("BasePart", true)
			if part then
				return part
			end
		end
	end

	return nil
end

local function holdPrompt(part)
	if not part then
		return false
	end

	local prompt = part:FindFirstChildOfClass("ProximityPrompt")

	if not prompt then
		prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true)
	end

	if not prompt then
		return false
	end

	local ok = pcall(function()
		prompt:InputHoldBegin()

		task.wait(
			math.max(
				tonumber(prompt.HoldDuration) or 0,
				0.05
			) + 0.08
		)

		prompt:InputHoldEnd()
	end)

	return ok
end

local function travelToBusiness(def)
	if not canRun(LastTravel, def.Key, 0.75) then
		return false
	end

	local part = findPromptPart(def)

	if not part then
		BusinessState[def.Key].LastMessage =
			"Interaction part not found"
		return false
	end

	local root = getCharacterRoot()

	if not root then
		BusinessState[def.Key].LastMessage =
			"Character not ready"
		return false
	end

	root.CFrame =
		part.CFrame
		*
		CFrame.new(
			0,
			Settings.TravelHeight,
			3
		)

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	task.wait(0.15)

	if Settings.AutoInteractOnTravel then
		holdPrompt(part)
	end

	BusinessState[def.Key].LastMessage =
		"Travelled to " .. def.Name

	return true
end

--======================================================================
-- BUSINESS PURCHASE
--======================================================================

local function buyBusiness(def, data, force)
	if isOwned(def, data) then
		return true
	end

	if not force and not Settings.AutoBuyBusinesses then
		return false
	end

	if not canRun(
		LastPurchase,
		def.Key,
		Settings.PurchaseCooldown
	) then
		return false
	end

	local price = businessPrice(def, data)
	local spendable = getCash() - Settings.CashReserve

	if price > 0 and spendable < price then
		BusinessState[def.Key].LastMessage =
			"Saving for " .. def.Name
			.. " ($" .. formatNumber(price) .. ")"
		return false
	end

	if Settings.AutoTravelOnPurchase then
		travelToBusiness(def)
	end

	local ok, accepted, message

	if def.PurchaseMode == "BusinessUnlock" then
		if not UnlockBuyBusiness then
			BusinessState[def.Key].LastMessage =
				"BusinessUnlock BuyBusiness missing"
			return false
		end

		ok, accepted, message =
			safeInvoke(
				UnlockBuyBusiness,
				def.BusinessId
			)
	else
		local rt = Runtime[def.Key]

		if not rt or not rt.PerformAction then
			return false
		end

		ok, accepted, message =
			safeInvoke(
				rt.PerformAction,
				"BuyBusiness"
			)
	end

	if ok and accepted == true then
		LocalPlayer:SetAttribute(
			def.OwnedAttribute,
			true
		)

		TotalBusinessPurchases = TotalBusinessPurchases + 1

		BusinessState[def.Key].LastMessage =
			tostring(message or "Business purchased")

		notify(
			def.Name,
			"Business purchased.",
			def.Icon
		)

		return true
	end

	if ok then
		BusinessState[def.Key].LastMessage =
			tostring(message or "Purchase rejected")
	else
		BusinessState[def.Key].LastMessage =
			"Purchase request failed"
	end

	return false
end

--======================================================================
-- CASH OUT
--======================================================================

local function cashOut(def, data, force)
	if not force and not Settings.AutoCollect then
		return false
	end

	if not isOwned(def, data) then
		return false
	end

	local unclaimed =
		type(data) == "table"
		and tonumber(data.UnclaimedEarnings)
		or nil

	if not force and unclaimed and unclaimed < Settings.MinimumCollect then
		return false
	end

	if not force and unclaimed and unclaimed <= 0 then
		return false
	end

	if not canRun(
		LastAction,
		def.Key .. ":CashOut",
		Settings.ActionCooldown
	) then
		return false
	end

	local rt = Runtime[def.Key]

	if not rt or not rt.PerformAction then
		return false
	end

	local ok, accepted, message =
		safeInvoke(
			rt.PerformAction,
			"CashOut"
		)

	if ok and accepted == true then
		TotalCollectedCalls = TotalCollectedCalls + 1

		BusinessState[def.Key].LastMessage =
			tostring(
				message
				or
				("Collected $" .. formatNumber(unclaimed or 0))
			)

		return true
	end

	return false
end

--======================================================================
-- OPTIMAL PRICE / RATE / FEE
--======================================================================

local function setOptimal(def, data, force)
	if not def.PriceAction then
		return false
	end

	if not force and not Settings.AutoOptimalPrice then
		return false
	end

	if not isOwned(def, data) then
		return false
	end

	if type(data) ~= "table" then
		return false
	end

	local current = tonumber(data[def.PriceField])
	local optimal = tonumber(data[def.OptimalField])

	if not current or not optimal then
		return false
	end

	if math.abs(current - optimal) < 0.0001 then
		return false
	end

	if not canRun(
		LastPrice,
		def.Key,
		Settings.PriceCooldown
	) then
		return false
	end

	local rt = Runtime[def.Key]

	if not rt or not rt.PerformAction then
		return false
	end

	local payload = {}
	payload[def.PriceField] = optimal

	local ok, accepted, message =
		safeInvoke(
			rt.PerformAction,
			def.PriceAction,
			payload
		)

	if ok and accepted == true then
		BusinessState[def.Key].LastMessage =
			tostring(
				message
				or
				("Optimal " .. def.PriceField .. " set")
			)

		return true
	end

	return false
end

--======================================================================
-- BUY UPGRADE
--======================================================================

local function buyNextUpgrade(def, data, force)
	if not force and not Settings.AutoUpgrades then
		return false
	end

	if not isOwned(def, data) then
		return false
	end

	if not canRun(
		LastUpgrade,
		def.Key,
		Settings.UpgradeCooldown
	) then
		return false
	end

	local upgrades = sortedUpgrades(def, data)

	if #upgrades == 0 then
		return false
	end

	local spendable =
		getCash()
		-
		Settings.CashReserve

	for _, upgrade in ipairs(upgrades) do
		local cost =
			getDiscountedCost(
				upgrade.Cost
			)

		if spendable >= cost then
			local rt = Runtime[def.Key]

			if not rt or not rt.PerformAction then
				return false
			end

			local ok, accepted, message =
				safeInvoke(
					rt.PerformAction,
					"BuyUpgrade",
					{
						UpgradeId = upgrade.Id
					}
				)

			if ok and accepted == true then
				TotalUpgradePurchases = TotalUpgradePurchases + 1

				BusinessState[def.Key].LastMessage =
					tostring(
						message
						or
						(
							"Bought "
							..
							tostring(
								upgrade.Name
								or
								upgrade.Id
							)
						)
					)

				return true
			end

			return false
		end
	end

	return false
end

--======================================================================
-- CLOTHING SPECIAL AUTOMATION
--======================================================================

local ClothingPresets = {
	["Max Income"] = {
		ProductId = "Suit",
		MaterialId = "Silk",
		DesignId = "Exclusive",
	},
	["Balanced"] = {
		ProductId = "Jacket",
		MaterialId = "Denim",
		DesignId = "Premium",
	},
	["Low Risk"] = {
		ProductId = "TShirt",
		MaterialId = "Cotton",
		DesignId = "Basic",
	},
}

local function setClothingChoice(rt, action, field, value)
	local payload = {}
	payload[field] = value

	local ok, accepted =
		safeInvoke(
			rt.PerformAction,
			action,
			payload
		)

	return ok and accepted == true
end

local function runClothingSpecial(def, data)
	if type(data) ~= "table" then
		return
	end

	if not isOwned(def, data) then
		return
	end

	local rt = Runtime[def.Key]
	if not rt or not rt.PerformAction then
		return
	end

	local preset =
		ClothingPresets[Settings.ClothingPreset]
		or
		ClothingPresets["Max Income"]

	if data.ProductId ~= preset.ProductId then
		if canRun(LastAction, def.Key .. ":Product", 1.0) then
			setClothingChoice(
				rt,
				"SetProduct",
				"ProductId",
				preset.ProductId
			)
		end
	end

	if data.MaterialId ~= preset.MaterialId then
		if canRun(LastAction, def.Key .. ":Material", 1.0) then
			setClothingChoice(
				rt,
				"SetMaterial",
				"MaterialId",
				preset.MaterialId
			)
		end
	end

	if data.DesignId ~= preset.DesignId then
		if canRun(LastAction, def.Key .. ":Design", 1.0) then
			setClothingChoice(
				rt,
				"SetDesign",
				"DesignId",
				preset.DesignId
			)
		end
	end
end

--======================================================================
-- ASSET MANAGER SPECIAL AUTOMATION
--======================================================================

local function autoConfigureClients(def, data)
	if type(data) ~= "table" then
		return
	end

	local rt = Runtime[def.Key]

	if not rt or not rt.PerformAction then
		return
	end

	local clients = data.Clients

	if type(clients) == "table" then
		for _, client in pairs(clients) do
			if type(client) == "table" and client.Id ~= nil then
				if client.Risk ~= Settings.AssetRisk then
					if canRun(
						LastAction,
						def.Key .. ":Risk:" .. tostring(client.Id),
						2.0
					) then
						safeInvoke(
							rt.PerformAction,
							"SetClientRisk",
							{
								ClientId = client.Id,
								Risk = Settings.AssetRisk
							}
						)
					end
				end

				if client.Goal ~= Settings.AssetGoal then
					if canRun(
						LastAction,
						def.Key .. ":Goal:" .. tostring(client.Id),
						2.0
					) then
						safeInvoke(
							rt.PerformAction,
							"SetClientGoal",
							{
								ClientId = client.Id,
								Goal = Settings.AssetGoal
							}
						)
					end
				end
			end
		end
	end
end

local function autoHireAssetClient(def, data)
	if not Settings.AssetAutoHire then
		return
	end

	if type(data) ~= "table" then
		return
	end

	local count = tonumber(data.ClientCount) or 0
	local maxClients = tonumber(data.MaxClients) or 0

	if maxClients > 0 and count >= maxClients then
		return
	end

	if not canRun(
		LastAction,
		def.Key .. ":Hire",
		2.5
	) then
		return
	end

	local rt = Runtime[def.Key]

	if not rt or not rt.Config or not rt.PerformAction then
		return
	end

	local tiers = rt.Config.HireTiers

	if type(tiers) ~= "table" then
		return
	end

	local candidates = {}

	for _, tier in pairs(tiers) do
		if type(tier) == "table" then
			table.insert(candidates, tier)
		end
	end

	table.sort(candidates, function(a, b)
		return (tonumber(a.Cost) or 0) > (tonumber(b.Cost) or 0)
	end)

	local spendable =
		getCash()
		-
		Settings.CashReserve

	for _, tier in ipairs(candidates) do
		local cost = tonumber(tier.Cost) or 0

		if spendable >= cost then
			local ok, accepted, message =
				safeInvoke(
					rt.PerformAction,
					"HireClient",
					{
						TierId = tier.Id
					}
				)

			if ok and accepted == true then
				BusinessState[def.Key].LastMessage =
					tostring(
						message
						or
						("Hired " .. tostring(tier.Label or tier.Id))
					)
				return
			end
		end
	end
end

local function runAssetSpecial(def, data)
	if not isOwned(def, data) then
		return
	end

	autoConfigureClients(def, data)
	autoHireAssetClient(def, data)
end

--======================================================================
-- ONE BUSINESS FARM CYCLE
--======================================================================

local function farmBusiness(def)
	local rt = Runtime[def.Key]

	if not rt or not rt.Available then
		BusinessState[def.Key].LastMessage =
			"System unavailable"
		return
	end

	local data = requestData(def)

	if not data then
		BusinessState[def.Key].LastMessage =
			"RequestData failed"
		return
	end

	if not isOwned(def, data) then
		buyBusiness(def, data, false)
		return
	end

	setOptimal(def, data, false)

	if def.Special == "Clothing" then
		runClothingSpecial(def, data)
	elseif def.Special == "AssetManager" then
		runAssetSpecial(def, data)
	end

	cashOut(def, data, false)
	buyNextUpgrade(def, data, false)
end

--======================================================================
-- LIVE STATUS TEXT
--======================================================================

local function describeBusiness(def)
	local rt = Runtime[def.Key]
	local state = BusinessState[def.Key]

	if not rt or not rt.Available then
		return "Unavailable / missing modules or remotes."
	end

	local data = state.LastData

	if type(data) ~= "table" then
		return "Ready. No server snapshot yet."
	end

	local owned = isOwned(def, data)
	local income = tonumber(data.IncomePerSecond) or 0
	local unclaimed = tonumber(data.UnclaimedEarnings) or 0

	local parts = {
		owned and "OWNED" or "LOCKED",
		"Income $" .. formatNumber(income) .. "/sec",
		"Unclaimed $" .. formatNumber(unclaimed),
	}

	if def.PriceField then
		local current = tonumber(data[def.PriceField])
		local optimal = tonumber(data[def.OptimalField])

		if current then
			table.insert(
				parts,
				def.PriceField .. " " .. tostring(current)
			)
		end

		if optimal then
			table.insert(
				parts,
				"Optimal " .. tostring(optimal)
			)
		end
	end

	if def.Key == "Clothing" then
		table.insert(
			parts,
			"Risk " .. formatNumber(data.RiskPercent or 0) .. "%"
		)

		table.insert(
			parts,
			"Setup "
			..
			tostring(data.ProductId or "?")
			..
			"/"
			..
			tostring(data.MaterialId or "?")
			..
			"/"
			..
			tostring(data.DesignId or "?")
		)
	end

	if def.Key == "GlobalAssetManager" then
		table.insert(
			parts,
			"Clients "
			..
			tostring(data.ClientCount or 0)
			..
			"/"
			..
			tostring(data.MaxClients or 0)
		)

		table.insert(
			parts,
			"Portfolio $"
			..
			formatNumber(data.TotalPortfolio or 0)
		)
	end

	if def.Key == "Bank" then
		table.insert(
			parts,
			"Vault $"
			..
			formatNumber(data.VaultBalance or 0)
			..
			"/$"
			..
			formatNumber(data.VaultCapacity or 0)
		)
	end

	if def.Key == "Logistics" then
		table.insert(
			parts,
			"Shipments "
			..
			tostring(
				math.floor(
					tonumber(data.ShipmentsPerSecond)
					or 0
				)
			)
		)
	end

	return table.concat(parts, "  |  ")
end

--======================================================================
-- DASHBOARD TAB
--======================================================================

local DashboardTab =
	Window:CreateTab(
		"Dashboard",
		0
	)

DashboardTab:CreateSection(
	"Master Automation"
)

DashboardTab:CreateToggle({
	Name = "Master Auto Farm",
	CurrentValue = false,
	Flag = "MasterAutoFarm",
	Callback = function(value)
		Settings.MasterFarm = value

		if value then
			notify(
				"RAINZXDEV | Get Rich ASAP",
				"Master farming enabled.",
				"play"
			)
		else
			notify(
				"RAINZXDEV | Get Rich ASAP",
				"Master farming stopped.",
				"square"
			)
		end
	end,
})

DashboardTab:CreateToggle({
	Name = "Auto Buy Businesses",
	CurrentValue = Settings.AutoBuyBusinesses,
	Flag = "AutoBuyBusinesses",
	Callback = function(value)
		Settings.AutoBuyBusinesses = value
	end,
})

DashboardTab:CreateToggle({
	Name = "Auto Collect All Earnings",
	CurrentValue = Settings.AutoCollect,
	Flag = "AutoCollectAll",
	Callback = function(value)
		Settings.AutoCollect = value
	end,
})

DashboardTab:CreateToggle({
	Name = "Auto Buy Upgrades",
	CurrentValue = Settings.AutoUpgrades,
	Flag = "AutoUpgradesAll",
	Callback = function(value)
		Settings.AutoUpgrades = value
	end,
})

DashboardTab:CreateToggle({
	Name = "Auto Optimal Prices / Rates",
	CurrentValue = Settings.AutoOptimalPrice,
	Flag = "AutoOptimalAll",
	Callback = function(value)
		Settings.AutoOptimalPrice = value
	end,
})

DashboardTab:CreateSection(
	"Business Selection"
)

DashboardTab:CreateButton({
	Name = "Enable Every Business",
	Callback = function()
		for _, def in ipairs(Businesses) do
			BusinessState[def.Key].Enabled = true

			local toggle =
				BusinessLabels[
					def.Key .. ":Toggle"
				]

			if toggle then
				pcall(function()
					toggle:Set(true)
				end)
			end
		end

		notify(
			"Business Selection",
			"Every discovered business enabled.",
			"check"
		)
	end,
})

DashboardTab:CreateButton({
	Name = "Disable Every Business",
	Callback = function()
		for _, def in ipairs(Businesses) do
			BusinessState[def.Key].Enabled = false

			local toggle =
				BusinessLabels[
					def.Key .. ":Toggle"
				]

			if toggle then
				pcall(function()
					toggle:Set(false)
				end)
			end
		end
	end,
})

DashboardTab:CreateSection(
	"Live Account"
)

local UIBackendLabel =
	DashboardTab:CreateLabel(
		"UI backend: " .. UI_BACKEND,
		0
	)

local CashLabel =
	DashboardTab:CreateLabel(
		"Cash: $0",
		0
	)

local MasterStatusLabel =
	DashboardTab:CreateLabel(
		"Master farm: OFF",
		0
	)

local TotalsLabel =
	DashboardTab:CreateLabel(
		"Collections 0 | Upgrades 0 | Businesses 0",
		0
	)

DashboardTab:CreateSection(
	"Quick Actions"
)

DashboardTab:CreateButton({
	Name = "Collect Every Owned Business Now",
	Callback = function()
		task.spawn(function()
			for _, def in ipairs(Businesses) do
				local rt = Runtime[def.Key]

				if rt and rt.Available then
					local data = requestData(def)

					if data and isOwned(def, data) then
						cashOut(def, data, true)
						task.wait(0.08)
					end
				end
			end
		end)
	end,
})

DashboardTab:CreateButton({
	Name = "Set Every Business To Optimal Price",
	Callback = function()
		task.spawn(function()
			for _, def in ipairs(Businesses) do
				if def.PriceAction then
					local data = requestData(def)

					if data and isOwned(def, data) then
						setOptimal(def, data, true)
						task.wait(0.08)
					end
				end
			end
		end)
	end,
})

DashboardTab:CreateButton({
	Name = "Buy One Upgrade In Every Business",
	Callback = function()
		task.spawn(function()
			for _, def in ipairs(Businesses) do
				local data = requestData(def)

				if data and isOwned(def, data) then
					buyNextUpgrade(def, data, true)
					task.wait(0.08)
				end
			end
		end)
	end,
})

DashboardTab:CreateButton({
	Name = "Refresh Every Business",
	Callback = function()
		task.spawn(function()
			for _, def in ipairs(Businesses) do
				if Runtime[def.Key] and Runtime[def.Key].Available then
					requestData(def)
					task.wait(0.04)
				end
			end
		end)
	end,
})

--======================================================================
-- SETTINGS TAB
--======================================================================

local SettingsTab =
	Window:CreateTab(
		"Settings",
		0
	)

SettingsTab:CreateSection(
	"Farm Timing"
)

SettingsTab:CreateSlider({
	Name = "Main Loop Delay",
	Range = {0.1, 2},
	Increment = 0.05,
	Suffix = " sec",
	CurrentValue = Settings.MainLoopDelay,
	Flag = "MainLoopDelay",
	Callback = function(value)
		Settings.MainLoopDelay = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Delay Between Businesses",
	Range = {0.02, 0.5},
	Increment = 0.01,
	Suffix = " sec",
	CurrentValue = Settings.BusinessDelay,
	Flag = "BusinessDelay",
	Callback = function(value)
		Settings.BusinessDelay = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Cash Out Cooldown",
	Range = {0.1, 5},
	Increment = 0.05,
	Suffix = " sec",
	CurrentValue = Settings.ActionCooldown,
	Flag = "ActionCooldown",
	Callback = function(value)
		Settings.ActionCooldown = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Upgrade Cooldown",
	Range = {0.2, 10},
	Increment = 0.1,
	Suffix = " sec",
	CurrentValue = Settings.UpgradeCooldown,
	Flag = "UpgradeCooldown",
	Callback = function(value)
		Settings.UpgradeCooldown = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Price Update Cooldown",
	Range = {0.5, 10},
	Increment = 0.25,
	Suffix = " sec",
	CurrentValue = Settings.PriceCooldown,
	Flag = "PriceCooldown",
	Callback = function(value)
		Settings.PriceCooldown = value
	end,
})

SettingsTab:CreateSection(
	"Money Management"
)

SettingsTab:CreateInput({
	Name = "Cash Reserve",
	CurrentValue = tostring(Settings.CashReserve),
	PlaceholderText = "Money kept unspent",
	RemoveTextAfterFocusLost = false,
	Flag = "CashReserve",
	Callback = function(text)
		local value = tonumber(text)
		if value and value >= 0 then
			Settings.CashReserve = value
		end
	end,
})

SettingsTab:CreateInput({
	Name = "Minimum Unclaimed Before Collecting",
	CurrentValue = tostring(Settings.MinimumCollect),
	PlaceholderText = "1",
	RemoveTextAfterFocusLost = false,
	Flag = "MinimumCollect",
	Callback = function(text)
		local value = tonumber(text)
		if value and value >= 0 then
			Settings.MinimumCollect = value
		end
	end,
})

SettingsTab:CreateDropdown({
	Name = "Upgrade Strategy",
	Options = {
		"Cheapest",
		"Most Expensive",
		"Best Benefit/Cost"
	},
	CurrentOption = {
		Settings.UpgradeStrategy
	},
	MultipleOptions = false,
	Flag = "UpgradeStrategy",
	Callback = function(options)
		if type(options) == "table" and options[1] then
			Settings.UpgradeStrategy = options[1]
		end
	end,
})

SettingsTab:CreateSection(
	"Movement / Interaction"
)

SettingsTab:CreateToggle({
	Name = "Travel To Business Before Buying",
	CurrentValue = Settings.AutoTravelOnPurchase,
	Flag = "TravelOnPurchase",
	Callback = function(value)
		Settings.AutoTravelOnPurchase = value
	end,
})

SettingsTab:CreateToggle({
	Name = "Automatically Hold Prompt On Travel",
	CurrentValue = Settings.AutoInteractOnTravel,
	Flag = "AutoHoldPrompt",
	Callback = function(value)
		Settings.AutoInteractOnTravel = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Teleport Height",
	Range = {0, 8},
	Increment = 0.5,
	Suffix = " studs",
	CurrentValue = Settings.TravelHeight,
	Flag = "TravelHeight",
	Callback = function(value)
		Settings.TravelHeight = value
	end,
})

SettingsTab:CreateSection(
	"Notifications"
)

SettingsTab:CreateToggle({
	Name = "RAINZXDEV Notifications",
	CurrentValue = Settings.Notifications,
	Flag = "Notifications",
	Callback = function(value)
		Settings.Notifications = value
	end,
})

--======================================================================
-- CLOTHING SETTINGS TAB
--======================================================================

local ProductionTab =
	Window:CreateTab(
		"Production",
		0
	)

ProductionTab:CreateSection(
	"Clothing Manufacturer"
)

ProductionTab:CreateDropdown({
	Name = "Factory Production Preset",
	Options = {
		"Max Income",
		"Balanced",
		"Low Risk"
	},
	CurrentOption = {
		Settings.ClothingPreset
	},
	MultipleOptions = false,
	Flag = "ClothingPreset",
	Callback = function(options)
		if type(options) == "table" and options[1] then
			Settings.ClothingPreset = options[1]
		end
	end,
})

ProductionTab:CreateParagraph({
	Title = "Max Income",
	Content =
		"Suit + Silk + Exclusive Collection. "
		..
		"Highest raw production-income preset from the supplied config, "
		..
		"but it also carries high production risk."
})

ProductionTab:CreateParagraph({
	Title = "Low Risk",
	Content =
		"Basic T-Shirts + Cotton + Basic design. "
		..
		"Lower income but the lowest raw configuration risk."
})

ProductionTab:CreateSection(
	"Global Asset Manager"
)

ProductionTab:CreateToggle({
	Name = "Auto Hire Clients",
	CurrentValue = Settings.AssetAutoHire,
	Flag = "AssetAutoHire",
	Callback = function(value)
		Settings.AssetAutoHire = value
	end,
})

ProductionTab:CreateDropdown({
	Name = "Client Risk",
	Options = {
		"Conservative",
		"Moderate",
		"Aggressive"
	},
	CurrentOption = {
		Settings.AssetRisk
	},
	MultipleOptions = false,
	Flag = "AssetRisk",
	Callback = function(options)
		if type(options) == "table" and options[1] then
			Settings.AssetRisk = options[1]
		end
	end,
})

ProductionTab:CreateDropdown({
	Name = "Client Goal",
	Options = {
		"Growth",
		"Income",
		"Preservation"
	},
	CurrentOption = {
		Settings.AssetGoal
	},
	MultipleOptions = false,
	Flag = "AssetGoal",
	Callback = function(options)
		if type(options) == "table" and options[1] then
			Settings.AssetGoal = options[1]
		end
	end,
})

--======================================================================
-- GENERATE BUSINESS TABS
--======================================================================

for _, def in ipairs(Businesses) do
	local tab =
		Window:CreateTab(
			def.Name,
			0
		)

	tab:CreateSection(
		"Automation"
	)

	local toggle =
		tab:CreateToggle({
			Name = "Include In Master Farm",
			CurrentValue = BusinessState[def.Key].Enabled,
			Flag = "Farm_" .. def.Key,
			Callback = function(value)
				BusinessState[def.Key].Enabled = value
			end,
		})

	BusinessLabels[
		def.Key .. ":Toggle"
	] = toggle

	tab:CreateButton({
		Name = "Run One Full Farm Cycle",
		Callback = function()
			task.spawn(function()
				farmBusiness(def)
			end)
		end,
	})

	tab:CreateSection(
		"Manual Management"
	)

	tab:CreateButton({
		Name = "Buy Business",
		Callback = function()
			task.spawn(function()
				local data = requestData(def)
				buyBusiness(def, data, true)
			end)
		end,
	})

	tab:CreateButton({
		Name = "Collect Earnings",
		Callback = function()
			task.spawn(function()
				local data = requestData(def)
				if data then
					cashOut(def, data, true)
				end
			end)
		end,
	})

	tab:CreateButton({
		Name = "Buy Next Upgrade",
		Callback = function()
			task.spawn(function()
				local data = requestData(def)
				if data then
					buyNextUpgrade(def, data, true)
				end
			end)
		end,
	})

	if def.PriceAction then
		tab:CreateButton({
			Name = "Set Optimal "
				..
				(
					def.Key == "RealEstate"
					and "Rent"
					or
					(
						def.Key == "Logistics"
						and "Freight Rate"
						or
						(
							def.Key == "Bank"
							and "Service Fee"
							or "Price"
						)
					)
				),
			Callback = function()
				task.spawn(function()
					local data = requestData(def)
					if data then
						setOptimal(def, data, true)
					end
				end)
			end,
		})
	end

	tab:CreateSection(
		"World Interaction"
	)

	tab:CreateButton({
		Name = "Travel + Hold Interaction",
		Callback = function()
			task.spawn(function()
				travelToBusiness(def)
			end)
		end,
	})

	tab:CreateButton({
		Name = "Refresh Server Data",
		Callback = function()
			task.spawn(function()
				requestData(def)
			end)
		end,
	})

	tab:CreateSection(
		"Live Status"
	)

	local availability =
		Runtime[def.Key]
		and Runtime[def.Key].Available
		and "READY"
		or "MISSING"

	local systemLabel =
		tab:CreateLabel(
			"System: " .. availability,
			availability == "READY"
				and "circle-check"
				or "circle-x"
		)

	local liveLabel =
		tab:CreateLabel(
			"Waiting for server snapshot...",
			0
		)

	local messageLabel =
		tab:CreateLabel(
			"Last: Waiting",
			0
		)

	BusinessLabels[
		def.Key .. ":System"
	] = systemLabel

	BusinessLabels[
		def.Key .. ":Live"
	] = liveLabel

	BusinessLabels[
		def.Key .. ":Message"
	] = messageLabel

	if def.Special == "Clothing" then
		tab:CreateSection(
			"Factory Presets"
		)

		tab:CreateButton({
			Name = "Apply Current Production Preset",
			Callback = function()
				task.spawn(function()
					local data = requestData(def)
					if data then
						runClothingSpecial(def, data)
					end
				end)
			end,
		})
	end

	if def.Special == "AssetManager" then
		tab:CreateSection(
			"Client Automation"
		)

		tab:CreateButton({
			Name = "Hire Best Affordable Client",
			Callback = function()
				task.spawn(function()
					local data = requestData(def)
					if data then
						autoHireAssetClient(def, data)
					end
				end)
			end,
		})

		tab:CreateButton({
			Name = "Apply Risk / Goal To Clients",
			Callback = function()
				task.spawn(function()
					local data = requestData(def)
					if data then
						autoConfigureClients(def, data)
					end
				end)
			end,
		})
	end
end

--======================================================================
-- DIAGNOSTICS TAB
--======================================================================

local DiagnosticsTab =
	Window:CreateTab(
		"Diagnostics",
		0
	)

DiagnosticsTab:CreateSection(
	"System Discovery"
)

local DiscoveryParagraph =
	DiagnosticsTab:CreateParagraph({
		Title = "Detected Systems",
		Content = "Scanning..."
	})

local function discoveryText()
	local lines = {}

	for _, def in ipairs(Businesses) do
		local rt = Runtime[def.Key]

		local state =
			rt
			and rt.Available
			and "READY"
			or "MISSING"

		table.insert(
			lines,
			def.Name
			..
			": "
			..
			state
			..
			" | "
			..
			def.EventsName
		)
	end

	return table.concat(lines, "\n")
end

pcall(function()
	DiscoveryParagraph:Set({
		Title = "Detected Systems",
		Content = discoveryText()
	})
end)

DiagnosticsTab:CreateButton({
	Name = "Rescan ReplicatedStorage",
	Callback = function()
		for _, def in ipairs(Businesses) do
			discover(def)
		end

		pcall(function()
			DiscoveryParagraph:Set({
				Title = "Detected Systems",
				Content = discoveryText()
			})
		end)

		notify(
			"Diagnostics",
			"Business systems rescanned.",
			"scan-search"
		)
	end,
})

DiagnosticsTab:CreateButton({
	Name = "STOP EVERYTHING",
	Callback = function()
		Settings.MasterFarm = false

		for _, def in ipairs(Businesses) do
			BusinessState[def.Key].Enabled = false

			local toggle =
				BusinessLabels[
					def.Key .. ":Toggle"
				]

			if toggle then
				pcall(function()
					toggle:Set(false)
				end)
			end
		end

		notify(
			"RAINZXDEV | Get Rich ASAP",
			"All business automation stopped.",
			"octagon-x"
		)
	end,
})

DiagnosticsTab:CreateSection(
	"Notes"
)

DiagnosticsTab:CreateParagraph({
	Title = "Server Authority",
	Content =
		"This hub uses the same RequestData and PerformAction RemoteFunctions "
		..
		"that the supplied business clients use. The server still decides "
		..
		"whether a purchase, upgrade, cash-out, price change, client hire, "
		..
		"or business unlock is accepted."
})

DiagnosticsTab:CreateParagraph({
	Title = "Real Estate",
	Content =
		"The Property Empire tab is optional. It becomes READY only when "
		..
		"PropertyConfigs + PropertyEvents are present."
})

--======================================================================
-- BACKGROUND FARM LOOP
--======================================================================

task.spawn(function()
	while Alive do
		if Settings.MasterFarm then
			for _, def in ipairs(Businesses) do
				if not Alive or not Settings.MasterFarm then
					break
				end

				if BusinessState[def.Key].Enabled then
					farmBusiness(def)
					task.wait(Settings.BusinessDelay)
				end
			end
		end

		task.wait(Settings.MainLoopDelay)
	end
end)

--======================================================================
-- BACKGROUND DATA REFRESH
--======================================================================

task.spawn(function()
	while Alive do
		for _, def in ipairs(Businesses) do
			local rt = Runtime[def.Key]

			if rt and rt.Available then
				-- Refresh less aggressively when master automation is off.
				if not Settings.MasterFarm then
					requestData(def)
					task.wait(0.04)
				end
			end
		end

		task.wait(
			Settings.MasterFarm
			and 1.5
			or 2.5
		)
	end
end)

--======================================================================
-- LIVE UI UPDATE
--======================================================================

task.spawn(function()
	while Alive do
		setLabel(
			CashLabel,
			"Cash: $" .. formatNumber(getCash())
		)

		setLabel(
			MasterStatusLabel,
			Settings.MasterFarm
				and
				"Master farm: RUNNING"
				or
				"Master farm: OFF"
		)

		setLabel(
			TotalsLabel,
			"Collections "
			..
			tostring(TotalCollectedCalls)
			..
			" | Upgrades "
			..
			tostring(TotalUpgradePurchases)
			..
			" | Businesses "
			..
			tostring(TotalBusinessPurchases)
		)

		for _, def in ipairs(Businesses) do
			local live =
				BusinessLabels[
					def.Key .. ":Live"
				]

			local message =
				BusinessLabels[
					def.Key .. ":Message"
				]

			if live then
				setLabel(
					live,
					describeBusiness(def)
				)
			end

			if message then
				setLabel(
					message,
					"Last: "
					..
					tostring(
						BusinessState[def.Key].LastMessage
					)
				)
			end
		end

		task.wait(0.25)
	end
end)

--======================================================================
-- RESPAWN SUPPORT
--======================================================================

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)

	if Settings.MasterFarm and Settings.AutoTravelOnPurchase then
		for _, def in ipairs(Businesses) do
			if BusinessState[def.Key].Enabled then
				local data =
					BusinessState[def.Key].LastData

				if not isOwned(def, data) then
					travelToBusiness(def)
					break
				end
			end
		end
	end
end)

--======================================================================
-- FORCE UI VISIBLE
--======================================================================

pcall(function()
	if PuckUI.SetVisibility then
		PuckUI:SetVisibility(true)
	end
end)

task.delay(1, function()
	pcall(function()
		if PuckUI.SetVisibility then
			PuckUI:SetVisibility(true)
		end
	end)
end)

--======================================================================
-- INITIAL SCAN
--======================================================================

task.spawn(function()
	for _, def in ipairs(Businesses) do
		if Runtime[def.Key] and Runtime[def.Key].Available then
			requestData(def)
			task.wait(0.05)
		end
	end

	notify(
		"RAINZXDEV | Get Rich ASAP",
		"Loaded. Press K to toggle the RAINZXDEV window.",
		0
	)
end)
