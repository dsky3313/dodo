local T, C, L = unpack((select(2, ...)))

--[[ THIS BAG MODULE IS CURRENTLY WORK IN PROGRESS]]
local ContainerFrameCombinedBags = _G.ContainerFrameCombinedBags
local C_Container = _G.C_Container
local C_Item = _G.C_Item

local Bags = CreateFrame("Frame")
local Inventory = T["Inventory"]
local Movers = T["Movers"]

function Bags:SkinButton(Button)
	if not Button then
		return
	end

	Button:StripTextures()
	Button:CreateBackdrop()
	Button.IconBorder:SetAlpha(0)
	Button.icon:SetTexCoord(.08, .92, .08, .92)
	Button.IconQuestTexture:SetAlpha(0)
end

function Bags:SkinButtons()
	local Bag = ContainerFrameCombinedBags
	local Reagent = ContainerFrame6

	for i, Button in Bag:EnumerateValidItems() do
		Bags:SkinButton(Button)
	end

	for i, Button in Reagent:EnumerateValidItems() do
		Bags:SkinButton(Button)
	end
end

function Bags.QuestItem(Button)
	local BagID = Button:GetBagID()
	local QuestInfo = C_Container.GetContainerItemQuestInfo(BagID, Button:GetID())
	local IsQuestItem = QuestInfo.isQuestItem
	local QuestID = QuestInfo.questID
	local IsActive = QuestInfo.isActive

	-- items starting quests are not considered quest items by Blizzard, mark them anyway
	if IsQuestItem or QuestID then
		if not Button.Quest then
			Button.Quest = CreateFrame("Frame", nil, Button)
			Button.Quest:SetFrameLevel(Button:GetFrameLevel())
			Button.Quest:SetSize(8, Button:GetHeight() - 2)
			Button.Quest:SetPoint("TOPLEFT", 1, -1)

			Button.Quest.Backdrop = Button.Quest:CreateTexture(nil, "ARTWORK")
			Button.Quest.Backdrop:SetAllPoints()
			Button.Quest.Backdrop:SetColorTexture(unpack(C.General.BackdropColor))

			Button.Quest.BorderRight = Button.Quest:CreateTexture(nil, "ARTWORK")
			Button.Quest.BorderRight:SetSize(1, 1)
			Button.Quest.BorderRight:SetPoint("TOPRIGHT", Button.Quest, "TOPRIGHT", 1, 0)
			Button.Quest.BorderRight:SetPoint("BOTTOMRIGHT", Button.Quest, "BOTTOMRIGHT", 1, 0)
			Button.Quest.BorderRight:SetColorTexture(1, 1, 0)

			Button.Quest.Texture = Button.Quest:CreateTexture(nil, "OVERLAY")
			Button.Quest.Texture:SetTexture("Interface\\QuestFrame\\AutoQuest-Parts")
			Button.Quest.Texture:SetTexCoord(0.13476563, 0.17187500, 0.01562500, 0.53125000)
			Button.Quest.Texture:SetSize(8, 16)
			Button.Quest.Texture:SetPoint("CENTER")
		end

		Button.Quest:Show()
		Button.Backdrop:SetBorderColor(1, 1, 0)
	else
		if Button.Quest and Button.Quest:IsShown() then
			Button.Quest:Hide()
		end
	end
end

local WEAPON = 2
local ARMOR = 4
local PROFESSION = 19
function Bags.ItemLevel(Button)
	local ID = Button:GetBagID()
	local Info = C_Container.GetContainerItemInfo(ID, Button:GetID())
	local ItemLink = Info and Info.hyperlink

	if ItemLink then
		local Level = C_Item.GetDetailedItemLevelInfo(ItemLink)
		local _, _, Rarity, _, _, _, _, _, _, _, _, ClassID = C_Item.GetItemInfo(ItemLink)

		-- Only weapons and armors have item levels (and profession tools but here the quality gems are shown instead)
		if ClassID and (ClassID == WEAPON or ClassID == ARMOR --[[or ClassID == PROFESSION]]) and Level and Level > 1 then
			if not Button.ItemLevel then
				Button.ItemLevel = Button:CreateFontString(nil, "ARTWORK")
				Button.ItemLevel:SetPoint("TOPRIGHT", 1, -1)
				Button.ItemLevel:SetFont(C.Medias.Font, 12, "OUTLINE")
				Button.ItemLevel:SetJustifyH("RIGHT")
			end

			Button.ItemLevel:SetText(Level)

			if Rarity then
				R, G, B = C_Item.GetItemQualityColor(Rarity)

				Button.ItemLevel:SetTextColor(R, G, B)
			else
				Button.ItemLevel:SetTextColor(1, 1, 1)
			end
		else
			if Button.ItemLevel then
				Button.ItemLevel:SetText("")
			end
		end
	else
		if Button.ItemLevel then
			Button.ItemLevel:SetText("")
		end
	end
