local DataStoreService = game:GetService("DataStoreService")

local Promise = require(script.Parent.Promise)
local Clock = require(script.Parent.Clock)

local function LockValid(Lock: any, Timeout: number)
	return type(Lock) == "table"
		and type(Lock.S) == "string"
		and type(Lock.T) == "number"
		and Lock.T > os.time() - Timeout
end

local function LockCanWrite(Lock: any, Timeout: number)
	return not LockValid(Lock, Timeout) or Lock.S == game.JobId
end

local function MakeLock()
	return { S = game.JobId, T = os.time() }
end

local Vault = {}
Vault.__index = Vault

type Data = { [string]: any } & {
	UserIds: { number }?,
	Order: number?,
}

export type Action = {
	Type: "Load",
	Key: string,
	Attempt: number,
} | {
	Type: "Save",
	Key: string,
	Attempt: number,
	Release: boolean,
}

type Options = {
	Locked: (Action: Action) -> "Fail" | "Retry" | "Force",
	Error: (Action: Action, Code: number, Error: string) -> "Fail" | "Retry",

	New: (Key: string) -> Data,
	Autosave: (Key: string) -> Data,

	AutosaveInterval: number,
	LockTimeout: number,
}

function Vault.new(Scope: string, Options: Options)
	return setmetatable({
		Global = DataStoreService:GetDataStore(`Vault/Global/{Scope}`),
		Ordered = DataStoreService:GetOrderedDataStore(`Vault/Ordered/{Scope}`),

		Options = Options,

		VersionList = {},
		Latest = 0,

		LockedMap = {},
	}, Vault)
end

export type Vault = typeof(Vault.new(...))

function Vault.Version(self: Vault, Migrator: (Data) -> Data)
	table.insert(self.VersionList, Migrator)

	self.Latest += 1
end

function Vault.AttemptLoad(self: Vault, Key: string, Lock: boolean, Force: boolean)
	return Promise.new(function(Resolve, Reject)
		local LoadData: Data, LoadVersion: number
		local Locked = false

		self.Global:UpdateAsync(Key, function(Data, KeyInfo)
			Data = Data or {}

			if Force or not LockValid(Data.L, self.Options.LockTimeout) then
				Data.L = MakeLock()

				LoadData = Data.D
				LoadVersion = Data.V
			else
				Locked = true
			end

			return Data, KeyInfo:GetUserIds()
		end)

		if Locked then
			Reject("Locked")
		else
			if LoadData == nil then
				LoadData = self.Options.New(Key)
				LoadVersion = self.Latest
			end

			while LoadVersion < self.Latest do
				LoadData = self.VersionList[LoadVersion](LoadData)
				LoadVersion += 1
			end

			self.LockedMap[Key] = Clock(self.Options.AutosaveInterval, function()
				self:AttemptSave(Key, self.Options.Autosave(Key), false, false)
			end)

			Resolve(LoadData)
		end
	end)
end

function Vault.AttemptSave(self: Vault, Key: string, Data: Data, Release: boolean, Force: boolean)
	return Promise.new(function(Resolve, Reject)
		local Locked = false

		self.Global:UpdateAsync(Key, function(OldData, KeyInfo)
			OldData = OldData or {}

			if Force or LockCanWrite(OldData.L, self.Options.LockTimeout) then
				OldData.D = Data
				OldData.V = self.Latest

				if Release then
					OldData.L = nil
				else
					OldData.L = MakeLock()
				end
			else
				Locked = true
			end

			return OldData, Data.UserIds or KeyInfo:GetUserIds()
		end)

		if Locked then
			Reject("Locked")
		else
			if Release and self.LockedMap[Key] then
				self.LockedMap[Key]()
				self.LockedMap[Key] = nil
			end

			if Data.Order then
				self.Ordered:SetAsync(Key, Data.Order, Data.UserIds)
			end

			Resolve()
		end
	end)
end

function Vault.Load(self: Vault, Key: string, Lock: boolean)
	return Promise.new(function(Resolve, Reject)
		local Force = false
		local Action: Action = {
			Type = "Load",
			Key = Key,
			Attempt = 0,
		}

		while true do
			Action.Attempt += 1

			local Status, Result = self:AttemptLoad(Key, Lock, Force):StatusAwait()

			if Status == "Resolved" then
				return Resolve(Result)
			elseif Result == "Locked" then
				local LockAction = self.Options.Locked(Action)

				if LockAction == "Fail" then
					return Reject("Locked")
				elseif LockAction == "Force" then
					Force = true
				end
			else
				local Code, Error = string.match(Result, "^(%d+): (.+)$")
				local ErrorAction = self.Options.Error(Action, tonumber(Code) :: number, Error :: string)

				if ErrorAction == "Fail" then
					return Reject(Result)
				end
			end

			task.wait(math.random(6, 12))
		end
	end)
end

function Vault.Save(self: Vault, Key: string, Data: Data, Release: boolean)
	return Promise.new(function(Resolve, Reject)
		local Force = false
		local Action: Action = {
			Type = "Save",
			Key = Key,
			Attempt = 0,
			Release = Release,
		}

		while true do
			Action.Attempt += 1

			local Status, Result = self:AttemptSave(Key, Data, Release, Force):StatusAwait()

			if Status == "Resolved" then
				return Resolve()
			elseif Result == "Locked" then
				local LockAction = self.Options.Locked(Action)

				if LockAction == "Fail" then
					return Reject("Locked")
				elseif LockAction == "Force" then
					Force = true
				end
			else
				local Code, Error = string.match(Result, "^(%d+): (.+)$")
				local ErrorAction = self.Options.Error(Action, tonumber(Code) :: number, Error :: string)

				if ErrorAction == "Fail" then
					return Reject(Result)
				end
			end

			task.wait(math.random(6, 12))
		end
	end)
end

return Vault
