local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Client = {}

local Cache = require(script.Parent.Cache)
local Processes = require(script.Parent.Processes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local purchasing = script.Purchasing:Clone()
local main = purchasing.Main
local wheel = main.Wheel
purchasing.Parent = playerGui

local remotes = script.Parent.Parent.Remotes

local animationConnection

local function animate(canAnimate, speed)
	TweenService:Create(main, TweenInfo.new(1), {
		GroupTransparency = if canAnimate then 0 else 1
	}):Play()
	
	if not canAnimate then
		animationConnection:Disconnect()
		return
	end

	animationConnection = RunService.RenderStepped:Connect(function(deltaTime)
		wheel.Rotation = (wheel.Rotation + deltaTime * speed) % 360
	end)
end

function Client.initiate()
	remotes.Purchase.OnClientEvent:Connect(function(purchaseType, id, data)
		local success, result = pcall(function()
			local handler = Processes[purchaseType][id]
			if not handler then
				return error("No handler")
			end

			return handler()
		end)

		if purchaseType == Enum.InfoType.GamePass then
			Cache.OwnedGamepasses[player][id] = true
		end

		if not success then
			warn(result)
		end
	end)
	
	-- Animate Wheel
	
	remotes.WheelSpinRemote.OnClientEvent:Connect(function(canAnimate)
		remotes.WheelSpin:Fire(player, canAnimate)
	end)

	remotes.WheelSpin.Event:Connect(function(player, canAnimate)
		animate(canAnimate, 25)
	end)
	
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
		remotes.WheelSpin:Fire(player, false)
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId)
		remotes.WheelSpin:Fire(player, false)
	end)

	MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, wasPurchased)
		remotes.WheelSpin:Fire(player, false)
	end)

	MarketplaceService.PromptPremiumPurchaseFinished:Connect(function()
		remotes.WheelSpin:Fire(player, false)
	end)
end

return Client