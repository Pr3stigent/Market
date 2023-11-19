local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Market = {}
local PlayerAdded = require(script.Parent.PlayerAdded)
local PlayerRemoving = require(script.Parent.PlayerRemoving)

local Cache = require(script.Main.Cache)
local Promise = require(script.Dependencies.Promise)
local Processes = require(script.Main.Processes)

function Market.hasGamepass(player, gamepassId): typeof(promise)
	if table.find(Cache.OwnedGamepasses[player], gamepassId) then
		return Promise.resolve(true)
	end
	
	return Promise.retry(function()
		return Promise.new(function(resolve, reject)
			local success, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
			end)
			
			if success then
				if result then
					table.insert(Cache.OwnedGamepasses[player], gamepassId)
				end
				
				resolve(result)
			else
				reject(result)
			end
		end)
	end, script:GetAttribute("Retries")):catch(warn)
end

function Market.getInfo(purchaseType, id)
	if Cache[purchaseType][id] then
		return Promise.resolve(Cache[purchaseType][id])
	end	
	
	return Promise.retry(function()
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
		end)
	end, script:GetAttribute("Retries")):catch(warn)
end

function Market.attachCallback(productType, id, callback)
	Processes[productType][id] = callback
	
	for _, player in Players:GetPlayers() do
		if Cache.OwnedGamepasses[player] and productType == Enum.InfoType.GamePass and Market.hasGamepass(player, id):awaitValue() and not table.find(Cache.ProcessedGamepass[player], id) then
			local success = callback(player)
			if success then
				table.insert(Cache.ProcessedGamepass[player], id)
			end
		end
	end
end

function Market.promptPurchase(player, purchaseType, id)
	if purchaseType == Enum.InfoType.Product then
		MarketplaceService:PromptProductPurchase(player, id)
	elseif purchaseType == Enum.InfoType.GamePass then
		MarketplaceService:PromptGamePassPurchase(player, id)
	end
	
	if RunService:IsServer() then
		script.Remotes.WheelSpinRemote:FireClient(player, true)
		return
	end
	
	script.Remotes.WheelSpin:Fire(true)
end

if RunService:IsServer() then
	local Server = require(script.Main.Server)
	Server.initiate()
elseif RunService:IsClient() then
	local Client = require(script.Main.Client)
	Client.initiate()
end

PlayerAdded(function(player)
	Cache.OwnedGamepasses[player] = {}
	Cache.ProcessedGamepass[player] = {}
	
	for id, callback in Processes[Enum.InfoType.GamePass] do
		if Market.hasGamepass(player, id):awaitValue() and not table.find(Cache.ProcessedGamepass[player], id) then
			local success = callback(player)
			if success then
				table.insert(Cache.ProcessedGamepass[player], id)
			end
		end
	end
end, 2, true)

PlayerRemoving(function(player)
	Cache.OwnedGamepasses[player] = nil
end)

return Market
