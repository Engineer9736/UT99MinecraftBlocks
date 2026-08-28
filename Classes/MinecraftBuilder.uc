class MinecraftBuilder extends TournamentWeapon;

#exec TEXTURE IMPORT NAME=MCHotbarAndSelector FILE="Textures\hotbar-and-selector.bmp" GROUP=GUI
#exec TEXTURE IMPORT NAME=MCSelector FILE="Textures\MCSelector_32.pcx" GROUP=GUI FLAGS=2

var() class<MinecraftBlock> BlockClass;

const GridSize = 64.0;
const TraceDistance = 10000.0;

var class<MinecraftBlock> BlockClasses[256];
var int BlockCount;
var int SelectedBlockIndex;

var texture HotbarAndSelectorTex;
var texture SelectorTex;

function float SnapToGrid(float V)
{
    if (V >= 0)
        return int((V / GridSize) + 0.5) * GridSize;
    else
        return int((V / GridSize) - 0.5) * GridSize;
}

function InitBlockList()
{
    BlockCount = 0;

    BlockClasses[BlockCount++] = class'MinecraftBlocks.Stone';
    BlockClasses[BlockCount++] = class'MinecraftBlocks.Grass';
    BlockClasses[BlockCount++] = class'MinecraftBlocks.Dirt';
    BlockClasses[BlockCount++] = class'MinecraftBlocks.Cobblestone';
    BlockClasses[BlockCount++] = class'MinecraftBlocks.OakPlanks';
    BlockClasses[BlockCount++] = class'MinecraftBlocks.Sand';
    BlockClasses[BlockCount++] = class'MinecraftBlocks.Glass';
    BlockClasses[BlockCount++] = class'MinecraftBlocks.Bricks';
    BlockClasses[BlockCount++] = class'MinecraftBlocks.TNT';
}

function SelectNextBlock()
{
    if (BlockCount <= 0)
        return;

    SelectedBlockIndex++;

    if (SelectedBlockIndex >= BlockCount)
        SelectedBlockIndex = 0;

    BlockClass = BlockClasses[SelectedBlockIndex];
}

function SelectPrevBlock()
{
    if (BlockCount <= 0)
        return;

    SelectedBlockIndex--;

    if (SelectedBlockIndex < 0)
        SelectedBlockIndex = BlockCount - 1;

    BlockClass = BlockClasses[SelectedBlockIndex];
}

function SelectVisibleSlot(int Slot)
{
    local int PageStart;
    local int Index;

    PageStart = (SelectedBlockIndex / 9) * 9;
    Index = PageStart + Slot;

    if (Index >= 0 && Index < BlockCount)
    {
        SelectedBlockIndex = Index;
        BlockClass = BlockClasses[SelectedBlockIndex];
    }
}

exec function MinecraftBlockNext()
{
    SelectNextBlock();
}

exec function MinecraftBlockPrev()
{
    SelectPrevBlock();
}

simulated function DrawHotbar(Canvas C)
{
    local int I;
    local int Index;
    local int PageStart;
    local int SelectedSlot;

    local float Scale;
    local float BarWidth;
    local float BarHeight;
    local float X;
    local float Y;
    local float IconX;
    local float IconY;
    local float SelectorX;
    local float SelectorY;

    local Texture BlockTexture;

    if (BlockCount <= 0)
        return;

    /*
     * Minecraft's original hotbar is 182x22 pixels.
     * 2x gives a 364x44 pixel hotbar.
     */
    Scale = 2.0;

    BarWidth  = 182.0 * Scale;
    BarHeight = 22.0 * Scale;

    /*
     * Center horizontally.
     * Leave some room underneath for UT's normal weapon bar.
     */
    X = (C.ClipX - BarWidth) * 0.5;
    Y = C.ClipY - BarHeight - 64.0;

    /*
     * Show blocks in pages of 9.
     */
    PageStart = (SelectedBlockIndex / 9) * 9;
    SelectedSlot = SelectedBlockIndex - PageStart;

    C.Style = ERenderStyle.STY_Normal;

    C.DrawColor.R = 255;
    C.DrawColor.G = 255;
    C.DrawColor.B = 255;

    /*
     * HOTBAR
     *
     * Source rectangle in hotbar-and-selector.bmp:
     *
     * X = 0
     * Y = 0
     * W = 182
     * H = 22
     */
    C.SetPos(X, Y);

    C.DrawTile(
        HotbarAndSelectorTex,
        182.0 * Scale,
        22.0 * Scale,
        0,
        0,
        182,
        22
    );

    /*
     * BLOCK ICONS
     *
     * Minecraft hotbar:
     *
     * first icon starts at pixel 3,3
     * every slot is 20 pixels apart
     * icon itself is 16x16
     *
     * Our Minecraft block atlas has the front face at:
     *
     * U = 64
     * V = 64
     * W = 64
     * H = 64
     */
    for (I = 0; I < 9; I++)
    {
        Index = PageStart + I;

        if (Index >= BlockCount)
            break;

        if (BlockClasses[Index] == None)
            continue;

        BlockTexture = BlockClasses[Index].default.Skin;

        if (BlockTexture == None)
            continue;

        IconX = X + ((3.0 + I * 20.0) * Scale);
        IconY = Y + (3.0 * Scale);

        C.SetPos(IconX, IconY);

        C.DrawTile(
            BlockTexture,
            16.0 * Scale,
            16.0 * Scale,
            64,
            64,
            64,
            64
        );
    }

    /*
     * SELECTOR
     *
     * Source rectangle in hotbar-and-selector.bmp:
     *
     * X = 0
     * Y = 22
     * W = 24
     * H = 24
     *
     * Minecraft draws this 1 pixel outside the selected
     * 20x20 slot.
     */
    SelectorX =
        X +
        ((SelectedSlot * 20.0) - 1.0) * Scale;

    SelectorY =
        Y -
        (1.0 * Scale);

	C.Style = ERenderStyle.STY_Masked;

	C.SetPos(
		SelectorX,
		SelectorY
	);

	C.DrawTile(
		SelectorTex,
		24.0 * Scale,
		24.0 * Scale,
		0,
		0,
		24,
		24
	);

	C.Style = ERenderStyle.STY_Normal;
}

