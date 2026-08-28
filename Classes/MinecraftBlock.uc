class MinecraftBlock extends Decoration;

#exec MESH IMPORT MESH=MinecraftCube ANIVFILE=MODELS\MinecraftCube_a.3D DATAFILE=MODELS\MinecraftCube_d.3D X=0 Y=0 Z=0
#exec MESH ORIGIN MESH=MinecraftCube X=0 Y=0 Z=0
#exec MESH SEQUENCE MESH=MinecraftCube SEQ=All STARTFRAME=0 NUMFRAMES=1
#exec MESH SEQUENCE MESH=MinecraftCube SEQ=Still STARTFRAME=0 NUMFRAMES=1
#exec MESHMAP SCALE MESHMAP=MinecraftCube X=0.125 Y=0.125 Z=0.250

const GridSize = 64.0;

function float SnapToGrid(float V)
{
    if (V >= 0)
        return int((V / GridSize) + 0.5) * GridSize;
    else
        return int((V / GridSize) - 0.5) * GridSize;
}

function bool SameGridSlot(vector A, vector B)
{
    return
        Abs(A.X - B.X) < 1.0 &&
        Abs(A.Y - B.Y) < 1.0 &&
        Abs(A.Z - B.Z) < 1.0;
}

function int SnapRotation90(int R)
{
    local int Step;

    Step = 16384; // 90 degrees

    if (R >= 0)
        return int((R + Step / 2) / Step) * Step;
    else
        return int((R - Step / 2) / Step) * Step;
}

function PostBeginPlay()
{
    local MinecraftBlock B;
    local vector GridLocation;
    local rotator GridRotation;

    Super(Actor).PostBeginPlay();

    GridLocation.X = SnapToGrid(Location.X);
    GridLocation.Y = SnapToGrid(Location.Y);
    GridLocation.Z = SnapToGrid(Location.Z);

    foreach AllActors(class'MinecraftBlock', B)
    {
        if (B != Self && SameGridSlot(B.Location, GridLocation))
        {
            B.Destroy();
            break;
        }
    }

    GridRotation.Pitch = 0;
    GridRotation.Yaw   = SnapRotation90(Rotation.Yaw);
    GridRotation.Roll  = 0;

    SetLocation(GridLocation);
    SetRotation(GridRotation);
}

defaultproperties
{
    bStatic=False
    bNoDelete=False

    DrawType=DT_Mesh
    Mesh=LodMesh'MinecraftCube'

    CollisionRadius=32.000000
    CollisionHeight=32.000000

    bCollideActors=True
    bCollideWorld=True
    bBlockActors=True
    bBlockPlayers=True
}