local Players = game:GetService("Players")

local callbacks = {}

Players.PlayerRemoving:Connect(function(player)
	for _, callback in callbacks do
		callback(player)
	end
end)

return function(callback, priority)
	if not priority then
		table.insert(callbacks, callback)
	else
		table.insert(callbacks, priority, callback)
	end
end