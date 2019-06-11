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
```

#### `LibRPMedia:GetNumMusicFiles()`

Returns the number of music files present within the database.

##### Usage

```lua
print("Number of music files:", LibRPMedia:GetNumMusicFiles());
```

#### `LibRPMedia:GetMusicFile(musicName)`

Returns the file ID associated with a given name or file path.

If using a file name, this will usually match that of a sound kit name as present within the internal client databases, eg. `zone-cursedlandfelwoodfurbolg_1`.

If using a file path, the database only includes entries for files within the `sound/music` directory tree. The file path should omit the `sound/music/` prefix, as well as the file extension (`.mp3`).

This function will automatically normalize the input name to a lowercase string, and have any backslashes (`\\`) replaced by forward slashes (`/`).

If no music file is found with the given name or path, `nil` is returned.

##### Usage

```lua
PlaySoundFile(LibRPMedia:GetMusicFile("zone-cursedlandfelwoodfurbolg_1"), "Music");
```

#### `LibRPMedia:GetMusicFileByIndex(musicIndex)`

Returns the file ID associated with the given numeric index inside the database, in the range of 1 through the result of `LibRPMedia:GetNumMusicFiles()`. Queries outside of this range will return `nil`.

##### Usage

```lua
PlaySoundFile(LibRPMedia:GetMusicFileByIndex(42), "Music");
```

#### `LibRPMedia:IterMusicFiles()`

Returns an iterator for accessing the contents of the music database. The iterator will return a pair of the music index and file ID on each successive call, or `nil` at the end of the database.

##### Usage

```lua
for index, fileID in LibRPMedia:IterMusicFiles() do
    print("Found music file: ", fileID);
end
```

## Building

The build script requires a Lua interpreter (ideally 5.1) as well as the following Lua libraries:

 * [Penlight](https://github.com/stevedonovan/Penlight)
 * [LuaSocket](http://w3.impa.br/~diego/software/luasocket/)

The following binaries must be present on your system:

 * [curl](https://curl.haxx.se/)

## License

The library is released under the terms of the [Unlicense](https://unlicense.org/), a copy of which can be found in the `LICENSE` document at the root of the repository.

Basically, you're completely free to use it and don't need to worry about crediting us.

## Contributors

* [Daniel "Meorawr" Yates](https://github.com/meorawr)
