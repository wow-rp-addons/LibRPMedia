-- This file is licensed under the terms expressed in the LICENSE file.
local ADDON_NAME = ...;

local LibRPMedia = LibStub and LibStub:GetLibrary("LibRPMedia-1.0", true);
if not LibRPMedia then
    return;
end

-- Upvalues.
local ceil = math.ceil;
local floor = math.floor;
local strformat = string.format;
local strgsub = string.gsub;
local tinsert = table.insert;
local tsort = table.sort;
local twipe = table.wipe;

--- Returns true if running in the classic client.
local function IsClassicClient()
    return WOW_PROJECT_ID == WOW_PROJECT_CLASSIC;
end

--- Wraps the given iterator in a protected version which will return nil
--  if an error is raised.
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

--- Mixin that allows pagination of content via a bar with page buttons.
LibRPMedia_PaginationBarMixin = CreateFromMixins(CallbackRegistryMixin);
LibRPMedia_PaginationBarMixin:GenerateCallbackEvents({
    "OnPageChanged",
});

function LibRPMedia_PaginationBarMixin:OnLoad()
    CallbackRegistryMixin.OnLoad(self);

    -- Initialize with a single page.
    self.pageCount = 1;
    self:FirstPage();
end

function LibRPMedia_PaginationBarMixin:OnMouseWheel(delta)
    -- Scroll down should go to the next page, so invert the delta.
    self:AdvancePage(-delta);
end

--- Sets the current page number to the first page.
function LibRPMedia_PaginationBarMixin:FirstPage()
    self:SetPageNumber(1);
end

--- Sets the current page number to the previous page.
function LibRPMedia_PaginationBarMixin:PreviousPage()
    self:AdvancePage(-1);
end

--- Sets the current page number to the next page.
function LibRPMedia_PaginationBarMixin:NextPage()
    self:AdvancePage(1);
end

--- Sets the current page number to the last page.
function LibRPMedia_PaginationBarMixin:LastPage()
    self:SetPageNumber(self:GetPageCount());
end

--- Advances the current page number by the given delta.
function LibRPMedia_PaginationBarMixin:AdvancePage(delta)
    self:SetPageNumber(self:GetPageNumber() + delta);
end

--- Returns the current page number.
function LibRPMedia_PaginationBarMixin:GetPageNumber()
    return self.pageNumber;
end

--- Sets the current page number, in the range 1 though GetPageCount. If the
--  given page number is outside of this range, it is clamped to within range.
--
--  If the page number changes, OnPageChanged is emitted with the new page
--  number.
function LibRPMedia_PaginationBarMixin:SetPageNumber(pageNumber)
    -- Clamp page range to 1 through GetPageCount.
    pageNumber = Clamp(pageNumber, 1, self.pageCount);
    if self.pageNumber == pageNumber then
        -- Page isn't changing; no need to signal anything.
        return;
    end

    self.pageNumber = pageNumber;
    self:UpdateVisualization();
    self:TriggerEvent("OnPageChanged", self, self.pageNumber);
end

--- Returns the maximum number of pages.
function LibRPMedia_PaginationBarMixin:GetPageCount()
    return self.pageCount;
end

--- Sets the maximum number of pages, in the range of 1 through infinity.
--  If the given page count is outside this range, it is clamped implicitly.
--
--  Changing the page count will additionally cause the current page number
--  to be clamped to the new range, potentially emitting OnPageChanged if the
--  previous page number was higher than the new page count.
function LibRPMedia_PaginationBarMixin:SetPageCount(pageCount)
    -- Page count must be a minimum of 1.
    self.pageCount = math.max(pageCount, 1);

    -- Update the page number; this will clamp to the new max range.
    self:SetPageNumber(self:GetPageNumber());
    self:UpdateVisualization();
end

