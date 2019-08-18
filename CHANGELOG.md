# LibRPMedia-1.0

## v1.1.0

 * Added Icons API.
 * Added `GetNativeMusicFile(fileID)` function to assist with Classic client compatibility.
 * Removed LibDeflate as a dependency.
 * Improvements to efficiency of data at rest.

## v1.0.1

 * No outward facing changes.

## v1.0.0

 * Added support for substring and pattern searches to FindMusicFiles.
 * Added typechecking on arguments for public functions.
 * Regenerated data against latest retail PTR builds.
 * Added support for loading compressed data.

## v1.0.0-beta.2

 * Added support for lazy loading of data to minimize memory usage when included.
 * Added API functions to support querying music name information from file IDs, among other things.
 * Added API functions to support search for music files based on a prefix query.

## v1.0.0-beta.1

Initial release with preliminary support for sound files present in client versions 8.2.0.30669 and 1.13.2.30682.
