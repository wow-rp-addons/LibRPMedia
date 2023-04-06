-- This file is licensed under the terms expressed in the LICENSE file.
local ADDON_NAME = ...;

local LRPM12 = LibStub and LibStub:GetLibrary("LibRPMedia-1.2", true);

if not LRPM12 then
    return;
end

local function SafeIterator(source, ...)
    local unwrap = function(ok, ...)
        if not ok then
            return nil;
        end

        return ...;
    end

    local iterator = function(state, key)
        return unwrap(pcall(source, state, key));
    end

    return iterator, ...;
end

LibRPMedia_PaginationBarMixin = CreateFromMixins(CallbackRegistryMixin);
LibRPMedia_PaginationBarMixin:GenerateCallbackEvents({
    "OnPageChanged",
});

function LibRPMedia_PaginationBarMixin:OnLoad()
    CallbackRegistryMixin.OnLoad(self);

    self.pageCount = 1;
    self:FirstPage();
end

function LibRPMedia_PaginationBarMixin:OnMouseWheel(delta)
    self:AdvancePage(-delta);
end

function LibRPMedia_PaginationBarMixin:FirstPage()
    self:SetPageNumber(1);
end

function LibRPMedia_PaginationBarMixin:PreviousPage()
    self:AdvancePage(-1);
end

function LibRPMedia_PaginationBarMixin:NextPage()
    self:AdvancePage(1);
end

function LibRPMedia_PaginationBarMixin:LastPage()
    self:SetPageNumber(self:GetPageCount());
end

function LibRPMedia_PaginationBarMixin:AdvancePage(delta)
    self:SetPageNumber(self:GetPageNumber() + delta);
end

function LibRPMedia_PaginationBarMixin:GetPageNumber()
    return self.pageNumber;
end

function LibRPMedia_PaginationBarMixin:SetPageNumber(pageNumber)
    pageNumber = Clamp(pageNumber, 1, self.pageCount);

    if self.pageNumber == pageNumber then
        return;
    end

    self.pageNumber = pageNumber;
    self:UpdateVisualization();
    self:TriggerEvent("OnPageChanged", self, self.pageNumber);
end

function LibRPMedia_PaginationBarMixin:GetPageCount()
    return self.pageCount;
end

function LibRPMedia_PaginationBarMixin:SetPageCount(pageCount)
    self.pageCount = math.max(pageCount, 1);
    self:SetPageNumber(self:GetPageNumber());
    self:UpdateVisualization();
end

function LibRPMedia_PaginationBarMixin:UpdateVisualization()
    self.PageText:SetFormattedText("Page %d/%d", self.pageNumber, self.pageCount);

    self.PrevButton:SetEnabled(self.pageNumber > 1);
    self.NextButton:SetEnabled(self.pageNumber < self.pageCount);
end

LibRPMedia_SearchOptionsDropDownMixin = {};

function LibRPMedia_SearchOptionsDropDownMixin:OnLoad()
    UIDropDownMenu_SetInitializeFunction(self, self.Initialize, "MENU");
end

function LibRPMedia_SearchOptionsDropDownMixin:Initialize(level)
    local info = {};

    local _, method = CallMethodOnNearestAncestor(self, "GetSearchMethod");
    local methodSetter = function(item)
        CallMethodOnNearestAncestor(self, "SetSearchMethod", item.value);
    end

    info.hasArrow = false;
    info.isNotRadio = nil;
    info.notCheckable = nil;
    info.keepShownOnClick = nil;

    info.text = "Search by Prefix";
    info.func = methodSetter;
    info.value = "prefix";
    info.checked = (method == info.value or method == nil);
    UIDropDownMenu_AddButton(info, level);

    info.text = "Search by Substring";
    info.func = methodSetter;
    info.value = "substring";
    info.checked = (method == info.value);
    UIDropDownMenu_AddButton(info, level);

    info.text = "Search by Pattern";
    info.func = methodSetter;
    info.value = "pattern";
    info.checked = (method == info.value);
    UIDropDownMenu_AddButton(info, level);
end

LibRPMedia_IconPreviewMixin = {};

function LibRPMedia_IconPreviewMixin:OnLoad()
    self:SetIconIndex(self.iconIndex);
end

function LibRPMedia_IconPreviewMixin:OnEnter()
    self:UpdateTooltipVisualization();
end

function LibRPMedia_IconPreviewMixin:OnLeave()
    self:UpdateTooltipVisualization();
