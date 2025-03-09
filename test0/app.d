module test0.app;

import std.stdio;
import std.string;
import std.conv;
import std.format;
import std.random;

import pixelperfectengine.graphics.raster;
import pixelperfectengine.graphics.layers;

import pixelperfectengine.graphics.bitmap;
import pixelperfectengine.graphics.shaders;

import pixelperfectengine.collision.common;
import pixelperfectengine.collision.objectcollision;
import pixelperfectengine.collision.tilecollision;

import pixelperfectengine.system.input;
import pixelperfectengine.system.file;
import pixelperfectengine.system.etc;
import pixelperfectengine.system.config;

import bindbc.opengl;

import pixelperfectengine.system.common;

int main(string[] args) {
	int w = 8, h = 8, s = 0;
	foreach (string arg ; args) {
		if (arg.startsWith("--shadervers=")) {
			pathSymbols["SHDRVER"] = arg[13..$];
		} else if (arg.startsWith("--mapwidth=")) {
			w = to!int(arg[11..$]);
		} else if (arg.startsWith("--mapheight=")) {
			h = to!int(arg[12..$]);
		} else if (arg.startsWith("--spritenum=")) {
			s = to!int(arg[12..$]);
		}
	}
	TileLayerTest tlt = new TileLayerTest(w, h, s);
	tlt.whereTheMagicHappens();
	return 0;
}

/**
 * Tests graphics output, input events, collision, etc.
 */
