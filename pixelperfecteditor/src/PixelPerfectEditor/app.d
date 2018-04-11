/*
Copyright (C) 2015, by Laszlo Szeremi under the Boost license.

VDP Engine
*/


module app;

import std.stdio;
import std.string;
import std.conv;
import std.random;

import derelict.sdl2.sdl;
import derelict.freeimage.freeimage;

//import system.config;

import PixelPerfectEngine.graphics.outputScreen;
import PixelPerfectEngine.graphics.raster;
import PixelPerfectEngine.graphics.layers;

import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.collision;
import PixelPerfectEngine.system.inputHandler;
import PixelPerfectEngine.system.file;
import PixelPerfectEngine.system.etc;
//import system.tgaconv;
import PixelPerfectEngine.system.config;
import PixelPerfectEngine.system.advBitArray;

import editor;
import PixelPerfectEngine.extbmp.extbmp;

version(Windows){
	static const string sdlSource = "system\\SDL2.dll";
	static const string fiSource = "system\\FreeImage.dll";
}else{
	static const string sdlSource = "/system/SDL2.so";
	static const string fiSource = "/system/FreeImage.so";
}

static this(){
	DerelictSDL2.load(sdlSource);
	DerelictFI.load(fiSource);
}

static ~this(){
	
	//DerelictSDL2.unload();
	//DerelictFI.unload();
}

int main(string[] args)
{

    /*DerelictSDL2.load(sdlSource);
	DerelictFI.load(fiSource);*/

	SDL_SetHint(SDL_HINT_WINDOWS_DISABLE_THREAD_NAMING, "1");
	
	Editor e = new Editor(args);
	
	e.whereTheMagicHappens;
    //e.destroy();
	//SDL_Quit();
	//testAdvBitArrays(128);
	//TileLayerTest prg = new TileLayerTest();
	
	return 0;
}

void testAdvBitArrays(int l){
	//General rule: at every step, write all the results to the screen
	//step 1: Generate 4 bitarrays with the l length
	AdvancedBitArray[4] ba;
	for(int i; i < ba.length; i++){
		int x = (l/8)+1;
		void[] rawData;
		rawData.length = x;
		for(int j; j < l/8 ; j++){
			ubyte b = to!ubyte(uniform(0,255));
			*cast(ubyte*)(rawData.ptr + j) = b;
		}
		ba[i] = new AdvancedBitArray(rawData,l);
		writeln(ba[i].toString());
	}
	//step 2: And, or, and then xor all the arrays together
	for(int i; i < ba.length; i++){
		for(int j; j < ba.length; j++){
			AdvancedBitArray resand = ba[i] & ba[j], resor = ba[i] | ba[j], resxor = ba[i] ^ ba[j];
			writeln(resand.toString());writeln(resor.toString());writeln(resxor.toString());
		}
	}//*/
	//step 3: Test bit shifting in both ways by 13
	/*for(int i; i < ba.length; i++){
		AdvancedBitArray shl = ba[i]<<5, shr = ba[i]>>5, sl = ba[i][1..50];
		writeln(shl.toString());
		writeln(shr.toString());
		writeln(sl.toString());
	}//*/
	ubyte[16] testdata = [0,0,81,51,186,186,0,86,48,82,35,5,99,208,95,9];
	ba[0] = new AdvancedBitArray(cast(void[])testdata,128);
	ba[1] = new AdvancedBitArray(cast(void[])testdata,128);
	for(int i ; i < 32 ; i++){
		writeln(ba[0].test(i,40,ba[1],16));
	}
}

