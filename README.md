# LibRPMedia

LibRPMedia provides a common database of in-game resources for use by RP addons.

## Embedding

LibRPMedia uses [LibStub](https://www.curseforge.com/wow/addons/libstub) as its versioning mechanism, so the existing documentation with regards to embedding and loading the library applies here.

You can import this repository as a Git submodule, or just download a release and copy the folder into your own project as needed.

To load the library, include a reference to any of the following files within your addon:

 * `LibRPMedia-1.0.xml`
 * `LibRPMedia-Classic-1.0.xml`
 * `LibRPMedia-Retail-1.0.xml`

The `LibRPMedia-1.0.xml` file includes all references to databases for both Retail and Classic, whereas the other files only include script references to files specific to their targetted product. Use of the product-specific XML files is recommended when you have control of the packaging process.

## Usage

### Music API

#### `LibRPMedia:IsMusicDataLoaded()`

Returns `true` if the music database has been loaded. If this returns `false`, most other Music API functions will raise errors.

##### Usage

```lua
print("Is music data loaded?", LibRPMedia:IsMusicDataLoaded());
-- Example output: "Is music data loaded? true"
```

#### `LibRPMedia:GetNumMusicFiles()`

Returns the number of music files present within the database.

##### Usage

```lua
print("Number of music files:", LibRPMedia:GetNumMusicFiles());
-- Example output: "Number of music files: 192"
```

#### `LibRPMedia:GetMusicFileByName(musicName)`

Returns the file ID associated with a given name or file path.

If using a file name, this will usually match that of a sound kit name as present within the internal client databases, eg. `zone-cursedlandfelwoodfurbolg_1`.

If using a file path, the database only includes entries for files within the `sound/music` directory tree. The file path should omit the `sound/music/` prefix, as well as the file extension (`.mp3`).

If no music file is found with the given name or path, `nil` is returned.

##### Usage

```lua
PlaySoundFile(LibRPMedia:GetMusicFileByName("zone-cursedlandfelwoodfurbolg_1"), "Music");
```

#### `LibRPMedia:GetMusicFileByIndex(musicIndex)`

Returns the file ID associated with the given numeric index inside the database, in the range of 1 through the result of `LibRPMedia:GetNumMusicFiles()`. Queries outside of this range will return `nil`.

##### Usage

```lua
PlaySoundFile(LibRPMedia:GetMusicFileByIndex(42), "Music");
```

#### `LibRPMedia:GetMusicFileDuration(musicFile)`

Returns the duration of a music file by its file ID. The value returned will be in fractional seconds, if present in the database.

If no duration information is found for the referenced file, `0` is returned.

##### Usage

```lua
local file = LibRPMedia:GetMusicFileByName("citymusic/darnassus/darnassus intro");
print("File duration (seconds):", LibRPMedia:GetMusicFileDuration(file));
-- Example output: "File duration (seconds): 39.923125"
```

#### `LibRPMedia:GetMusicIndexByFile(musicFile)`

Returns the music index associated with the given file ID inside the database.

If no matching file ID is found, `nil` is returned.

The index returned by this function is not guaranteed to remain stable between updates to this library.

##### Usage

```lua
print("Music index (by file):", LibRPMedia:GetMusicIndexByFile(53183));
-- Example output: "Music index (by file): 1"
```

#### `LibRPMedia:GetMusicIndexByName(musicName)`

Returns the music index associated with the given music name inside the database.

Music files may be associated with multiple names, and this function will search against all of them. If no matching name is found, `nil` is returned.

The index returned by this function is not guaranteed to remain stable between updates to this library.

##### Usage

```lua
print("Music index (by name):", LibRPMedia:GetMusicIndexByName("citymusic/darnassus/darnassus intro"));
-- Example output: "Music index (by name): 1"
```

#### `LibRPMedia:GetMusicNameByIndex(musicIndex)`

Returns the music name associated with the given numeric index inside the database, in the range of 1 through the result of `LibRPMedia:GetNumMusicFiles()`. Queries outside of this range will return `nil`.

Music files may be associated with multiple names, however only one name will ever be returned by this function. The name returned by this function is not guaranteed to remain stable between updates to this library.

##### Usage

```lua
print("Music name (by index):", LibRPMedia:GetMusicNameByIndex(1));
-- Example output: "Music name (by index): citymusic/darnassus/darnassus intro"
```

#### `LibRPMedia:GetMusicNameByFile(musicFile)`

Returns the music name associated with the given file ID inside the database.

Music files may be associated with multiple names, however only one name will ever be returned by this function. The name returned by this function is not guaranteed to remain stable between updates to this library. If no matching name is found, `nil` is returned.

##### Usage

```lua
print("Music name (by file):", LibRPMedia:GetMusicNameByFile(53183));
-- Example output: "Music name (by file): citymusic/darnassus/darnassus intro"
```

#### `LibRPMedia:FindMusicFiles(musicName[, options])`

Returns an iterator for accessing the contents of the music database for music files matching the given name. The iterator will return a triplet of the music index, file ID, and music name on each successive call, or `nil` at the end of the database.

Music files may be associated with multiple names, and this function will search against all of them. The music index and name yielded by this iterator is not guaranteed to remain stable between updates to this library.

The order of files returned by this iterator is not stable between updates to this library.

##### Usage

```lua
-- Prefix searching (default):
for index, file, name in LibRPMedia:FindMusicFiles("citymusic/") do
    print("Found music file:", name, file);
    -- Example output: "Found music file: citymusic/darnassus/darnassus intro, 53183"
end

-- Substring matching:
for index, file, name in LibRPMedia:FindMusicFiles("mus_50", { method = "substring" }) do
    print("Found music file:", name, file);
    -- Example output: "Found music file: mus_50_augustcelestials_01, 642565"
end

-- Pattern matching:
for index, file, name in LibRPMedia:FindMusicFiles("^mus_[78]", { method = "pattern" }) do
    print("Found music file:", name, file);
    -- Example output: "Found music file: mus_70_artif_brokenshore_battewalk_01, 1506788"
end
```

#### `LibRPMedia:FindAllMusicFiles()`

Returns an iterator for accessing the contents of the music database. The iterator will return a triplet of the music index, file ID, and music name on each successive call, or `nil` at the end of the database.

The music index and name yielded by this iterator is not guaranteed to remain stable between updates to this library.

The order of files returned by this iterator is not stable between updates to this library.

##### Usage

```lua
for index, file, name in LibRPMedia:FindAllMusicFIles() do
    print("Found music file:", name, file);
    -- Example output: "Found music file: citymusic/darnassus/darnassus intro, 53183"
end
```

## Building

The following binaries must be present on your system:

 * [curl](https://curl.haxx.se/)

## License

The library is released under the terms of the [Unlicense](https://unlicense.org/), a copy of which can be found in the `LICENSE` document at the root of the repository.

Basically, you're completely free to use it and don't need to worry about crediting us.

## Contributors

* [Daniel "Meorawr" Yates](https://github.com/meorawr)
