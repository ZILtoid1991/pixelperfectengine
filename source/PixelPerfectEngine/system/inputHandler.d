module PixelPerfectEngine.system.inputHandler;
/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, input module
 */

import std.stdio;
import std.conv;
import std.algorithm.searching;
public import derelict.sdl2.sdl;

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

public class InputHandler : TextInputHandler{
	public AxisListener[] al;
	public InputListener[] il;
	public MouseListener[] ml;
	public TextInputListener[string] tl;
	public SystemEventListener[] sel;
	private string tiSelect;
	private bool tiEnable, enableBindingCapture, delOldOnEvent, delConflKeys, exitOnSysKeys;
	//private string name;
	public KeyBinding[] kb;
	private string hatpos, proposedID;
	private int mouseX, mouseY;
	public SDL_Joystick*[] joysticks;
	public string[] joyNames;
	public int[] joyButtons, joyAxes, joyHats;
	
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
	
	/*~this(){
	 foreach(SDL_Joystick* p; joysticks)
	 SDL_JoystickClose(p);
	 }*/
	/*
	 * Captures a key for binding
	 */
	public void captureEvent(string proposedID, bool delOldOnEvent, bool delConflKeys, bool exitOnSysKeys){
		this.proposedID = proposedID;
		enableBindingCapture = true;
		this.delOldOnEvent = delOldOnEvent;
		this.delConflKeys = delConflKeys;
		this.exitOnSysKeys = exitOnSysKeys;
	}
	
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

