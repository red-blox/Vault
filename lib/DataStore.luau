local DataStoreService = game:GetService("DataStoreService")

local Promise = require(script.Parent.Parent.Promise)

local DataStore = {}

export type UserData = {
	[string]: any,

	Order: number,
	UserIds: { number },
}

export type VaultData = {
	D: UserData,
}

local function DataScope(Scope: string)
	return DataStoreService:GetDataStore(`Vault/Data/{Scope}`)
end

local function OrderScope(Scope: string)
	return DataStoreService:GetOrderedDataStore(`Vault/Order/{Scope}`)
end

function DataStore.Get(Scope: string, Key: string)
	return DataScope(Scope):GetAsync(Key)
end

function DataStore.Update(Scope: string, Key: string, Update: (VaultData?) -> VaultData?)
	return DataScope(Scope):UpdateAsync(Key, function(Old: VaultData?)
		local New = Update(Old)

		if New then
			return New, New.D.UserIds
		else
			return nil
		end
	end)
end

function DataStore.Order(Scope: string, Key: string, VaultData: VaultData)
	return OrderScope(Scope):SetAsync(Key, VaultData.D.Order, VaultData.D.UserIds)
end

function DataStore.GetAsync(Scope: string, Key: string, Retry: number)
	return Promise.Retry(Retry, DataStore.Get, Scope, Key)
end

function DataStore.UpdateAsync(Scope: string, Key: string, Update: (VaultData?) -> VaultData?, Retry: number)
	return Promise.Retry(Retry, DataStore.Update, Scope, Key, Update)
end

function DataStore.OrderAsync(Scope: string, Key: string, VaultData: VaultData, Retry: number)
	return Promise.Retry(Retry, DataStore.Order, Scope, Key, VaultData)
end

return DataStore