--- Updates the UI for the page bar.
function LibRPMedia_PaginationBarMixin:UpdateVisualization()
    self.PageText:SetFormattedText("Page %d/%d",
        self.pageNumber, self.pageCount);

    self.PrevButton:SetEnabled(self.pageNumber > 1);
    self.NextButton:SetEnabled(self.pageNumber < self.pageCount);
end

--- Mixin for a dropdown that provides search options.
LibRPMedia_SearchOptionsDropDownMixin = {};

function LibRPMedia_SearchOptionsDropDownMixin:OnLoad()
    UIDropDownMenu_Initialize(self, self.Initialize, "MENU");
end

--- Initializes the dropdown, populating it with search options.
function LibRPMedia_SearchOptionsDropDownMixin:Initialize(level)
    local info = UIDropDownMenu_CreateInfo();

    -- Search methods.
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

--- Mixin for an icon preview widget.
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

--- Unsets the current icon index used by the widget, clearing its display.
function LibRPMedia_IconPreviewMixin:ClearIconIndex()
    self:SetIconIndex(nil);
end

--- Returns the icon index being displayed by the widget, if any is set.
function LibRPMedia_IconPreviewMixin:GetIconIndex(iconIndex)
    return self.iconIndex;
end

--- Sets the icon index to be displayed by the widget.
function LibRPMedia_IconPreviewMixin:SetIconIndex(iconIndex)
    self.iconIndex = iconIndex;
    self.showIconByFile = false;

    self:UpdateVisualization();
    self:UpdateTooltipVisualization();
end

--- Returns true if the icon index used by the widget is within the range
--  allowable by the database.
function LibRPMedia_IconPreviewMixin:IsValidIconIndex()
    if not self.iconIndex then
        return false;
    end

    return self.iconIndex > 0 and self.iconIndex <= LibRPMedia:GetNumIcons();
end

--- Updates the UI for the widget based on the current icon index.
function LibRPMedia_IconPreviewMixin:UpdateVisualization()
    local iconFile = 0;
    local iconName = [[Interface\Icons\INV_Misc_QuestionMark]];
    local iconType = LibRPMedia.IconType.Texture;

    if self:IsValidIconIndex() then
        -- Icon is valid; query for actual data.
        iconFile = LibRPMedia:GetIconFileByIndex(self.iconIndex);
        iconName = LibRPMedia:GetIconNameByIndex(self.iconIndex);
        iconType = LibRPMedia:GetIconTypeByIndex(self.iconIndex);
    end

    if iconType == LibRPMedia.IconType.Texture then
        if self.showIconByFile then
            self.Icon:SetTexture(iconFile);
        else
            self.Icon:SetTexture([[Interface\Icons\]] .. iconName);
        end
    elseif iconType == LibRPMedia.IconType.Atlas then
        self.Icon:SetAtlas(iconName, false);
    else
        -- Unhandled type. We don't know how to display it, so default.
        self.Icon:SetTexture([[Interface\Icons\INV_Misc_QuestionMark]]);
    end
end

--- Updates the tooltip for the widget based on the current icon index.
function LibRPMedia_IconPreviewMixin:UpdateTooltipVisualization()
    local isMouseFocus = (GetMouseFocus() == self);
    if not isMouseFocus or not self:IsValidIconIndex() then
        -- The widget isn't focused or the icon index is now invalid.
        if GameTooltip:GetOwner() == self then
            -- We own the tooltip, so we should hide it.
            GameTooltip:Hide();
        end

        return;
    end

    -- The icon index is otherwise valid, so obtain the data and display.
    local iconName = LibRPMedia:GetIconNameByIndex(self.iconIndex);
    local iconFile = LibRPMedia:GetIconFileByIndex(self.iconIndex);
    local iconType = LibRPMedia:GetIconTypeByIndex(self.iconIndex);

    local iconTypeText = tostring(iconType);
    if iconType == LibRPMedia.IconType.Texture then
        iconTypeText = "Texture";
    elseif iconType == LibRPMedia.IconType.Atlas then
        iconTypeText = "Atlas";
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip_SetTitle(GameTooltip, iconName, GREEN_FONT_COLOR, false);

    local fileLineText = strformat("File: |cffffffff%s|r", iconFile or "nil");
    GameTooltip_AddNormalLine(GameTooltip, fileLineText, false);

    local typeLineText = strformat("Type: |cffffffff%s|r", iconTypeText);
    GameTooltip_AddNormalLine(GameTooltip, typeLineText, false);

    if iconType == LibRPMedia.IconType.Texture and self.showIconByFile then
        local displayText = "|c0042b1fe<Showing via File ID>|r";
        GameTooltip_AddNormalLine(GameTooltip, displayText, false);
    end

    GameTooltip:Show();
