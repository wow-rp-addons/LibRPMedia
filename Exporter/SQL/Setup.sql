--
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
--

--
-- Temporary Table Setup
--
-- Our database is set up such that the client databases are imported as CSV
-- tables via the CSV Virtual Table extension; this allows us to bypass a
-- lengthy load time by processing them in Lua and inserting them into the
-- database.
--
-- However, virtual tables have issues in that they can't be modified, nor
-- can you add indexes to them. This ends up causing a huge performance
-- problem for our export - to the point where it essentially never finishes.
--
-- To work around this we re-define the schema for the parts of the client
-- databases we need as temporary tables and import the data from the virtual
-- CSV tables, then drop them.
--

-- Foreign keys are more a suggestion. Blizzards' client databases are
-- woefully inconsistent.

PRAGMA foreign_keys = OFF;

CREATE TEMPORARY TABLE File
(
    Id INTEGER PRIMARY KEY,
    Path TEXT NOT NULL COLLATE NOCASE,
    ContentHash TEXT NOT NULL COLLATE NOCASE
);

CREATE TEMPORARY TABLE ManifestInterfaceData
(
    FileId INTEGER PRIMARY KEY,
    FilePath TEXT NOT NULL COLLATE NOCASE
);

CREATE TEMPORARY TABLE SoundKit
(
    Id INTEGER PRIMARY KEY,
    SoundType INTEGER NOT NULL
);

CREATE TEMPORARY TABLE SoundKitEntry
(
    Id INTEGER PRIMARY KEY,
    SoundKitId INTEGER NOT NULL REFERENCES SoundKit (Id),
    FileId INTEGER NOT NULL REFERENCES File (Id)
);

CREATE TEMPORARY TABLE ZoneIntroMusic
(
    Id INTEGER PRIMARY KEY,
    Name TEXT NOT NULL,
    SoundKitId INTEGER NOT NULL REFERENCES SoundKit (Id)
);

CREATE TEMPORARY TABLE ZoneMusic
(
    Id INTEGER PRIMARY KEY,
    Name TEXT NOT NULL,
    SoundKitIdDay INTEGER REFERENCES SoundKit (Id),
    SoundKitIdNight INTEGER REFERENCES SoundKit (Id),
    CHECK (SoundKitIdDay IS NOT NULL OR SoundKitIdNight IS NOT NULL)
);

CREATE TEMPORARY TABLE UiTextureAtlas
(
    Id INTEGER PRIMARY KEY,
    FileId INTEGER NOT NULL REFERENCES File (Id)
);

CREATE TEMPORARY TABLE UiTextureAtlasElement
(
    Id INTEGER PRIMARY KEY,
    Name TEXT NOT NULL UNIQUE
);

CREATE TEMPORARY TABLE UiTextureAtlasMember
(
    Id INTEGER PRIMARY KEY,
    AtlasId INTEGER NOT NULL REFERENCES UiTextureAtlas (Id),
    AtlasElementId INTEGER NOT NULL REFERENCES UiTextureAtlasElement (Id),
    Left INTEGER NOT NULL,
    Right INTEGER NOT NULL,
    Top INTEGER NOT NULL,
    Bottom INTEGER NOT NULL
);

-- Set up indexes for foreign keys and commonly joined fields.

CREATE INDEX FileContentHash ON File (ContentHash);
CREATE INDEX SoundKitEntryKit ON SoundKitEntry (SoundKitId);
CREATE INDEX SoundKitEntryFile ON SoundKitEntry (FileId);
CREATE INDEX ZoneIntroMusicKit ON ZoneIntroMusic (SoundKitId);
CREATE INDEX ZoneMusicKitDay ON ZoneMusic (SoundKitIdDay);
CREATE INDEX ZoneMusicKitNight ON ZoneMusic (SoundKitIdNight);

-- Import data from the CSV virtual tables to the temporary ones. Note that
-- all data in the CSV tables will be of the TEXT type so we apply casts to
-- make it clear what should/shouldn't be text.

