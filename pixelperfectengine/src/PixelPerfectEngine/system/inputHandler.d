module PixelPerfectEngine.system.inputHandler;
/*
 * Copyright (C) 2015-2019, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, input module
 */

import std.stdio;
import std.conv;
import std.algorithm.searching;
import bindbc.sdl;
/**
 * Basic Force Feedback implementation.
 */
public class ForceFeedbackHandler{
	public SDL_Haptic*[] haptic;
	private InputHandler src;

	public this(InputHandler src){
		SDL_InitSubSystem(SDL_INIT_HAPTIC);
		this.src = src;
		foreach(SDL_Joystick* p; src.joysticks){

			if(p !is null){
				haptic ~= SDL_HapticOpenFromJoystick(p);
				//;

				if(SDL_HapticRumbleSupported(haptic[haptic.length-1]) == SDL_TRUE){
					SDL_HapticRumbleInit(haptic[haptic.length-1]);
				}
			}
		}
	}
	public void reinitalize(){
		foreach(SDL_Joystick* p; src.joysticks){
			haptic.length = 0;
			if(p !is null){
				haptic ~= SDL_HapticOpenFromJoystick(p);
				//;

				if(SDL_HapticRumbleSupported(haptic[haptic.length-1]) == SDL_TRUE){
					SDL_HapticRumbleInit(haptic[haptic.length-1]);
				}
			}
		}
	}

	public void addEffect(int deviceID, SDL_HapticEffect* type){
		SDL_HapticNewEffect(haptic[deviceID], type);
	}
	public void runEffect(int deviceID, int num, uint type){
		SDL_HapticRunEffect(haptic[deviceID], num, type);
	}
	public void updateEffect(int deviceID, int num, SDL_HapticEffect* type){
		SDL_HapticUpdateEffect(haptic[deviceID], num, type);
	}
	public void stopEffect(int deviceID, int num){
		SDL_HapticStopEffect(haptic[deviceID], num);
	}

	public void runRumbleEffect(int deviceID, float strenght, uint duration){
		SDL_HapticRumblePlay(haptic[deviceID], strenght, duration);
	}
	public void stopRumbleEffect(int deviceID){
		SDL_HapticRumbleStop(haptic[deviceID]);
	}
}
/**
 * Handles the events for the various input devices.
 */
public class InputHandler : TextInputHandler{
	public AxisListener[] al;
	public InputListener[] il;
	public MouseListener[] ml;
	public TextInputListener[] tl;
	public SystemEventListener[] sel;
	private TextInputListener tiSelect;
	private bool tiEnable, enableBindingCapture, delOldOnEvent, delConflKeys, exitOnSysKeys;
	//private string name;
	public KeyBinding[] kb;
	private string hatpos, proposedID;
	private int mouseX, mouseY;
	public SDL_Joystick*[] joysticks;
	public string[] joyNames;
	public int[] joyButtons, joyAxes, joyHats;
	///Upon construction, it detects the connected joysticks.
	public this(){
		SDL_InitSubSystem(SDL_INIT_JOYSTICK);
		int j = SDL_NumJoysticks();
		for(int i ; i < j ; i++){
			joysticks ~= SDL_JoystickOpen(i);
			if(joysticks[i] !is null){
				joyNames ~= to!string(SDL_JoystickName(joysticks[i]));
				joyButtons ~= SDL_JoystickNumButtons(joysticks[i]);
				joyAxes ~= SDL_JoystickNumAxes(joysticks[i]);
				joyHats ~= SDL_JoystickNumHats(joysticks[i]);
				/*writeln("Buttons: ", SDL_JoystickNumButtons(joysticks[i]));
				 writeln("Axes: ", SDL_JoystickNumAxes(joysticks[i]));
				 writeln("Hats: ", SDL_JoystickNumHats(joysticks[i]));*/
			}
		}
	}