end

--- Mixin for the icon browser content frame widget.
LibRPMedia_IconContentMixin = {};

function LibRPMedia_IconContentMixin:OnLoad()
    -- Array of icon indices to display in the browser.
    self.icons = {};
    -- Pool of icon widgets to display in the UI for each index.
    self.iconPool = CreateFramePool("Button", self.IconsFrame,
        "LibRPMedia_IconPreviewTemplate");

    -- When the page changes, we'll need to update our icons.
    self.PaginationBar:RegisterCallback("OnPageChanged", function()
        self:UpdateIconVisualization();
    end, self);

    -- Start by displaying all icons.
    self:SetSearchFilter("");
end

function LibRPMedia_IconContentMixin:OnMouseWheel(delta)
    -- The bar itself allows scrolling, but it also feels good if the whole
    -- frame can have the same behaviour.
    self.PaginationBar:AdvancePage(-delta);
end

function LibRPMedia_IconContentMixin:OnSizeChanged()
    self:UpdateVisualization();
end

--- Resets the icons displayed by the frame and re-queries the library
--  using the given query string and options.
function LibRPMedia_IconContentMixin:SetSearchFilter(query, options)
    twipe(self.icons);

    for iconIndex in SafeIterator(LibRPMedia:FindIcons(query, options)) do
        tinsert(self.icons, iconIndex);
    end

    self:UpdateVisualization();
end

--- Returns the size of icon widgets managed by this frame.
function LibRPMedia_IconContentMixin:GetIconSize()
    return self.iconWidth, self.iconHeight;
end

--- Sets the size of icon widgets managed by this frame.
function LibRPMedia_IconContentMixin:SetIconSize(iconWidth, iconHeight)
    self.iconWidth, self.iconHeight = iconWidth, iconHeight;
    self:UpdateVisualization();
end

--- Returns the total number of icons being hosted by the frame.
function LibRPMedia_IconContentMixin:GetNumIcons()
    return #self.icons;
end

--- Calculates the number of displayable icons on the content grid based
--  upon the size of the frame and icons, returning the number of columns,
--  rows, and total number of cells per page.
--
--  If the size cannot be calculated, all values returned are zero.
function LibRPMedia_IconContentMixin:CalculateGridSize()
    local gridWidth, gridHeight = self.IconsFrame:GetSize();
    if gridWidth == 0 or gridHeight == 0 then
        return 0, 0, 0;
    end

    local iconWidth, iconHeight = self:GetIconSize();
    if iconWidth == 0 or iconHeight == 0 then
        return 0, 0, 0;
    end

    local columns = floor(gridWidth / iconWidth);
    local rows = floor(gridHeight / iconHeight);

    return columns, rows, columns * rows;
end

--- Updates all subwidgets on the UI.
function LibRPMedia_IconContentMixin:UpdateVisualization()
    self:UpdatePageVisualization();
    self:UpdateIconVisualization();
end

--- Updates the pagination bar on the UI to cap the page count appropriately.
function LibRPMedia_IconContentMixin:UpdatePageVisualization()
    -- The number of pages required is based on the icon count and size of
    -- the displayable grid in terms of its cells-per-page.
    local gridCells = select(3, self:CalculateGridSize());
    local iconCount = self:GetNumIcons();
    local pageCount = 0;

    if gridCells > 0 then
        pageCount = ceil(iconCount / gridCells);
    end

    self.PaginationBar:SetPageCount(pageCount);
