-- This is free and unencumbered software released into the public domain.
--
-- Anyone is free to copy, modify, publish, use, compile, sell, or
-- distribute this software, either in source code form or as a compiled
-- binary, for any purpose, commercial or non-commercial, and by any
-- means.
--
-- In jurisdictions that recognize copyright laws, the author or authors
-- of this software dedicate any and all copyright interest in the
-- software to the public domain. We make this dedication for the benefit
-- of the public at large and to the detriment of our heirs and
-- successors. We intend this dedication to be an overt act of
-- relinquishment in perpetuity of all present and future rights to this
-- software under copyright law.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
-- OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
-- ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
-- OTHER DEALINGS IN THE SOFTWARE.
--
-- For more information, please refer to <https://unlicense.org>

assert(LibStub, "Missing dependency: LibStub");

local MINOR_VERSION = 10;

local LRPM10 = LibStub:NewLibrary("LibRPMedia-1.0", MINOR_VERSION);
local LRPM12 = LibStub:GetLibrary("LibRPMedia-1.2", false);

if not LRPM10 then
    return;
end

local FixupIncompatibleData;

LRPM10.IconType = { Texture = LRPM12.IconType.File, Atlas = LRPM12.IconType.Atlas };

function LRPM10:IsMusicDataLoaded()
    return true;  -- No equivalent in 1.2 API.
end

function LRPM10:GetNumMusicFiles()
    return LRPM12:GetNumMusic();
end

function LRPM10:GetMusicDataByName(musicName, target)
    local musicInfo = LRPM12:GetMusicInfoByName(musicName);
    return self:GetMusicInfoByIndex(musicInfo and musicInfo.index or nil, target);
end

function LRPM10:GetMusicDataByFile(musicFile, target)
    local musicInfo = LRPM12:GetMusicInfoByFile(musicFile);
    return self:GetMusicInfoByIndex(musicInfo and musicInfo.index or nil, target);
end

function LRPM10:GetMusicDataByIndex(musicIndex, target)
    -- TODO: Reimplement.
end

function LRPM10:GetMusicFileByName(musicName)
    local musicInfo = LRPM12:GetMusicInfoByName(musicName);
    return musicInfo and musicInfo.fileID or nil;
end

function LRPM10:GetMusicFileByIndex(musicIndex)
    local musicInfo = LRPM12:GetMusicInfoByIndex(musicIndex);
    return musicInfo and musicInfo.fileID or nil;
end

function LRPM10:GetMusicFileDuration(musicFile)
    local musicInfo = LRPM12:GetMusicInfoByFile(musicFile);
    return musicInfo and musicInfo.duration or 0;
end

function LRPM10:GetNativeMusicFile(musicFile)
    local musicInfo = LRPM12:GetMusicInfoByFile(musicFile);
    return musicInfo and (musicInfo.filePath or musicInfo.fileID) or nil;
end

function LRPM10:GetMusicIndexByFile(musicFile)
    local musicInfo = LRPM12:GetMusicInfoByFile(musicFile);
    return musicInfo and musicInfo.index or nil;
end

function LRPM10:GetMusicIndexByName(musicName)
    local musicInfo = LRPM12:GetMusicInfoByName(musicName);
    return musicInfo and musicInfo.index or nil;
end

function LRPM10:GetMusicNameByIndex(musicIndex)
    local musicInfo = LRPM12:GetMusicInfoByIndex(musicIndex);
    return musicInfo and musicInfo.names[1] or nil;
end

function LRPM10:GetMusicNameByFile(musicFile)
    local musicInfo = LRPM12:GetMusicInfoByFile(musicFile);
    return musicInfo and musicInfo.names[1] or nil;
end

function LRPM10:FindMusicFiles(musicName, options)
    local NextMusic = LRPM12:FindMusic(musicName, options);

    local function NextUnpackedMusic()
        local musicInfo = NextMusic();

        if musicInfo then
            return musicInfo.index, musicInfo.fileID, musicInfo.matchingName;
        end
    end

    return NextUnpackedMusic;
end

function LRPM10:FindAllMusicFiles()
    return LRPM12:EnumerateMusic();
end

function LRPM10:IsIconDataLoaded()
    return true;  -- No equivalent in 1.2 API.
end

function LRPM10:GetNumIcons()
    return LRPM12:GetNumIcons();
end

function LRPM10:GetIconDataByName(iconName, target)
    local iconInfo = LRPM12:GetIconInfoByName(iconName);
    return self:GetMusicInfoByIndex(iconInfo and iconInfo.index or nil, target);
end

function LRPM10:GetIconDataByIndex(iconIndex, target)
    -- TODO: Reimplement.
end

function LRPM10:GetIconNameByIndex(iconIndex)
    local iconInfo = LRPM12:GetIconInfoByIndex(iconIndex);
    return iconInfo and iconInfo.name or nil;
end

function LRPM10:GetIconFileByIndex(iconIndex)
    local iconInfo = FixupIncompatibleData(LRPM12:GetIconInfoByIndex(iconIndex));
    return iconInfo and iconInfo.fileID or nil;
end

function LRPM10:GetIconFileByName(iconName)
    local iconInfo = FixupIncompatibleData(LRPM12:GetIconInfoByName(iconName));
    return iconInfo and iconInfo.fileID or nil;
end

function LRPM10:GetIconTypeByIndex(iconIndex)
    local iconInfo = FixupIncompatibleData(LRPM12:GetIconInfoByIndex(iconIndex));
    return iconInfo and iconInfo.type or nil;
end

function LRPM10:GetIconTypeByName(iconName)
    local iconInfo = FixupIncompatibleData(LRPM12:GetIconInfoByName(iconName));
    return iconInfo and iconInfo.type or nil;
end

function LRPM10:GetIconIndexByName(iconName)
    local iconInfo = FixupIncompatibleData(LRPM12:GetIconInfoByName(iconName));
    return iconInfo and iconInfo.index or nil;
end

function LRPM10:FindIcons(iconName, options)
    local NextIcon = LRPM12:FindIcons(iconName, options);

    local function NextUnpackedIcon()
        local iconInfo = FixupIncompatibleData(NextIcon());

        if iconInfo then
            return iconInfo.index, iconInfo.name;
        end
    end

    return NextUnpackedIcon;
end

function LRPM10:FindAllIcons()
    return LRPM12:EnumerateIcons();
end

--
-- Internal Functions
--

function FixupIncompatibleData(iconInfo)
    if not iconInfo then
        return nil;
    elseif iconInfo.type == LRPM12.IconType.Atlas then
        iconInfo.type = LRPM12.IconType.File;
        iconInfo.atlasID = nil;
        iconInfo.fileID = 134400; -- Interface\ICONS\INV_Misc_QuestionMark
        iconInfo.key = "INV_Misc_QuestionMark";
        iconInfo.name = "INV_Misc_QuestionMark";
    elseif not GetFileIDFromPath([[Interface\ICONS\]] .. iconInfo.name) then
        iconInfo.atlasID = nil;
        iconInfo.fileID = 134400; -- Interface\ICONS\INV_Misc_QuestionMark
        iconInfo.key = "INV_Misc_QuestionMark";
        iconInfo.name = "INV_Misc_QuestionMark";
    end

    return iconInfo;
end

--@do-not-package@

_G.LRPM10 = LRPM10;

--@end-do-not-package@