	~this(){
		foreach(SDL_Joystick* p; joysticks)
			SDL_JoystickClose(p);
	}
	/**
	 * Captures a key for binding
	 */
	public void captureEvent(string proposedID, bool delOldOnEvent, bool delConflKeys, bool exitOnSysKeys){
		this.proposedID = proposedID;
		enableBindingCapture = true;
		this.delOldOnEvent = delOldOnEvent;
		this.delConflKeys = delConflKeys;
		this.exitOnSysKeys = exitOnSysKeys;
	}
	/**
	 * Polls for events. If there's any, calls the eventlisteners.
	 */
	public void test(){
		SDL_Event event;
		while(SDL_PollEvent(&event)){
			//writeln(event.type);
			if(enableBindingCapture){

				KeyBinding kb0;
				if(event.type == SDL_KEYDOWN){
					kb0 = KeyBinding(event.key.keysym.mod, event.key.keysym.scancode, 0, proposedID, Devicetype.KEYBOARD);
					enableBindingCapture = false;
				}else if(event.type == SDL_JOYBUTTONDOWN){

					kb0 = KeyBinding(0, event.jbutton.button, event.jbutton.which, proposedID, Devicetype.JOYSTICK);
					enableBindingCapture = false;
				}else if(event.type == SDL_JOYHATMOTION){
					kb0 = KeyBinding(4, event.jhat.hat, event.jhat.which, proposedID, Devicetype.JOYSTICK);
					enableBindingCapture = false;
				}else if(event.type == SDL_JOYAXISMOTION){

					if((event.jaxis.value > 4096 || event.jaxis.value <-4096)){
						kb0 = KeyBinding(8, event.jaxis.axis, event.jaxis.which, proposedID, Devicetype.JOYSTICK);
						enableBindingCapture = false;
					}
				}
				if(!enableBindingCapture){
					if(exitOnSysKeys){
						foreach(KeyBinding kb1; kb){
							if(kb1.conflKey(kb0) && kb1.ID[0..3] == "sys"){
								return;

							}
						}

					}
					int[] removelist;
					if(delOldOnEvent){
						for(int i; i < kb.length; i++){
							if(kb[i].ID == kb0.ID){
								removelist ~= i;
							}
						}
					}
					if(delConflKeys){
						for(int i; i < kb.length; i++){
							if(kb[i].conflKey(kb0)){
								removelist ~= i;
							}
						}
					}

					if(delOldOnEvent && delConflKeys){
						KeyBinding[] kb1;
						for(int i; i < kb.length; i++){
							if(count(removelist, i) == 0){
								kb1 ~= kb[i];
							}
						}
						kb = kb1;
					}
					kb ~= kb0;
				}
			}
			switch(event.type){
				case SDL_KEYDOWN:
					ushort km = keyModConv(event.key.keysym.mod);
					if(!tiEnable){
						foreach(k; kb){
							if(event.key.keysym.scancode == k.scancode && ((km | k.keymodIgnore) == 
									(k.keymod | k.keymodIgnore)) && k.devicetype == Devicetype.KEYBOARD){
								invokeKeyPressed(k.ID, event.key.timestamp, 0, Devicetype.KEYBOARD);
							}
						}
					}else{
						switch(event.key.keysym.scancode){
							case SDL_SCANCODE_RETURN, SDL_SCANCODE_RETURN2, SDL_SCANCODE_KP_ENTER:
								tiSelect.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.ENTER);
								break;
							case SDL_SCANCODE_ESCAPE:
								tiSelect.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.ESCAPE);
								break;
							case SDL_SCANCODE_BACKSPACE:
								tiSelect.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.BACKSPACE);
								break;
							case SDL_SCANCODE_UP:
								tiSelect.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.CURSORUP);
								break;
							case SDL_SCANCODE_DOWN:
								tiSelect.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.CURSORDOWN);
								break;
							case SDL_SCANCODE_LEFT:
								tiSelect.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.CURSORLEFT);
								break;
							case SDL_SCANCODE_RIGHT:
								tiSelect.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.CURSORRIGHT);
								break;
							case SDL_SCANCODE_INSERT:
								tiSelect.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.INSERT);
								break;
							case SDL_SCANCODE_DELETE:
								tiSelect.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.DELETE);
								break;
							case SDL_SCANCODE_HOME:
								tiSelect.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.HOME);
								break;
							case SDL_SCANCODE_END:
								tiSelect.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.END);
								break;
							case SDL_SCANCODE_PAGEUP:
								tiSelect.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.PAGEUP);
								break;
							case SDL_SCANCODE_PAGEDOWN:
								tiSelect.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.PAGEDOWN);
								break;
							default: break;
						}
					}
					break;
				case SDL_KEYUP:
					if(!tiEnable){
						foreach(k; kb ){
							if(event.key.keysym.scancode == k.scancode && ((event.key.keysym.mod | k.keymodIgnore) == (k.keymod | k.keymodIgnore)) && k.devicetype == Devicetype.KEYBOARD){
								invokeKeyReleased(k.ID, event.key.timestamp, 0, Devicetype.KEYBOARD);
							}
						}
					}
					break;
				case SDL_TEXTINPUT:
					if(tiEnable){
						import std.utf : toUTF32;
						import std.string : fromStringz;
						dstring eventText = toUTF32(fromStringz(event.text.text.ptr));
						tiSelect.textInputEvent(event.text.timestamp, event.text.windowID, eventText);
					}
					break;
				case SDL_JOYBUTTONDOWN:
					foreach(k; kb){
						if(event.jbutton.button == k.scancode && 0 == k.keymod && k.devicetype == Devicetype.JOYSTICK && k.devicenumber == event.jbutton.which){
							invokeKeyPressed(k.ID, event.jbutton.timestamp, event.jbutton.which, Devicetype.JOYSTICK);
						}
					}
					break;
				case SDL_JOYBUTTONUP:
					foreach(k; kb){
						if(event.jbutton.button == k.scancode && 0 == k.keymod && k.devicetype == Devicetype.JOYSTICK && k.devicenumber == event.jbutton.which){
							invokeKeyReleased(k.ID, event.jbutton.timestamp, event.jbutton.which, Devicetype.JOYSTICK);
						}
					}
					break;
				case SDL_JOYHATMOTION:
					foreach(k; kb){
						if(event.jhat.alignof == k.scancode && 4 == k.keymod && k.devicetype == Devicetype.JOYSTICK && k.devicenumber == event.jhat.which){
							invokeKeyReleased(hatpos, event.jhat.timestamp, event.jhat.which, Devicetype.JOYSTICK);
							invokeKeyPressed(k.ID, event.jhat.timestamp, event.jhat.which, Devicetype.JOYSTICK);
							hatpos = k.ID;
						}
					}
					break;
				case SDL_JOYAXISMOTION:
					foreach(k; kb){
						if(event.jaxis.axis == k.scancode && 8 == k.keymod && k.devicetype == Devicetype.JOYSTICK && k.devicenumber == event.jaxis.which){
							invokeAxisEvent(k.ID, event.jaxis.timestamp, event.jaxis.value, event.jaxis.which, Devicetype.JOYSTICK);
						}
					}
					break;
				case SDL_MOUSEBUTTONDOWN:
					invokeMouseEvent(event.button.which, event.button.timestamp, event.button.windowID, event.button.button, event.button.state, event.button.clicks, event.button.x, event.button.y);
					break;
				case SDL_MOUSEBUTTONUP:
					invokeMouseEvent(event.button.which, event.button.timestamp, event.button.windowID, event.button.button, event.button.state, event.button.clicks, event.button.x, event.button.y);
					break;
				case SDL_MOUSEMOTION:
					invokeMouseMotionEvent(event.motion.timestamp, event.motion.windowID, event.motion.which, event.motion.state, event.motion.x, event.motion.y, event.motion.xrel, event.motion.yrel);
					mouseX = event.motion.x;
					mouseY = event.motion.y;
					break;
				case SDL_MOUSEWHEEL:
					invokeMouseWheelEvent(event.wheel.type, event.wheel.timestamp, event.wheel.windowID, event.wheel.which, event.wheel.x, event.wheel.y);
					break;
				case SDL_QUIT:
					invokeQuitEvent();
					break;
				case SDL_JOYDEVICEADDED:
					int i = event.jdevice.which;
					joysticks ~= SDL_JoystickOpen(i);
					if(joysticks[i] !is null){
						joyNames ~= to!string(SDL_JoystickName(joysticks[i]));
						joyButtons ~= SDL_JoystickNumButtons(joysticks[i]);
						joyAxes ~= SDL_JoystickNumAxes(joysticks[i]);
						joyHats ~= SDL_JoystickNumHats(joysticks[i]);
						/*writeln("Buttons: ", SDL_JoystickNumButtons(joysticks[i]));
				 writeln("Axes: ", SDL_JoystickNumAxes(joysticks[i]));
				 writeln("Hats: ", SDL_JoystickNumHats(joysticks[i]));*/
					}
					invokeControllerAddedEvent(i);
					break;
				case SDL_JOYDEVICEREMOVED:
					SDL_JoystickClose(joysticks[event.jdevice.which]);
					invokeControllerRemovedEvent(event.jdevice.which);
					break;
				default: break;
			}

		}

	}

	private void invokeKeyPressed(string ID, uint timestamp, uint devicenumber, uint devicetype){
		foreach(i; il){
			if(i)
				i.keyPressed(ID, timestamp, devicenumber, devicetype);
		}
	}
	private void invokeKeyReleased(string ID, uint timestamp, uint devicenumber, uint devicetype){
		foreach(i; il){
			if(i)
				i.keyReleased(ID, timestamp, devicenumber, devicetype);
		}
	}
	private void invokeMouseEvent(uint which, uint timestamp, uint windowID, ubyte button, ubyte state, ubyte clicks, int x, int y){
		foreach(MouseListener m; ml){
			if(m)
				m.mouseButtonEvent(which, timestamp, windowID, button, state, clicks, x, y);
		}
	}
	private void invokeMouseWheelEvent(uint type, uint timestamp, uint windowID, uint which, int x, int y){
		foreach(MouseListener m; ml){
			if(m)
				m.mouseWheelEvent(type, timestamp, windowID, which, x, y, mouseX, mouseY);
		}
	}
	private void invokeMouseMotionEvent(uint timestamp, uint windowID, uint which, uint state, int x, int y, int relX, int relY){
		foreach(MouseListener m; ml){
			if(m)
				m.mouseMotionEvent(timestamp, windowID, which, state, x, y, relX, relY);
		}
	}
	private void invokeAxisEvent(string ID, uint timestamp, short val, uint devicenumber, uint devicetype){
		foreach(a; al){
			if(a)
				a.axisEvent(ID, timestamp, val, devicenumber, devicetype);
		}
	}
	private void invokeQuitEvent(){
		foreach(SystemEventListener q; sel){
			q.onQuit();
		}
	}
	private void invokeControllerRemovedEvent(uint ID){
		foreach(SystemEventListener q; sel){
			q.controllerRemoved(ID);
		}
	}
	private void invokeControllerAddedEvent(uint ID){
		foreach(SystemEventListener q; sel){
			q.controllerAdded(ID);
		}
	}
	///Sets wether to use the newer XInput over the older DirectInput.
	public static setXInput(bool state){
		if(state){
			SDL_SetHint(SDL_HINT_XINPUT_ENABLED, "1");
		}else{
			SDL_SetHint(SDL_HINT_XINPUT_ENABLED, "0");
		}
	}
	///Starts the TextInputEvent and disables the polling of normal input events.
	public void startTextInput(TextInputListener tl){
		if(tiSelect !is null){
			tiSelect.dropTextInput();
		}
		SDL_StartTextInput();
		tiEnable = true;

		tiSelect = tl;
	}
	///Stops the TextInputEvent and enables the polling of normal input events.
	public void stopTextInput(TextInputListener tl){
		SDL_StopTextInput();
		tl.dropTextInput();
		tiEnable = false;
		tiSelect = null;
	}
}