end

--- Updates the UI to display icons based on the current selected page.
function LibRPMedia_IconContentMixin:UpdateIconVisualization()
    local gridColumns, gridRows, gridCells = self:CalculateGridSize();
    local iconWidth, iconHeight = self:GetIconSize();

    -- We'll need the current page and an offset for obtaining the icon index.
    local pageNumber = self.PaginationBar:GetPageNumber();
    local iconOffset = ((pageNumber - 1) * gridCells);

    self.iconPool:ReleaseAll();

    -- Iterate over the total number of displayable cells; from this we can
    -- calculate the column/row and the index of the icon.
    for gridIndex = 1, gridCells do
        -- Acquire and position an icon widget for this cell.
        local gridColumn = ((gridIndex - 1) % gridColumns) + 1;
        local gridRow = floor((gridIndex - 1) / gridColumns) + 1;

        local iconWidget = self.iconPool:Acquire();
        local iconParent = self.IconsFrame;

        -- We want the icons to be centered both horizontally and vertically
        -- in the frame, hence the below calculations.
        local iconX = -(((gridColumns / 2) - (gridColumn - 1)) * iconWidth);
        local iconY = ((gridRows / 2) - (gridRow - 1)) * iconHeight;
        iconWidget:SetPoint("TOPLEFT", iconParent, "CENTER", iconX, iconY);
        iconWidget:SetSize(iconWidth, iconHeight);

        -- Display the appropriate icon within this widget.
        local iconIndex = self.icons[iconOffset + gridIndex];
        iconWidget:SetIconIndex(iconIndex);
        iconWidget:SetShown(iconWidget:IsValidIconIndex());
    end
end

--- Mixin for the icon browser frame.
LibRPMedia_IconBrowserMixin = {};

function LibRPMedia_IconBrowserMixin:OnLoad()
    -- Start off with a sensible search method.
    self:SetSearchMethod("substring");
end

--- Returns the search method used by the icon browser.
function LibRPMedia_IconBrowserMixin:GetSearchMethod()
    return self.searchMethod;
end

--- Sets the search method used by the icon browser.
function LibRPMedia_IconBrowserMixin:SetSearchMethod(searchMethod)
    self.searchMethod = searchMethod;
    self:UpdateVisualization();
end

--- Updates the UI of the browser, refreshing icons according to the search
--  parameters.
function LibRPMedia_IconBrowserMixin:UpdateVisualization()
    -- Update the search filter on the content frame.
    self.ContentFrame:SetSearchFilter(self.SearchBox:GetText(), {
        method = self.searchMethod,
    });
end

--- Mixin for the column list on the music browser.
LibRPMedia_MusicColumnDisplayMixin = CreateFromMixins(ColumnDisplayMixin);

function LibRPMedia_MusicColumnDisplayMixin:OnLoad()
    ColumnDisplayMixin.OnLoad(self);

    self.sortingFunction = function(_, columnIndex)
        CallMethodOnNearestAncestor(self, "SortByColumnIndex", columnIndex);
    end

    self:LayoutColumns({
        [1] = {
            title = "File",
            width = 120,
        },
        [2] = {
            title = "Name",
            width = 450,
        },
        [3] = {
            title = "Duration",
            width = 0,
        },
    });
end

--- Mixin for individual music item rows in the music browser.
LibRPMedia_MusicItemRowMixin = {};

function LibRPMedia_MusicItemRowMixin:OnLoad()
    self:ClearMusicName();
end

