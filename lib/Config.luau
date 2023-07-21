local RunService = game:GetService("RunService")

local DataStore = require(script.Parent.DataStore)

local Config = {}

export type Config = {
	Name: string | {
		Test: string,
		Live: string,
	},

	Cache: number | boolean | nil,
	Update: number | nil,
	Retry: number | nil,

	New: (Key: string) -> DataStore.UserData,
}

export type SimpleConfig = {
	Name: string,

	Cache: number | boolean,
	Update: number,
	Retry: number,

	New: (Key: string) -> DataStore.UserData,
}

function Config.Name(self: Config): string
	local Name = self.Name

	if type(Name) == "string" then
		return Name
	elseif Name.Test and RunService:IsStudio() then
		return Name.Test
	elseif Name.Live and not RunService:IsStudio() then
		return Name.Live
	else
		error("Invalid Config.Name")
	end
end

function Config.Cache(self: Config): number | boolean
	local Cache = self.Cache

	if Cache == nil then
		return 15
	elseif type(Cache) == "number" or type(Cache) == "boolean" then
		return Cache
	else
		error("Invalid Config.Cache")
	end
end

function Config.Update(self: Config): number
	local Update = self.Update

	if Update == nil then
		return 15
	elseif type(Update) == "number" then
		return Update
	else
		error("Invalid Config.Update")
	end
end

function Config.Retry(self: Config): number
	local Retry = self.Retry

	if Retry == nil then
		return 5
	elseif type(Retry) == "number" then
		return Retry
	else
		error("Invalid Config.Retry")
	end
end

function Config.Simple(self: Config): SimpleConfig
	return {
		Name = Config.Name(self),
		Cache = Config.Cache(self),
		Update = Config.Update(self),
		Retry = Config.Retry(self),
		New = self.New,
	}
end

return Config
