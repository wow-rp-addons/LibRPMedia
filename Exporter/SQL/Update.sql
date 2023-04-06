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

-- These queries will probe our views for any assets that need their
-- attributes collected.
--
-- These implicitly trigger functions that will fetch the file contents from
-- CASC for processing; as such this can be very slow.

BEGIN TRANSACTION;

INSERT OR REPLACE INTO MusicAttribute (ContentHash, Duration)
SELECT
    ContentHash,
    GetMusicDuration(ContentHash)
FROM
    (
        SELECT ContentHash FROM MusicFile
        EXCEPT
        SELECT ContentHash FROM MusicAttribute WHERE Duration <> 0
    );

INSERT OR REPLACE INTO IconAttribute (ContentHash, Width, Height)
SELECT
    ContentHash,
    GetIconWidth(ContentHash),
    GetIconHeight(ContentHash)
FROM
    (
        SELECT ContentHash FROM IconFile INNER JOIN File ON File.Id = IconFile.Id
        EXCEPT
        SELECT ContentHash FROM IconAttribute WHERE Width <> 0 AND Height <> 0
    );

COMMIT TRANSACTION;