function LibRPMedia_MusicItemRowMixin:OnClick(button)
    -- Always stop currently playing music irrespective of button.
    StopMusic();

    if button == "LeftButton" and self:IsValidMusicName() then
        -- Left button was clicked; Classic client doesn't support playing
        -- via file IDs so we'll need to use the path instead.
        if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
            -- The name we might have could be an alias; we need the real one.
            local musicIndex = LibRPMedia:GetMusicIndexByName(self.musicName);
            local musicName = LibRPMedia:GetMusicNameByIndex(musicIndex);
            musicName = strgsub(musicName, "/", "\\");

            PlayMusic(strformat([[Sound\Music\%s.mp3]], musicName));
        else
            local musicFile = LibRPMedia:GetMusicFileByName(self.musicName);
            if musicFile then
                PlayMusic(musicFile);
            end
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

--- Resets the music name displayed by this row.
function LibRPMedia_MusicItemRowMixin:ClearMusicName()
    self:SetMusicName(nil);
end

--- Returns the music name displayed by this row.
function LibRPMedia_MusicItemRowMixin:GetMusicName()
    return self.musicName;
end

--- Sets the music name to be displayed by this row.
function LibRPMedia_MusicItemRowMixin:SetMusicName(musicName)
    self.musicName = musicName;

    self:UpdateVisualization();
    self:UpdateTooltipVisualization();
end

--- Returns true if the currently assigned music name points to a valid entry
--  in the database.
function LibRPMedia_MusicItemRowMixin:IsValidMusicName()
    if not self.musicName then
        return false;
    end

    return LibRPMedia:GetMusicIndexByName(self.musicName) ~= nil;
end

--- Returns true if the background stripe on the row is showing.
function LibRPMedia_MusicItemRowMixin:GetStripeShown()
    return self.Stripe:IsShown();
end

--- Sets the shown state of the background stripe on the row.
function LibRPMedia_MusicItemRowMixin:SetStripeShown(shown)
    self.Stripe:SetShown(shown);
end

--- Updates the UI for the row.
function LibRPMedia_MusicItemRowMixin:UpdateVisualization()
    local musicName = self.musicName;
    local musicFile;
    local musicDuration = 0;

    if self:IsValidMusicName() then
        musicFile = LibRPMedia:GetMusicFileByName(musicName);
        musicDuration = LibRPMedia:GetMusicFileDuration(musicFile);
    end

    self.FileText:SetText(musicFile or "");
    self.NameText:SetText(musicName or "");
    self.DurationText:SetText(SecondsToTime(musicDuration));
end

--- Updates the tooltip for the row, showing/hiding it if needed.
function LibRPMedia_MusicItemRowMixin:UpdateTooltipVisualization()
    local isMouseFocus = (GetMouseFocus() == self);
    if not isMouseFocus or not self:IsValidMusicName() then
        -- The widget isn't focused or the music name is invalid.
        if GameTooltip:GetOwner() == self then
            -- We own the tooltip, so we should hide it.
            GameTooltip:Hide();
        end

        return;
    end

    -- The music index is otherwise valid, so obtain the data and display.
    local musicIndex = LibRPMedia:GetMusicIndexByName(self.musicName);
    local musicName = LibRPMedia:GetMusicNameByIndex(musicIndex);
    local musicFile = LibRPMedia:GetMusicFileByIndex(musicIndex);
    local musicDuration = LibRPMedia:GetMusicFileDuration(musicFile);

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

    GameTooltip_AddInstructionLine(GameTooltip,
        "Left-Click: |cffffffffPlay Music");
    GameTooltip_AddInstructionLine(GameTooltip,
        "Right-Click: |cffffffffStop Music");

    GameTooltip:Show();
end

--- Mixin for the music scroll frame.
LibRPMedia_MusicScrollMixin = {};

--- Height of each row in the frame.
LibRPMedia_MusicScrollMixin.ROW_HEIGHT = 25;

function LibRPMedia_MusicScrollMixin:OnLoad()
    -- List of music names that pass the assigned filter.
    self.music = {};

    -- Sorting state for columns in the UI. The index is the column number,
    -- and ascending is true if the data is sorted in ascending order.
    self.sortIndex = 1;
    self.sortAscending = true;

    -- Pool of item widgets to display as rows.
    self.itemPool = CreateFramePool("Button", self,
        "LibRPMedia_MusicItemRowTemplate");
