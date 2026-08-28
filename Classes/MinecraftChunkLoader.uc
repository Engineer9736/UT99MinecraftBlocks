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

var int WorkBelow[256];
var int WorkCurrent[256];
var int WorkAbove[256];

var int SpawnedBlockCount;


/*
 * Compact INI code -> block class.
 *
 * Codes 16 and 17 currently have no corresponding generated class
 * in this project, so they deliberately return None.
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

        /*
         * 16 = TallGrass
         * 17 = Dandelion
         *
         * No matching block classes currently exist.
         */

        case 18:
            return class'MinecraftBlocks.CraftingTable';
    }

    return None;
}


/*
 * A block only hides another block if we can actually represent it.
 *
 * Unsupported blocks therefore behave like air for visibility.
 */
function bool CodeOccludes(int Code)
{
    if (Code == 0)
        return False;

    return GetBlockClass(Code) != None;
}


/*
 * Remove and return the first comma-separated integer.
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
 * Parse one complete 16x16 layer into one of our work buffers.
 *
 * Buffer:
 *     0 = WorkBelow
 *     1 = WorkCurrent
 *     2 = WorkAbove
 */
function ParseLayer(int MinecraftY, int Buffer)
{
    local string Data;
    local int I;
    local int Code;

    if (MinecraftY < MinY || MinecraftY > MaxY)
    {
        for (I = 0; I < 256; I++)
        {
            if (Buffer == 0)
                WorkBelow[I] = 0;
            else if (Buffer == 1)
                WorkCurrent[I] = 0;
            else
                WorkAbove[I] = 0;
        }

        return;
    }

    Data = Layer[MinecraftY];

    for (I = 0; I < 256; I++)
    {
        if (Data == "")
            Code = 0;
        else
            Code = PopValue(Data);

        if (Buffer == 0)
            WorkBelow[I] = Code;
        else if (Buffer == 1)
            WorkCurrent[I] = Code;
        else
            WorkAbove[I] = Code;
    }
}


/*
 * Check exposure during initial chunk loading.
 *
 * X/Z boundaries are currently considered exposed because this loader
 * owns one 16x16 chunk. This can later be replaced by neighbour-chunk
 * queries when multiple chunks are loaded.
 */
function bool IsInitiallyExposed(int X, int Z)
{
    local int I;

    I = Z * 16 + X;

    if (X == 0 || X == 15)
        return True;

    if (Z == 0 || Z == 15)
        return True;

    if (!CodeOccludes(WorkCurrent[I - 1]))
        return True;

    if (!CodeOccludes(WorkCurrent[I + 1]))
        return True;

    if (!CodeOccludes(WorkCurrent[I - 16]))
        return True;

    if (!CodeOccludes(WorkCurrent[I + 16]))
        return True;

    if (!CodeOccludes(WorkBelow[I]))
        return True;

    if (!CodeOccludes(WorkAbove[I]))
        return True;

    return False;
}


/*
 * Convert Minecraft local block coordinates to UT world coordinates.
 */
function vector GetBlockLocation(int X, int Y, int Z)
{
    local vector P;

    P.X = Location.X + (X * GridSize);
    P.Y = Location.Y + (Z * GridSize);
    P.Z = Location.Z + (Y * GridSize);

    return P;
}


/*
 * Spawn one actual block actor.
 */
function MinecraftBlock SpawnBlock(
    int X,
    int Y,
    int Z,
    int Code
)
{
    local class<MinecraftBlock> BlockClass;
    local MinecraftBlock B;
    local vector P;

    BlockClass = GetBlockClass(Code);

    if (BlockClass == None)
        return None;

    P = GetBlockLocation(X, Y, Z);

    /*
     * Self as Owner is important:
     *
     * MinecraftBlock.PostBeginPlay() sees that its Owner is a
     * MinecraftChunkLoader and therefore skips the expensive
     * duplicate AllActors search.
     */
    B = Spawn(
        BlockClass,
        Self,
        ,
        P
    );

    if (B == None)
        return None;

    B.ChunkLoader = Self;
    B.MinecraftX = X;
    B.MinecraftY = Y;
    B.MinecraftZ = Z;
    B.bChunkRemovalReported = False;

    SpawnedBlockCount++;

    return B;
}


/*
 * Initial load:
 *
 * Parse this layer plus the layers immediately above and below,
 * then spawn only blocks with at least one exposed side.
 */
