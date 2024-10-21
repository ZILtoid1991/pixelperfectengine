module snake.app;

import bindbc.opengl;

import pixelperfectengine.graphics.raster;
import pixelperfectengine.graphics.layers;

import pixelperfectengine.graphics.bitmap;

import pixelperfectengine.system.input;
import pixelperfectengine.system.input.scancode;
import pixelperfectengine.system.file;
import pixelperfectengine.system.etc;
import pixelperfectengine.system.config;
import pixelperfectengine.system.timer;
import pixelperfectengine.system.rng;

import pixelperfectengine.system.common;
/**
 * The main entry point. Contains essential calls to initializing and running the program.
 */
int main() {
	//Initialize our game.
	SnakeGame game = new SnakeGame();
	//Run the game.
	game.whereTheMagicHappens();
	return 0;
}
/** 
 * A simple snake game.
 * Uses code-generated graphics to avoid relying on external assets.
 *
 * Game rules:
 * * The player controls a snake.
 * * The player must collect apples to get score, which also makes the snake grow.
 * * Every time an apple is collected, a new one is randomly spawned on the map at a point outside of the snake.
 * * If the player either hits the snake or wall, they lose.
 * * If the player somehow makes the snake to grow so big a new apple cannot be spawned, then the player wins.
 *
 * Design guidelines:
 * * No much external assets. (except for engine essentials).
 * * Snake tail follows past directions
 *
 * Some possible assignments to practice using the engine:
 * * Use some external assets.
 * * Add some obstacles.
 * * Add a second, third, etc. player.
 */