end

function LibRPMedia_MusicScrollMixin:OnShow()
    -- Reset to the start of the list upon being shown.
    FauxScrollFrame_SetOffset(self, 0);
    self.ScrollBar:SetValue(0);

    -- Refresh the UI.
    self:UpdateVisualization();
end

function LibRPMedia_MusicScrollMixin:OnVerticalScroll(offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, self.ROW_HEIGHT, function()
        self:UpdateVisualization();
    end);
end

--- Sets the search filter used by the scroll list, refreshing the contents
--  of the view appropriately.
function LibRPMedia_MusicScrollMixin:SetSearchFilter(query, options)
    -- Wipe the existing list and re-query the database.
    twipe(self.music);

    for _, _, name in SafeIterator(LibRPMedia:FindMusicFiles(query, options))
    do
        tinsert(self.music, name);
    end

    -- Sort data as needed.
    self:SortByColumnIndex(self.sortIndex, self.sortAscending);
end

--- Sorts the music list by the given column index.
function LibRPMedia_MusicScrollMixin:SortByColumnIndex(columnIndex, ascending)
    if self.sortIndex == columnIndex then
        -- We're sorting the same column; flip the order only.
        self.sortAscending = not self.sortAscending;
    else
        -- Sorting a different column, reset the order.
        self.sortIndex = columnIndex;
        self.sortAscending = true;
    end

    -- If an explicit order was given, honor it.
    if ascending ~= nil then
        self.sortAscending = ascending;
    end

    -- Predicate used for ordering the results.
    local predicate = function(a, b)
        if self.sortAscending then
            return a < b;
        else
            return a > b;
        end
    end

    -- Run over the list of music that we currently have and build a separate
    -- table with data that can be sorted.
    local music = {};
    for _, musicName in ipairs(self.music) do
        local value;
        if columnIndex == 1 then
            -- Sorting by file ID.
            value = LibRPMedia:GetMusicFileByName(musicName) or 0;
        elseif columnIndex == 2 then
            -- Sorting by name.
            value = musicName;
        elseif columnIndex == 3 then
            -- Sorting by duration.
            local musicFile = LibRPMedia:GetMusicFileByName(musicName) or 0;
            value = LibRPMedia:GetMusicFileDuration(musicFile);
        else
            -- Invalid column; ignore the request.
            return;
        end

        tinsert(music, { key = musicName, value = value })
    end

    -- Sort the table by the values and then re-populate our actual music
    -- name table with the now sorted keys.
    tsort(music, function(a, b) return predicate(a.value, b.value); end);

    twipe(self.music);
    for _, row in ipairs(music) do
        tinsert(self.music, row.key);
    end

    -- Refresh the UI.
    self:UpdateVisualization();
end

--- Updates the UI of the list, refreshing all shown music rows.
function LibRPMedia_MusicScrollMixin:UpdateVisualization()
    local musicRowHeight = self.ROW_HEIGHT;
    local musicCount = #self.music;
    local musicShown = floor(self:GetHeight() / musicRowHeight);
    local itemOffset = FauxScrollFrame_GetOffset(self);

    -- Release all existing widgets.
    self.itemPool:ReleaseAll();

    local previousWidget = nil;
    for itemIndex = 1, musicShown do
        -- Grab a widget and anchor it to the previous row if possible, or
        -- the top of the frame if not.
        local itemWidget = self.itemPool:Acquire();
        itemWidget:SetHeight(musicRowHeight);

        if previousWidget then
            itemWidget:SetPoint("TOP", previousWidget, "BOTTOM", 0, 0);
        else
            itemWidget:SetPoint("TOP", self, "TOP", 0, 0);
        end

        itemWidget:SetPoint("LEFT", 0, 0);
        itemWidget:SetPoint("RIGHT", 0, 0);

        -- Configure the row to display the appropriate music entry.
        local musicIndex = itemOffset + itemIndex;
        itemWidget:SetMusicName(self.music[musicIndex]);
        itemWidget:SetStripeShown(itemIndex % 2 == 0);
        itemWidget:SetShown(self.music[musicIndex] ~= nil);

        previousWidget = itemWidget;
    end

    -- Configure the scrollbar step and update the scrollframe.
    self.ScrollBar.scrollStep = floor(musicShown / 2) * musicRowHeight;
    FauxScrollFrame_Update(self, musicCount, musicShown, musicRowHeight,
        nil, nil, nil, nil, nil, nil, true);