					if(!tiEnable){
						foreach(k; kb){
							if(event.key.keysym.scancode == k.scancode && ((event.key.keysym.mod | k.keymodIgnore) == (k.keymod | k.keymodIgnore)) && k.devicetype == Devicetype.KEYBOARD){

								invokeKeyPressed(k.ID, event.key.timestamp, 0, Devicetype.KEYBOARD);
							}
						}
					}
					else{
						switch(event.key.keysym.scancode){
							case SDL_SCANCODE_RETURN: tl[tiSelect].textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.ENTER); break;
							case SDL_SCANCODE_ESCAPE: tl[tiSelect].textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.ESCAPE); break;
							case SDL_SCANCODE_BACKSPACE: tl[tiSelect].textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.BACKSPACE); break;
							case SDL_SCANCODE_UP: tl[tiSelect].textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.CURSORUP); break;
							case SDL_SCANCODE_DOWN: tl[tiSelect].textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.CURSORDOWN); break;
							case SDL_SCANCODE_LEFT: tl[tiSelect].textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.CURSORLEFT); break;
							case SDL_SCANCODE_RIGHT: tl[tiSelect].textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.CURSORRIGHT); break;
							case SDL_SCANCODE_INSERT: tl[tiSelect].textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.INSERT); break;
							case SDL_SCANCODE_DELETE: tl[tiSelect].textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.DELETE); break;
							case SDL_SCANCODE_HOME: tl[tiSelect].textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.HOME); break;
							case SDL_SCANCODE_END: tl[tiSelect].textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.END); break;
							case SDL_SCANCODE_PAGEUP: tl[tiSelect].textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.PAGEUP); break;
							case SDL_SCANCODE_PAGEDOWN: tl[tiSelect].textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.PAGEDOWN); break;
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
						tl[tiSelect].textInputEvent(event.text.timestamp, event.text.windowID, event.text.text);
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
			i.keyPressed(ID, timestamp, devicenumber, devicetype);
		}
	}
	private void invokeKeyReleased(string ID, uint timestamp, uint devicenumber, uint devicetype){
		foreach(i; il){
			i.keyReleased(ID, timestamp, devicenumber, devicetype);
		}
	}
	private void invokeMouseEvent(uint which, uint timestamp, uint windowID, ubyte button, ubyte state, ubyte clicks, int x, int y){
		foreach(MouseListener m; ml){
			
			m.mouseButtonEvent(which, timestamp, windowID, button, state, clicks, x, y);
		}
	}
	private void invokeMouseWheelEvent(uint type, uint timestamp, uint windowID, uint which, int x, int y){
		foreach(MouseListener m; ml){

			m.mouseWheelEvent(type, timestamp, windowID, which, x, y, mouseX, mouseY);
		}
	}
	private void invokeMouseMotionEvent(uint timestamp, uint windowID, uint which, uint state, int x, int y, int relX, int relY){
		foreach(MouseListener m; ml){
			
			m.mouseMotionEvent(timestamp, windowID, which, state, x, y, relX, relY);
		}
	}
	private void invokeAxisEvent(string ID, uint timestamp, short val, uint devicenumber, uint devicetype){
		foreach(a; al){
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
	public static setXInput(bool state){
		if(state){
			SDL_SetHint(SDL_HINT_XINPUT_ENABLED, "1");
		}else{
			SDL_SetHint(SDL_HINT_XINPUT_ENABLED, "0");
		}
	}
	public void startTextInput(string ID){
		if(tiSelect !is null){
			if(tl.get(tiSelect, null) !is null)
				tl[tiSelect].dropTextInput();
			else
				tl.remove(tiSelect);

		}
		SDL_StartTextInput();
		tiEnable = true;

		tiSelect = ID;
	}
	public void stopTextInput(string ID){
		SDL_StopTextInput();
		tiEnable = false;
		tiSelect = null;
	}
	public void addTextInputListener(string ID, TextInputListener til){
		tl[ID] = til;
	}
}



public struct KeyBinding{
	public uint scancode, devicenumber, devicetype;
	public ushort keymod, keymodIgnore;
	public string ID;
	
	//public string device;
	
	this(ushort keymod, uint scancode, uint devicenumber, string ID, uint devicetype, ushort keymodIgnore = 0){
		this.keymod = keymod;
		this.scancode = scancode;
		this.devicenumber = devicenumber;
		this.ID = ID;
		this.devicetype = devicetype;
		this.keymodIgnore = keymodIgnore;
	}
	public bool conflKey(KeyBinding a){
		if(a.scancode == this.scancode && a.keymod == this.keymod && a.devicenumber == this.devicenumber && a.devicetype == this.devicetype){
			return true;
		}
		return false;
	}
	public bool conflID(KeyBinding a){
		if(a.ID == this.ID){
			return true;
		}
		return false;
	}
	bool opEquals(const KeyBinding s){
		if(s.scancode == this.scancode && s.keymod == this.keymod && s.devicenumber == this.devicenumber && s.devicetype == this.devicetype && s.ID == this.ID){
			return true;
		}
		return false;
	}
	string toString(){
		string s;
		s ~= "ID: ";
		s ~= ID;
		s ~= " Keycode: ";
		s ~= to!string(scancode);
		s ~= " Keymod: ";
		s ~= to!string(keymod);
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
	public void textInputEvent(uint timestamp, uint windowID, char[32] text);
	public void textInputKeyEvent(uint timestamp, uint windowID, TextInputKey key, ushort modifier = 0);
	//public void textSelectionEvent(uint timestamp, uint window, int action);
	//public void textClipboardEvent(uint timestamp, uint window, wstring text);
	public void dropTextInput();
}

public interface TextInputHandler{
	public void startTextInput(string ID);
	public void stopTextInput(string ID);
	public void addTextInputListener(string ID, TextInputListener til);
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

/// Standard key modifiers to avoid public SDL imports and to allow alternative library backends.
public enum KeyModifier : ushort{
	NONE 		= 0x0000,
	LSHIFT 		= 0x0001,
	RSHIFT 		= 0x0002,
	SHIFT 		= 0x0003,
	LCTRL 		= 0x0040,
	RCTRL	 	= 0x0080,
	CTRL 		= 0x00C0,
	LALT 		= 0x0100,
	RALT 		= 0x0200,
	ALT 		= 0x0300,
	LGUI 		= 0x0400,
	RGUI	 	= 0x0800,
	GUI 		= 0x0C00,
	NUM 		= 0x1000,
	CAPS 		= 0x2000,
	MODE 		= 0x4000,
	RESERVED 	= 0x8000,
	ANY			= 0xFFFF
}
public enum JoyModifier : ushort{
	BUTTONS		= 0x0000,
	DPAD		= 0x0004,
	AXIS		= 0x0008
}