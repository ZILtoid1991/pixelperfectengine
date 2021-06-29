/*
Copyright (C) 2015, by Laszlo Szeremi under the Boost license.

VDP Engine
*/


module app;

import std.stdio;
import std.string;
import std.conv;
import std.format;
import std.random;

import bindbc.sdl;
//import derelict.freeimage.freeimage;

//import system.config;

import PixelPerfectEngine.graphics.outputScreen;
import PixelPerfectEngine.graphics.raster;
import PixelPerfectEngine.graphics.layers;

import PixelPerfectEngine.graphics.bitmap;

import PixelPerfectEngine.collision.common;
import PixelPerfectEngine.collision.objectCollision;

import PixelPerfectEngine.system.input;
import PixelPerfectEngine.system.file;
import PixelPerfectEngine.system.etc;
import PixelPerfectEngine.system.config;
//import PixelPerfectEngine.system.binarySearchTree;
import PixelPerfectEngine.system.common;

public import editor;
//import PixelPerfectEngine.extbmp.extbmp;

public Editor prg;

int main(string[] args){
	initialzeSDL();

	if (args.length > 1) {
		if (args[1] == "--test") {
			bool testTransformableTileLayer;
			if (args.length > 2) 
				if (args[2] == "transform")
					testTransformableTileLayer = true;
			TileLayerTest lprg = new TileLayerTest(testTransformableTileLayer, 8, 8);
			lprg.whereTheMagicHappens;
			return 0;
		}
	}

	prg = new Editor(args);
	prg.whereTheMagicHappens;
	return 0;
}
/**
 * Tests graphics output, input events, collision, etc.
 */