/**
 * Defines a keybinding.
 */
public struct KeyBinding{
	public uint scancode;		///The code of the phisical key relative to the US English keyboard.
	public uint  devicenumber;	///The identificator of the device.
	public uint devicetype;		///The type of the device.
	public ushort keymod, keymodIgnore;		///Keymod sets the modifierkeys required to activate the event, keymodIgnore sets the keys that are ignored during event polling.
	public string ID;		///ID of the event
	this(ushort keymod, uint scancode, uint devicenumber, string ID, uint devicetype, ushort keymodIgnore = KeyModifier.All){
		this.keymod = keymod;
		this.scancode = scancode;
		this.devicenumber = devicenumber;
		this.ID = ID;
		this.devicetype = devicetype;
		this.keymodIgnore = keymodIgnore;
	}
	///Returns if there's a conflicting key.
	public bool conflKey(KeyBinding a){
		if(a.scancode == this.scancode && a.keymod == this.keymod && a.devicenumber == this.devicenumber && a.devicetype == this.devicetype){
			return true;
		}
		return false;
	}
	///Returns true if the two KeyBindings have the same ID
	public bool conflID(KeyBinding a){
		if(a.ID == this.ID){
			return true;
		}
		return false;
	}
	///Returns true it the two KeyBindings are equal.
	public bool opEquals(const KeyBinding s){
		if(s.scancode == this.scancode && s.keymod == this.keymod && s.devicenumber == this.devicenumber && s.devicetype == this.devicetype && s.ID == this.ID){
			return true;
		}
		return false;
	}
	///Returns a standard string representation of the keybinding.
	public string toString(){
		string s;
		s ~= "ID: ";
		s ~= ID;
		s ~= " Keycode: ";
		s ~= to!string(scancode);
		s ~= " Keymod: ";
		s ~= to!string(keymod);
		s ~= " KeymodIgnore:";
		s ~= to!string(keymodIgnore);
		s ~= " Devicetype: ";
		s ~= to!string(devicetype);
		s ~= " Devicenumber: ";
		s ~= to!string(devicenumber);
		return s;
	}
}

