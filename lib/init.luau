local DataStoreService = game:GetService("DataStoreService")

local Future = require(script.Parent.Future)
local Signal = require(script.Parent.Signal)

type Future<T> = typeof(Future.new(function()
	return ({} :: any) :: T
end))

type Config<T> = {
	Scope: string,

	New: () -> T,

	UpdateTime: number,

	-- -1: Forever
	--  0: Never
	-- >0: Seconds
	CacheTime: number,
}

local function DeepFreeze<T>(Value: T): T
	table.freeze(Value :: any)

	for _, v in Value :: any do
		if type(v) == "table" then
			DeepFreeze(v)
		end
	end

	return Value
end

local function RunUpdate<T>(Data: T, Update: (T, ...any) -> T, ...: any)
	local Success, Result = pcall(Update, Data, ...)

	if Success then
		return true, DeepFreeze(Result)
	else
		warn("[Vault] Update failed: " .. Result :: any)
		return false, Data
	end
end

local Gem = {}
Gem.__index = Gem

export type Gem<T> = {
	Name: string,
	Config: Config<T>,

	OnClose: (Gem<T>) -> (),

	Cache: T?,
	CacheThread: thread?,

	UpdateQueue: { { any } },
	UpdateThread: thread,

	ChangeSignal: typeof(Signal()),

	Observe: (self: Gem<T>, Callback: (T) -> ()) -> () -> (),
	Update: <U...>(self: Gem<T>, Update: (T, U...) -> T, U...) -> (),
	Close: (self: Gem<T>) -> Future<boolean>,
	Save: (self: Gem<T>) -> Future<boolean>,
	Get: (self: Gem<T>, SkipCache: boolean?) -> typeof(Future.Try(function()
		return ({} :: any) :: T
	end)),
}

function Gem.new<T>(Name: string, Config: Config<T>, OnClose: (Gem<T>) -> ())
	local self = setmetatable({}, Gem)

	self.Name = Name
	self.Config = Config

	self.OnClose = OnClose

	self.Cache = nil :: T?
	self.CacheThread = nil :: thread?

	self.UpdateQueue = {} :: { { any } }
	self.UpdateThread = task.spawn(function(self: any)
		while true do
			task.wait(self.Config.UpdateTime)

			self:Save()
		end
	end, self :: any)

	self.ChangeSignal = Signal()

	return self
end

local function SetCache<T>(self: Gem<T>, Data: T)
	if self.Config.CacheTime > 0 then
		self.Cache = Data

		if self.CacheThread then
			task.cancel(self.CacheThread)
		end

		self.CacheThread = task.delay(self.Config.CacheTime, function()
			self.Cache = nil
			self.CacheThread = nil
		end)
	elseif self.Config.CacheTime == -1 then
		self.Cache = Data
	end

	self.ChangeSignal:Fire(Data :: any)
end

function Gem.Get<T>(self: Gem<T>, SkipCache: boolean?)
	return Future.Try(function(self: Gem<T>, SkipCache: boolean?)
		if self.Cache == nil or SkipCache then
			local Data: T = DataStoreService:GetDataStore(self.Config.Scope):GetAsync(self.Name)

			if Data == nil then
				Data = self.Config.New()
			end

			DeepFreeze(Data)
			SetCache(self, Data)

			return Data
		else
			return self.Cache
		end
	end, self, SkipCache)
end

function Gem.Observe<T>(self: Gem<T>, Callback: (T) -> ())
	return self.ChangeSignal:Connect(Callback)
end

function Gem.Update<T, U...>(self: Gem<T>, Update: (T, U...) -> T, ...: U...)
	local PackedUpdate = table.pack(Update, ...)

	if self.Cache then
		local Success, Result = RunUpdate(self.Cache, Update, ...)

		if Success then
			self.Cache = Result
			self.ChangeSignal:Fire(Result :: any)
		else
			return
		end
	end

	table.insert(self.UpdateQueue, PackedUpdate)
end

function Gem.Save<T>(self: Gem<T>)
	return Future.Try(function(self: Gem<T>)
		local UpdateQueue = self.UpdateQueue
		self.UpdateQueue = {}

		local Data: T = DataStoreService:GetDataStore(self.Config.Scope):UpdateAsync(self.Name, function(Data: T)
			if Data == nil then
				Data = self.Config.New()
			end

			DeepFreeze(Data)

			for _, Update in UpdateQueue do
				local Success, Result = RunUpdate(Data, table.unpack(Update))

				if Success then
					Data = Result
				else
					return Data
				end
			end

			return Data
		end)

		SetCache(self, Data)
	end, self)
end

function Gem.Close<T>(self: Gem<T>)
	task.cancel(self.UpdateThread)
	local Save = self:Save()

	Save:After(function()
		if self.CacheThread then
			task.cancel(self.CacheThread)
		end

		self.OnClose(self)
	end)

	return Save
end

local function Vault<T>(Config: Config<T>)
	local GemMap = {}

	local function OnClose(Gem)
		GemMap[Gem.Name] = nil
	end

	return function(Name: string): Gem<T>
		if GemMap[Name] == nil then
			GemMap[Name] = Gem.new(Name, Config, OnClose)
		end

		return GemMap[Name] :: any
	end
end

return Vault