class TileLayerTest : SystemEventListener, InputListener {
	bool isRunning, up, down, left, right, scrup, scrdown, scrleft, scrright;
	OutputScreen output;
	Raster r;
	TileLayer t;
	TileLayer textLayer;
	TransformableTileLayer!(Bitmap8Bit,16,16) tt;
	Bitmap8Bit[] tiles;
	Bitmap8Bit dlangMan;
	Bitmap1bit dlangManCS;
	SpriteLayer s;
	InputHandler ih;
	ObjectCollisionDetector ocd;
	float theta;
	int framecounter;
	this (bool testTransformableTileLayer, int mapWidth, int mapHeight) {
		theta = 0;
		isRunning = true;
		Image tileSource = loadImage(File("../assets/sci-fi-tileset.png"));
		//Image tileSource = loadImage(File("../assets/_system/concreteGUIE0.tga"));
		Image spriteSource = loadImage(File("../assets/d-man.tga"));
		Image fontSource = loadImage(File("../system/codepage_8_8.png"));
		output = new OutputScreen("TileLayer test", 424 * 4, 240 * 4);
		r = new Raster(424,240,output,0);
		output.setMainRaster(r);
		t = new TileLayer(16,16, RenderingMode.Copy);
		textLayer = new TileLayer(8,8, RenderingMode.AlphaBlend);
		textLayer.paletteOffset = 512;
		textLayer.masterVal = 127;
		textLayer.loadMapping(53, 30, new MappingElement[](53 * 30));
		//tt = new TransformableTileLayer!(Bitmap8Bit,16,16)(RenderingMode.Copy);
		s = new SpriteLayer(RenderingMode.AlphaBlend);
		if (testTransformableTileLayer) r.addLayer(tt, 0);
		else r.addLayer(t, 0);
		r.addLayer(s, 1);
		r.addLayer(textLayer, 65_536);

		Color[] localPal = loadPaletteFromImage(tileSource);
		localPal.length = 256;
		r.addPaletteChunk(localPal);
		localPal = loadPaletteFromImage(spriteSource);
		localPal.length = 256;
		r.addPaletteChunk(localPal);
		r.addPaletteChunk([Color(0x00,0x00,0x00,0xFF),Color(0xff,0xff,0xff,0xFF),Color(0x00,0x00,0x00,0xFF),
				Color(0xff,0x00,0x00,0xFF),Color(0x00,0x00,0x00,0xFF),Color(0x00,0xff,0x00,0xFF),Color(0x00,0x00,0x00,0xFF),
				Color(0x00,0x00,0xff,0xFF)]);

		//writeln(r.layerMap);
		//c = new CollisionDetector();
		dlangMan = loadBitmapFromImage!Bitmap8Bit(spriteSource);
		dlangManCS = dlangMan.generateStandardCollisionModel();
		ocd = new ObjectCollisionDetector(&onCollision, 0);
		s.addSprite(dlangMan, 65_536, 0, 0, 1);
		ocd.objects[65_536] = CollisionShape(Box(0, 0, 31, 31), dlangManCS);
		
		for(int i = 1 ; i < 10 ; i++){
			const int x = uniform(0,320), y = uniform(0,240);
			s.addSprite(dlangMan, i, x, y, 1);
			ocd.objects[i] = CollisionShape(Box(x, y, x + 31, y + 31), dlangManCS);
		}
		
		tiles = loadBitmapSheetFromImage!Bitmap8Bit(tileSource, 16, 16);//loadBitmapSheetFromFile!Bitmap8Bit("../assets/sci-fi-tileset.png",16,16);
		//tiles = loadBitmapSheetFromFile!(Bitmap8Bit)("../assets/sci-fi-tileset.png", 16, 16);
		if (testTransformableTileLayer) {
			for (int i; i < tiles.length; i++) {
				tt.addTile(tiles[i], cast(wchar)i);
			}
		} else {
			for (int i; i < tiles.length; i++) {
				t.addTile(tiles[i], cast(wchar)i);
			}
		}
		{
			Bitmap8Bit[] fontSet = loadBitmapSheetFromImage!Bitmap8Bit(fontSource, 8, 8);
			for (ushort i; i < fontSet.length; i++) {
				textLayer.addTile(fontSet[i], i, 1);
			}
		}
		//wchar[] mapping;
		MappingElement[] mapping;
		mapping.length = mapWidth * mapHeight;//64*64;
		//attrMapping.length = 256*256;
		for(int i; i < mapping.length; i++){
			//mapping[i] = to!wchar(uniform(0x0000,0x00AA));
			const int rnd = uniform(0,1024);
			//attrMapping[i] = BitmapAttrib(rnd & 1 ? true : false, rnd & 2 ? true : false);
			mapping[i] = MappingElement(cast(wchar)(rnd & 63), BitmapAttrib(rnd & 1024 ? true : false, rnd & 512 ? true : false));
			//mapping[i] = MappingElement(0x0, BitmapAttrib(false,false));
		}
		ih = new InputHandler();
		ih.systemEventListener = this;
		ih.inputListener = this;
		
		{
			import PixelPerfectEngine.system.input.scancode;
			ih.addBinding(BindingCode(ScanCode.UP, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("up"));
			ih.addBinding(BindingCode(ScanCode.DOWN, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("down"));
			ih.addBinding(BindingCode(ScanCode.LEFT, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("left"));
			ih.addBinding(BindingCode(ScanCode.RIGHT, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("right"));
			ih.addBinding(BindingCode(ScanCode.np8, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("scrup"));
			ih.addBinding(BindingCode(ScanCode.np2, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("scrdown"));
			ih.addBinding(BindingCode(ScanCode.np4, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("scrleft"));
			ih.addBinding(BindingCode(ScanCode.np6, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("scrright"));
			ih.addBinding(BindingCode(ScanCode.Q, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("A+"));
			ih.addBinding(BindingCode(ScanCode.A, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("A-"));
			ih.addBinding(BindingCode(ScanCode.W, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("B+"));
			ih.addBinding(BindingCode(ScanCode.S, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("B-"));
			ih.addBinding(BindingCode(ScanCode.E, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("C+"));
			ih.addBinding(BindingCode(ScanCode.D, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("C-"));
			ih.addBinding(BindingCode(ScanCode.R, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("D+"));
			ih.addBinding(BindingCode(ScanCode.F, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("D-"));
			ih.addBinding(BindingCode(ScanCode.T, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("x0+"));
			ih.addBinding(BindingCode(ScanCode.G, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("x0-"));
			ih.addBinding(BindingCode(ScanCode.Y, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("y0+"));
			ih.addBinding(BindingCode(ScanCode.H, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("y0-"));
			ih.addBinding(BindingCode(ScanCode.PAGEUP, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("alpha+"));
			ih.addBinding(BindingCode(ScanCode.PAGEDOWN, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("alpha-"));
		}
		if (testTransformableTileLayer) {
			tt.loadMapping(mapWidth, mapHeight, mapping);
			tt.warpMode = WarpMode.TileRepeat;
		} else {
			t.loadMapping(mapWidth, mapHeight, mapping);
			t.warpMode = WarpMode.TileRepeat;
		}
		//t.setWrapMode(true);
		//tt.D = -256;
		//loadPaletteFromXMP(tileSource, "default", r);

		/*for(int y ; y < 240 ; y++){
			for(int x ; x < 240 ; x++){
				writeln('[',x,',',y,"] : ", t.transformFunc([x,y]));
			}
		}*/
		
		//writeln(r.palette);
		//r.palette[0].alpha = 255;
		r.palette[256].base = 0;
		//textLayer.writeTextToMap(2,2,0,"Hello world!",BitmapAttrib(true, false));
		textLayer.writeTextToMap(0, 0, 0, "Framerate:", BitmapAttrib(true, false));
		textLayer.writeTextToMap(0, 1, 0, "Collision:", BitmapAttrib(true, false));
		textLayer.writeTextToMap(0, 2, 0, "Col. type:", BitmapAttrib(true, false));
		//writeln(tt);
		//r.palette[0] = 255;
		//r.addRefreshListener(output, 0);

	}
	private @nogc void ttlHBlankInterrupt(ref short[4] localABCD, ref short[2] localsXsY, ref short[2] localx0y0, short y){
		localABCD[0]++;
	}
	public void whereTheMagicHappens(){
		while(isRunning){
			r.refresh();
			ih.test();
			if(up) {
				s.relMoveSprite(65_536,0,-1);
			}
			if(down) {
				s.relMoveSprite(65_536,0,1);
			}
			if(left) {
				s.relMoveSprite(65_536,-1,0);
			}
			if(right) {
				s.relMoveSprite(65_536,1,0);
			}
			ocd.objects.ptrOf(65_536).position = s.getSpriteCoordinate(65_536);
			ocd.testSingle(65_536);
			if(scrup) {
				t.relScroll(0,-1);
				tt.relScroll(0,-1);
				s.relScroll(0,-1);
			}
			if(scrdown) {
				t.relScroll(0,1);
				tt.relScroll(0,1);
				s.relScroll(0,1);
			}
			if(scrleft) {
				t.relScroll(-1,0);
				tt.relScroll(-1,0);
				s.relScroll(-1,0);
			}
			if(scrright) {
				t.relScroll(1,0);
				tt.relScroll(1,0);
				s.relScroll(1,0);
			}
			
			framecounter++;
			if(framecounter == 10){
				//textLayer.writeTextToMap(10,0,0,format("%3.3f"w,r.avgfps),BitmapAttrib(true, false));
				framecounter = 0;
			}
			//t.relScroll(1,0);
		}
	}
	public void onCollision(ObjectCollisionEvent event) {
		//textLayer.writeTextToMap(10,1,0,format("%8X"w,event.idB),BitmapAttrib(true, false));
		final switch (event.type) with (ObjectCollisionEvent.Type) {
			case None:
				textLayer.writeTextToMap(10,2,0,"        None",BitmapAttrib(true, false));
				break;
			case BoxEdge:
				textLayer.writeTextToMap(10,2,0,"     BoxEdge",BitmapAttrib(true, false));
				break;
			case BoxOverlap:
				textLayer.writeTextToMap(10,2,0,"  BoxOverlap",BitmapAttrib(true, false));
				break;
			case ShapeOverlap:
				textLayer.writeTextToMap(10,2,0,"ShapeOverlap",BitmapAttrib(true, false));
				break;
		}
	}
	override public void onQuit() {
		isRunning = false;
	}
	public void controllerAdded(uint id) {

	}
	public void controllerRemoved(uint id) {

	}
	/+override public void keyPressed(string ID,uint timestamp,uint devicenumber,uint devicetype) {
		//writeln(ID);
		import PixelPerfectEngine.graphics.transformFunctions;
		switch(ID){
			case "up": up = true; break;
			case "down": down = true; break;
			case "left": left = true; break;
			case "right": right = true; break;
			case "scrup": scrup = true; break;
			case "scrdown": scrdown = true; break;
			case "scrleft": scrleft = true; break;
			case "scrright": scrright = true; break;
			case "A+": tt.A = cast(short)(tt.A + 16); break;
			case "A-": tt.A = cast(short)(tt.A - 16); break;
			case "B+": tt.B = cast(short)(tt.B + 16); break;
			case "B-": tt.B = cast(short)(tt.B - 16); break;
			case "C+": tt.C = cast(short)(tt.C + 16); break;
			case "C-": tt.C = cast(short)(tt.C - 16); break;
			case "D+": tt.D = cast(short)(tt.D + 16); break;
			case "D-": tt.D = cast(short)(tt.D - 16); break;
			case "x0+": tt.x_0 = cast(short)(tt.x_0 + 1); break;
			case "x0-": tt.x_0 = cast(short)(tt.x_0 - 1); break;
			case "y0+": tt.y_0 = cast(short)(tt.y_0 + 1); break;
			case "y0-": tt.y_0 = cast(short)(tt.y_0 - 1); break;
			case "sH-":
				if(s.getScaleSpriteHoriz(0) == 16){
					s.scaleSpriteHoriz(0,-16);
					return;
				}
				s.scaleSpriteHoriz(0,s.getScaleSpriteHoriz(0) - 16);
				//writeln(s.getScaleSpriteHoriz(0));
				break;
			case "sH+":
				if(s.getScaleSpriteHoriz(0) == -16){
					s.scaleSpriteHoriz(0,16);
					return;
				}
				s.scaleSpriteHoriz(0,s.getScaleSpriteHoriz(0) + 16);
				//writeln(s.getScaleSpriteHoriz(0));
				break;
			case "sV-":
				if(s.getScaleSpriteVert(0) == 16){
					s.scaleSpriteVert(0,-16);
					return;
				}
				s.scaleSpriteVert(0,s.getScaleSpriteVert(0) - 16);
				break;
			case "sV+":
				if(s.getScaleSpriteVert(0) == -16){
					s.scaleSpriteVert(0,16);
					return;
				}
				s.scaleSpriteVert(0,s.getScaleSpriteVert(0) + 16);
				break;
			case "HM":
				s.scaleSpriteHoriz(0,s.getScaleSpriteHoriz(0) * -1);
				break;
			case "VM":
				s.scaleSpriteVert(0,s.getScaleSpriteVert(0) * -1);
				break;
			case "theta+":
				theta += 1;
				short[4] newTP = rotateFunction(theta);
				tt.A = newTP[0];
				tt.B = newTP[1];
				tt.C = newTP[2];
				tt.D = newTP[3];
				break;
			case "theta-":
				theta -= 1;
				short[4] newTP = rotateFunction(theta);
				tt.A = newTP[0];
				tt.B = newTP[1];
				tt.C = newTP[2];
				tt.D = newTP[3];
				break;
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
	}+/
/*public void spriteCollision(CollisionEvent ce){
		writeln("COLLISION!!!!11!1111!!!ONEONEONE!!!");
	}

	public void backgroundCollision(CollisionEvent ce){}*/
	/**
	 * Called when a keybinding event is generated.
	 * The `id` should be generated from a string, usually the name of the binding.
	 * `code` is a duplicate of the code used for fast lookup of the binding, which also contains other info (deviceID, etc).
	 * `timestamp` is the time lapsed since the start of the program, can be used to measure time between keypresses.
	 * NOTE: Hat events on joysticks don't generate keyReleased events, instead they generate keyPressed events on release.
	 */
	public void keyEvent(uint id, BindingCode code, uint timestamp, bool isPressed) {
		//writeln(id, ";", code, ";",timestamp, ";",isPressed, ";");
		switch (id) {
			case 1720810685:	//up
				up = isPressed;
				break;
			case 1672064345:	//down
				down = isPressed;
				break;
			case 2840212248:	//left
				left = isPressed;
				break;
			case 1786548735:	//right
				right = isPressed;
				break;
			case 3938104347:	//scrup
				scrup = isPressed;
				break;
			case 131561283:		//scrdown
				scrdown = isPressed;
				break;
			case 4011913815:	//scrleft
				scrleft = isPressed;
				break;
			case 2073272778:	//scrright
				scrright = isPressed;
				break;
			case 4284782897: 	//A+
				tt.A = cast(short)(tt.A + 16);
				break;
			case 142754382:		//A-
				tt.A = cast(short)(tt.A - 16);
				break;
			case 2060572171:	//B+
				tt.B = cast(short)(tt.B + 16);
				break;
			case 919786464:		//B-
				tt.B = cast(short)(tt.B - 16);
				break;
			case 2857229774:	//C+
				tt.C = cast(short)(tt.C + 16);
				break;
			case 1598464886:	//C-
				tt.C = cast(short)(tt.C - 16);
				break;
			case 2476135441:	//D+
				tt.D = cast(short)(tt.D + 16);
				break;
			case 3708187064:	//D-
				tt.D = cast(short)(tt.D - 16);
				break;
			case 3238134781:	//x0+
				tt.x_0 = cast(short)(tt.x_0 + 1);
				break;
			case 135027337:		//x0-
				tt.x_0 = cast(short)(tt.x_0 - 1);
				break;
			case 983492653:		//y0+
				tt.y_0 = cast(short)(tt.y_0 + 1);
				break;
			case 2733639921:	//y0-
				tt.y_0 = cast(short)(tt.y_0 - 1);
				break;
			default:
				break;
		}
	}
	/**
	 * Called when an axis is being operated.
	 * The `id` should be generated from a string, usually the name of the binding.
	 * `code` is a duplicate of the code used for fast lookup of the binding, which also contains other info (deviceID, etc).
	 * `timestamp` is the time lapsed since the start of the program, can be used to measure time between keypresses.
	 * `value` is the current position of the axis normalized between -1.0 and +1.0 for joysticks, and 0.0 and +1.0 for analog
	 * triggers.
	 */
	public void axisEvent(uint id, BindingCode code, uint timestamp, float value) {

	}
}