end

function LibRPMedia_IconPreviewMixin:OnClick()
    self.showIconByFile = not self.showIconByFile;
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);

    self:UpdateVisualization();
    self:UpdateTooltipVisualization();
end

function LibRPMedia_IconPreviewMixin:ClearIconIndex()
    self:SetIconIndex(nil);
end

function LibRPMedia_IconPreviewMixin:GetIconIndex(iconIndex)
    return self.iconIndex;
end

function LibRPMedia_IconPreviewMixin:SetIconIndex(iconIndex)
    self.iconIndex = iconIndex;
    self.showIconByFile = false;

    self:UpdateVisualization();
    self:UpdateTooltipVisualization();
end

function LibRPMedia_IconPreviewMixin:IsValidIconIndex()
    if not self.iconIndex then
        return false;
    end

    return self.iconIndex > 0 and self.iconIndex <= LRPM12:GetNumIcons();
end

function LibRPMedia_IconPreviewMixin:UpdateVisualization()
    local iconInfo = LRPM12:GetIconInfoByIndex(self.iconIndex);
    LRPM12:SetTextureToIcon(self.Icon, iconInfo and iconInfo.name or "");
end

function LibRPMedia_IconPreviewMixin:UpdateTooltipVisualization()
    local iconInfo = LRPM12:GetIconInfoByIndex(self.iconIndex);

    if not self:IsMouseMotionFocus() or not iconInfo then
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide();
        end

        return;
    end

    local iconName = iconInfo.name;
    local iconFile = iconInfo.file;
    local iconType = iconInfo.type;

    local iconTypeText = tostring(iconType);

    if iconType == LRPM12.IconType.File then
        iconTypeText = "Texture";
    elseif iconType == LRPM12.IconType.Atlas then
        iconTypeText = "Atlas";
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip_SetTitle(GameTooltip, iconName, GREEN_FONT_COLOR, false);

    local fileLineText = string.format("File: |cffffffff%s|r", iconFile or "nil");
    GameTooltip_AddNormalLine(GameTooltip, fileLineText, false);

    local typeLineText = string.format("Type: |cffffffff%s|r", iconTypeText);
    GameTooltip_AddNormalLine(GameTooltip, typeLineText, false);

    if iconType == LRPM12.IconType.File and self.showIconByFile then
        local displayText = "|c0042b1fe<Showing via File ID>|r";
        GameTooltip_AddNormalLine(GameTooltip, displayText, false);
    end

    GameTooltip:Show();
end

LibRPMedia_IconContentMixin = {};

function LibRPMedia_IconContentMixin:OnLoad()
    self.icons = {};
    self.iconPool = CreateFramePool("Button", self.IconsFrame, "LibRPMedia_IconPreviewTemplate");
    self.PaginationBar:RegisterCallback("OnPageChanged", function() self:UpdateIconVisualization(); end, self);
    self:SetSearchFilter("");
end

function LibRPMedia_IconContentMixin:OnMouseWheel(delta)
    self.PaginationBar:AdvancePage(-delta);
end

function LibRPMedia_IconContentMixin:OnSizeChanged()
    self:UpdateVisualization();
end

function LibRPMedia_IconContentMixin:SetSearchFilter(query, options)
    table.wipe(self.icons);

    for iconInfo in SafeIterator(LRPM12:FindIcons(query, options)) do
        table.insert(self.icons, iconInfo.index);
    end

    self:UpdateVisualization();
end

function LibRPMedia_IconContentMixin:GetIconSize()
    return self.iconWidth, self.iconHeight;
end

function LibRPMedia_IconContentMixin:SetIconSize(iconWidth, iconHeight)
    self.iconWidth, self.iconHeight = iconWidth, iconHeight;
    self:UpdateVisualization();
end

function LibRPMedia_IconContentMixin:GetNumIcons()
    return #self.icons;
end

function LibRPMedia_IconContentMixin:CalculateGridSize()
    local gridWidth, gridHeight = self.IconsFrame:GetSize();
    if gridWidth == 0 or gridHeight == 0 then
        return 0, 0, 0;
    end

    local iconWidth, iconHeight = self:GetIconSize();
    if iconWidth == 0 or iconHeight == 0 then
        return 0, 0, 0;
    end

    local columns = math.floor(gridWidth / iconWidth);
    local rows = math.floor(gridHeight / iconHeight);

    return columns, rows, columns * rows;
