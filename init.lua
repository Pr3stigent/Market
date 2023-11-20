local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Market = {}

local Cache = require(script.Main.Cache)
local Processes = require(script.Main.Processes)

local Promise = require(script.Dependencies.Promise)
local PlayerAdded = require(script.Dependencies.PlayerAdded)
local PlayerRemoving = require(script.Dependencies.PlayerRemoving)

local remotes = script.Remotes

local function processOwnedGamepasses(player, gamepassId, callback)
	local hasGamepass = Market.hasGamepass(player, gamepassId):awaitValue()

	if hasGamepass and not Cache.ProcessedGamepass[player][gamepassId] then
		local success = callback(player)
		if success then
			Cache.ProcessedGamepass[player][gamepassId] = true
		end
	end
end

function Market.hasGamepass(player, gamepassId): typeof(promise)
	if Cache.OwnedGamepasses[player][gamepassId] then
		return Promise.resolve(true)
	end

	return Promise.new(function(resolve, reject)
		local success, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
		end)

		if success then
			if result then
				Cache.OwnedGamepasses[player][gamepassId] = true
			end

			resolve(result)
		else
			reject(result)
		end
	end):catch(warn)
end

function Market.getInfo(purchaseType, id)
	if Cache[purchaseType][id] then
		return Promise.resolve(Cache[purchaseType][id])
	end	

	return Promise.new(function(resolve, reject)
		local success, result = pcall(function()
			return MarketplaceService:GetProductInfo(id, purchaseType)
		end)

		if success then
			Cache[purchaseType][id] = result
			return resolve(result)
		else
			return reject(result)
		end
	end):catch(warn)
end

function Market.attachCallback(productType, id, callback)
	Processes[productType][id] = callback

	if productType == Enum.InfoType.GamePass then
		for _, player in Players:GetPlayers() do
			processOwnedGamepasses(player, id, callback)
		end
	end
end

function Market.promptPurchase(player, purchaseType, id)
	if purchaseType == Enum.InfoType.Product then
		MarketplaceService:PromptProductPurchase(player, id)
	elseif purchaseType == Enum.InfoType.GamePass then
		MarketplaceService:PromptGamePassPurchase(player, id)
	elseif purchaseType == Enum.InfoType.Asset then
		MarketplaceService:PromptPurchase(player, id)
	end
	
	remotes.WheelSpin:Fire(player, true)
end

PlayerAdded(function(player)
	Cache.OwnedGamepasses[player] = {}
	Cache.ProcessedGamepass[player] = {}

	for gamepassId, callback in Processes[Enum.InfoType.GamePass] do
		processOwnedGamepasses(player, gamepassId, callback)
	end
end, 2, true)

PlayerRemoving(function(player)
	Cache.OwnedGamepasses[player] = nil
end)

if RunService:IsServer() then
	local Server = require(script.Main.Server)
	Server.initiate()
else
	local Client = require(script.Main.Client)
	Client.initiate()
end

return Market
