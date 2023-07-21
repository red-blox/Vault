local DataStore = require(script.Parent.DataStore)

type AllUpdate = (DataStore.VaultData) -> (DataStore.VaultData)
type KeyUpdate = (any) -> (any)

local function Key(Key: string, Update: KeyUpdate)
	return function(VaultData: DataStore.VaultData)
		VaultData.D[Key] = Update(VaultData.D[Key])

		return VaultData
	end
end

local function Set(Value: any)
	return function()
		return Value
	end
end

local Number = {}

function Number.Increment(Amount: number)
	return function(Value: number)
		return Value + Amount
	end
end

function Number.Decrement(Amount: number)
	return function(Value: number)
		return Value - Amount
	end
end

Number.Add = Number.Increment
Number.Subtract = Number.Decrement

local String = {}

function String.Append(Append: string)
	return function(Value: string)
		return Value .. Append
	end
end

function String.Prepend(Prepend: string)
	return function(Value: string)
		return Prepend .. Value
	end
end

String.Concat = String.Append

local Boolean = {}

function Boolean.Toggle(Value: boolean)
	return not Value
end

local List = {}

function List.Push(Append: any)
	return function(Value: { any })
		table.insert(Value, Append)

		return Value
	end
end

function List.Unshift(Prepend: any)
	return function(Value: { any })
		table.insert(Value, 1, Prepend)

		return Value
	end
end

function List.Pop(Value: { any })
	table.remove(Value)

	return Value
end

function List.Shift(Value: { any })
	table.remove(Value, 1)

	return Value
end

function List.For(Update: KeyUpdate)
	return function(Value: { any })
		for Index, Item in Value do
			Value[Index] = Update(Item)
		end

		return Value
	end
end

local Map = {}

function Map.Set(Key: string, Value: any)
	return function(Map: { [string]: any })
		Map[Key] = Value

		return Map
	end
end

function Map.Delete(Key: string)
	return function(Map: { [string]: any })
		Map[Key] = nil

		return Map
	end
end

function Map.Update(Key: string, Update: KeyUpdate)
	return function(Map: { [string]: any })
		Map[Key] = Update(Map[Key])

		return Map
	end
end

function Map.For(Update: (string, any) -> (any))
	return function(Map: { [string]: any })
		for Key, Value in Map do
			Map[Key] = Update(Key, Value)
		end

		return Map
	end
end

local UniqueList = {}

function UniqueList.Add(Value: any)
	return function(List: { any })
		if not table.find(List, Value) then
			table.insert(List, Value)
		end

		return List
	end
end

function UniqueList.Remove(Value: any)
	return function(List: { any })
		local Index = table.find(List, Value)

		if Index then
			table.remove(List, Index)
		end

		return List
	end
end

function UniqueList.For(Update: KeyUpdate)
	return function(List: { any })
		for Index, Item in List do
			List[Index] = Update(Item)
		end

		return List
	end
end

return {
	Key = Key,
	Set = Set,

	Number = Number,
	String = String,
	Boolean = Boolean,
	List = List,
	Map = Map,
	UniqueList = UniqueList,
}
