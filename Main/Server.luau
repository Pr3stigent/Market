local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Cache = require(script.Parent.Parent.Main.Cache)
local Processes = require(script.Parent.Processes)
local ProfileService = require(script.Parent.Parent.Dependencies.ProfileService)
local Promise = require(script.Parent.Parent.Dependencies.Promise)

local PlayerAdded = require(script.Parent.Parent.Parent.PlayerAdded)
local PlayerRemoving = require(script.Parent.Parent.Parent.PlayerRemoving)

local Server = {}

local purchaseHistory = ProfileService.GetProfileStore("PurchaseHistory", {})

local profiles = {}

local RETRIES = 3

local remotes = script.Parent.Parent.Remotes

function Server.initiate()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		-- Check if the player exists and has their data
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		
		if not profiles[player] then
			warn("Profile doesn't exist for Player: " .. player.Name)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		
		local playerData = profiles[player].Data
		
		-- Check to see if the devproduct has already been processed
		if playerData[receiptInfo.PurchaseId]  then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		
		-- Handle purchasing of dev products
		local success, result = pcall(function()
			local handler = Processes[Enum.InfoType.Product][receiptInfo.ProductId]
			if not handler then
				return error("No devproduct handler")
			end
			
			return handler()
		end)
		
		if not success then
			warn("Failed to process a product purchase for ProductId: " .. receiptInfo.ProductId .. " Player: " .. player.Name)
			warn(result)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		
		-- On successful granting of product, tell the client in case it has any client related processes and add the receipt info to the datastore
		remotes.Purchase:FireClient(player, Enum.InfoType.Product, receiptInfo.ProductId)
		playerData[receiptInfo.PurchaseId] = true
		
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
		if not wasPurchased then
			return
		end

		Promise.retry(function()
			return Promise.new(function(resolve, reject)
				-- Handle purchasing of gamepasses
				local success, result = pcall(function()
					local handler = Processes[Enum.InfoType.GamePass][gamepassId]
					if not handler then
						return error("No gamepass handler")
					end

					return handler()
				end)

				if success then
					resolve()
				else
					reject(result)
				end
			end)
		end, RETRIES):andThen(function(data)
			-- If the handling of the gamepass was successful then we state that it was already processed and that it is now owned
			-- Also allows for the client to go onto handling their own processes
			
			Cache.ProcessedGamepass[player][gamepassId] = true
			Cache.OwnedGamepasses[player][gamepassId] = true
			
			remotes.Purchase:FireClient(player, Enum.InfoType.GamePass, gamepassId, data)
		end):catch(warn)
	end)
	
	MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, wasPurchased)
		if not wasPurchased then
			return
		end

		Promise.retry(function()
			return Promise.new(function(resolve, reject)
				-- Handle purchasing of assets
				local success, result = pcall(function()
					local handler = Processes[Enum.InfoType.Asset][assetId]
					if not handler then
						return error("No asset handler")
					end

					return handler()
				end)

				if success then
					resolve()
				else
					reject(result)
				end
			end)
		end, RETRIES):andThen(function(data)
			-- If the handling of the gamepass was successful then we state that it was already processed and that it is now owned
			-- Also allows for the client to go onto handling their own processes
			remotes.Purchase:FireClient(player, Enum.InfoType.Asset, assetId, data)
		end):catch(warn)
	end)
	
	remotes.WheelSpin.Event:Connect(function(player, canAnimate)
		remotes.WheelSpinRemote:FireClient(player, canAnimate)
	end)
	
	PlayerAdded(function(player)
		local profile = purchaseHistory:LoadProfileAsync(
			"player_" .. player.UserId,
			"ForceLoad"
		)

		if profile ~= nil then
			profile:AddUserId(player.UserId)
			profile:Reconcile()
			profile:ListenToRelease(function()
				profiles[player] = nil
				player:Kick()
			end)
			
			if player:IsDescendantOf(Players) then
				profiles[player] = profile
			else
				profile:Release()
			end
		else
			player:Kick() 
		end
	end, 2, true)

	PlayerRemoving(function(player)
		if profiles[player] ~= nil then
			profiles[player]:Release()
		end
	end)
end

return Server