end

function LibRPMedia_IconContentMixin:UpdateVisualization()
    self:UpdatePageVisualization();
    self:UpdateIconVisualization();
end

function LibRPMedia_IconContentMixin:UpdatePageVisualization()
    local gridCells = select(3, self:CalculateGridSize());
    local iconCount = self:GetNumIcons();
    local pageCount = 0;

    if gridCells > 0 then
        pageCount = math.ceil(iconCount / gridCells);
    end

    self.PaginationBar:SetPageCount(pageCount);
end

function LibRPMedia_IconContentMixin:UpdateIconVisualization()
    local gridColumns, gridRows, gridCells = self:CalculateGridSize();
    local iconWidth, iconHeight = self:GetIconSize();

    local pageNumber = self.PaginationBar:GetPageNumber();
    local iconOffset = ((pageNumber - 1) * gridCells);

    self.iconPool:ReleaseAll();

    for gridIndex = 1, gridCells do
        local gridColumn = ((gridIndex - 1) % gridColumns) + 1;
        local gridRow = math.floor((gridIndex - 1) / gridColumns) + 1;

        local iconWidget = self.iconPool:Acquire();
        local iconParent = self.IconsFrame;

        local iconX = -(((gridColumns / 2) - (gridColumn - 1)) * iconWidth);
        local iconY = ((gridRows / 2) - (gridRow - 1)) * iconHeight;
        iconWidget:SetPoint("TOPLEFT", iconParent, "CENTER", iconX, iconY);
        iconWidget:SetSize(iconWidth, iconHeight);

        local iconIndex = self.icons[iconOffset + gridIndex];
        iconWidget:SetIconIndex(iconIndex);
        iconWidget:SetShown(iconWidget:IsValidIconIndex());
    end
end

LibRPMedia_IconBrowserMixin = {};

function LibRPMedia_IconBrowserMixin:OnLoad()
    self:SetSearchMethod("substring");
end

function LibRPMedia_IconBrowserMixin:GetSearchMethod()
    return self.searchMethod;
end

function LibRPMedia_IconBrowserMixin:SetSearchMethod(searchMethod)
    self.searchMethod = searchMethod;
    self:UpdateVisualization();
end

function LibRPMedia_IconBrowserMixin:UpdateVisualization()
    -- Update the search filter on the content frame.
    self.ContentFrame:SetSearchFilter(self.SearchBox:GetText(), {
        method = self.searchMethod,
    });
end

LibRPMedia_MusicColumnDisplayMixin = CreateFromMixins(ColumnDisplayMixin);

function LibRPMedia_MusicColumnDisplayMixin:OnLoad()
    ColumnDisplayMixin.OnLoad(self);

    self.sortingFunction = function(_, columnIndex)
        CallMethodOnNearestAncestor(self, "SortByColumnIndex", columnIndex);
    end

    self:LayoutColumns({
        { title = "File", width = 120 },
        { title = "Name", width = 450 },
        { title = "Duration", width = 0 },
    });
end

LibRPMedia_MusicItemRowMixin = {};

function LibRPMedia_MusicItemRowMixin:OnLoad()
    self:ClearMusicName();
end

function LibRPMedia_MusicItemRowMixin:OnClick(button)
    StopMusic();

    if button == "LeftButton" and self:IsValidMusicName() then
        local musicInfo = LRPM12:GetMusicInfoByName(self.musicName);

        if musicInfo then
            LRPM12:PlayMusic(musicInfo.id);
        end
    end

    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
end

function LibRPMedia_MusicItemRowMixin:OnEnter(button)
    self:UpdateTooltipVisualization();
end

function LibRPMedia_MusicItemRowMixin:OnLeave(button)
    self:UpdateTooltipVisualization();
end

function LibRPMedia_MusicItemRowMixin:ClearMusicName()
    self:SetMusicName(nil);
end

function LibRPMedia_MusicItemRowMixin:GetMusicName()
    return self.musicName;
end

function LibRPMedia_MusicItemRowMixin:SetMusicName(musicName)
    self.musicName = musicName;

    self:UpdateVisualization();
    self:UpdateTooltipVisualization();
end

function LibRPMedia_MusicItemRowMixin:IsValidMusicName()
    if not self.musicName then
        return false;
    end

    return LRPM12:GetMusicInfoByName(self.musicName) ~= nil;
end