class TileLayerTest : SystemEventListener, InputListener {
	bool isRunning, up, down, left, right, scrup, scrdown, scrleft, scrright, fullScreen;
	OSWindow output;
	Raster r;
	TileLayer t;
	TileLayer textLayer;
	TransformableTileLayer!(Bitmap8Bit,16,16) tt;
	Bitmap8Bit[] tiles;
	Bitmap8Bit dlangMan;
	Bitmap1Bit dlangManCS;
	SpriteLayer s;
	InputHandler ih;
	ObjectCollisionDetector ocd;
	TileCollisionDetector tcd;
	float theta;
	int framecounter;
	this (int mapWidth, int mapHeight, int spriteNum) {
		output = new OSWindow("TileLayer Test", "ppe_tilelayertest", -1, -1, 424 * 4, 240 * 4, WindowCfgFlags.IgnoreMenuKey);
		version (Windows) output.getOpenGLHandleAttribsARB([
			OpenGLContextAtrb.MajorVersion, 3,
			OpenGLContextAtrb.MinorVersion, 3,
			OpenGLContextAtrb.Flags, OpenGLContextFlags.Debug | OpenGLContextFlags.ForwardCompatible,
			0
		]);
		else output.getOpenGLHandle();
		const glStatus = loadOpenGL();
		if (glStatus < GLSupport.gl11) {
			writeln("OpenGL not found!");
		}
		theta = 0;
		isRunning = true;
		Image tileSource = loadImage(File(resolvePath("%PATH%/assets/sci-fi-tileset.png")));
		//Image tileSource = loadImage(File("../assets/_system/concreteGUIE0.tga"));
		Image spriteSource = loadImage(File(resolvePath("%PATH%/assets/d-man.tga")));
		Image fontSource = loadImage(File(resolvePath("%SYSTEM%/codepage_8_8.png")));
		r = new Raster(424,240,output, 1);
		r.readjustViewport(424 * 4, 240 * 4, 0, 0);
		//output.setMainRaster(r);
		t = new TileLayer(16,16, RenderingMode.Copy);
		textLayer = new TileLayer(8,8, RenderingMode.AlphaBlend);
		textLayer.paletteOffset = 512;
		textLayer.masterVal = 127;
		textLayer.loadMapping(53, 30, new MappingElement[](53 * 30));
		tt = new TransformableTileLayer!(Bitmap8Bit,16,16)(RenderingMode.AlphaBlend);
		s = new SpriteLayer(GLShader(loadShader(`%SHADERS%/base_%SHDRVER%.vert`),
				loadShader(`%SHADERS%/base_%SHDRVER%.frag`)));
		// r.addLayer(tt, 1);
		// r.addLayer(t, 0);
		r.addLayer(s, 2);
		// r.addLayer(textLayer, 65_536);

		// Color[] localPal = loadPaletteFromImage(tileSource);
		// localPal.length = 256;
		r.loadPaletteChunk(loadPaletteFromImage(tileSource), 0);
		// localPal = loadPaletteFromImage(spriteSource);
		// localPal.length = 256;
		r.loadPaletteChunk(loadPaletteFromImage(spriteSource), 256);
		r.loadPaletteChunk([Color(0x00,0x00,0x00,0xFF),Color(0xff,0xff,0xff,0xFF),Color(0x00,0x00,0x00,0xFF),
				Color(0xff,0x00,0x00,0xFF),Color(0x00,0x00,0x00,0xFF),Color(0x00,0xff,0x00,0xFF),Color(0x00,0x00,0x00,0xFF),
				Color(0x00,0x00,0xff,0xFF),Color(0x00,0x00,0xff,0xFF),Color(0x00,0x00,0xff,0xFF),Color(0x00,0x00,0xff,0xFF),
				Color(0x00,0x00,0xff,0xFF),Color(0x00,0x00,0xff,0xFF),Color(0x00,0x00,0xff,0xFF),Color(0x00,0x00,0xff,0xFF),
				Color(0x00,0x00,0xff,0xFF)], 512);

		//writeln(r.layerMap);
		//c = new CollisionDetector();
		dlangMan = loadBitmapFromImage!Bitmap8Bit(spriteSource);
		dlangManCS = dlangMan.generateStandardCollisionModel();
		ocd = new ObjectCollisionDetector(&onCollision, 0);
		//tcd = new TileCollisionDetector(&onTileCollision, 1, t);
		// {
		// 	Image i = loadImage(File(getPathToAsset("/assets/basn3p04.png")));
		// 	r.addPaletteChunk(loadPaletteFromImage(i));
		// 	s.addSprite(loadBitmapFromImage!Bitmap4Bit(i), 65_537, 320, 200, 0x21);//34
		// }
		// {
		// 	Image i = loadImage(File(getPathToAsset("/assets/basn3p02.png")));
		// 	r.addPaletteChunk(loadPaletteFromImage(i));
		// 	s.addSprite(loadBitmapFromImage!Bitmap2Bit(i), 65_538, 352, 200, 0x88);//0x88
		// }
		//s.addSprite(loadBitmapFromFile!Bitmap2Bit("..assets/basn3p04.png"));
		s.addBitmapSource(dlangMan, 0);
		s.createSpriteMaterial(0, 0, Box(0, 0, 31, 31));
		s.addSprite(0, 65_536, Point(0, 0), 1);
		ocd.objects[65_536] = CollisionShape(Box(0, 0, 31, 31), dlangManCS);
		//tcd.objects[65_536] = ocd.objects[65_536];
		// s.addSprite(dlangMan, 0, 0, 0, 1, 0x0, 0x0, -1024, -1024);

		for(int i = 1 ; i < spriteNum ; i++){
			const int x = uniform(0,320), y = uniform(0,240);
			s.addSprite(0, i, Point(x, y), 1);
			ocd.objects[i] = CollisionShape(Box(x, y, x + 31, y + 31), dlangManCS);
		}
		
		tiles = loadBitmapSheetFromImage!Bitmap8Bit(tileSource, 16, 16);//loadBitmapSheetFromFile!Bitmap8Bit("../assets/sci-fi-tileset.png",16,16);
		
		for (int i; i < tiles.length; i++) {
			tt.addTile(tiles[i], cast(wchar)i);
		}
		
		for (int i; i < tiles.length; i++) {
			t.addTile(tiles[i], cast(wchar)i);
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
			import pixelperfectengine.system.input.scancode;
			import iota.controls.gamectrl : GameControllerButtons;
			ih.addBinding(BindingCode(ScanCode.UP, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("up"));
			ih.addBinding(BindingCode(ScanCode.DOWN, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("down"));
			ih.addBinding(BindingCode(ScanCode.LEFT, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("left"));
			ih.addBinding(BindingCode(ScanCode.RIGHT, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("right"));
			ih.addBinding(BindingCode(GameControllerButtons.DPadUp, 0, Devicetype.Joystick, 0, 0), InputBinding("up"));
			ih.addBinding(BindingCode(GameControllerButtons.DPadDown, 0, Devicetype.Joystick, 0, 0), InputBinding("down"));
			ih.addBinding(BindingCode(GameControllerButtons.DPadLeft, 0, Devicetype.Joystick, 0, 0), InputBinding("left"));
			ih.addBinding(BindingCode(GameControllerButtons.DPadRight, 0, Devicetype.Joystick, 0, 0), InputBinding("right"));
			ih.addBinding(BindingCode(ScanCode.np8, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("scrup"));
			ih.addBinding(BindingCode(ScanCode.np2, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("scrdown"));
			ih.addBinding(BindingCode(ScanCode.np4, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("scrleft"));
			ih.addBinding(BindingCode(ScanCode.np6, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("scrright"));
			ih.addBinding(BindingCode(GameControllerButtons.North, 0, Devicetype.Joystick, 0, 0), InputBinding("scrup"));
			ih.addBinding(BindingCode(GameControllerButtons.South, 0, Devicetype.Joystick, 0, 0), InputBinding("scrdown"));
			ih.addBinding(BindingCode(GameControllerButtons.West, 0, Devicetype.Joystick, 0, 0), InputBinding("scrleft"));
			ih.addBinding(BindingCode(GameControllerButtons.East, 0, Devicetype.Joystick, 0, 0), InputBinding("scrright"));
			ih.addBinding(BindingCode(ScanCode.Q, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("A+"));
			ih.addBinding(BindingCode(ScanCode.A, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("A-"));
			ih.addBinding(BindingCode(ScanCode.W, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("B+"));
			ih.addBinding(BindingCode(ScanCode.S, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("B-"));
			ih.addBinding(BindingCode(ScanCode.E, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("C+"));
			ih.addBinding(BindingCode(ScanCode.D, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("C-"));
			ih.addBinding(BindingCode(ScanCode.R, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("D+"));
			ih.addBinding(BindingCode(ScanCode.F, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("D-"));
			ih.addBinding(BindingCode(ScanCode.T, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("x0+"));
			ih.addBinding(BindingCode(ScanCode.G, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("x0-"));
			ih.addBinding(BindingCode(ScanCode.Y, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("y0+"));
			ih.addBinding(BindingCode(ScanCode.H, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("y0-"));
			ih.addBinding(BindingCode(ScanCode.PAGEUP, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("alpha+"));
			ih.addBinding(BindingCode(ScanCode.PAGEDOWN, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("alpha-"));
			ih.addBinding(BindingCode(ScanCode.HOME, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("hidettl"));
			ih.addBinding(BindingCode(ScanCode.END, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("unhidettl"));
			ih.addBinding(BindingCode(ScanCode.n1, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("sprtH-"));
			ih.addBinding(BindingCode(ScanCode.n2, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("sprtH+"));
			ih.addBinding(BindingCode(ScanCode.n3, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("sprtV-"));
			ih.addBinding(BindingCode(ScanCode.n4, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("sprtV+"));
			ih.addBinding(BindingCode(ScanCode.n5, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("2up"));
			ih.addBinding(BindingCode(ScanCode.n6, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("2down"));
			ih.addBinding(BindingCode(ScanCode.n7, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("2left"));
			ih.addBinding(BindingCode(ScanCode.n8, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("2right"));
			ih.addBinding(BindingCode(ScanCode.F11, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("fullscreen"));
		}
		
		tt.loadMapping(mapWidth, mapHeight, mapping);
		tt.warpMode = WarpMode.Off;
		
		t.loadMapping(mapWidth, mapHeight, mapping);
		t.warpMode = WarpMode.TileRepeat;
		
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
		//r.palette[256].base = 0;
		//textLayer.writeTextToMap(2,2,0,"Hello world!",BitmapAttrib(true, false));
		textLayer.writeTextToMap(0, 0, 0, "Framerate:", BitmapAttrib(true, false));
		textLayer.writeTextToMap(0, 1, 0, "Collision:", BitmapAttrib(true, false));
		textLayer.writeTextToMap(0, 2, 0, "Col. type:", BitmapAttrib(true, false));
		textLayer.writeTextToMap(0, 3, 0, "Overlapping tiles:", BitmapAttrib(true, false));
		//writeln(tt);
		//r.palette[0] = 255;
		//r.addRefreshListener(output, 0);

	}
	private @nogc void ttlHBlankInterrupt(ref short[4] localABCD, ref short[2] localsXsY, ref short[2] localx0y0, short y){
		localABCD[0]++;
	}
	public void whereTheMagicHappens(){
		while(isRunning){
			r.refresh_GL();
			ih.test();
			if(up) {
				s.relMoveSprite(65_536,0,-1);
				textLayer.writeTextToMap(10,2,0,"        None",BitmapAttrib(true, false));
			}
			if(down) {
				s.relMoveSprite(65_536,0,1);
				textLayer.writeTextToMap(10,2,0,"        None",BitmapAttrib(true, false));
			}
			if(left) {
				s.relMoveSprite(65_536,-1,0);
				textLayer.writeTextToMap(10,2,0,"        None",BitmapAttrib(true, false));
			}
			if(right) {
				s.relMoveSprite(65_536,1,0);
				textLayer.writeTextToMap(10,2,0,"        None",BitmapAttrib(true, false));
			}
			ocd.objects.ptrOf(65_536).position = s.getSpriteCoordinate(65_536).boxOf();
			onTileCollision(getAllOverlappingTiles(s.getSpriteCoordinate(65_536).boxOf(), t));
			//tcd.objects.ptrOf(65_536).position = s.getSpriteCoordinate(65_536);
			ocd.testSingle(65_536);
			//tcd.testAll();
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
				float avgFPS = r.avgfps;
				wstring fpsCounter = format(" %3.3f"w, avgFPS);
				textLayer.writeTextToMap(10,0,0,fpsCounter,BitmapAttrib(true, false));
				framecounter = 0;
			}
			//t.relScroll(1,0);
		}
		destroy(output);
	}
	public void onCollision(ObjectCollisionEvent event) {
		textLayer.writeTextToMap(10,1,0,format("%8X"w,event.idB),BitmapAttrib(true, false));
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
	public void onTileCollision(MappingElement[] overlapList) {
		wstring tileList = "[";
		foreach (MappingElement me ; overlapList) {
			tileList ~= format("%4X;"w, me.tileID);
		}
		tileList ~= "]";
		textLayer.writeTextToMap(10,4,0,tileList,BitmapAttrib(true, false));
	}
	override public void onQuit() {
		isRunning = false;
	}
	public void inputDeviceAdded(InputDevice id) {

	}
	public void inputDeviceRemoved(InputDevice id) {

	}
	/**
	 * Called when a keybinding event is generated.
	 * The `id` should be generated from a string, usually the name of the binding.
	 * `code` is a duplicate of the code used for fast lookup of the binding, which also contains other info (deviceID, etc).
	 * `timestamp` is the time lapsed since the start of the program, can be used to measure time between keypresses.
	 * NOTE: Hat events on joysticks don't generate keyReleased events, instead they generate keyPressed events on release.
	 */
	public void keyEvent(uint id, BindingCode code, Timestamp timestamp, bool isPressed) {
		//writeln(id, ";", code, ";",timestamp, ";",isPressed, ";");
		switch (id) {
			case hashCalc("up"):	//up
				up = isPressed;
				break;
			case hashCalc("down"):	//down
				down = isPressed;
				break;
			case hashCalc("left"):	//left
				left = isPressed;
				break;
			case hashCalc("right"):	//right
				right = isPressed;
				break;
			case hashCalc("scrup"):	//scrup
				scrup = isPressed;
				break;
			case hashCalc("scrdown"):		//scrdown
				scrdown = isPressed;
				break;
			case hashCalc("scrleft"):	//scrleft
				scrleft = isPressed;
				break;
			case hashCalc("scrright"):	//scrright
				scrright = isPressed;
				break;
			case hashCalc("A+"): 	//A+
				tt.A = cast(short)(tt.A + 16);
				break;
			case hashCalc("A-"):	//A-
				tt.A = cast(short)(tt.A - 16);
				break;
			case hashCalc("B+"):	//B+
				tt.B = cast(short)(tt.B + 16);
				break;
			case hashCalc("B-"):	//B-
				tt.B = cast(short)(tt.B - 16);
				break;
			case hashCalc("C+"):	//C+
				tt.C = cast(short)(tt.C + 16);
				break;
			case hashCalc("C-"):	//C-
				tt.C = cast(short)(tt.C - 16);
				break;
			case hashCalc("D+"):	//D+
				tt.D = cast(short)(tt.D + 16);
				break;
			case hashCalc("D-"):	//D-
				tt.D = cast(short)(tt.D - 16);
				break;
			case hashCalc("x0+"):	//x0+
				tt.x_0 = cast(short)(tt.x_0 + 1);
				break;
			case hashCalc("x0-"):	//x0-
				tt.x_0 = cast(short)(tt.x_0 - 1);
				break;
			case hashCalc("y0+"):	//y0+
				tt.y_0 = cast(short)(tt.y_0 + 1);
				break;
			case hashCalc("y0-"):	//y0-
				tt.y_0 = cast(short)(tt.y_0 - 1);
				break;
			case hashCalc("hidettl"):
				r.removeLayer(0);
				break;
			case hashCalc("unhidettl"):
				r.addLayer(tt, 0);
				break;
			case hashCalc("sprtH-"):
				if(s.getScaleSpriteHoriz(0) == 16)
					s.scaleSpriteHoriz(0,-16);
				else
					s.scaleSpriteHoriz(0,s.getScaleSpriteHoriz(0) - 16);
				break;
			case hashCalc("sprtH+"):
				if(s.getScaleSpriteHoriz(0) == -16)
					s.scaleSpriteHoriz(0,16);
				else
					s.scaleSpriteHoriz(0,s.getScaleSpriteHoriz(0) + 16);
				break;
			case hashCalc("sprtV-"):
				if(s.getScaleSpriteVert(0) == 16)
					s.scaleSpriteVert(0,-16);
				else
					s.scaleSpriteVert(0,s.getScaleSpriteVert(0) - 16);
				break;
			case hashCalc("sprtV+"):
				if(s.getScaleSpriteVert(0) == -16)
					s.scaleSpriteVert(0,16);
				else
					s.scaleSpriteVert(0,s.getScaleSpriteVert(0) + 16);
				break;
			case hashCalc("2up"):
				s.relMoveSprite(0,0,-1);
				break;
			case hashCalc("2down"):
				s.relMoveSprite(0,0,1);
				break;
			case hashCalc("2left"):
				s.relMoveSprite(0,-1,0);
				break;
			case hashCalc("2right"):
				s.relMoveSprite(0,1,0);
				break;
			case hashCalc("fullscreen"):
				if (isPressed) {
					fullScreen = !fullScreen;
					output.setScreenMode(-1, fullScreen ? DisplayMode.FullscreenDesktop : DisplayMode.Windowed);
				}
				break;
			default:
				break;
		}
	}
	/** 
	 * Called if a window was resized.
	 * Params:
	 *   window = Handle to the OSWindow class.
	 *   width = active area width.
	 *   height = active area height.
	 */
	public void windowResize(OSWindow window, int width, int height) {
		// immutable double origAspectRatio = 424.0 / 240.0;//Calculate original aspect ratio
		// double newAspectRatio = cast(double)width / cast(double)height;//Calculate new aspect ratio
		// if (newAspectRatio > origAspectRatio) {		//Display area is now wider, padding needs to be added on the sides
		// 	const double visibleWidth = height * origAspectRatio;
		// 	const double sideOffset = (width - visibleWidth) / 2.0;
		// 	r.readjustViewport(cast(int)visibleWidth, height, cast(int)sideOffset, 0);
		// 	// glViewport(cast(int)sideOffset, 0, cast(int)visibleWidth, height);
		// } else {	//Display area is now taller, padding needs to be added on the top and bottom
		// 	const double visibleHeight = width / origAspectRatio;
		// 	const double topOffset = (height - visibleHeight) / 2.0;
		// 	r.readjustViewport(width, cast(int)visibleHeight, 0, cast(int)topOffset);
		// 	// glViewport(0, cast(int)topOffset, width, cast(int)visibleHeight);
		// }
		r.readjustViewport(width, height, 0, 0);
	}
	/**
	 * Called when an axis is being operated.
	 * The `id` should be generated from a string, usually the name of the binding.
	 * `code` is a duplicate of the code used for fast lookup of the binding, which also contains other info (deviceID, etc).
	 * `timestamp` is the time lapsed since the start of the program, can be used to measure time between keypresses.
	 * `value` is the current position of the axis normalized between -1.0 and +1.0 for joysticks, and 0.0 and +1.0 for analog
	 * triggers.
	 */
	public void axisEvent(uint id, BindingCode code, Timestamp timestamp, float value) {

	}
}