end

function Bags:UpdateItems()
	for i, Button in self:EnumerateValidItems() do
		local ID = Button:GetBagID()
		local Info = C_Container.GetContainerItemInfo(ID, Button:GetID())
		local ItemLink = Info and Info.hyperlink
		local Texture = Info and Info.iconFileID
		local Count = Info and Info.stackCount
		local Lock = Info and Info.isLocked
		local Quality = Info and Info.quality
		local Readable = Info and Info.IsReadable
		local ItemLink = Info and Info.hyperlink
		local IsFiltered = Info and Info.isFiltered
		local NoValue = Info and Info.hasNoValue
		local ItemID = Info and Info.itemID
		local IsBound = Info and Info.isBound
		local R, G, B

		if Button.Backdrop then
			if Quality then
				R, G, B = C_Item.GetItemQualityColor(Quality)

				Button.Backdrop:SetBorderColor(R, G, B)
			else
				Button.Backdrop:SetBorderColor(unpack(C.General.BorderColor))
			end
		end

		-- Quest Items
		if C.Bags.IdentifyQuestItems then
			Bags.QuestItem(Button)
		end

		-- Items Level
		if C.Bags.ItemLevel then
			Bags.ItemLevel(Button)
		end
	end
end

function Bags:SkinContainer()
	local Container = ContainerFrameCombinedBags
	local NineSlice = Container.NineSlice
	local CloseButton = Container.CloseButton
	local Portrait = ContainerFrameCombinedBagsPortrait
	local TokensBorder = BackpackTokenFrame.Border
	local MoneyBorder = ContainerFrameCombinedBags.MoneyFrame.Border
	local SearchBox = BagItemSearchBox
	local SortButton = BagItemAutoSortButton

	NineSlice:StripTextures()
	NineSlice:SetTemplate()
	NineSlice:SetFrameLevel(0)
	NineSlice:CreateShadow()

	CloseButton:SkinCloseButton()

	Portrait:Kill()

	TokensBorder:Kill()

	MoneyBorder:Kill()

	SearchBox:StripTextures()
	SearchBox:SkinEditBox()

	-- Reagent Bag
	if ContainerFrame6 then
		local ReagentContainer = ContainerFrame6
		local ReagentNineSlice = ReagentContainer.NineSlice
		local ReagentCloseButton = ReagentContainer.CloseButton
		local ReagentPortrait = ContainerFrame6Portrait

		ReagentNineSlice:StripTextures()
		ReagentNineSlice:SetTemplate()
		ReagentNineSlice:SetFrameLevel(0)
		ReagentNineSlice:CreateShadow()

		ReagentCloseButton:SkinCloseButton()

		ReagentPortrait:Kill()
	end
end

function Bags:UpdatePosition()
	local Container = ContainerFrameCombinedBags
	local Position = TukuiDatabase.Variables[T.MyRealm][T.MyName].Move.ContainerFrameCombinedBags

	if Position then
		Container:ClearAllPoints()
		Container:SetPoint(unpack(Position))
	end
end

function Bags:AddHooks()
	hooksecurefunc("UpdateContainerFrameAnchors", Bags.UpdatePosition)
	hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", Bags.UpdateItems)
	hooksecurefunc(ContainerFrame6, "UpdateItems", Bags.UpdateItems)
end

function Bags:Enable()
	if (not C.Bags.Enable) then
		return
	end

	SetCVar("combinedBags", 1)
	C_Container.SetInsertItemsLeftToRight(false)

	if C.Bags.SortToBottom then
		C_Container.SetSortBagsRightToLeft(false)
	else
		C_Container.SetSortBagsRightToLeft(true)
	end

	-- Create the AIO container on load
	ToggleAllBags()
	ToggleAllBags()

	-- Start doing shit
	self:AddHooks()
	self:SkinContainer()
	self:SkinButtons()

	Movers:RegisterFrame(ContainerFrameCombinedBags, "Bags")
	
	if T.Retail then
		T.Print("NEWS: Tukui 22 will be back in full health for midnight with a total rewrite from scratch, meanwhile, here a patched version of Tukui 21 until Midnight release. If you see some errors, don't hesitate to ping me on Discord - Tukz")
	end
end

Inventory.Bags = Bags
