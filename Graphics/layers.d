/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, layer module
 */
module graphics.layers;

public import graphics.bitmap;
import std.conv;
import system.etc;
import system.exc;
import std.algorithm;


//Used mainly to return both the color ID and the transparency at the same time to reduce CPU time.
/*public struct PixelData {
    public bool alpha;
    public ushort color;
    this(bool a, ushort c){
        alpha = a;
        color = c;
    }
}*/

public enum FlipRegister : ubyte {
	NORM	=	0x00,
	X		=	0x01,
	Y		=	0x02,
	XY		=	0x03
}

public interface ILayer{
    // Returns color.
    //public ushort getPixel(ushort x, ushort y);
    // Returns if the said pixel's color is equals with the transparent color index.
    //public bool isTransparent(ushort x, ushort y);
    // Returns the PixelData.
    //public PixelData getPixelData(ushort x, ushort y);

	public void setRasterizer(int rX, int rY);
	public void updateRaster(Bitmap16Bit frameBuffer);
}

abstract class Layer : ILayer{

    // scrolling position
    private int sX, sY, rasterX, rasterY;

	private ushort transparencyIndex;

	public void setTransparencyIndex(ushort color){
		transparencyIndex = color;
	}

	public void setRasterizer(int rX, int rY){
		//frameBuffer = frameBufferP;
		rasterX=rX;
		rasterY=rY;

	}

    //Absolute scrolling.
    public void scroll(int x, int y){
        sX=x;
        sY=y;
    }
    //Relative scrolling. Positive values scrolls the layer left and up, negative values scrolls the layer down and right.
    public void relScroll(int x, int y){
        sX=sX+x;
        sY=sY+y;
    }
    //Getters for the scroll positions.
    public int getSX(){
        return sX;
    }
    public int getSY(){
        return sY;
    }
}

public struct BLInfo{
	public int tileX, tileY, mX, mY;
	this(int tileX1,int tileY1,int x1,int y1){
		tileX = tileX1;
		tileY = tileY1;
		mX = x1;
		mY = y1;
	}
}
/*
 *Used by the background-sprite tester.
 */
public interface IBackgroundLayer{
	public BLInfo getLayerInfo();
	public Bitmap16Bit getTile(wchar id);
	public wchar[] getMapping();
}
/*
 *Use multiple of this class for paralax scrolling.
 */
public class BackgroundLayer : Layer, IBackgroundLayer{
    private int tileX, tileY, mX, mY;
    private long totalX, totalY;
    private wchar[] mapping;
    private Bitmap16Bit[wchar] tileSet;
    //Constructor. tX , tY : Set the size of the tiles on the layer.
    this(ushort tX, ushort tY){
        tileX=tX;
        tileY=tY;
    }
    //Gets the the ID of the given element from the mapping. x , y : Position.
    public wchar readMapping(int x, int y){
		/*if(x<0 || x>totalX/tileX){
			return 0xFFFF;
		}*/
		return mapping[x+(mX*y)];
    }
    //Writes to the map. x , y : Position. w : ID of the tile.
    public void writeMapping(int x, int y, wchar w){
        mapping[x+(mX*y)]=w;
    }
    //Loads a mapping from an array. x , y : Sizes of the mapping. map : an array representing the elements of the map.
    //x*y=map.length
    public void loadMapping(int x, int y, wchar[] map){
        mX=x;
        mY=y;
        mapping = map;
        totalX=mX*tileX;
        totalY=mY*tileY;
    }
    //Adds a tile to the tileSet. t : The tile. id : The ID in wchar to differentiate between different tiles.
    public void addTile(Bitmap16Bit t, wchar id){
        if(t.getX()==tileX && t.getY()==tileY){
            tileSet[id]=t;
        }
		else{
			throw new TileFormatException("Incorrect tile size!", __FILE__, __LINE__, null);
		}
    }
    //Removes the tile with the ID from the set.
    public void removeTile(wchar id){
        tileSet.remove(id);
    }

	public void updateRaster(Bitmap16Bit frameBuffer){
		if(sX + rasterX <= 0 || sX > totalX) return;
		for(int y ; y < rasterY ; y++){
			if(sY + y >= totalY) break;
			if(y + sY >= 0){

				//int outscrollX = sX<0 ? sX*-1 : 0;
				int tnXreg = sX>0 ? (sX-(sX%tileX))/tileX : 0;
				//int tnXC = tnXreg + (rasterX/tileX);
				bool finish;
				while(!finish){
					//writeln(tnXreg+(mX*((y+sY-((y+sY)%tileY))/tileY)));
					ushort[] chunk = tileSet[mapping[tnXreg+(mX*((y+sY-((y+sY)%tileY))/tileY))]].readRow((y+sY)%tileY);
					for(int x; x <tileX; x++){

						if((tnXreg*tileX)+x-sX >= 0 && (tnXreg*tileX)+x-sX < rasterX){
							frameBuffer.writePixel((tnXreg*tileX)+x-sX,y,chunk[x]);
						}else if((tnXreg*tileX)+x-sX >= rasterX){
							finish = true;
						}
					}
					tnXreg++;
					if(tnXreg == mX){ finish = true;}
				}
			}
		}

	}

