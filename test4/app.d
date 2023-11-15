module test4.app;

/*
This is a template for creating games with PixelPerfectEngine.
Contains some basic setup, but needs further work to be fully featured besides of adding some game logic.

Feel free to modify this, or even create your own templates (you might want to modularize). Contact me, if you encounter any errors on the way.
 */

//Some commonly used stuff
import std.stdio;
import std.typecons : BitFlags;					//This is a good way to create bitflags, so you don't need to keep track of a bunch of boolean values.
import std.file : readText;

import bindbc.sdl;								//As of now, this is needed to initialize the SDL API. Might be changed in the future
//Graphics related imports
import pixelperfectengine.graphics.outputscreen;//Needed to display the final graphics
import pixelperfectengine.graphics.raster;		//Needed to display layers in order
import pixelperfectengine.graphics.layers;		//Imports all layers and layer-related functionality
import pixelperfectengine.graphics.bitmap;		//Imports bitmaps and all bitmap-related functionality
//The next two lines imports the collision detector
import pixelperfectengine.collision.common;		
import pixelperfectengine.collision.objectcollision;
//Various system related imports
import pixelperfectengine.system.input;			//Every game needs some sort of interaction capability, and thus here's the input
import pixelperfectengine.system.file;			//Used to load bitmap and image files
import pixelperfectengine.system.config;		//Needed for configuration files
import pixelperfectengine.system.common;

import pixelperfectengine.system.rng;			//64 bit LFSR random number generator
import pixelperfectengine.system.timer;			//Low-precision timer for keeping time-based events relatively precise
//Audio-related imports
import pixelperfectengine.audio.base.handler;	//Most of the basic stuff we will need
import pixelperfectengine.audio.base.modulebase;//Module interfaces to play back sound effects otherwise not tied to the sequence being played back
import pixelperfectengine.audio.base.config;	//Audio configuration loader and parser
import pixelperfectengine.audio.base.midiseq;	//MIDI sequencer
//Imports the engine's own map format.
import pixelperfectengine.map.mapformat;
//Other imports that might be important. Uncomment any you feel you'll need.
/* import pixelperfectengine.system.common; */
import pixelperfectengine.scripting.lua;
import pixelperfectengine.scripting.globals;


///Our main function, needed for the program to operate.
///You can add `string[] args` if your either really need or really want.
int main() {
	initialzeSDL();						//Initializes the SDL subsystem, so we will have input and graphics
	initLua();
	try {								//A try-catch block to handle any errors. A bit ugly, but can save us when there's issues with debug symbols, or an error happened outside of a D code
		GameApp app = new GameApp();
		app.whereTheMagicHappens();
	} catch (Throwable e) {
		writeln(e);
	}
	return 0;
}
///I generally like to put most of the application logic into one class to keep track of globals, as well as targets to certain events.
public class GameApp : SystemEventListener, InputListener {
	///Defines various states of the game.
	///I have added some quite useful and very often used ones
	enum StateFlags {
		isRunning	=	1<<0,
		pause		=	1<<1,
		mainMenu	=	1<<2,
	}
	///Defines various states for the control. Mainly used to avoid effects from typematic and such.
	///These are the bare minimum requirements for a game.
	enum ControlFlags {
		up			=   1<<0,
		down		=   1<<1,
		left		=   1<<2,
		right		=   1<<3,
	}
	///Stores the currently loaded map file with all related data.
	MapFormat		mapSource;
	///To display our game's graphics
	OutputScreen	output;
	///To manage our layers and palette.
	Raster			rstr;
	///For input handling.
	InputHandler	ih;
	///Detects object collisions that were registered to it.
	ObjectCollisionDetector	ocd;
	///Contains various game state flags (is it running, is it paused, etc).
	BitFlags!StateFlags	stateFlags;
	///Contains various control state flags
	BitFlags!ControlFlags controlFlags;
	///Contains the pointer to the textlayer.
	///Can be used for the menu, status bars, etc.
	TileLayer		textLayer;
	///Contains pointer to the game field, so we can easily interact with it.
	SpriteLayer		gameField;
	///Contains the random number generator and its state.
	//RandomNumberGenerator	rng;
	//ConfigurationProfile	cfg;
	//Audio related stuff goes here.
	//Note: some of the audio stuff is preliminary. It works, but cannot handle certain cases, such as sample rate mismatches, or device disconnection.
	//Sequencer is untested as of now due to a lack of time and manpower.
	AudioDeviceHandler adh;	///Handles audio devices and outputs.
	ModuleManager	modMan;	///Handles the modules and their output.
	ModuleConfig	modCfg;	///Loads and handles module configuration, including routing, patches, and samples.
	SequencerM1		midiSeq;///MIDI sequencer for MIDI playback.
	LuaScript		scrp;
	
