local Promise = require(script.Parent.Parent.Promise)

type Promise = typeof(Promise.new(nil :: any))

local DataStore = require(script.Parent.DataStore)
local Config = require(script.Parent.Config)

local function RunUpdate(Data: DataStore.VaultData, Update: (DataStore.VaultData) -> DataStore.VaultData)
	local Success, Result = pcall(Update, Data)

	if Success then
		return Result
	else
		warn(`Update Failed: {Result}`)
		return Data
	end
end

local Gem = {}
Gem.__index = Gem

function Gem.new(Config: Config.SimpleConfig, Key: string, Release: (Gem) -> nil)
	local self = setmetatable({}, Gem)

	self.Config = Config
	self.Key = Key

	self.Loading = nil :: Promise?
	self.Saving = nil :: Promise?

	self.Cache = nil :: DataStore.VaultData?
	self.CacheThread = nil :: thread?

	self.UpdateQueue = {} :: { (DataStore.VaultData) -> DataStore.VaultData }

	self.Release = Release

	return self
end

export type Gem = typeof(Gem.new(...))

local function SetCache(self: Gem, Data: DataStore.VaultData, ResetThread: boolean)
	local Cache = self.Config.Cache

	if Cache == true then
		self.Cache = Data
	elseif type(Cache) == "number" and ResetThread then
		if self.CacheThread then
			task.cancel(self.CacheThread)
		end
		
		self.CacheThread = task.delay(Cache, function()
			self.Cache = nil
			self.CacheThread = nil
		end)
	end
end

local function Load(self: Gem)
	if not self.Loading then
		self.Loading = DataStore.GetAsync(self.Config.Name, self.Key, self.Config.Retry)
			:Then(function(MaybeData: DataStore.VaultData?)
				local Data: DataStore.VaultData = MaybeData or {
					D = self.Config.New(self.Key),
				}

				-- apply any pending updates to the just loaded data
				for _, Update in self.UpdateQueue do
					Data = RunUpdate(Data, Update)
				end

				SetCache(self, Data, true)

				return Data
			end)
			:Finally(function()
				self.Loading = nil
			end)
	end

	-- If self.Loading doesn't yield then this will be nil, as
	-- this is doing a datastore operation it *should* yield
	return self.Loading :: Promise
end

function Gem.Save(self: Gem)
	if not self.Saving and #self.UpdateQueue > 0 then
		self.Saving = DataStore.UpdateAsync(self.Config.Name, self.Key, function(MaybeData)
			local Data: DataStore.VaultData = MaybeData or {
				D = self.Config.New(self.Key),
			}

			for _, Update in self.UpdateQueue do
				Data = RunUpdate(Data, Update)
			end

			return Data
		end, self.Config.Retry):Then(function(Data: DataStore.VaultData)
			SetCache(self, Data, true)

			return Data
		end):Finally(function()
			table.clear(self.UpdateQueue)
			self.Saving = nil
		end)
	elseif #self.UpdateQueue == 0 then
		return Promise.Resolve(self.Cache)
	end

	-- If self.Saving doesn't yield then this will be nil, as
	-- this is doing a datastore operation it *should* yield
	return self.Saving :: Promise
end

function Gem.Get(self: Gem, Key: string)
	if self.Cache then
		return Promise.Resolve(self.Cache.D[Key])
	else
		return Load(self):Then(function(Data: DataStore.VaultData)
			return Data.D[Key]
		end)
	end
end

function Gem.Update(self: Gem, Update: (DataStore.VaultData) -> DataStore.VaultData)
	table.insert(self.UpdateQueue, Update)

	if self.Cache then
		SetCache(self, RunUpdate(self.Cache, Update), false)
	end
end

return Gem.new