public interface InputListener{
	public void keyPressed(string ID, uint timestamp, uint devicenumber, uint devicetype);
	public void keyReleased(string ID, uint timestamp, uint devicenumber, uint devicetype);
}

public interface AxisListener{
	public void axisEvent(string ID, uint timestamp, short val, uint devicenumber, uint devicetype);
}

public interface MovementListener{
	public void movementEvent(string ID, short x, short y, short relX, short relY, uint devicenumber, uint devicetype);
}

public interface MouseListener{
	public void mouseButtonEvent(uint which, uint timestamp, uint windowID, ubyte button, ubyte state, ubyte clicks, int x, int y);
	public void mouseWheelEvent(uint type, uint timestamp, uint windowID, uint which, int x, int y, int wX, int wY);
	public void mouseMotionEvent(uint timestamp, uint windowID, uint which, uint state, int x, int y, int relX, int relY);
}

public interface TextInputListener{
	public void textInputEvent(uint timestamp, uint windowID, dstring text);
	public void textInputKeyEvent(uint timestamp, uint windowID, TextInputKey key, ushort modifier = 0);
	//public void textInputBegin();
	public void dropTextInput();
}

public interface TextInputHandler{
	public void startTextInput(TextInputListener tl);
	public void stopTextInput(TextInputListener tl);
	//public void addTextInputListener(TextInputListener tl); DEPRECATED!
	//public void removeTextInputListener(TextInputListener tl); DEPRECATED!
}