function LoadLayer(int MinecraftY)
{
    local int X;
    local int Z;
    local int I;
    local int Code;

    ParseLayer(MinecraftY - 1, 0);
    ParseLayer(MinecraftY,     1);
    ParseLayer(MinecraftY + 1, 2);

    for (Z = 0; Z < 16; Z++)
    {
        for (X = 0; X < 16; X++)
        {
            I = Z * 16 + X;
            Code = WorkCurrent[I];

            if (Code == 0)
                continue;

            if (GetBlockClass(Code) == None)
                continue;

            if (!IsInitiallyExposed(X, Z))
                continue;

            SpawnBlock(
                X,
                MinecraftY,
                Z,
                Code
            );
        }
    }
}


/*
 * Read one cell directly from the authoritative INI-backed world data.
 *
 * This is only used during gameplay changes, not for bulk loading,
 * so parsing one string here is cheap enough.
 */
function int GetBlockCode(int X, int Y, int Z)
{
    local string Data;
    local int TargetIndex;
    local int I;
    local int Code;

    if (X < 0 || X >= 16)
        return 0;

    if (Z < 0 || Z >= 16)
        return 0;

    if (Y < MinY || Y > MaxY)
        return 0;

    Data = Layer[Y];
    TargetIndex = Z * 16 + X;

    for (I = 0; I <= TargetIndex; I++)
    {
        if (Data == "")
            return 0;

        Code = PopValue(Data);
    }

    return Code;
}


/*
 * Replace one cell in a comma-separated INI layer.
 *
 * We only do this when gameplay changes the world, so rebuilding a
 * 256-value string occasionally is fine.
 */
function SetBlockCode(
    int X,
    int Y,
    int Z,
    int NewCode
)
{
    local string Data;
    local string NewData;
    local int TargetIndex;
    local int I;
    local int Code;

    if (X < 0 || X >= 16)
        return;

    if (Z < 0 || Z >= 16)
        return;

    if (Y < MinY || Y > MaxY)
        return;

    Data = Layer[Y];
    TargetIndex = Z * 16 + X;
    NewData = "";

    for (I = 0; I < 256; I++)
    {
        if (Data == "")
            Code = 0;
        else
            Code = PopValue(Data);

        if (I == TargetIndex)
            Code = NewCode;

        if (I > 0)
            NewData = NewData $ ",";

        NewData = NewData $ string(Code);
    }

    Layer[Y] = NewData;
}


/*
 * Determine whether the actor for this exact Minecraft cell already
 * exists.
 *
 * RadiusActors avoids walking every Minecraft block in the level.
 */
function MinecraftBlock FindBlockActor(
    int X,
    int Y,
    int Z
)
{
    local MinecraftBlock B;
    local vector P;

    P = GetBlockLocation(X, Y, Z);

    foreach RadiusActors(
        class'MinecraftBlock',
        B,
        8.0,
        P
    )
    {
        if (
            B.ChunkLoader == Self &&
            B.MinecraftX == X &&
            B.MinecraftY == Y &&
            B.MinecraftZ == Z
        )
        {
            return B;
        }
    }

    return None;
}


/*
 * A block next to a block that has just disappeared is necessarily
 * exposed.
 *
 * Therefore there is no need to run a complete six-neighbour
 * IsExposed() test here.
 */
function RevealBlock(int X, int Y, int Z)
{
    local int Code;

    Code = GetBlockCode(X, Y, Z);

    if (Code == 0)
        return;

    if (GetBlockClass(Code) == None)
        return;

    if (FindBlockActor(X, Y, Z) != None)
        return;

    SpawnBlock(
        X,
        Y,
        Z,
        Code
    );
}


/*
 * Called automatically by MinecraftBlock.Destroyed().
 *
 * First make this position air in the authoritative world state.
 * Then expose its six neighbours.
 */
function BlockActorDestroyed(
    int X,
    int Y,
    int Z,
    MinecraftBlock OldBlock
)
{
    /*
     * If it was already air, this removal has already been handled.
     */
    if (GetBlockCode(X, Y, Z) == 0)
        return;

    SetBlockCode(
        X,
        Y,
        Z,
        0
    );

    RevealBlock(X - 1, Y,     Z);
    RevealBlock(X + 1, Y,     Z);

    RevealBlock(X,     Y,     Z - 1);
    RevealBlock(X,     Y,     Z + 1);

    RevealBlock(X,     Y - 1, Z);
    RevealBlock(X,     Y + 1, Z);
}


/*
 * Load one Minecraft Y layer per timer tick.
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
            $ " - "
            $ SpawnedBlockCount
            $ " visible block actors spawned"
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
    SpawnedBlockCount = 0;

    Log(
        "Minecraft chunk loader started at "
        $ Location
    );

    SetTimer(0.05, True);
}


defaultproperties
{
    bStatic=False
    bNoDelete=False
    bHidden=True

    RemoteRole=ROLE_None
}