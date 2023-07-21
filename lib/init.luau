local Clock = require(script.Parent.Clock)

local Op = require(script.Op)
local Gem = require(script.Gem)
local Config = require(script.Config)

return {
	Op = Op,

	new = function(VaultConfig: Config.Config)
		local SimpleConfig = Config.Simple(VaultConfig)
		local GemMap: { [string]: Gem.Gem } = {}

		local function Release(self: Gem.Gem)
			GemMap[self.Key] = nil
		end

		Clock(SimpleConfig.Update, function()
			for _, Gem in GemMap do
				Gem:Save()
			end
		end)

		return function(Key: string)
			if not GemMap[Key] then
				GemMap[Key] = Gem(SimpleConfig, Key, Release)
			end

			return GemMap[Key]
		end
	end,
}