public interface SystemEventListener{
	public void onQuit();
	public void controllerRemoved(uint ID);
	public void controllerAdded(uint ID);
}

public enum Devicetype{
	KEYBOARD	= 0,
	JOYSTICK	= 1,
	MOUSE		= 2,
	TOUCHSCREEN	= 3
}

public enum TextInputKey{
	ENTER		= 1,
	ESCAPE		= 2,
	BACKSPACE	= 3,
	CURSORUP	= 4,
	CURSORDOWN	= 5,
	CURSORLEFT	= 6,
	CURSORRIGHT	= 7,
	INSERT		= 8,
	DELETE		= 9,
	HOME		= 10,
	END			= 11,
	PAGEUP		= 12,
	PAGEDOWN	= 13
}

public enum TextInputType : uint{
	NULL		= 0,
	TEXT		= 1,
	DECIMAL		= 2,
	DISABLE		= 65536, ///For use in listboxes
}

/// Key modifiers used by the SDL backend
/+public enum BackendKeyModifier : ushort{
	NONE 		= 0x0000,	//0b0000_0000_0000_0000
	LSHIFT 		= 0x0001,	//0b0000_0000_0000_0001
	RSHIFT 		= 0x0002,	//0b0000_0000_0000_0010
	SHIFT 		= 0x0003,	//0b0000_0000_0000_0011
	LCTRL 		= 0x0040,	//0b0000_0000_0100_0000
	RCTRL	 	= 0x0080,	//0b0000_0000_1000_0000
	CTRL 		= 0x00C0,	//0b0000_0000_1100_0000
	LALT 		= 0x0100,	//0b0000_0001_0000_0000
	RALT 		= 0x0200,	//0b0000_0010_0000_0000
	ALT 		= 0x0300,	//0b0000_0011_0000_0000
	LGUI 		= 0x0400,	//0b0000_0100_0000_0000
	RGUI	 	= 0x0800,	//0b0000_1000_0000_0000
	GUI 		= 0x0C00,	//0b0000_1100_0000_0000
	NUM 		= 0x1000,	//0b0001_0000_0000_0000
	CAPS 		= 0x2000,	//0b0010_0000_0000_0000
	LOCKKEYIGNORE	= NUM + CAPS,		///Use this if only Caps lock and Num lock needs to be ignored
	MODE 		= 0x4000,	//0b0100_0000_0000_0000
	RESERVED 	= 0x8000,	//0b1000_0000_0000_0000
	ANY			= 0xFFFF
}+/
/// Key modifiers used by the engine
public enum KeyModifier : ushort {
	None		= 0x0000,
	Shift		= 0x0001,
	Ctrl		= 0x0002,
	Alt			= 0x0004,
	GUI			= 0x0008,
	NumLock		= 0x0010,
	CapsLock	= 0x0020,
	ScrollLock	= 0x0040,
	LockKeys	= NumLock | CapsLock | ScrollLock,
	Mode		= 0x0100,
	All			= 0xFFFF,
}
/**
 * Converts key modifier codes from SDL to the engine's own
 */