end

--- Mixin for the music browser tab panel.
LibRPMedia_MusicBrowserMixin = {};

function LibRPMedia_MusicBrowserMixin:OnLoad()
    -- Start off with a sensible search method.
    self:SetSearchMethod("substring");
end

--- Returns the search method used by the music browser.
function LibRPMedia_MusicBrowserMixin:GetSearchMethod()
    return self.searchMethod;
end

--- Sets the search method used by the music browser.
function LibRPMedia_MusicBrowserMixin:SetSearchMethod(searchMethod)
    self.searchMethod = searchMethod;
    self:UpdateVisualization();
end

--- Sorts the music list by the given column index.
function LibRPMedia_MusicBrowserMixin:SortByColumnIndex(columnIndex)
    self.ContentFrame.ScrollFrame:SortByColumnIndex(columnIndex);
end

--- Updates the UI of the browser, refreshing music according to the search
--  parameters.
function LibRPMedia_MusicBrowserMixin:UpdateVisualization()
    -- Update the search filter on the content frame.
    self.ContentFrame.ScrollFrame:SetSearchFilter(self.SearchBox:GetText(), {
        method = self.searchMethod,
    });
end

--- Mixin for a tab button on the browser window.
LibRPMedia_BrowserTabMixin = {};

function LibRPMedia_BrowserTabMixin:OnLoad()
    -- The template in Classic/BCC lacks the .Text parentkey, and so the
    -- various tab functions used in the browser break.
    self.Text = _G[self:GetName() .. "Text"];
end

function LibRPMedia_BrowserTabMixin:OnClick()
    CallMethodOnNearestAncestor(self, "SetTab", self:GetID());
    PlaySound(SOUNDKIT.UI_TOYBOX_TABS);
end

--- Mixin for the main browser window.
LibRPMedia_BrowserMixin = {};

--- Number of tabs on the window.
LibRPMedia_BrowserMixin.TABS_COUNT = 2;
--- Maximum width of individual tabs.
LibRPMedia_BrowserMixin.TABS_MAX_WIDTH = 185;

--- Enumeration of tab IDs.
LibRPMedia_BrowserMixin.TAB_ICONS = 1;
LibRPMedia_BrowserMixin.TAB_MUSIC = 2;

function LibRPMedia_BrowserMixin:OnLoad()
    PanelTemplates_SetNumTabs(self, self.TABS_COUNT);

    self:SetTab(self.TAB_ICONS);

    if IsClassicClient() then
        local asset = [[Interface\Icons\INV_Box_04]];
        SetPortraitToTexture(self.portrait, asset);
    else
        local asset = [[Interface\Icons\Inv_legion_chest_KirinTor]];
        self:SetPortraitToAsset(asset);
    end

    self.TitleText:SetFormattedText("%s: Media Browser", ADDON_NAME);
end

function LibRPMedia_BrowserMixin:OnShow()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN);
end

function LibRPMedia_BrowserMixin:OnHide()
    PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE);
end

--- Sets the tab ID for the browser window.
function LibRPMedia_BrowserMixin:SetTab(tabID)
    PanelTemplates_SetTab(self, tabID);
    PanelTemplates_ResizeTabsToFit(self, self.TABS_MAX_WIDTH);

    self.IconsFrame:SetShown(tabID == self.TAB_ICONS);
    self.MusicFrame:SetShown(tabID == self.TAB_MUSIC);
end
