-- This file is licensed under the terms expressed in the LICENSE file.
local LibRPMedia = LibStub and LibStub:GetLibrary("LibRPMedia-1.0", true);
if not LibRPMedia or not LibRPMedia.Test then
    return;
end

-- Allow running the tests via a slash command.
SLASH_LIBRPMEDIA_SLASHCMD1 = "/lrpm";
SlashCmdList['LIBRPMEDIA_SLASHCMD'] = LibRPMedia.Test.RunTests;

LibRPMedia.Test.RunTests();