public ushort keyModConv(ushort input) @nogc pure nothrow @safe {
	ushort result;
	if (input & KMOD_SHIFT) result |= KeyModifier.Shift;
	if (input & KMOD_CTRL) result |= KeyModifier.Ctrl;
	if (input & KMOD_ALT) result |= KeyModifier.Alt;
	if (input & KMOD_GUI) result |= KeyModifier.GUI;
	if (input & KMOD_NUM) result |= KeyModifier.NumLock;
	if (input & KMOD_CAPS) result |= KeyModifier.CapsLock;
	if (input & KMOD_MODE) result |= KeyModifier.Mode;
	//debug writeln(input,';',result);
	return result;
}
public enum JoyModifier : ushort{
	BUTTONS		= 0x0000,
	DPAD		= 0x0004,
	AXIS		= 0x0008
}
public enum MouseButton : ubyte{
	LEFT		= 1,
	MID			= 2,
	RIGHT		= 3,
	NEXT		= 4,
	PREVIOUS	= 5
}
public enum ButtonState : ubyte{
	RELEASED	= 0,
	PRESSED		= 1
}
public enum ScanCode : uint{
	A				=	4,
	B				=	5,
	C				=	6,
	D				=	7,
	E				=	8,
	F				=	9,
	G				=	10,
	H				=	11,
	I				=	12,
	J				=	13,
	K				=	14,
	L				=	15,
	M				=	16,
	N				=	17,
	O				=	18,
	P				=	19,
	Q				=	20,
	R				=	21,
	S				=	22,
	T				=	23,
	U				=	24,
	V				=	25,
	W				=	26,
	X				=	27,
	Y				=	28,
	Z				=	29,

	n1				=	30,
	n2				=	31,
	n3				=	32,
	n4				=	33,
	n5				=	34,
	n6				=	35,
	n7				=	36,
	n8				=	37,
	n9				=	38,
	n0				=	39,

	ENTER			=	40,
	ESCAPE			=	41,
	BACKSPACE		=	42,
	TAB				=	43,
	SPACE			=	44,

	MINUS			=	45,
	EQUALS			=	46,
	LEFTBRACKET		=	47,
	RIGHTBRACKET	=	48,
	BACKSLASH		=	49,
	NONUSLASH		=	50,
	SEMICOLON		=	51,
	APOSTROPHE		=	52,
	GRAVE			=	53,
	COMMA			=	54,
	PERIOD			=	55,
	SLASH			=	56,
	CAPSLOCK		=	57,

	F1				=	58,
	F2				=	59,
	F3				=	60,
	F4				=	61,
	F5				=	62,
	F6				=	63,
	F7				=	64,
	F8				=	65,
	F9				=	66,
	F10				=	67,
	F11				=	68,
	F12				=	69,

	PRINTSCREEN		=	70,
	SCROLLLOCK		=	71,
	PAUSE			=	72,
	INSERT			=	73,
	HOME			=	74,
	PAGEUP			=	75,
	DELETE			=	76,
	END				=	77,
	PAGEDOWN		=	78,
	RIGHT			=	79,
	LEFT			=	80,
	DOWN			=	81,
	UP				=	82,

	NUMLOCK			=	83,
	NP_DIVIDE		=	84,
	NP_MULTIPLY		=	85,
	NP_MINUS		=	86,
	NP_PLUS			=	87,
	NP_ENTER		=	88,

	np1				=	89,
	np2				=	90,
	np3				=	91,
	np4				=	92,
	np5				=	93,
	np6				=	94,
	np7				=	95,
	np8				=	96,
	np9				=	97,
	np0				=	98,

