local _, ns = ...

local MAX_NAME_LENGTH = 32

local function CopyTable(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = type(value) == "table" and CopyTable(value) or value
	end
	return copy
end

-- Default first, then the rest alphabetically.
function ns.GetProfileNames()
	local names = {}
	for name in pairs(ns.account.profiles) do
		if name ~= ns.DEFAULT_PROFILE then
			names[#names + 1] = name
		end
	end
	table.sort(names, function(a, b) return a:lower() < b:lower() end)
	table.insert(names, 1, ns.DEFAULT_PROFILE)
	return names
end

-- The name with spaces trimmed, or nil and the reason it can't be used. Names differing only in
-- capitals count as the same, so the list never shows two that look alike.
function ns.CheckProfileName(name)
	name = (name or ""):match("^%s*(.-)%s*$")
	if name == "" then
		return nil, "Type a name for the profile."
	end
	if #name > MAX_NAME_LENGTH then
		return nil, "That name is too long."
	end
	for existing in pairs(ns.account.profiles) do
		if existing:lower() == name:lower() then
			return nil, "There's already a profile with that name."
		end
	end
	return name
end

-- Switching places the frames again, which can't happen in combat. Returns whether it switched.
function ns.UseProfile(name)
	local profile = ns.account.profiles[name]
	if not profile or InCombatLockdown() then
		return false
	end
	ns.profileName, ns.db = name, profile
	ns.account.characters[ns.characterKey] = name ~= ns.DEFAULT_PROFILE and name or nil
	ns.ApplyProfile()
	return true
end

-- A new profile with copyFrom's settings, or the defaults when copyFrom is nil, which this character
-- then uses. Returns its name, or nil and the reason it couldn't be made.
function ns.CreateProfile(name, copyFrom)
	local problem
	name, problem = ns.CheckProfileName(name)
	if not name then
		return nil, problem
	end
	if InCombatLockdown() then
		return nil, "Profiles can't be changed during combat."
	end
	local source = copyFrom and ns.account.profiles[copyFrom]
	ns.account.profiles[name] = ns.CleanProfile(source and CopyTable(source) or {})
	ns.UseProfile(name)
	return name
end

-- Default and the profile in use can't be deleted. Characters that used it go back to Default.
function ns.CanDeleteProfile(name)
	return name ~= ns.DEFAULT_PROFILE and name ~= ns.profileName and ns.account.profiles[name] ~= nil
end

function ns.DeleteProfile(name)
	if not ns.CanDeleteProfile(name) or InCombatLockdown() then
		return false
	end
	ns.account.profiles[name] = nil
	for character, used in pairs(ns.account.characters) do
		if used == name then
			ns.account.characters[character] = nil
		end
	end
	return true
end
