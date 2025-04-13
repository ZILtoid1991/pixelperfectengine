module test2.app;

import std.stdio;
import std.typecons : BitFlags;
import std.format;
import std.algorithm;

import pixelperfectengine.graphics.raster;
import pixelperfectengine.graphics.layers;

import pixelperfectengine.graphics.bitmap;

import pixelperfectengine.physics.common;
import pixelperfectengine.physics.objectcollision;

import pixelperfectengine.system.input;
import pixelperfectengine.system.file;
import pixelperfectengine.system.etc;
import pixelperfectengine.system.config;

import pixelperfectengine.system.common;

import bindbc.opengl;

import pixelperfectengine.map.mapformat;

int main(string[] args) {
	string path = resolvePath("%PATH%/assets/test2.xmf");
	foreach(arg ; args[1..$]) {
		if (arg.startsWith("--shadervers=")) {
			pathSymbols["SHDRVER"] = arg[13..$];
		} else if (arg.startsWith("--path=")) {
			path = arg[7..$];
		}
	}
	try {
		MapFormatTester app = new MapFormatTester(path);
		app.whereTheMagicHappens();
	} catch (Throwable e) {
		writeln(e);
	}
	return 0;
}

public class MapFormatTester : SystemEventListener, InputListener {
	enum StateFlags {
		isRunning	=	1<<0,
		fullScreen	=	1<<1,
	}
	enum ControlFlags {
		up			=   1<<0,
		down		=   1<<1,
		left		=   1<<2,
		right		=   1<<3,
	}
	MapFormat		mapSource;
	OSWindow		output;
	Raster			r;
	InputHandler	ih;
	ObjectCollisionDetector	ocd;
	BitFlags!StateFlags	stateFlags;
	BitFlags!ControlFlags controlFlags;
	TileLayer		textLayer;
	SpriteLayer		gameField;
	GLShader		tileShader;
	this(string path) {
		output = new OSWindow("TileLayer Test", "ppe_tilelayertest", -1, -1, 424 * 4, 240 * 4, WindowCfgFlags.IgnoreMenuKey);//new OutputScreen("TileLayer test", 424 * 4, 240 * 4);
		version (Windows) output.getOpenGLHandleAttribsARB([
			OpenGLContextAtrb.MajorVersion, 3,
			OpenGLContextAtrb.MinorVersion, 3,
			OpenGLContextAtrb.ProfileMask, 1,
			OpenGLContextAtrb.Flags, OpenGLContextFlags.Debug,
			0
		]);
		else output.getOpenGLHandle();
		const glStatus = loadOpenGL();
		if (glStatus < GLSupport.gl33) {
			writeln("OpenGL not found!");
		}
		stateFlags.isRunning = true;
		tileShader = GLShader(loadShader(`%SHADERS%/tile_%SHDRVER%.vert`),
				loadShader(`%SHADERS%/tile_%SHDRVER%.frag`));
		r = new Raster(424,240,output);
		r.readjustViewport(424 * 4, 240 * 4, 0, 0);
		Image fontSource = loadImage(File(resolvePath("%SYSTEM%/codepage_8_8.png")));
		ih = new InputHandler();
		ih.systemEventListener = this;
		ih.inputListener = this;
		{
			import pixelperfectengine.system.input.scancode;
			ih.addBinding(BindingCode(ScanCode.UP, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("up"));
			ih.addBinding(BindingCode(ScanCode.DOWN, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("down"));
			ih.addBinding(BindingCode(ScanCode.LEFT, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("left"));
			ih.addBinding(BindingCode(ScanCode.RIGHT, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("right"));
			ih.addBinding(BindingCode(ScanCode.F11, 0, Devicetype.Keyboard, 0, IGNORE_LOCKLIGHTS), InputBinding("fullscreen"));
		}


		textLayer = new TileLayer(8,8, tileShader);
		textLayer.paletteOffset = 512;
		textLayer.masterVal = 127;
		textLayer.loadMapping(53, 30, new MappingElement[](53 * 30));
		{
			textLayer.addBitmapSource(loadBitmapFromImage!Bitmap8Bit(fontSource), 0, 1);
			for (ushort i; i < 256; i++) {
				textLayer.addTile(i, 0, (i & 0x0F)<<3, (i & 0xF0)>>1, 1);
			}
		}
		textLayer.writeTextToMap(0, 1, 0, "Collision:", BitmapAttrib(true, false, false));
		textLayer.writeTextToMap(0, 2, 0, "Col. type:", BitmapAttrib(true, false, false));
		textLayer.reprocessTilemap();
		ocd = new ObjectCollisionDetector(&onCollision, 0);

		stateFlags.isRunning = true;
		loadMap(path);
	}
	void loadMap(string m) {
		mapSource = new MapFormat(File(m));
		mapSource.loadTiles(r);
		mapSource.loadAllSpritesAndObjects(r, ocd);
		mapSource.loadMappingData();
		r.loadLayers(mapSource.layeroutput);
		gameField = cast(SpriteLayer)(mapSource.layeroutput[16]);
		r.addLayer(textLayer, 32);
		r.loadPaletteChunk([Color(0x00,0x00,0x00,0xFF),Color(0xff,0xff,0xff,0xFF),Color(0x00,0x00,0x00,0xFF),
				Color(0xff,0x00,0x00,0xFF),Color(0x00,0x00,0x00,0xFF),Color(0x00,0xff,0x00,0xFF),Color(0x00,0x00,0x00,0xFF),
				Color(0x00,0x00,0xff,0xFF),Color(0x00,0x00,0xff,0xFF),Color(0x00,0x00,0xff,0xFF),Color(0x00,0x00,0xff,0xFF),
				Color(0x00,0x00,0xff,0xFF),Color(0x00,0x00,0xff,0xFF),Color(0x00,0x00,0xff,0xFF),Color(0x00,0x00,0xff,0xFF),
				Color(0x00,0x00,0xff,0xFF)], 512);
		foreach (Layer l ; r.layerMap) {
			if (l.getLayerType == LayerType.Tile) {
				TileLayer tl = cast(TileLayer)l;
				tl.reprocessTilemap();
			}
		}
	}
	void whereTheMagicHappens() {
		while (stateFlags.isRunning) {
			r.refresh_GL();
			ih.test();
			ocd.objects.ptrOf(65_536).position = gameField.getSpriteCoordinate(65_536).boxOf();
			if(controlFlags.up) {
				gameField.relMoveSprite(65_536,0,-1);
				textLayer.writeTextToMap(10,2,0,"        None",BitmapAttrib(true, false, false));
				textLayer.reprocessTilemap();
			}
			if(controlFlags.down) {
				gameField.relMoveSprite(65_536,0,1);
				textLayer.writeTextToMap(10,2,0,"        None",BitmapAttrib(true, false, false));
				textLayer.reprocessTilemap();
			}
			if(controlFlags.left) {
				gameField.relMoveSprite(65_536,-1,0);
				textLayer.writeTextToMap(10,2,0,"        None",BitmapAttrib(true, false, false));
				textLayer.reprocessTilemap();
			}
			if(controlFlags.right) {
				gameField.relMoveSprite(65_536,1,0);
				textLayer.writeTextToMap(10,2,0,"        None",BitmapAttrib(true, false, false));
				textLayer.reprocessTilemap();
			}
			ocd.testSingle(65_536);
		}
		destroy(output);
	}
	public void onCollision(ObjectCollisionEvent event) {
		textLayer.writeTextToMap(10,1,0,format("%8X"w,event.idB),BitmapAttrib(true, false, false));
		final switch (event.type) with (ObjectCollisionEvent.Type) {
			case None:
				textLayer.writeTextToMap(10,2,0,"        None",BitmapAttrib(true, false, false));
				break;
			case BoxEdge:
				textLayer.writeTextToMap(10,2,0,"     BoxEdge",BitmapAttrib(true, false, false));
				break;
			case BoxOverlap:
				textLayer.writeTextToMap(10,2,0,"  BoxOverlap",BitmapAttrib(true, false, false));
				break;
			case ShapeOverlap:
				textLayer.writeTextToMap(10,2,0,"ShapeOverlap",BitmapAttrib(true, false, false));
				break;
		}
		textLayer.reprocessTilemap();
	}

	override public void onQuit() {
		stateFlags.isRunning = false;
	}
	public void inputDeviceAdded(InputDevice id) {

	}
	public void inputDeviceRemoved(InputDevice id) {

	}
	
	public void keyEvent(uint id, BindingCode code, Timestamp timestamp, bool isPressed) {
		switch (id) {
			case hashCalc("up"):	//up
				controlFlags.up = isPressed;
				break;
			case hashCalc("down"):	//down
				controlFlags.down = isPressed;
				break;
			case hashCalc("left"):	//left
				controlFlags.left = isPressed;
				break;
			case hashCalc("right"):	//right
				controlFlags.right = isPressed;
				break;
			case hashCalc("fullscreen"):
				if (isPressed) {
					stateFlags.fullScreen = !stateFlags.fullScreen;
					output.setScreenMode(-1, stateFlags.fullScreen ? DisplayMode.FullscreenDesktop : DisplayMode.Windowed);
				}
				break;
			default:
				break;
		}
	}
	
	public void axisEvent(uint id, BindingCode code, Timestamp timestamp, float value) {
		
	}

	/**
	 * Called if a window was resized.
	 * Params:
	 *   window = Handle to the OSWindow class.
	 *   width = active area width.
	 *   height = active area height.
	 */
	public void windowResize(OSWindow window, int width, int height) {
		//Code template for window resizing that keeps the content relatively in ratio.
		immutable double origAspectRatio = 424.0 / 240.0;//Calculate original aspect ratio
		double newAspectRatio = cast(double)width / cast(double)height;//Calculate new aspect ratio
		if (newAspectRatio > origAspectRatio) {		//Display area is now wider, padding needs to be added on the sides
			const double visibleWidth = height * origAspectRatio;
			const double sideOffset = (width - visibleWidth) / 2.0;
			r.readjustViewport(cast(int)visibleWidth, height, cast(int)sideOffset, 0);
		} else {	//Display area is now taller, padding needs to be added on the top and bottom
			const double visibleHeight = width / origAspectRatio;
			const double topOffset = (height - visibleHeight) / 2.0;
			r.readjustViewport(width, cast(int)visibleHeight, 0, cast(int)topOffset);
		}
	}
	
}