	NP_PERIOD		=	99,

	NONUSBACKSLASH	=	100,
	APPLICATION		=	101,

	NP_EQUALS		=	102,

	F13				=	104,
	F14				=	105,
	F15				=	106,
	F16				=	107,
	F17				=	108,
	F18				=	109,
	F19				=	110,
	F20				=	111,
	F21				=	112,
	F22				=	113,
	F23				=	114,
	F24				=	115,

	EXECUTE			=	116,
	HELP			=	117,
	MENU			=	118,
	SELECT			=	119,
	STOP			=	120,
	REDO			=	121,
	UNDO			=	122,
	CUT				=	123,
	COPY			=	124,
	PASTE			=	125,
	FIND			=	126,
	MUTE			=	127,
	VOLUME_UP		=	128,
	VOLUME_DOWN		=	129,

	NP_COMMA		=	133,
	NP_EQUALSAS400	=	134,

	INTERNATIONAL1	=	135,
	INTERNATIONAL2	=	136,
	INTERNATIONAL3	=	137,
	INTERNATIONAL4	=	138,
	INTERNATIONAL5	=	139,
	INTERNATIONAL6	=	140,
	INTERNATIONAL7	=	141,
	INTERNATIONAL8	=	142,
	INTERNATIONAL9	=	143,

	LANGUAGE1		=	144,
	LANGUAGE2		=	145,
	LANGUAGE3		=	146,
	LANGUAGE4		=	147,
	LANGUAGE5		=	148,
	LANGUAGE6		=	149,
	LANGUAGE7		=	150,
	LANGUAGE8		=	151,
	LANGUAGE9		=	152,

	ALTERASE		=	153,
	SYSREQ			=	154,
	CANCEL			=	155,
	PRIOR			=	157,
	ENTER2			=	158,
	SEPARATOR		=	159,
	OUT				=	160,
	OPERATE			=	161,
	CLEARAGAIN		=	162,
	CRSEL			=	163,
	EXSEL			=	164,

	NP00			=	176,
	NP000			=	177,
	THROUSANDSEPAR	=	178,
	HUNDREDSSEPAR	=	179,
	CURRENCYUNIT	=	180,
	CURRENCYSUBUNIT	=	181,
	NP_LEFTPAREN	=	182,
	NP_RIGHTPAREN	=	183,
	NP_LEFTBRACE	=	184,
	NP_RIGHTBRACE	=	185,
	NP_TAB			=	186,
	NP_BACKSPACE	=	187,
	NP_A			=	188,
	NP_B			=	189,
	NP_C			=	190,
	NP_D			=	191,
	NP_E			=	192,
	NP_F			=	193,
	NP_XOR			=	194,
	NP_POWER		=	195,
	NP_PERCENT		=	196,
	NP_LESS			=	197,
	NP_GREATER		=	198,
	NP_AMPERSAND	=	199,
	NP_DBAMPERSAND	=	200,
	NP_VERTICALBAR	=	201,
	NP_DBVERTICALBAR=	202,
	NP_COLON		=	203,
	NP_HASH			=	204,
	NP_SPACE		=	205,
	NP_AT			=	206,
	NP_EXCLAM		=	207,
	NP_MEMSTORE		=	208,
	NP_MEMRECALL	=	209,
	NP_MEMCLEAR		=	210,
	NP_MEMADD		=	211,
	NP_MEMSUBSTRACT	=	212,
	NP_MEMMULTIPLY	=	213,
	NP_MEMDIVIDE	=	214,
	NP_PLUSMINUS	=	215,
	NP_CLEAR		=	216,
	NP_CLEARENTRY	=	217,
	NP_BINARY		=	218,
	NP_OCTAL		=	219,
	NP_DECIMAL		=	220,
	NP_HEXADECIMAL	=	221,

	LCTRL			=	224,
	LSHIFT			=	225,
	LALT			=	226,
	LGUI			=	227,
	RCTRL			=	228,
	RSHIFT			=	229,
	RALT			=	230,
	RGUI			=	231,

	AUDIONEXT		=	258,
	AUDIOPREV		=	259,
	AUDIOSTOP		=	260,
	AUDIOPLAY		=	261,
	AUDIOMUTE		=	262,
	MEDIASELECT		=	263,
	WWW				=	264,
	MAIL			=	265,
	CALCULATOR		=	266,
	COMPUTER		=	267,
}
