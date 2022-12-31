-- Super Game Boy packet delay test for Mesen-X
-- posted to gbdev Discord server by GenericHeroGuy on 2022-12-30
-- 
-- Copyright 2022 GenericHeroGuy
-- Copying and distribution of this file, with or without
-- modification, are permitted in any medium without royalty,
-- provided the copyright notice and this notice are preserved.
-- This file is offered as-is, without any warranty.

-- This script draws a number of squares at the top left corner of
-- the screen corresponding to how long the SGB system software
-- waited to check ICD2 for a new packet.  It was discovered that
-- clearing a user-drawn border with the bomb tool causes SGB to
-- delay up to 4 frames.  This happens to match the 4-frame delay
-- present in licensed software.
packetCheckDelay = 0
colors = {0x00FF00, 0xFFFF00, 0xFF7F00, 0xFF0000, 0x7F0000}

function CheckedPackets()
  packetCheckDelay = 0
end

function EndFrame()
  for i = 0, packetCheckDelay - 1 do
    emu.drawRectangle(i*32, 0, 32, 32, colors[i+1], true, 30)
  end
  if packetCheckDelay < 5 then
    packetCheckDelay = packetCheckDelay + 1
  end
end

rev = emu.read(0x7FDB, emu.memType.prgRom)
emu.addMemoryCallback(CheckedPackets, emu.memCallbackType.exec, (rev == 0 and 0x00BBDC or 0x00BBD9))
emu.addEventCallback(EndFrame, emu.eventType.endFrame)