simulated function RenderOverlays(Canvas C)
{
    Super.RenderOverlays(C);

    DrawHotbar(C);
}

function PostBeginPlay()
{
    Super.PostBeginPlay();

    InitBlockList();

    if (SelectedBlockIndex < 0 || SelectedBlockIndex >= BlockCount)
        SelectedBlockIndex = 0;

    if (BlockCount > 0)
        BlockClass = BlockClasses[SelectedBlockIndex];
}

function vector SnapVectorToGrid(vector V)
{
    local vector R;

    R.X = SnapToGrid(V.X);
    R.Y = SnapToGrid(V.Y);
    R.Z = SnapToGrid(V.Z);

    return R;
}


function MinecraftBlock FindBlockAt(vector GridLocation)
{
    local MinecraftBlock B;

    foreach AllActors(class'MinecraftBlock', B)
    {
        if (
            Abs(B.Location.X - GridLocation.X) < 1.0 &&
            Abs(B.Location.Y - GridLocation.Y) < 1.0 &&
            Abs(B.Location.Z - GridLocation.Z) < 1.0
        )
        {
            return B;
        }
    }

    return None;
}


function Actor TraceTarget(
    out vector HitLocation,
    out vector HitNormal
)
{
    local Pawn P;
    local vector TraceStart;
    local vector TraceEnd;

    P = Pawn(Owner);

    if (P == None)
        return None;

    TraceStart = P.Location;
    TraceStart.Z += P.EyeHeight;

    TraceEnd =
        TraceStart +
        Vector(P.ViewRotation) * TraceDistance;

    return P.Trace(
        HitLocation,
        HitNormal,
        TraceEnd,
        TraceStart,
        True
    );
}


/*
 * PRIMARY FIRE:
 * Place a block against whatever surface we're aiming at.
 */
function Fire(float Value)
{
    local Pawn P;
    local Actor HitActor;
    local vector HitLocation;
    local vector HitNormal;
    local vector BlockLocation;
    local rotator BlockRotation;
    local MinecraftBlock OldBlock;
    local MinecraftBlock NewBlock;

    P = Pawn(Owner);

    if (P == None || BlockClass == None)
        return;

    HitActor = TraceTarget(HitLocation, HitNormal);

    if (HitActor == None)
        return;

    /*
     * Move half a block outward from the hit surface,
     * then snap to the 64 UU voxel grid.
     */
    BlockLocation =
        HitLocation +
        HitNormal * (GridSize * 0.5);

    BlockLocation = SnapVectorToGrid(BlockLocation);

    /*
     * If that grid slot is already occupied by a MinecraftBlock,
     * replace it.
     */
    OldBlock = FindBlockAt(BlockLocation);

    if (OldBlock != None)
        OldBlock.Destroy();

    /*
     * Initial orientation follows the player.
     * MinecraftBlock.PostBeginPlay() can snap this to 90-degree steps.
     */
    BlockRotation = P.ViewRotation;
    BlockRotation.Pitch = 0;
    BlockRotation.Roll = 0;

	NewBlock = Spawn(
		BlockClass,
		P,
		,
		BlockLocation,
		BlockRotation
	);

	if (NewBlock != None)
	{
		NewBlock.Instigator = P;
		NewBlock.PlayPlaceSound();
	}
}


/*
 * ALT FIRE:
 * Destroy only the MinecraftBlock directly under the crosshair.
 */
function AltFire(float Value)
{
    local Actor HitActor;
    local MinecraftBlock B;
    local vector HitLocation;
    local vector HitNormal;

    HitActor = TraceTarget(HitLocation, HitNormal);

    if (HitActor == None)
        return;

    B = MinecraftBlock(HitActor);

    if (B != None)
        B.Destroy();
}


defaultproperties
{
	HotbarAndSelectorTex=Texture'MinecraftBlocks.GUI.MCHotbarAndSelector'
	SelectorTex=Texture'MinecraftBlocks.GUI.MCSelector'

    PickupMessage="You got the Minecraft Builder"
    ItemName="Minecraft Builder"

    bCanThrow=False

    AutoSwitchPriority=1
    InventoryGroup=10
}