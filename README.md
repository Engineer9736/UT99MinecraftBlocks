This project is mostly made by just talking with ChatGPT, taking small steps and understanding what the next logic step will be, and making choices on the methodology. This is probably the future of software development in any case.

**Ingame console commands:**
- summon MinecraftBlocks.BlockBuilder - Spawns a weapon which will give you the option to place and break blocks. Blocks always snap onto a grid with the size of themself. Block orientation is locked to 90 degrees depending which direction the player was looking into. Use the console commands MinecraftBlockPrev and MinecraftBlockNext to switch through the Minecraft hotbar. You can assign these commands to any keyboard key with "set input m MinecraftBlockNext" for example.
- summon MinecraftBlocks.MinecraftChunkLoader - Reads MinecraftChunk.ini to generate one chunk of blocks in the UT map.

**Development scripts:**
- mca_to_ini.py - Converts a Minecraft 1.12.2 regionfile into MinecraftChunk.ini which can be loaded ingame with "summon MinecraftBlocks.MinecraftChunkLoader". Minecraft chunkfiles can be found in [Install dir]\saves\New World\region.
- generate_textures_to_textures.py - Convert the original Minecraft textures into PCX files that UT understands. The original textures can be found in .minecraft\versions\1.12.2\1.12.2.jar, and then inside this jar in: assets\minecraft\textures\blocks\
- generate_classes.py - Generate all the block material classes like Cobblestone.uc

- Minecraft sounds can be found in .minecraft\assets\indexes\1.12.json which will give you a hash which is the actual filename of the sound, which is then found in .minecraft\assets\objects\<first 2 hash chars>\<full hash>

**Screenshots:**
<img width="2500" alt="image" src="https://github.com/user-attachments/assets/54513f30-b249-4266-9cea-38ab5d5b45ca" />
<img width="3440" height="1440" alt="Shot00058" src="https://github.com/user-attachments/assets/99dcf042-ec13-4e74-b18a-93f137b6c53b" />
<img width="3440" height="1440" alt="Shot00059" src="https://github.com/user-attachments/assets/a262c746-17d7-4078-87d2-9139140ced10" />
<img width="3440" height="1440" alt="Shot00060" src="https://github.com/user-attachments/assets/8edc8f90-a037-48e5-9f15-1fc0cd6424b0" />