public class SnakeGame : InputListener, SystemEventListener {
	/** 
	 * Used for direction tracing in the API.
	 */
	enum Direction : ubyte {
		init		=	0,
		North		=	1,
		South		=	2,
		East		=	4,
		West		=	8,
	}
	/** 
	 * Defines tile type codes.
	 *
	 * Can also be used to track the snake itself.
	 */
	enum TileTypes : wchar {
		init,
		Empty		=	0x00,
		Apple		=	0x01,
		SnakeH		=	0x11,
		SnakeV		=	0x12,
		SnakeNE		=	0x13,
		SnakeSE		=	0x14,
		SnakeNW		=	0x15,
		SnakeSW		=	0x16,
	}
	///The position of the head of the snake.
	///We can track the rest of the snake by tracking the directions.
	Point snakeHead;
	///Counts how much score the player has.
	int score;
	///Program and game state.
	///4: program exit
	///5: game start
	///6: game over
	///7: game won
	ubyte state;
	///Contains the current direction.
	ubyte dir;
	///Contains the previous direction.
	ubyte prevDir;
	bool fullScreen;
	///The output screen, where the output is being displayed.
	OSWindow		output;
	///Handles all the inputs. On every keypress/buttonpress, a new event is created, which changes the internal state
	///of the program.
	InputHandler	ih;
	///The raster handles frame buffer and layer priority management. Even though we currently only have a single 
	///tilelayer, we will still needing it.
	Raster			raster;
	///The TileLayer, that:
	/// * Displays the current game state
	/// * Stores playfield data (snaketail, apple's position, etc)
	TileLayer		playfield;
	///These are the tiles, we're going to use in our game
	Bitmap8Bit		empty, apple, snakeH, snakeV, snakeNE, snakeSE, snakeNW, snakeSW;
	///A random number generator
	RandomNumberGenerator rng;
	///Constructor to initialize things.
	///It is important to keep initialization and game logic separate.
	public this() {
		//Create all the tiles needed for the game.

		//Let's make empty tiles a grid!.
		empty = new Bitmap8Bit(8,8);
		for (int y ; y < 8 ; y+=2) {
			empty.writePixel(0, y, 0x1);
			empty.writePixel(7, y + 1, 0x1);
		}
		for (int x ; x < 8 ; x+=2) {
			empty.writePixel(x, 0, 0x1);
			empty.writePixel(x + 1, 7, 0x1);
		}
		//The apple uses all red color. Initialize an empty bitmap, then set all the pixels to index 2.
		apple = new Bitmap8Bit(8,8);
		for (int y ; y < 8 ; y++) {	//Use some iterations to easily set all indexes. Top-left is the origin point, and indexing starts at 0.
			for (int x ; x < 8 ; x++) {
				//NOTE: it's faster to write to the bitmap by directly accessing its data, but for this purpose, it's
				//more than enough.
				apple.writePixel(x, y, 0x2);
			}
		}
		//The snakeH is a horizontal piece, and our snake is 4 pixels thick. Let's draw it with similar method!
		snakeH = new Bitmap8Bit(8,8);
		for (int y = 2 ; y < 6 ; y++) {
			for (int x ; x < 8 ; x++) {
				snakeH.writePixel(x, y, 0x1);
			}
		}
		//The snakeV is the straight vertical piece.
		snakeV = new Bitmap8Bit(8,8);
		for (int y ; y < 8 ; y++) {
			for (int x = 2 ; x < 6 ; x++) {
				snakeV.writePixel(x, y, 0x1);
			}
		}
		//The corner pieces are more complicated, but not too hard.
		//This piece is the north-east piece, it connects the top (north) with the right (east). The rest of the corner
		//tiles use the same system, so I won't annotate their creation.
		snakeNE = new Bitmap8Bit(8,8);
		for (int y ; y < 2 ; y++) {
			for (int x = 2 ; x < 6 ; x++) {
				snakeNE.writePixel(x, y, 0x1);
			}
		}
		for (int y = 2 ; y < 6 ; y++) {
			for (int x = 2 ; x < 8 ; x++) {
				snakeNE.writePixel(x, y, 0x1);
			}
		}
		snakeSE = new Bitmap8Bit(8,8);
		for (int y = 6 ; y < 8 ; y++) {
			for (int x = 2 ; x < 6 ; x++) {
				snakeSE.writePixel(x, y, 0x1);
			}
		}
		for (int y = 2 ; y < 6 ; y++) {
			for (int x = 2 ; x < 8 ; x++) {
				snakeSE.writePixel(x, y, 0x1);
			}
		}
		snakeNW = new Bitmap8Bit(8,8);
		for (int y ; y < 2 ; y++) {
			for (int x = 2 ; x < 6 ; x++) {
				snakeNW.writePixel(x, y, 0x1);
			}
		}
		for (int y = 2 ; y < 6 ; y++) {
			for (int x ; x < 6 ; x++) {
				snakeNW.writePixel(x, y, 0x1);
			}
		}
		snakeSW = new Bitmap8Bit(8,8);
		for (int y = 6 ; y < 8 ; y++) {
			for (int x = 2 ; x < 6 ; x++) {
				snakeSW.writePixel(x, y, 0x1);
			}
		}
		for (int y = 2 ; y < 6 ; y++) {
			for (int x ; x < 6 ; x++) {
				snakeSW.writePixel(x, y, 0x1);
			}
		}

		//We now have all the necessary graphics elements, let's create the rest!
		//First, we need an output screen. It's 4:3, which isn't very modern, but will be useful for demo purposes.
		output = new OSWindow("Snek game", "ppe_snekgaem", -1, -1, 320 * 4, 240 * 4, WindowCfgFlags.IgnoreMenuKey);
		//Initialize OpenGL.
		output.getOpenGLHandle();
		//Load OpenGL.
		const glStatus = loadOpenGL();
		assert(glStatus >= GLSupport.gl11, "OpenGL not found!");
		
		//Next, we have to create the raster, with 320x240 resolution, and 256 colors. Technically we will only use 3 
		//colors, however one should overprovision the palette length to the multiple of the maximum color of the used
		//indexed bitmap. (16 bit is mainly there to directly access all colors of the palette)
		raster = new Raster(320, 240, output, 256);
		//Set up the color palette
		raster.setPaletteIndex(0, Color(0,0,0,255));
		raster.setPaletteIndex(1, Color(255,255,255,255));
		raster.setPaletteIndex(2, Color(255,0,0,255));
		//Let's create our playfield, where the action will happen.
		//The `Copy` rendering mode does not support transparency or anything fancy like that, but is very fast and
		//harder to make things go bad.
		playfield = new TileLayer(8, 8, RenderingMode.Copy);
		//Add the tile layer to the raster.
		raster.addLayer(playfield, 0);
		//Load an empty mapping into our playfield, which we will be modifying later through the `readMapping` and 
		//`writeMapping` functions.
		{
			MappingElement[] emptyMap;
			emptyMap.length = 40 * 30;
			playfield.loadMapping(40, 30, emptyMap);
		}
		//Add the tiles to the playfield
		playfield.addTile(empty, TileTypes.Empty);
		playfield.addTile(apple, TileTypes.Apple);
		playfield.addTile(snakeH, TileTypes.SnakeH);
		playfield.addTile(snakeV, TileTypes.SnakeV);
		playfield.addTile(snakeNE, TileTypes.SnakeNE);
		playfield.addTile(snakeSE, TileTypes.SnakeSE);
		playfield.addTile(snakeNW, TileTypes.SnakeNW);
		playfield.addTile(snakeSW, TileTypes.SnakeSW);
		//Initialize input handler
		ih = new InputHandler();
		ih.systemEventListener = this;
		ih.inputListener = this;
		//Register key bindings.
		ih.addBinding(BindingCode(ScanCode.UP, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("up"));
		ih.addBinding(BindingCode(ScanCode.DOWN, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("down"));
		ih.addBinding(BindingCode(ScanCode.LEFT, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("left"));
		ih.addBinding(BindingCode(ScanCode.RIGHT, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("right"));
		ih.addBinding(BindingCode(ScanCode.ENTER, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("start"));
		ih.addBinding(BindingCode(ScanCode.ESCAPE, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("quit"));
		ih.addBinding(BindingCode(ScanCode.F11, 0, Devicetype.Keyboard, 0, IGNORE_ALL), InputBinding("fullscreen"));
		ih.addBinding(BindingCode(GameControllerButtons.DPadUp, 0, Devicetype.Joystick, 0, 0), InputBinding("up"));
		ih.addBinding(BindingCode(GameControllerButtons.DPadDown, 0, Devicetype.Joystick, 0, 0), InputBinding("down"));
		ih.addBinding(BindingCode(GameControllerButtons.DPadLeft, 0, Devicetype.Joystick, 0, 0), InputBinding("left"));
		ih.addBinding(BindingCode(GameControllerButtons.DPadRight, 0, Devicetype.Joystick, 0, 0), InputBinding("right"));
		ih.addBinding(BindingCode(GameControllerButtons.RightNav, 0, Devicetype.Joystick, 0, 0), InputBinding("start"));
		//Register an initial timer event
		timer.register(&timerEvent, msecs(200));
	}
	/// Main loop cycle, where all the good things happen.
	public void whereTheMagicHappens() {
		while (state != 4) {
			if (state == 5)
				timer.test();
			ih.test();
			raster.refresh();
			rng.seed();
		}
	}
	/// Places the next apple to a random empty location.
	/// If it can no longer put any new apples anywhere, then the game have been won.
	public void placeNextApple() {
		const int x = cast(int)(rng() % 40), y = cast(int)(rng() & 30);
		for (int yi ; yi < 30 ; yi++) {
			for (int xi ; xi < 40 ; xi++) {
				if (playfield.readMapping((xi + x) % 40, (yi + y) % 30).tileID == TileTypes.Empty) {
					playfield.writeMapping((xi + x) % 40, (yi + y) % 30, MappingElement(TileTypes.Apple));
					return;
				}
			}
		}
		//If didn't escape from the loop, then it means we can place no more apples, and the player have won.
		state = 7;
	}
	///Moves the snake in the given direction.
	public void moveSnake() {
		changeDir();
		Point curr, prev = snakeHead;
		bool appleFound;
		switch (dir) {
			default:
				return;
			case Direction.North:
				snakeHead.relMove(0, -1);
				break;
			case Direction.South:
				snakeHead.relMove(0, 1);
				break;
			case Direction.East:
				snakeHead.relMove(1, 0);
				break;
			case Direction.West:
				snakeHead.relMove(-1, 0);
				break;
		}
		curr = snakeHead;
		// Check for collision
		MappingElement me = playfield.readMapping(curr.x, curr.y);
		if (me.tileID == TileTypes.Apple) {	//Player has collected an apple, let's reward them!
			score++;
			placeNextApple();
			appleFound = true;
		} else if (me.tileID != TileTypes.Empty || !Box(0, 0, 39, 29).isBetween(curr)) {	//Player has died, stop game.
			raster.setPaletteIndex(0, Color(255,0,0,255));
			state = 6;
			return;
		}
		// Draw the head to the new place
		if (dir == Direction.East || dir == Direction.West)
			playfield.writeMapping(curr.x, curr.y, MappingElement(TileTypes.SnakeH));
		else
			playfield.writeMapping(curr.x, curr.y, MappingElement(TileTypes.SnakeV));
		// Move the snake.
		// This iteration finds the endpiece of the snake, by using the shape identifier codes.
		for (int i ; i <= score ; i++) {
			//MappingElement currT = playfield.readMapping(curr.x, curr.y);
			MappingElement prevT = playfield.readMapping(prev.x, prev.y);
			switch (prevT.tileID) {
				case TileTypes.SnakeH:
					const int cX = curr.x, pX = prev.x;
					curr.x = prev.x;
					if (pX < cX)
						prev.x -= 1;
					else
						prev.x += 1;
					break;
				case TileTypes.SnakeV:
					const int cY = curr.y, pY = prev.y;
					curr.y = prev.y;
					if (pY < cY)
						prev.y -= 1;
					else
						prev.y += 1;
					break;
				case TileTypes.SnakeNE:
					const int cX = curr.x, pX = prev.x;
					curr = prev;
					if (cX == pX)
						prev.x += 1;
					else
						prev.y -= 1;
					break;
				case TileTypes.SnakeSE:
					const int cX = curr.x, pX = prev.x;
					curr = prev;
					if (cX == pX)
						prev.x += 1;
					else
						prev.y += 1;
					break;
				case TileTypes.SnakeNW:
					const int cX = curr.x, pX = prev.x;
					curr = prev;
					if (cX == pX)
						prev.x -= 1;
					else
						prev.y -= 1;
					break;
				case TileTypes.SnakeSW:
					const int cX = curr.x, pX = prev.x;
					curr = prev;
					if (cX == pX)
						prev.x -= 1;
					else
						prev.y += 1;
					break;
				default:
					break;
			}
		}
		
		// Remove end if growth doesn't happen.
		if (!appleFound) 
			playfield.writeMapping(curr.x, curr.y, MappingElement(TileTypes.Empty));
	}
	/// Since tilemaps get initialized with 0xFFFF (none) tiles, we need to set it to 0x0000
	public void clearTilemap() {
		for (int y ; y < 30 ; y++) {
			for (int x ; x < 40 ; x++) {
				playfield.writeMapping(x,y, MappingElement(TileTypes.Empty));
			}
		}
	}
	/// A timer event, to make the game run stable regardless of the framerate.
	public void timerEvent(Duration jitter) {
		//Reregister timer event
		timer.register(&timerEvent, msecs(200));
		//Move snake if needed
		if (dir) {
			moveSnake();
		}
	}
	/// Changes the direction if a key was pressed
	public void changeDir() {
		if (dir != prevDir) {
			switch (dir) {
				case Direction.North:
					switch (prevDir) {
						case Direction.East:
							playfield.writeMapping(snakeHead.x, snakeHead.y, MappingElement(TileTypes.SnakeNW));
							break;
						case Direction.West:
							playfield.writeMapping(snakeHead.x, snakeHead.y, MappingElement(TileTypes.SnakeNE));
							break;
						default: break;
					}
					break;
				case Direction.South:
					switch (prevDir) {
						case Direction.East:
							playfield.writeMapping(snakeHead.x, snakeHead.y, MappingElement(TileTypes.SnakeSW));
							break;
						case Direction.West:
							playfield.writeMapping(snakeHead.x, snakeHead.y, MappingElement(TileTypes.SnakeSE));
							break;
						default: break;
					}
					break;
				case Direction.West:
					switch (prevDir) {
						case Direction.North:
							playfield.writeMapping(snakeHead.x, snakeHead.y, MappingElement(TileTypes.SnakeSW));
							break;
						case Direction.South:
							playfield.writeMapping(snakeHead.x, snakeHead.y, MappingElement(TileTypes.SnakeNW));
							break;
						default: break;
					}
					break;
				case Direction.East:
					switch (prevDir) {
						case Direction.North:
							playfield.writeMapping(snakeHead.x, snakeHead.y, MappingElement(TileTypes.SnakeSE));
							break;
						case Direction.South:
							playfield.writeMapping(snakeHead.x, snakeHead.y, MappingElement(TileTypes.SnakeNE));
							break;
						default: break;
					}
					break;
				default: break;
			}
			prevDir = dir;
		}
	}
	/// Key event data is received here.
	public void keyEvent(uint id, BindingCode code, Timestamp timestamp, bool isPressed) {
		switch (id) {
		case hashCalc("up"):
			if (prevDir != Direction.South) {
				dir = Direction.North;
			}
			if (!prevDir) {
				playfield.writeMapping(snakeHead.x, snakeHead.y, MappingElement(TileTypes.SnakeV));
			}
			break;
		case hashCalc("down"):
			if (prevDir != Direction.North) {
				dir = Direction.South;
			}
			if (!prevDir) {
				playfield.writeMapping(snakeHead.x, snakeHead.y, MappingElement(TileTypes.SnakeV));
			}
			break;
		case hashCalc("left"):
			if (prevDir != Direction.East) {
				dir = Direction.West;
			}
			break;
		case hashCalc("right"):
			if (prevDir != Direction.West) {
				dir = Direction.East;
			}
			break;
		case hashCalc("start"):
			raster.setPaletteIndex(0, Color(0,0,0,255));
			clearTilemap();
			state = 5;
			snakeHead = Point(20, 15);
			score = 0;
			dir = 0;
			prevDir = 0;
			placeNextApple();
			playfield.writeMapping(snakeHead.x, snakeHead.y, MappingElement(TileTypes.SnakeH));
			break;
		case hashCalc("quit"):
			state = 4;
			break;
		case hashCalc("fullscreen"):
			if (isPressed) {
				fullScreen = !fullScreen;
				output.setScreenMode(-1, fullScreen ? DisplayMode.FullscreenDesktop : DisplayMode.Windowed);
			}
			break;
		default: break;
		}
	}

	public void axisEvent(uint id, BindingCode code, Timestamp timestamp, float value) {
		
	}
	/// Makes it possible to close the game the `proper` way.
	public void onQuit() {
		state = 4;
	}

	public void inputDeviceAdded(InputDevice id) {

	}
	public void inputDeviceRemoved(InputDevice id) {

	}
	/** 
	 * Called if a window was resized.
	 * Params:
	 *   window = Handle to the OSWindow class.
	 */
	public void windowResize(OSWindow window, int width, int height) {
		immutable double origAspectRatio = 320.0 / 240.0;//Calculate original aspect ratio
		double newAspectRatio = cast(double)width / cast(double)height;//Calculate new aspect ratio
		if (newAspectRatio > origAspectRatio) {		//Display area is now wider, padding needs to be added on the sides
			const double visibleWidth = height * origAspectRatio;
			const double sideOffset = (width - visibleWidth) / 2.0;
			glViewport(cast(int)sideOffset, 0, cast(int)visibleWidth, height);
		} else {	//Display area is now taller, padding needs to be added on the top and bottom
			const double visibleHeight = width / origAspectRatio;
			const double topOffset = (height - visibleHeight) / 2.0;
			glViewport(0, cast(int)topOffset, width, cast(int)visibleHeight);
		}
	}
}
