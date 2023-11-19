local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Client = {}

local Cache = require(script.Parent.Cache)
local Processes = require(script.Parent.Processes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)
local purchasing = script.Purchasing
purchasing.Parent = playerGui
local main = purchasing:WaitForChild("Main")
local wheel = main:WaitForChild("Wheel", 10)

function Client.initiate()
	script.Parent.Parent.Remotes.Purchase.OnClientEvent:Connect(function(purchaseType, id, data)
		local handler = Processes[purchaseType][id]

		local success, result = pcall(function()
			assert(handler, "No devproduct handler")
			
			handler(data)
		end)
		
		if purchaseType == Enum.InfoType.Product then
			table.insert(Cache.BoughtDevProdcuts[player], id)
		else
			table.insert(Cache.OwnedGamepasses[player], id)
		end
		
		if not success then
			warn(result)
		end
	end)
	
	script.Parent.Parent.Remotes.WheelSpinRemote.OnClientEvent:Connect(function(state)
		script.Parent.Parent.Remotes.WheelSpin:Fire(state)
	end)
	
	script.Parent.Parent.Remotes.WheelSpin.Event:Connect(function(state)
		TweenService:Create(main, TweenInfo.new(1), {
			GroupTransparency = if state then 0 else 1
		}):Play()
	end)
	
	RunService.RenderStepped:Connect(function(deltaTime)
		wheel.Rotation = (wheel.Rotation + deltaTime * 25) % 360
	end)
end

return Client