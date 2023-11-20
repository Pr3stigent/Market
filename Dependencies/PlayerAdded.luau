local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local callbacks = {}
local playerRanFOr = {}

local function run(player)
	for _, callbackData in callbacks do
		if table.find(playerRanFOr[callbackData.Callback], player) then
			continue
		end
		
		if callbackData.Yield then
			callbackData.Callback(player)
		else
			task.spawn(callbackData.Callback, player)
		end		
		
		table.insert(playerRanFOr[callbackData.Callback], player)
	end
end

Players.PlayerAdded:Connect(function(player)
	run(player)
end)

Players.PlayerRemoving:Connect(function(player)
	for _, callbackData in callbacks do
		local inCallback = table.find(playerRanFOr[callbackData.Callback], player)
		if not inCallback then
			return
		end
		
		table.remove(playerRanFOr[callbackData.Callback], inCallback)
	end
end)

return function(callback, priority, yield)
	if not callback then
		for _, player in Players:GetPlayers() do
			run(player)
		end
		
		return
	end
	
	if not priority then
		table.insert(callbacks, {Callback = callback, Yield = yield})
	else
		table.insert(callbacks, {Callback = callback, Yield = yield})
	end
	
	playerRanFOr[callback] = {}
end