function LibRPMedia_MusicItemRowMixin:GetStripeShown()
    return self.Stripe:IsShown();
end

function LibRPMedia_MusicItemRowMixin:SetStripeShown(shown)
    self.Stripe:SetShown(shown);
end

function LibRPMedia_MusicItemRowMixin:UpdateVisualization()
    local musicName = self.musicName;
    local musicFile;
    local musicDuration = 0;

    local musicInfo = LRPM12:GetMusicInfoByName(musicName);

    if musicInfo then
        musicFile = musicInfo.file;
        musicDuration = musicInfo.duration;
    end

    self.FileText:SetText(musicFile or "");
    self.NameText:SetText(musicName or "");
    self.DurationText:SetText(SecondsToTime(musicDuration));
end

function LibRPMedia_MusicItemRowMixin:UpdateTooltipVisualization()
    local musicInfo = LRPM12:GetMusicInfoByName(self.musicName);

    if not self:IsMouseMotionFocus() or not musicInfo then
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide();
        end

        return;
    end

    local musicIndex = musicInfo.index;
    local musicName = musicInfo.names[1];
    local musicFile = musicInfo.file;
    local musicDuration = musicInfo.duration;

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip_SetTitle(GameTooltip, self.musicName, GREEN_FONT_COLOR);

    if self.musicName ~= musicName then
        local nameLine = "Name: |cffffffff" .. musicName;
        GameTooltip_AddNormalLine(GameTooltip, nameLine);
    end

    local timeLine = "Duration: |cffffffff" .. SecondsToTime(musicDuration);
    local fileLine = "File: |cffffffff" .. tostring(musicFile);
    local indexLine = "Index: |cffffffff" .. tostring(musicIndex);

    GameTooltip_AddNormalLine(GameTooltip, timeLine);
    GameTooltip_AddNormalLine(GameTooltip, fileLine);
    GameTooltip_AddNormalLine(GameTooltip, indexLine);
    GameTooltip_AddNormalLine(GameTooltip, " ");

    GameTooltip_AddInstructionLine(GameTooltip, "Left-Click: |cffffffffPlay Music");
    GameTooltip_AddInstructionLine(GameTooltip, "Right-Click: |cffffffffStop Music");

    GameTooltip:Show();
end

LibRPMedia_MusicScrollMixin = {};

LibRPMedia_MusicScrollMixin.ROW_HEIGHT = 25;

function LibRPMedia_MusicScrollMixin:OnLoad()
    self.music = {};
    self.sortIndex = 1;
    self.sortAscending = true;
    self.itemPool = CreateFramePool("Button", self, "LibRPMedia_MusicItemRowTemplate");
end

function LibRPMedia_MusicScrollMixin:OnShow()
    FauxScrollFrame_SetOffset(self, 0);
    self.ScrollBar:SetValue(0);
    self:UpdateVisualization();
end

function LibRPMedia_MusicScrollMixin:OnVerticalScroll(offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, self.ROW_HEIGHT, function() self:UpdateVisualization(); end);
end

function LibRPMedia_MusicScrollMixin:SetSearchFilter(query, options)
    table.wipe(self.music);

    for musicInfo in SafeIterator(LRPM12:FindMusic(query, options)) do
        table.insert(self.music, musicInfo.names[1]);
    end

    self:SortByColumnIndex(self.sortIndex, self.sortAscending);
end

function LibRPMedia_MusicScrollMixin:SortByColumnIndex(columnIndex, ascending)
    if self.sortIndex == columnIndex then
        self.sortAscending = not self.sortAscending;
    else
        self.sortIndex = columnIndex;
        self.sortAscending = true;
    end

    if ascending ~= nil then
        self.sortAscending = ascending;
    end

    local predicate = function(a, b)
        if self.sortAscending then
            return a < b;
        else
            return a > b;
        end
    end

    local music = {};
    for _, musicName in ipairs(self.music) do
        local value;
        if columnIndex == 1 then
            -- Sorting by file ID.
            local musicInfo = LRPM12:GetMusicInfoByName(musicName);
            value = musicInfo and musicInfo.file or 0;
        elseif columnIndex == 2 then
            -- Sorting by name.
            value = musicName;
        elseif columnIndex == 3 then
            -- Sorting by duration.
            local musicInfo = LRPM12:GetMusicInfoByName(musicName);
            value = musicInfo and musicInfo.duration or 0;
        else
            -- Invalid column; ignore the request.
            return;
        end

        table.insert(music, { key = musicName, value = value })
    end

    table.sort(music, function(a, b) return predicate(a.value, b.value); end);

    table.wipe(self.music);
    for _, row in ipairs(music) do
        table.insert(self.music, row.key);
    end

    self:UpdateVisualization();
