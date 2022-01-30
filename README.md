# MiSTerFPGA - NTSC Encoder - S-Video / Composite Output 
This is an attempt to add chroma out to the MiSTerFPGA using the (Red) output for the Chroma output and (Green) for the Luma

## Quick Note:

**YPbPr is requred in the MiSTer ini file, as well as using green for LUMA (Y) and red for CHROMA (C). A VGA to component is what I am currently using.

The YUV standard was used with the following assumptions

  Y	0.299R' + 0.587G' + 0.114B'

  U	0.492(B' - Y) 

  V	0.877(R' - Y)  

  C = U * Sin(wt) + V * Cos(wt) 

## Reference Lookup Tables

There are three LUTs - sin, cos, colorburst / sin(wt ~180) 

  Sampling rate = 14 * 3.579545 or 50,113,560 Hz
  w = =2 * PI * (3.579545*10^6)
  t = 1/sampling rate

## Other notes:

This is only a concept right now and there is still a lot of work to see how well this can be applied to more applications or even how the existing issues can be cleaned up.

A AC coupling 0.1uF capacitor was used on the Chroma output, but may not be required.

All source is written in the frameworks vga_out.sv


# [Nintendo Entertainment System](https://en.wikipedia.org/wiki/Nintendo_Entertainment_System) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

This is an FPGA implementation of the NES/Famicom based on [FPGANES](https://github.com/strigeus/fpganes) by Ludvig Strigeus and ported to MiSTer.

## Features
 * Supports saves for most games
 * Savestates
 * Supports NTSC, PAL, and Dendy system types
 * FDS Support with expansion audio
 * Multiple Palette options
 * Zapper, Powerpad, Microphone, and Miracle Piano support
 * Supports four players
 * Setting for increasing sprite per line by 8
 * Supports up to 32 cheat codes
 * Supports NSF Player
 * Supports expansion audio from mappers including VRC6 & 7, MMC5, Namco 163 and Sunsoft 5b
 * Supports many popular mappers including VRC1-7, MMC0-5, and many more (see below)
 * Supports large games such as Legend of Link and Rockman Minus Infinity

## Installation
Copy the NES_\*.rbf file to the root of the SD card. Create a **NES** folder on the root of the card, and place NES roms (\*.NES) inside this folder. The ROMs must have an iNES or NES2.0 header, which most already do. NES2.0 headers are prefered for the best accuracy. To have a game ROM load automatically upon starting the core and place it in the **NES** folder.
- boot0.rom = FDS BIOS file.  Will be used for any FDS images loaded
- boot1.rom = NES Cart file.  Can be used with boot0.rom (BIOS) in place
- boot2.rom = FDS image file.  Requires boot0.rom (BIOS).  Use a blank FDS (header only) to boot the FDS BIOS without a disk image.
- boot3.rom = PAL file. It can be used to set your default custom palette. Save the menu option on "Custom" to apply immediately.

## Famicom Disk System Usage
Before loading \*.FDS files, you must first load the official, unpatched FDS BIOS. The BIOS file should be renamed to boot0.rom and placed in the same folder as the ROMs (NES).  Alternatively, it can be loaded from the OSD if boot0.rom doesn't exist. After loading the core and the bios you may select an FDS image. By default, the NES core will swap disk sides for you automatically. To suppress this behavior, hold the FDS button on the player 1 controller. The "Disk Swap" OSD option manually controls the disk side.  Each button press increments the disk side.  Press and hold the fds button to eject and increment the disk side in this mode.  Some games only work correctly in manual disk swap mode, and require holding the FDS button for up to a few seconds (Gall Force,...).

## Extra Sprites
This feature will double the number of sprites drawn per scanlines, decreasing the flickering sprites that NES is known for. Some games relied on the 8 sprite behavior to work correctly, such as Simon's Quest swamps. Other mappers may be impacted by using extra sprites. While it works well in most games, glitches may occur with this enabled.

## Saving and Loading
The battery backed RAM (Save RAM) for the NES does not write to disk automatically. After saving in your game, you must then write the RAM to the SD card by selecting **Save Backup RAM** from the menu. If you do not save your RAM to disk, the contents will be lost next time you restart the core or switch games. Alternatively you can enable to Autosave option from the OSD menu, and if you do your games will be recorded to disk every time you open the OSD menu. FDS saving uses the same method as for cartridge RAM saves. Save RAM is stored as a .sav file based on the NES/FDS filename in `/media/fat/saves/NES/`.  Examples:  
`Metroid (Japan) (Rev 3).fds` -> `Metroid (Japan) (Rev 3).sav`  
`Legend of Zelda, The (USA) (Rev 1).nes` -> `Legend of Zelda, The (USA) (Rev 1).sav`

# Savestates
Core provides 4 slots to save and restore the state (FDS not supported). 
Those can be saved to SDCard or reside only in memory for temporary use(OSD Option). 
Usage with either Keyboard, Gamepad mappable button or OSD. Save states are stored as .ss files in `/media/fat/savestates/NES/`, with an underscore and the save slot number (1,2,3,4) preceding `.ss`. Example (save slot 1): `Metroid (USA).nes` -> `Metroid (USA)_1.ss`

Keyboard Hotkeys for save states:
- Alt-F1..F4 - save the state
- F1...F4 - restore

Gamepad:
- Savestatebutton+Left or Right switches the savestate slot
- Savestatebutton+Start+Down saves to the selected slot
- Savestatebutton+Start+Up loads from the selected slot

## Zapper Support
The "Zapper" (aka Light Gun) can be used via two methods. You can select Peripheral: Zapper(Mouse) to use your mouse to aim and shoot with the left button. This mode uses relative mouse motion, so devices that rely on absolute coordinates will not work via this method. Alternatively, you can choose Zapper(Joy) to use the Analog stick to aim, and the defined Trigger button to fire. Guns such as Aimtrak have joystick modes which may be compatible with this method.

## Miracle Piano Support
The Miracle Piano is a MIDI keyboard compatible with the Miracle Piano Education System cart.  To use it with SNAC, no further settings are needed.  To use it with midilink, in the System Settings, set the UART connection to use MIDI.  The piano will then be connected on controller port 1 as expected.  The primary controller will automatically be assigned to port 2 as the cart expects.  The header for the ROM file should be set to NES 2.0 with controller type (0xF) set to the Miracle Piano (0x19).

## Supported Mappers

|#||||||||||||||||
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
|**0**|**1**|**2**|**3**|**4**|**5**||**7**||**9**|**10**|**11**|~~12~~|13||15|
|**16**||**18**|**19**|FDS|**21**|**22**|**23**|**24**|**25**|**26**|**27**|**28**||**30**|31|
|**32**|33|**34**|**35**|**36**|37|**38**|**39**|~~40~~|41|42|~~43~~|**44**|~~45~~|**46**|**47**|
|48|~~49~~|~~50~~|~~51~~|~~52~~|~~53~~|~~54~~|~~55~~|~~56~~|~~57~~|~~58~~|~~59~~|~~60~~|~~61~~|~~62~~|~~63~~|
|**64**|**65**|**66**|**67**|**68**|**69**|**70**|**71**|**72**|**73**|**74**|**75**|**76**|**77**|**78**|**79**|
|**80**|~~81~~|**82**|83|~~84~~|85|**86**|**87**|**88**|**89**|**90**|91|**92**|**93**|**94**|**95**|
|~~96~~|**97**||~~99~~|~~100~~|**101**|||~~104~~|105||107|~~108~~|~~109~~|~~110~~|**111**|
|**112**|**113**|~~114~~|~~115~~|~~116~~|~~117~~|**118**|**119**|~~120~~||~~122~~|~~123~~||~~125~~|~~126~~|~~127~~|
|~~128~~|~~129~~|~~130~~|~~131~~|**132**|**133**|~~134~~|~~135~~|**136**|**137**|**138**|**139**|**140**|**141**|~~142~~|**143**|
|~~144~~|145|**146**|**147**|**148**|149|**150**|~~151~~|**152**|153|**154**|155|~~156~~|~~157~~|**158**|**159**|
|~~160~~|~~161~~|162|163|164|165|~~166~~|~~167~~|~~168~~|~~169~~||**171**|**172**|**173**|||
|||||**180**|~~181~~|~~182~~|~~183~~|**184**|**185**|~~186~~|~~187~~|~~188~~|**189**|**190**|191|
|192|~~193~~|194|195|196||~~198~~|~~199~~|~~200~~|~~201~~|~~202~~|~~203~~|~~204~~|~~205~~|**206**|**207**|
|~~208~~|**209**|**210**|**211**|~~212~~|~~213~~|~~214~~|~~215~~|~~216~~|~~217~~|**218**||||~~222~~||
|~~224~~|**225**|~~226~~|227|228|~~229~~|~~230~~|~~231~~|**232**|~~233~~|234|~~235~~|~~236~~|~~237~~|||
|~~240~~|~~241~~|~~242~~|**243**|~~244~~|~~245~~|246||~~248~~|~~249~~|~~250~~|~~251~~|~~252~~||~~254~~|255|

Key: **Supported+Save state**, Supported, ~~Not Supported~~. Mappers that are not existent or not useful are blank.

