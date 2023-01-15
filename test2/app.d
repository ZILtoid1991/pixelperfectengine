module test2.app;

import bindbc.sdl;

import std.stdio;
import std.typecons : BitFlags;
import std.format;

import pixelperfectengine.graphics.outputscreen;
import pixelperfectengine.graphics.raster;
import pixelperfectengine.graphics.layers;

import pixelperfectengine.graphics.bitmap;

import pixelperfectengine.collision.common;
import pixelperfectengine.collision.objectcollision;

import pixelperfectengine.system.input;
import pixelperfectengine.system.file;
import pixelperfectengine.system.etc;
import pixelperfectengine.system.config;

import pixelperfectengine.system.common;

import pixelperfectengine.map.mapformat;

int main(string[] args) {
	initialzeSDL();
	string path = "../assets/test2.xmf";
	if (args.length > 1)
		path = args[1];
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
	}
	enum ControlFlags {
		up			=   1<<0,
		down		=   1<<1,
		left		=   1<<2,
		right		=   1<<3,
	}
	MapFormat		mapSource;
	OutputScreen	output;
	Raster			r;
	InputHandler	ih;
	ObjectCollisionDetector	ocd;
	BitFlags!StateFlags	stateFlags;
	BitFlags!ControlFlags controlFlags;
	TileLayer		textLayer;
	SpriteLayer		gameField;
	this(string path) {
		stateFlags.isRunning = true;
		output = new OutputScreen("TileLayer test", 424 * 4, 240 * 4);
		r = new Raster(424,240,output,0);
		output.setMainRaster(r);
		Image fontSource = loadImage(File("../system/codepage_8_8.png"));
		ih = new InputHandler();
		ih.systemEventListener = this;
		ih.inputListener = this;
		{
			import pixelperfectengine.system.input.scancode;
			ih.addBinding(BindingCode(ScanCode.UP, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("up"));
			ih.addBinding(BindingCode(ScanCode.DOWN, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("down"));
			ih.addBinding(BindingCode(ScanCode.LEFT, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("left"));
			ih.addBinding(BindingCode(ScanCode.RIGHT, 0, Devicetype.Keyboard, 0, KeyModifier.All), InputBinding("right"));
		}


		textLayer = new TileLayer(8,8, RenderingMode.AlphaBlend);
		textLayer.paletteOffset = 512;
		textLayer.masterVal = 127;
		textLayer.loadMapping(53, 30, new MappingElement[](53 * 30));
		{
			Bitmap8Bit[] fontSet = loadBitmapSheetFromImage!Bitmap8Bit(fontSource, 8, 8);
			for (ushort i; i < fontSet.length; i++) {
				textLayer.addTile(fontSet[i], i, 1);
			}
		}
		textLayer.writeTextToMap(0, 1, 0, "Collision:", BitmapAttrib(true, false));
		textLayer.writeTextToMap(0, 2, 0, "Col. type:", BitmapAttrib(true, false));

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
	}
	void whereTheMagicHappens() {
		while (stateFlags.isRunning) {
			r.refresh();
			ih.test();
			ocd.objects.ptrOf(65_536).position = gameField.getSpriteCoordinate(65_536);
			if(controlFlags.up) {
				gameField.relMoveSprite(65_536,0,-1);
				textLayer.writeTextToMap(10,2,0,"        None",BitmapAttrib(true, false));
			}
			if(controlFlags.down) {
				gameField.relMoveSprite(65_536,0,1);
				textLayer.writeTextToMap(10,2,0,"        None",BitmapAttrib(true, false));
			}
			if(controlFlags.left) {
				gameField.relMoveSprite(65_536,-1,0);
				textLayer.writeTextToMap(10,2,0,"        None",BitmapAttrib(true, false));
			}
			if(controlFlags.right) {
				gameField.relMoveSprite(65_536,1,0);
				textLayer.writeTextToMap(10,2,0,"        None",BitmapAttrib(true, false));
			}
			ocd.testSingle(65_536);
		}
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

	public void onQuit() {
		stateFlags.isRunning = false;
	}
	
	public void controllerAdded(uint id) {
		
	}
	
	public void controllerRemoved(uint id) {
		
	}
	
	public void keyEvent(uint id, BindingCode code, uint timestamp, bool isPressed) {
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
			default:
				break;
		}
	}
	
	public void axisEvent(uint id, BindingCode code, uint timestamp, float value) {
		
	}
	
}