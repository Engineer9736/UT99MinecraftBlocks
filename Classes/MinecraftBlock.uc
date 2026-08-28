class MinecraftBlock extends Decoration;

#exec MESH IMPORT MESH=MinecraftCube ANIVFILE=MODELS\MinecraftCube_a.3D DATAFILE=MODELS\MinecraftCube_d.3D X=0 Y=0 Z=0
#exec MESH ORIGIN MESH=MinecraftCube X=0 Y=0 Z=0
#exec MESH SEQUENCE MESH=MinecraftCube SEQ=All STARTFRAME=0 NUMFRAMES=1
#exec MESH SEQUENCE MESH=MinecraftCube SEQ=Still STARTFRAME=0 NUMFRAMES=1
#exec MESHMAP SCALE MESHMAP=MinecraftCube X=0.125 Y=0.125 Z=0.250

#exec AUDIO IMPORT FILE="Sounds\cloth1.wav" NAME=MCCloth1 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\cloth2.wav" NAME=MCCloth2 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\cloth3.wav" NAME=MCCloth3 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\cloth4.wav" NAME=MCCloth4 GROUP=Minecraft

#exec AUDIO IMPORT FILE="Sounds\grass1.wav" NAME=MCGrass1 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\grass2.wav" NAME=MCGrass2 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\grass3.wav" NAME=MCGrass3 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\grass4.wav" NAME=MCGrass4 GROUP=Minecraft

#exec AUDIO IMPORT FILE="Sounds\gravel1.wav" NAME=MCGravel1 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\gravel2.wav" NAME=MCGravel2 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\gravel3.wav" NAME=MCGravel3 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\gravel4.wav" NAME=MCGravel4 GROUP=Minecraft

#exec AUDIO IMPORT FILE="Sounds\sand1.wav" NAME=MCSand1 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\sand2.wav" NAME=MCSand2 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\sand3.wav" NAME=MCSand3 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\sand4.wav" NAME=MCSand4 GROUP=Minecraft

#exec AUDIO IMPORT FILE="Sounds\snow1.wav" NAME=MCSnow1 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\snow2.wav" NAME=MCSnow2 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\snow3.wav" NAME=MCSnow3 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\snow4.wav" NAME=MCSnow4 GROUP=Minecraft

#exec AUDIO IMPORT FILE="Sounds\stone1.wav" NAME=MCStone1 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\stone2.wav" NAME=MCStone2 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\stone3.wav" NAME=MCStone3 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\stone4.wav" NAME=MCStone4 GROUP=Minecraft

#exec AUDIO IMPORT FILE="Sounds\wood1.wav" NAME=MCWood1 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\wood2.wav" NAME=MCWood2 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\wood3.wav" NAME=MCWood3 GROUP=Minecraft
#exec AUDIO IMPORT FILE="Sounds\wood4.wav" NAME=MCWood4 GROUP=Minecraft

var() float PlaceSoundVolume;
const GridSize = 64.0;
var Pawn SpawnedBy;
var() name PlaceSoundFamily;

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

    if (Pawn(Owner) != None)
        SpawnedBy = Pawn(Owner);
    else if (Instigator != None)
        SpawnedBy = Instigator;

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

function TakeDamage(
    int Damage,
    Pawn InstigatedBy,
    vector HitLocation,
    vector Momentum,
    name DamageType
)
{
    if (SpawnedBy != None && InstigatedBy == SpawnedBy)
    {
        Destroy();
        return;
    }

    // Shots from anyone else do nothing.
}