INSERT INTO File (Id, Path, ContentHash)
SELECT
    CAST(Id AS INTEGER),
    GetNormalizedFilePath(Path),
    ContentHash
FROM
    CsvFile;

INSERT INTO ManifestInterfaceData (FileId, FilePath)
SELECT
    CAST(ID AS INTEGER),
    GetNormalizedFilePath(FilePath || FileName)
FROM
    CsvManifestInterfaceData;

INSERT INTO SoundKit (Id, SoundType)
SELECT
    CAST(ID AS INTEGER) AS Id,
    CAST(SoundType AS INTEGER) AS SoundType
FROM
    CsvSoundKit;

INSERT INTO SoundKitEntry (Id, SoundKitId, FileId)
SELECT
    CAST(ID AS INTEGER) AS Id,
    NULLIF(CAST(SoundKitID AS INTEGER), 0) AS SoundKitId,
    NULLIF(CAST(FileDataID AS INTEGER), 0) AS FileId
FROM
    CsvSoundKitEntry
WHERE
    SoundKitId IS NOT NULL AND FileId IS NOT NULL;

INSERT INTO ZoneIntroMusic (Id, Name, SoundKitId)
SELECT
    CAST(ID AS INTEGER) AS Id,
    NULLIF(Name, '') AS Name,
    NULLIF(CAST(SoundID AS INTEGER), 0) AS SoundKitId
FROM
    CsvZoneIntroMusic
WHERE
    Name IS NOT NULL AND SoundKitId IS NOT NULL;

INSERT INTO ZoneMusic (Id, Name, SoundKitIdDay, SoundKitIdNight)
SELECT
    CAST(ID AS INTEGER) AS Id,
    NULLIF(SetName, '') AS Name,
    NULLIF(CAST("Sounds_0" AS INTEGER), 0) AS SoundKitIdDay,
    NULLIF(CAST("Sounds_1" AS INTEGER), 0) AS SoundKitIdNight
FROM
    CsvZoneMusic
WHERE
    Name IS NOT NULL AND (SoundKitIdDay IS NOT NULL OR SoundKitIdNight IS NOT NULL);

INSERT INTO UiTextureAtlas (Id, FileId)
SELECT
    CAST(ID AS INTEGER) AS Id,
    NULLIF(CAST(FileDataID AS INTEGER), 0) AS FileId
FROM
    CsvUiTextureAtlas
WHERE
    FileId IS NOT NULL;

INSERT INTO UiTextureAtlasElement (Id, Name)
SELECT
    CAST(ID AS INTEGER) AS Id,
    NULLIF(GetNormalizedAtlasName(Name), '') AS Name
FROM
    CsvUiTextureAtlasElement
WHERE
    Name IS NOT NULL;

INSERT INTO UiTextureAtlasMember (Id, AtlasId, AtlasElementId, Left, Right, Top, Bottom)
SELECT
    CAST(ID AS INTEGER) AS Id,
    NULLIF(CAST(UiTextureAtlasID AS INTEGER), 0) AS AtlasId,
    NULLIF(CAST(UiTextureAtlasElementID AS INTEGER), 0) AS AtlasElementId,
    CAST(CommittedLeft AS INTEGER) AS Left,
    CAST(CommittedRight AS INTEGER) AS Right,
    CAST(CommittedTop AS INTEGER) AS Top,
    CAST(CommittedBottom AS INTEGER) AS Bottom
FROM
    CsvUiTextureAtlasMember
WHERE
    AtlasId IS NOT NULL AND AtlasElementId IS NOT NULL;

-- Drop the CSV virtual tables once we're done with the import.

DROP TABLE CsvFile;
DROP TABLE CsvManifestInterfaceData;
DROP TABLE CsvSoundKit;
DROP TABLE CsvSoundKitEntry;
DROP TABLE CsvUiTextureAtlas;
DROP TABLE CsvUiTextureAtlasElement;
DROP TABLE CsvUiTextureAtlasMember;
DROP TABLE CsvZoneIntroMusic;
DROP TABLE CsvZoneMusic;

