module test2.app;

import bindbc.sdl;

import std.stdio;
import std.typecons : BitFlags;

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
	string path = "../assets/test2.xmp";
	if (args.length > 1)
		path = args[1];
	MapFormatTester app = new MapFormatTester(path);
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
		r.addLayer(textLayer, 65_536);
		textLayer.writeTextToMap(0, 1, 0, "Collision:", BitmapAttrib(true, false));
		textLayer.writeTextToMap(0, 2, 0, "Col. type:", BitmapAttrib(true, false));
	}
	void loadMap(string m) {
		mapSource = new MapFormat(File(m));
		mapSource.loadTiles(r);
		mapSource.loadAllSpritesAndObjects(r, ocd);
		r.layerMap = mapSource.layeroutput;
		r.addLayer(textLayer, 65_536);
	}
	void whereTheMagicHappens() {
		while (stateFlags.isRunning) {
			r.refresh();
			ih.test();
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
		
	}
	
	public void controllerAdded(uint id) {
		
	}
	
	public void controllerRemoved(uint id) {
		
	}
	
	public void keyEvent(uint id, BindingCode code, uint timestamp, bool isPressed) {
		
	}
	
	public void axisEvent(uint id, BindingCode code, uint timestamp, float value) {
		
	}
	
}