function PlayPlaceSound()
{
    local int I;

    I = Rand(4);

    switch (PlaceSoundFamily)
	{
		case 'Cloth':
			switch (I)
			{
				case 0: PlaySound(Sound'MinecraftBlocks.Minecraft.MCCloth1', SLOT_Misc, PlaceSoundVolume); break;
				case 1: PlaySound(Sound'MinecraftBlocks.Minecraft.MCCloth2', SLOT_Misc, PlaceSoundVolume); break;
				case 2: PlaySound(Sound'MinecraftBlocks.Minecraft.MCCloth3', SLOT_Misc, PlaceSoundVolume); break;
				case 3: PlaySound(Sound'MinecraftBlocks.Minecraft.MCCloth4', SLOT_Misc, PlaceSoundVolume); break;
			}
			break;

		case 'Grass':
			switch (I)
			{
				case 0: PlaySound(Sound'MinecraftBlocks.Minecraft.MCGrass1', SLOT_Misc, PlaceSoundVolume); break;
				case 1: PlaySound(Sound'MinecraftBlocks.Minecraft.MCGrass2', SLOT_Misc, PlaceSoundVolume); break;
				case 2: PlaySound(Sound'MinecraftBlocks.Minecraft.MCGrass3', SLOT_Misc, PlaceSoundVolume); break;
				case 3: PlaySound(Sound'MinecraftBlocks.Minecraft.MCGrass4', SLOT_Misc, PlaceSoundVolume); break;
			}
			break;

		case 'Gravel':
			switch (I)
			{
				case 0: PlaySound(Sound'MinecraftBlocks.Minecraft.MCGravel1', SLOT_Misc, PlaceSoundVolume); break;
				case 1: PlaySound(Sound'MinecraftBlocks.Minecraft.MCGravel2', SLOT_Misc, PlaceSoundVolume); break;
				case 2: PlaySound(Sound'MinecraftBlocks.Minecraft.MCGravel3', SLOT_Misc, PlaceSoundVolume); break;
				case 3: PlaySound(Sound'MinecraftBlocks.Minecraft.MCGravel4', SLOT_Misc, PlaceSoundVolume); break;
			}
			break;

		case 'Sand':
			switch (I)
			{
				case 0: PlaySound(Sound'MinecraftBlocks.Minecraft.MCSand1', SLOT_Misc, PlaceSoundVolume); break;
				case 1: PlaySound(Sound'MinecraftBlocks.Minecraft.MCSand2', SLOT_Misc, PlaceSoundVolume); break;
				case 2: PlaySound(Sound'MinecraftBlocks.Minecraft.MCSand3', SLOT_Misc, PlaceSoundVolume); break;
				case 3: PlaySound(Sound'MinecraftBlocks.Minecraft.MCSand4', SLOT_Misc, PlaceSoundVolume); break;
			}
			break;

		case 'Snow':
			switch (I)
			{
				case 0: PlaySound(Sound'MinecraftBlocks.Minecraft.MCSnow1', SLOT_Misc, PlaceSoundVolume); break;
				case 1: PlaySound(Sound'MinecraftBlocks.Minecraft.MCSnow2', SLOT_Misc, PlaceSoundVolume); break;
				case 2: PlaySound(Sound'MinecraftBlocks.Minecraft.MCSnow3', SLOT_Misc, PlaceSoundVolume); break;
				case 3: PlaySound(Sound'MinecraftBlocks.Minecraft.MCSnow4', SLOT_Misc, PlaceSoundVolume); break;
			}
			break;

		case 'Stone':
			switch (I)
			{
				case 0: PlaySound(Sound'MinecraftBlocks.Minecraft.MCStone1', SLOT_Misc, PlaceSoundVolume); break;
				case 1: PlaySound(Sound'MinecraftBlocks.Minecraft.MCStone2', SLOT_Misc, PlaceSoundVolume); break;
				case 2: PlaySound(Sound'MinecraftBlocks.Minecraft.MCStone3', SLOT_Misc, PlaceSoundVolume); break;
				case 3: PlaySound(Sound'MinecraftBlocks.Minecraft.MCStone4', SLOT_Misc, PlaceSoundVolume); break;
			}
			break;

		case 'Wood':
			switch (I)
			{
				case 0: PlaySound(Sound'MinecraftBlocks.Minecraft.MCWood1', SLOT_Misc, PlaceSoundVolume); break;
				case 1: PlaySound(Sound'MinecraftBlocks.Minecraft.MCWood2', SLOT_Misc, PlaceSoundVolume); break;
				case 2: PlaySound(Sound'MinecraftBlocks.Minecraft.MCWood3', SLOT_Misc, PlaceSoundVolume); break;
				case 3: PlaySound(Sound'MinecraftBlocks.Minecraft.MCWood4', SLOT_Misc, PlaceSoundVolume); break;
			}
			break;
	}
}

defaultproperties
{
    bStatic=False
    bNoDelete=False

    DrawType=DT_Mesh
    Mesh=LodMesh'MinecraftCube'
	AmbientGlow=100

    CollisionRadius=32.000000
    CollisionHeight=32.000000

    bCollideActors=True
    bCollideWorld=True
    bBlockActors=True
    bBlockPlayers=True
	
	PlaceSoundFamily=Wood
	PlaceSoundVolume=2.0
}