	public BLInfo getLayerInfo(){
		return BLInfo(tileX,tileY,mX,mY);
	}
	public Bitmap16Bit getTile(wchar id){
		return tileSet[id];
	}
	public wchar[] getMapping(){
		return mapping;
	}
}
/*
 *Used by the collision detectors
 */
public interface ISpriteLayer{
	public Bitmap16Bit[] getSpriteSet();
	public Coordinate[] getCoordinates();
	public ushort getTransparencyIndex();
}
/*
 *Use it to call the collision detector
 */
public interface SpriteMovementListener{
	void spriteMoved(int ID);
}
/*
 *Sprite controller and renderer. 
 */
public class SpriteLayer : Layer, ISpriteLayer{
	public Bitmap16Bit[] spriteSet;
	public Coordinate[] coordinates;		//Use moveSprite() and relMoveSprite() instead to move sprites
	public FlipRegister[] flipRegisters;
	public SpriteMovementListener[int] collisionDetector;
	//Constructors. 
	public this(int n){
		spriteSet.length = n;
		coordinates.length = n;
		flipRegisters.length = n;
	}

	public this(){

	}

    public void addSprite(Bitmap16Bit s, int n, Coordinate c){
        spriteSet[n] = s;
		coordinates[n] = c;
		flipRegisters[n] = FlipRegister.NORM;
    }

	public void addSprite(Bitmap16Bit s, int n, int x, int y){
		spriteSet[n] = s;
		coordinates[n] = Coordinate(x,y,s.getX(),s.getY());
		flipRegisters[n] = FlipRegister.NORM;
	}

	public ushort getTransparencyIndex(){
		return transparencyIndex;
	}

    /*public void removeSprite(int n){

        

    }*/
    public void moveSprite(int n, int x, int y){
		coordinates[n].move(x,y);
		callCollisionDetector(n);
    }
    public void relMoveSprite(int n, int x, int y){
		coordinates[n].relMove(x,y);
		callCollisionDetector(n);
    }

	public Bitmap16Bit[] getSpriteSet(){
		return spriteSet[];
	}

	public Coordinate[] getCoordinates(){
		return coordinates;
	}

	private void callCollisionDetector(int n){
		foreach(c; collisionDetector){
			c.spriteMoved(n);
		}
	}

	public void updateRaster(Bitmap16Bit frameBuffer){
		for(int i ; i < spriteSet.length ; i++){
			if((coordinates[i].xb > sX && coordinates[i].yb > sY) && (coordinates[i].xa < sX + rasterX && coordinates[i].ya < sY + rasterY)) {
				//writeln(0);
				int offsetXA, offsetXB, offsetYA, offsetYB;
				//if(sX > coordinates[i].xa) {offsetXA = sX - coordinates[i].xa; }
				if(sY > coordinates[i].ya) {offsetYA = sY - coordinates[i].ya; }
				//if(sX + rasterX < coordinates[i].xb) {offsetXB = sX - coordinates[i].xb - rasterX; }
				if(sY + rasterY < coordinates[i].yb) {offsetYB = coordinates[i].yb - rasterY; }
				for(int y = offsetYA ; y < coordinates[i].getYSize() - offsetYB ; y++){
					ushort[] chunk = (flipRegisters[i] == FlipRegister.Y || flipRegisters[i] == FlipRegister.XY) ? spriteSet[i].readRowReverse(y) : spriteSet[i].readRow(y);
					if(flipRegisters[i] == FlipRegister.X || flipRegisters[i] == FlipRegister.XY){
						for(int x ; x < chunk.length ; x++){
							if(coordinates[i].xa - sX + x >= 0 && coordinates[i].xa - sX + x < rasterX){
								if(chunk[chunk.length-x-1] != transparencyIndex) frameBuffer.writePixel(coordinates[i].xa - sX + x, coordinates[i].ya - sY + y, chunk[chunk.length-x-1]);
							}
						}
					}
					else{
						for(int x ; x < chunk.length ; x++){
							if(coordinates[i].xa - sX + x >= 0 && coordinates[i].xa - sX + x < rasterX){
								if(chunk[x] != transparencyIndex) frameBuffer.writePixel(coordinates[i].xa - sX + x, coordinates[i].ya - sY + y, chunk[x]);
							}
						}
					}
				}
			}
		}
	}

    
}

