class MinecraftChunkLoader extends Actor
    config(MinecraftChunk);

const GridSize = 64.0;

var config int ChunkX;
var config int ChunkZ;
var config int MinY;
var config int MaxY;

var config string BlockName[19];
var config string Layer[256];

var int CurrentY;


/*
 * Convert our compact INI block code to a MinecraftBlock class.
 */
function class<MinecraftBlock> GetBlockClass(int Code)
{
    switch (Code)
    {
        case 1:
            return class'MinecraftBlocks.Stone';

        case 2:
            return class'MinecraftBlocks.Grass';

        case 3:
            return class'MinecraftBlocks.Dirt';

        case 4:
            return class'MinecraftBlocks.Bedrock';

        case 5:
            return class'MinecraftBlocks.Granite';

        case 6:
            return class'MinecraftBlocks.Diorite';

        case 7:
            return class'MinecraftBlocks.Andesite';

        case 8:
            return class'MinecraftBlocks.BirchPlanks';

        case 9:
            return class'MinecraftBlocks.BirchLog';

        case 10:
            return class'MinecraftBlocks.BirchLeaves';

        case 11:
            return class'MinecraftBlocks.CoalOre';

        case 12:
            return class'MinecraftBlocks.IronOre';

        case 13:
            return class'MinecraftBlocks.GoldOre';

        case 14:
            return class'MinecraftBlocks.RedstoneOre';

        case 15:
            return class'MinecraftBlocks.Gravel';

        case 18:
            return class'MinecraftBlocks.CraftingTable';
    }

    return None;
}


/*
 * Pull one comma-separated value from a string.
 *
 * Example:
 *     "4,4,1,0,..."
 *
 * Value receives 4, Source becomes "4,1,0,..."
 */
function int PopValue(out string Source)
{
    local int P;
    local string S;

    P = InStr(Source, ",");

    if (P < 0)
    {
        S = Source;
        Source = "";
    }
    else
    {
        S = Left(Source, P);
        Source = Mid(Source, P + 1);
    }

    return int(S);
}


/*
 * Load one 16x16 Minecraft Y layer.
 *
 * INI order:
 *     index = Z * 16 + X
 *
 * Coordinate conversion:
 *
 *     Minecraft X -> Unreal X
 *     Minecraft Z -> Unreal Y
 *     Minecraft Y -> Unreal Z
 *
 * All multiplied by 64 UU.
 */
function LoadLayer(int MinecraftY)
{
    local string Data;
    local int X;
    local int Z;
    local int Code;

    local vector BlockLocation;
    local class<MinecraftBlock> BlockClass;

    Data = Layer[MinecraftY];

    if (Data == "")
        return;

    for (Z = 0; Z < 16; Z++)
    {
        for (X = 0; X < 16; X++)
        {
            Code = PopValue(Data);

            // 0 = Air
            if (Code == 0)
                continue;

            BlockClass = GetBlockClass(Code);

            if (BlockClass == None)
                continue;

            BlockLocation.X =
                Location.X +
                (X * GridSize);

            BlockLocation.Y =
                Location.Y +
                (Z * GridSize);

            BlockLocation.Z =
                Location.Z +
                (MinecraftY * GridSize);

            /*
             * Self is deliberately passed as Owner.
             *
             * MinecraftBlock.PostBeginPlay() can recognize the
             * MinecraftChunkLoader owner and skip its expensive
             * duplicate-block AllActors search.
             */
            Spawn(
                BlockClass,
                Self,
                ,
                BlockLocation
            );
        }
    }
}


/*
 * Don't spawn all ~16,500 blocks in one PostBeginPlay call.
 *
 * Load one 16x16 layer per timer tick instead.
 */
function Timer()
{
    if (CurrentY > MaxY)
    {
        SetTimer(0.0, False);

        Log(
            "Minecraft chunk loading complete: "
            $ ChunkX
            $ ","
            $ ChunkZ
        );

        return;
    }

    LoadLayer(CurrentY);

    Log(
        "Minecraft chunk loading layer "
        $ CurrentY
        $ " / "
        $ MaxY
    );

    CurrentY++;
}


function PostBeginPlay()
{
    Super(Actor).PostBeginPlay();

    CurrentY = MinY;

    Log(
        "Minecraft chunk loader started at "
        $ Location
    );

    /*
     * One layer every 0.05 seconds.
     * 80 layers = roughly 4 seconds.
     */
    SetTimer(0.05, True);
}


defaultproperties
{
    bStatic=False
    bNoDelete=False

    bHidden=True

    RemoteRole=ROLE_None
}