end

function LibRPMedia_MusicScrollMixin:UpdateVisualization()
    local musicRowHeight = self.ROW_HEIGHT;
    local musicCount = #self.music;
    local musicShown = math.floor(self:GetHeight() / musicRowHeight);
    local itemOffset = FauxScrollFrame_GetOffset(self);

    self.itemPool:ReleaseAll();

    local previousWidget = nil;
    for itemIndex = 1, musicShown do
        local itemWidget = self.itemPool:Acquire();
        itemWidget:SetHeight(musicRowHeight);

        if previousWidget then
            itemWidget:SetPoint("TOP", previousWidget, "BOTTOM", 0, 0);
        else
            itemWidget:SetPoint("TOP", self, "TOP", 0, 0);
        end

        itemWidget:SetPoint("LEFT", 0, 0);
        itemWidget:SetPoint("RIGHT", 0, 0);

        local musicIndex = itemOffset + itemIndex;
        itemWidget:SetMusicName(self.music[musicIndex]);
        itemWidget:SetStripeShown(itemIndex % 2 == 0);
        itemWidget:SetShown(self.music[musicIndex] ~= nil);

        previousWidget = itemWidget;
    end

    self.ScrollBar.scrollStep = math.floor(musicShown / 2) * musicRowHeight;
    FauxScrollFrame_Update(self, musicCount, musicShown, musicRowHeight, nil, nil, nil, nil, nil, nil, true);
end

LibRPMedia_MusicBrowserMixin = {};

function LibRPMedia_MusicBrowserMixin:OnLoad()
    self:SetSearchMethod("substring");
end

function LibRPMedia_MusicBrowserMixin:GetSearchMethod()
    return self.searchMethod;
end

function LibRPMedia_MusicBrowserMixin:SetSearchMethod(searchMethod)
    self.searchMethod = searchMethod;
    self:UpdateVisualization();
end

function LibRPMedia_MusicBrowserMixin:SortByColumnIndex(columnIndex)
    self.ContentFrame.ScrollFrame:SortByColumnIndex(columnIndex);
end

function LibRPMedia_MusicBrowserMixin:UpdateVisualization()
    self.ContentFrame.ScrollFrame:SetSearchFilter(self.SearchBox:GetText(), { method = self.searchMethod });
end

LibRPMedia_BrowserTabMixin = {};

function LibRPMedia_BrowserTabMixin:OnLoad()
end

function LibRPMedia_BrowserTabMixin:OnClick()
    CallMethodOnNearestAncestor(self, "SetTab", self:GetID());
    PlaySound(SOUNDKIT.UI_TOYBOX_TABS);
end

LibRPMedia_BrowserMixin = {};
LibRPMedia_BrowserMixin.TABS_COUNT = 2;
LibRPMedia_BrowserMixin.TABS_MAX_WIDTH = 185;
LibRPMedia_BrowserMixin.TAB_ICONS = 1;
LibRPMedia_BrowserMixin.TAB_MUSIC = 2;

function LibRPMedia_BrowserMixin:OnLoad()
    PanelTemplates_SetNumTabs(self, self.TABS_COUNT);

    self:SetTab(self.TAB_ICONS);

    if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
        local asset = [[Interface\Icons\INV_Box_04]];
        SetPortraitToTexture(self.portrait, asset);
    else
        local asset = [[Interface\Icons\Inv_legion_chest_KirinTor]];
        self:SetPortraitToAsset(asset);
    end

    self:SetTitle(string.format("%s: Media Browser", ADDON_NAME));
end

function LibRPMedia_BrowserMixin:OnShow()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN);
end

function LibRPMedia_BrowserMixin:OnHide()
    PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE);
end

function LibRPMedia_BrowserMixin:SetTab(tabID)
    PanelTemplates_SetTab(self, tabID);
    PanelTemplates_ResizeTabsToFit(self, self.TABS_MAX_WIDTH);

    self.IconsFrame:SetShown(tabID == self.TAB_ICONS);
    self.MusicFrame:SetShown(tabID == self.TAB_MUSIC);
end