	/// Initializes our application.
	/// Put other things here if you need them.
	this () {
		stateFlags.isRunning = true;	//Sets the state to running, so the main loop will stay running.
		output = new OutputScreen("Your app name here", 424 * 4, 240 * 4);	//Creates an output window with the display size of 1696x960.
		rstr = new Raster(424,240,output,0);//Creates a raster with the size of 424x240.
		output.setMainRaster(rstr);		//Sets the main raster of the output screen.

		ih = new InputHandler();		//Creates an instance of an InputHandler (should be only one)
		ih.systemEventListener = this;	//Sets the system event target to this instance
		ih.inputListener = this;		//Sets the input event target to this instance
		
		//ocd = new ObjectCollisionDetector(&onCollision, 0);	//Creates an object collision detector
		//Let's create our layer for statuses, etc
		textLayer = new TileLayer(16,16, RenderingMode.Copy);	//Creates a TileLayer with 8x8 tiles and alpha blending
		textLayer.paletteOffset = 0;						//Sets the palette offset to 512. You might want to change this to the value to the place where you loaded your GUI palette
		textLayer.masterVal = 255;							//Sets the master value for the alpha blending, making this layer semi-transparent initially.
		rstr.addLayer(textLayer, 0);
		gameField = new SpriteLayer();
		rstr.addLayer(gameField, 16);
		//cfg = new ConfigurationProfile();					//Creates and loads the configuration profile.
		/* //Comment the next part out, if you're having too much trouble with audio working, since you still can add sound later on.
		//audio related part begin
		AudioDeviceHandler.initAudioDriver(OS_PREFERRED_DRIVER);	//Initializes the driver
		AudioSpecs as = AudioSpecs(predefinedFormats[PredefinedFormats.FP32], 48_000, 0, 2, cfg.audioBufferLen, 
				Duration.init);								//Sets up a default audio specification
		adh = new AudioDeviceHandler(as, 1024, 1024 / 128);	//Creates a new AudioDeviceHandler and sets up the basics
		adh.initAudioDevice(-1);							//Initializes the default device
		modMan = new ModuleManager(adh);					//Initializes the module manager
		modCfg = new ModuleConfig(modMan);					//Initializes the module configurator
		modCfg.loadConfigFromFile("../assets/test4_audio.sdl");//This line loads an audio configuration file (make sure you have a valid one - create one with the ADK/test1!)
		modCfg.compile(false);								//Compiles the current module configuration.
		midiSeq = new SequencerM1(modMan.moduleList, modCfg.midiRouting, modCfg.midiGroups);
		modMan.runAudioThread();							//Runs the audio thread.
		//audio related part end 
		*/
		textLayer.loadMapping(32, 16, new MappingElement[](32*16));
		
		//<Put other initialization code here>
		mainRaster = rstr;
		{
			Image dlangMan = loadImage(File("../assets/d-man.tga"));
			scrptResMan["dlangman"] = loadBitmapFromImage!Bitmap8Bit(dlangMan);
			rstr.loadPaletteChunk(loadPaletteFromImage(dlangMan),0);
			Image kumapu = loadImage(File("../assets/kumapu.png"));
			textLayer.addTile(loadBitmapFromImage!Bitmap32Bit(kumapu), 0x0000);
		}
		for (int y ; y < 16 ; y++) {
			for (int x ; x < 32 ; x++) {
				textLayer.writeMapping(x, y, MappingElement(0x0000));
			}
		}
		scrp = new LuaScript(readText("../assets/test4.lua"), "test4.lua");
		scrp.runMain();
	}
	void whereTheMagicHappens() {
		while (stateFlags.isRunning) {
			//Refreshes the raster, then sends the new image to the output window.
			rstr.refresh();
			//Tests the input devices for events.
			ih.test();
			scrp.callFunction("UpdateFunc");
			//Tests the timer for any registered events that are to happen.
			//Note: You can put this call into a separate thread for more precision.
			timer.test();
			//Calling the RNG for every frame will make it less deterministic. Speed runners might hate you for this.
			//rng();
			//This calls the collision detector on all registered objects.
			//You'll want to only call it on moving objects, especially when you have a lot of objects on screen.
			//ocd.testAll();

			//<Per-frame code comes here>
		}
	}
	///This function will load a map file to display levels, or portions of levels.
	///If you're clever, you can store other things in map files
	void loadMap(string m) {
		//This loop removes all previously loaded layers from the raster.
		foreach (key, elem; mapSource.layeroutput) {
			rstr.removeLayer(key);
		}
		mapSource = new MapFormat(File(m));			//Loads the map file itself, and parses it.
		mapSource.loadTiles(rstr);					//Loads the tiles with the palettes needed to display them.
		mapSource.loadAllSpritesAndObjects(rstr, ocd);	//Loads all sprites and objects to the layers, and the collision detector. Also loads the palettes for the sprites
		mapSource.loadMappingData();				//Loads all mapping data to the tilelayers.
		rstr.loadLayers(mapSource.layeroutput);		//Adds the layers to the raster for display.
		//Stores a reference to the gamefield.
		//Change the index number if you want.
		gameField = cast(SpriteLayer)(mapSource.layeroutput[16]);
	}
	///Collision events can be handled from here.
	public void onCollision(ObjectCollisionEvent event) {

	}
	///Called if the window is closed, etd.
	public void onQuit() {
		//You might want to put here a more complicated prompt instead.
		stateFlags.isRunning = false;
	}
	///Called when a controller is added to the system.
	///Note: This function will be changed once I move input handling and output screen handling to iota.
	public void controllerAdded(uint id) {
		
	}
	///Called when a controller is removed the system.
	///Note: This function will be changed once I move input handling and output screen handling to iota.
	public void controllerRemoved(uint id) {
		
	}
	///Called if a key input event has occured.
	///Note: This function will be changed once I move input handling and output screen handling to iota.
	public void keyEvent(uint id, BindingCode code, uint timestamp, bool isPressed) {
		
	}
	///Called if an axis input event has occured.
	///Note: This function will be changed once I move input handling and output screen handling to iota.
	public void axisEvent(uint id, BindingCode code, uint timestamp, float value) {
		
	}
}