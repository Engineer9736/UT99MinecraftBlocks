class MinecraftBuilder extends TournamentWeapon;

var() class<MinecraftBlock> BlockClass;

const GridSize = 64.0;
const TraceDistance = 10000.0;

function float SnapToGrid(float V)
{
    if (V >= 0)
        return int((V / GridSize) + 0.5) * GridSize;
    else
        return int((V / GridSize) - 0.5) * GridSize;
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
    BlockClass=class'MinecraftBlocks.Cobblestone'

    PickupMessage="You got the Minecraft Builder"
    ItemName="Minecraft Builder"

    bCanThrow=False

    AutoSwitchPriority=1
    InventoryGroup=10
}