PRAGMA foreign_keys = ON;

--
-- Persistent Cache Tables
--
-- These tables are saved to the disk and contain attributes about files
-- identified by their content hash. Use these for things that take a bloody
-- long time to obtain.
--

CREATE TEMPORARY TABLE IF NOT EXISTS MusicAttribute
(
    ContentHash TEXT PRIMARY KEY,
    Duration REAL NOT NULL
);

CREATE TEMPORARY TABLE IF NOT EXISTS IconAttribute
(
    ContentHash TEXT PRIMARY KEY,
    Width INTEGER NOT NULL,
    Height INTEGER NOT NULL
);

--
-- Music Views
--

--
-- The MusicKit view contains sound kit IDs and a generated name for each one
-- based on its source. The names are stored in a normalized form, and the
-- view is pre-filtered to exclude soundkits that aren't of interest.
--

CREATE TEMPORARY VIEW MusicKit (Id, Name) AS
SELECT
    SoundKitIdDay,
    GetNormalizedMusicName(
        CASE SoundKitIdDay
        WHEN SoundKitIdNight
        THEN Name ELSE Name || " (Day)"
    END) AS NormalizedName
FROM
    ZoneMusic
WHERE
    SoundKitIdDay IS NOT NULL AND NOT IsMusicKitExcluded(SoundKitIdDay, NormalizedName)
UNION
SELECT
    SoundKitIdNight,
    GetNormalizedMusicName(
        CASE SoundKitIdNight
        WHEN SoundKitIdDay
        THEN Name ELSE Name || " (Night)"
    END) AS NormalizedName
FROM
    ZoneMusic
WHERE
    SoundKitIdNight IS NOT NULL AND NOT IsMusicKitExcluded(SoundKitIdNight, NormalizedName)
UNION
SELECT
    SoundKitId,
    GetNormalizedMusicName(Name) AS NormalizedName
FROM ZoneIntroMusic
WHERE
    NOT IsMusicKitExcluded(SoundKitId, NormalizedName)
ORDER BY
    SoundKitId ASC;

--
-- The MusicFile view contains file IDs and a content hash for each file,
-- this is sourced from a combination of both the listfile (File) table and
-- all of the files linked to sound kits present in the MusicKit table.
--
-- In both cases the list of files is filtered to exclude files that we don't
-- want, so it's not possible for a soundkit to bring in a file that has been
-- explicitly rejected.
--
-- The content hash is provided here because music kits and pull in files that
-- may have not been present in the list file, so we need to fill in the
-- blanks for those as we go.
--

CREATE TEMPORARY VIEW MusicFile (Id, ContentHash) AS
SELECT
    Id,
    ContentHash
FROM
    File
WHERE
    Path LIKE "sound/%" AND NOT IsMusicFileExcluded(Id, Path, ContentHash)
UNION
SELECT
    SoundKitEntry.FileId,
    COALESCE(File.ContentHash, GetFileContentHash(SoundKitEntry.FileId))
FROM
    MusicKit
INNER JOIN
    SoundKitEntry ON SoundKitEntry.SoundKitId = MusicKit.Id
LEFT OUTER JOIN
    File ON File.Id = SoundKitEntry.FileId
WHERE
    File.Path LIKE "sound/%" AND NOT IsMusicFileExcluded(File.Id, File.Path, File.ContentHash)
ORDER BY
    SoundKitEntry.FileId;

--
-- The Music view combines both of the previous to provide a queryable
-- manifest of all music files, information on attached sound kits, and
-- fully deduplicated names for each.
--