class TileLayerTest : SystemEventListener, InputListener, CollisionListener{
	bool isRunning, up, down, left, right, scrup, scrdown, scrleft, scrright;
	OutputScreen output;
	Raster r;
	TransformableTileLayer t;
	SpriteLayer s;
	//Bitmap16Bit[wchar] tiles;
	InputHandler ih;
	CollisionDetector c;
	this(){
		isRunning = true;
		ExtendibleBitmap tileSource = new ExtendibleBitmap("tiletest.xmp");
		ExtendibleBitmap spriteSource = new ExtendibleBitmap("collisionTest.xmp");
		t = new TransformableTileLayer(32,32, LayerRenderingMode.COPY);
		s = new SpriteLayer();
		c = new CollisionDetector();
		Bitmap16Bit dlangMan = loadBitmapFromXMP!Bitmap16Bit(spriteSource,"DLangMan");
		CollisionModel cm = new CollisionModel(dlangMan.width, dlangMan.height, dlangMan.generateStandardCollisionModel());
		dlangMan.offsetIndexes(256);
		s.addSprite(dlangMan,0,0,0,BitmapAttrib(false,true));
		s.addSprite(dlangMan,1,64,64,BitmapAttrib(false,false));
		s.collisionDetector[1] = c;
		c.source = s;
		c.addCollisionModel(cm,0);
		c.addCollisionModel(cm,1);
		c.addCollisionListener(this);
		for(int i; i < tileSource.bitmapID.length; i++){
			string hex = tileSource.bitmapID[i];
			//writeln(hex[hex.length-4..hex.length]);
			t.addTile(loadBitmapFromXMP!Bitmap16Bit(tileSource, hex), to!wchar(parseHex(hex[hex.length-4..hex.length])));
		}
		wchar[] mapping;
		BitmapAttrib[] attrMapping;
		mapping.length = 256*256;
		attrMapping.length = 256*256;
		for(int i; i < mapping.length; i++){
			mapping[i] = to!wchar(uniform(0x0000,0x00AA));
			int rnd = uniform(0,1024);
			attrMapping[i] = BitmapAttrib(rnd & 1 ? true : false, rnd & 2 ? true : false);
			//attrMapping[i] = BitmapAttrib( true , false);
		}
		ih = new InputHandler();
		ih.sel ~= this;
		ih.il ~= this;
		ih.kb ~= KeyBinding(0, SDL_SCANCODE_UP,0, "up", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, SDL_SCANCODE_DOWN,0, "down", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, SDL_SCANCODE_LEFT,0, "left", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, SDL_SCANCODE_RIGHT,0, "right", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.np8,0, "scrup", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.np2,0, "scrdown", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.np4,0, "scrleft", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.np6,0, "scrright", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.F1,0, "A+", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.F2,0, "A-", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.F3,0, "B+", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.F4,0, "B-", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.F5,0, "C+", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.F6,0, "C-", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.F7,0, "D+", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.F8,0, "D-", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.F9,0, "x0+", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.F10,0, "x0-", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.F11,0, "y0+", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.F12,0, "y0-", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.PAGEUP,0, "theta+", Devicetype.KEYBOARD, KeyModifier.ANY);
		ih.kb ~= KeyBinding(0, ScanCode.PAGEDOWN,0, "theta-", Devicetype.KEYBOARD, KeyModifier.ANY);

		t.loadMapping(256,256,mapping, attrMapping);
		//t.setWrapMode(true);

		output = new OutputScreen("TileLayer test", 1280,960);
		r = new Raster(320,240,output);
		output.setMainRaster(r);
		loadPaletteFromXMP(tileSource, "default", r);
		/*for(int y ; y < 240 ; y++){
			for(int x ; x < 240 ; x++){
				writeln('[',x,',',y,"] : ", t.transformFunc([x,y]));
			}
		}*/
		r.addLayer(t, 0);
		r.addLayer(s, 1);
		r.palette ~= cast(Color[])spriteSource.getPalette("default");
		//writeln(r.palette);
		//r.palette[0] = 255;
		//r.addRefreshListener(output, 0);
		while(isRunning){
			r.refresh();
			ih.test();
			if(up) s.relMoveSprite(0,0,-1);
			if(down) s.relMoveSprite(0,0,1);
			if(left) s.relMoveSprite(0,-1,0);
			if(right) s.relMoveSprite(0,1,0);
			if(scrup) t.relScroll(0,-1);
			if(scrdown) t.relScroll(0,1);
			if(scrleft) t.relScroll(-1,0);
			if(scrright) t.relScroll(1,0);
			//t.relScroll(1,0);
		}
	}
	override public void onQuit() {
		isRunning = false;
	}
	override public void controllerAdded(uint ID) {
		
	}
	override public void controllerRemoved(uint ID) {
		
	}
	override public void keyPressed(string ID,uint timestamp,uint devicenumber,uint devicetype) {
		//writeln(ID);
		switch(ID){
			case "up": up = true; break;
			case "down": down = true; break;
			case "left": left = true; break;
			case "right": right = true; break;
			case "scrup": scrup = true; break;
			case "scrdown": scrdown = true; break;
			case "scrleft": scrleft = true; break;
			case "scrright": scrright = true; break;
			case "A+": t.A = t.A + 0.01; 
				writeln(t.A); 
				break;
			case "A-": t.A = t.A - 0.01; 
				writeln(t.A); 
				break;
			case "B+": t.B = t.B + 0.01; break;
			case "B-": t.B = t.B - 0.01; break;
			case "C+": t.C = t.C + 0.01; break;
			case "C-": t.C = t.C - 0.01; break;
			case "D+": t.D = t.D + 0.01; break;
			case "D-": t.D = t.D - 0.01; break;
			case "x0+": t.x_0 = t.x_0 + 0.01; break;
			case "x0-": t.x_0 = t.x_0 - 0.01; break;
			case "y0+": t.y_0 = t.y_0 + 0.01; break;
			case "y0-": t.y_0 = t.y_0 - 0.01; break;
			case "theta+": t.rotate(1); break;
			case "theta-": t.rotate(-1); break;
			default: break;
		}
	}
	override public void keyReleased(string ID,uint timestamp,uint devicenumber,uint devicetype) {
		switch(ID){
			case "up": up = false; break;
			case "down": down = false; break;
			case "left": left = false; break;
			case "right": right = false; break;
			case "scrup": scrup = false; break;
			case "scrdown": scrdown = false; break;
			case "scrleft": scrleft = false; break;
			case "scrright": scrright = false; break;
			default: break;
		}
	}
	public override void spriteCollision(CollisionEvent ce){
		writeln("COLLISION!!!!11!1111!!!ONEONEONE!!!");
	}
	
	public override void backgroundCollision(CollisionEvent ce){}
}