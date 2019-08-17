-- This file is licensed under the terms expressed in the LICENSE file.
local LibRPMedia = LibStub and LibStub:GetLibrary("LibRPMedia-1.0", true);
if not LibRPMedia or not LibRPMedia.Test then
    return;
end

-- Run tests immediately on login.
LibRPMedia.Test.RunTests();