CREATE TEMPORARY VIEW Music (FileId, ContentHash, Path, Duration, Name) AS
WITH MusicAll (FileId, SoundKitId, Name) AS
(
    -- This CTE fetches a list of rows for each music file and sound kit with
    -- one alternate name per row sourced from both the file path and the
    -- individual kit names.
    SELECT
        MusicFile.Id,
        NULL,
        File.Path
    FROM
        MusicFile
    LEFT OUTER JOIN
        File ON File.Id = MusicFile.Id
    UNION
    SELECT
        MusicFile.Id,
        MusicKit.Id,
        MusicKit.Name
    FROM
        MusicKit
    INNER JOIN
        SoundKitEntry ON SoundKitEntry.SoundKitId = MusicKit.Id
    INNER JOIN
        MusicFile ON MusicFile.Id = SoundKitEntry.FileId
)
SELECT
    MusicAll.FileId,
    MusicFile.ContentHash,
    File.Path,
    MusicAttribute.Duration,
    GetCountedNameForMusic(MusicAll.FileId, MusicAll.SoundKitId, MusicAll.Name, ROW_NUMBER() OVER DuplicateNames) AS DeduplicatedName
FROM
    MusicAll
INNER JOIN
    MusicFile ON MusicFile.Id = MusicAll.FileId
INNER JOIN
    MusicAttribute ON MusicAttribute.ContentHash = MusicFile.ContentHash
LEFT OUTER JOIN
    File ON File.Id = MusicAll.FileId
WINDOW
    DuplicateNames AS
    (
        PARTITION BY
            GetNameForMusic(MusicAll.FileId, MusicAll.SoundKitId, MusicAll.Name)
        ORDER BY
            MusicAll.FileId ASC
    )
ORDER BY
    MusicAll.FileId ASC, DeduplicatedName COLLATE BINARY ASC;

--
-- Icon Views
--
-- The icon views are structured similarly to the music ones:
--
--   - IconFile
--   - IconAtlas
--   - Icon
--
-- IconFile and IconAtlas act as the source collections for data that passes
-- all basic filters, and feeds into the Icon view which exports a manifest.
--

CREATE TEMPORARY VIEW IconFile (Id) AS
SELECT
    ManifestInterfaceData.FileId AS Id
FROM
    ManifestInterfaceData
INNER JOIN
    File ON File.Id = FileId
WHERE
    ManifestInterfaceData.FilePath LIKE 'interface/icons/%.blp' AND NOT IsIconFileExcluded(FileId, FilePath, File.ContentHash)
ORDER BY
    FileId ASC;

CREATE TEMPORARY VIEW IconAtlas (Id) AS
SELECT
    UiTextureAtlasElement.Id
FROM
    UiTextureAtlasElement
WHERE
    NOT IsIconAtlasExcluded(Id, Name)
ORDER BY
    Id ASC;

CREATE TEMPORARY VIEW Icon (Id, FileId, ContentHash, Name, Width, Height, Type) AS
SELECT
    IconFile.Id AS IconId,
    File.Id,
    File.ContentHash,
    GetNameForIconFile(File.Id, ManifestInterfaceData.FilePath),
    IconAttribute.Width,
    IconAttribute.Height,
    1
FROM
    IconFile
INNER JOIN
    File ON File.Id = IconFile.Id
INNER JOIN
    ManifestInterfaceData ON ManifestInterfaceData.FileId = File.Id
INNER JOIN
    IconAttribute ON IconAttribute.ContentHash = File.ContentHash
UNION
SELECT
    (IconAtlas.Id | 0x80000000) AS IconId,
    File.Id,
    File.ContentHash,
    GetNameForIconAtlas(UiTextureAtlasElement.Id, UiTextureAtlasElement.Name),
    ABS(UiTextureAtlasMember.Right - UiTextureAtlasMember.Left),
    ABS(UiTextureAtlasMember.Bottom - UiTextureAtlasMember.Top),
    2
FROM
    IconAtlas
INNER JOIN
    UiTextureAtlasElement ON UiTextureAtlasElement.Id = IconAtlas.Id
INNER JOIN
    UiTextureAtlasMember ON UiTextureAtlasMember.AtlasElementId = IconAtlas.Id
INNER JOIN
    UiTextureAtlas ON UiTextureAtlas.Id = UiTextureAtlasMember.AtlasId
INNER JOIN
    File On File.Id = UiTextureAtlas.FileId
ORDER BY
    IconId ASC;
