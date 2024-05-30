module pixelperfectengine.system.input.handler;

import bindbc.sdl;

import collections.treemap;
import collections.linkedlist;
import collections.commons : defaultHash;

public import pixelperfectengine.system.input.types;
public import pixelperfectengine.system.input.interfaces;
public import pixelperfectengine.graphics.common : Box;
import pixelperfectengine.system.input.scancode;

/**
 * Converts and redirects inputs as events.
 */
public class InputHandler {
	/**
	 * Contains data related to joysticks.
	 */
	public struct JoyInfo {
		string			name;			///The name of the joystick
		int				buttons;		///The amount of buttons on this joystick
		int				axis;			///The amount of axes of this joystick
		int				hats;			///The amount of hats (d-pads) of this joystick
	}
	protected enum StatusFlags {
		none				=	0,
		TextInputEnable		=	1<<0,
		TI_ReportTextEditingEvents	=	1<<1,
		CaptureEvent		=	1<<2,
		CE_DelConflCodes	=	1<<3,	///If set, the code will be removed from all other keys
		CE_DelConflKeys		=	1<<4,	///If set, alternative codes of the key will be removed.
		CE_CancelOnSysEsc	=	1<<5,	///If set, bindings with the `SysEsc` ID will cancel event capture
		CE_AllowMouse		=	1<<6,	///If set, allows mouse buttons to be recorded
		AnyKey				=	1<<7	///Enables an anykey event.
	}
	///Code that is emmitted on an any key event.
	public static immutable uint anykeyCode = 1402_508_842; //= defaultHash("AnyKey");
	///Code that is emmitted on a system escape key (keyboard Esc key, joystick start button, etc) event.
	public static immutable uint sysescCode = 2320_826_867; //= defaultHash("SysEsc");
	//alias CodeTreeSet = TreeMap!(uint, void);
	
	alias CodeTreeSet = TreeMap!(InputBinding, void);
	alias InputBindingLookupTree = TreeMap!(BindingCode, CodeTreeSet);//alias InputBindingLookupTree = TreeMap!(BindingCode, InputBinding[]);
	alias JoyInfoMap = TreeMap!(int, JoyInfo);
	alias JoyMap = TreeMap!(int, SDL_Joystick*);
	/**
	 * The main input lookup tree.
	 */
	protected InputBindingLookupTree	inputLookup;
	///Contains pointers related to joystick handling
	protected JoyMap					joysticks;
	///Contains info related to each joystick
	protected JoyInfoMap				joyInfo;
	///Contains info about the current status of the Input Handler.
	///See the enum `StatusFlags` for more info.
	protected uint						statusFlags;
	///The currently recorded code.
	protected InputBinding				recordedCode;
	///Passes all codes from keybindings to this interface.
	///Multiple listeners at once are removed from newer versions to reduce overhead.
	///Functionality can be restored with an event hub.
	public InputListener				inputListener;
	///Passes all system events to this interface.
	///Multiple listeners at once are removed from newer versions to reduce overhead.
	///Functionality can be restored with an event hub.
	public SystemEventListener			systemEventListener;
	///Passes all text input events to this interface.
	///Only a single listener should get text input at once.
	protected TextInputListener			textInputListener;
	///Passes all mouse events to this interface.
	///Multiple listeners at once are removed from newer versions to reduce overhead.
	///Functionality can be restored with an event hub.
	public MouseListener				mouseListener;
	/**
	 * CTOR.
	 * Detects joysticks upon construction.
	 * IMPORTANT: Only a single instance of this class should exist!
	 */
	public this() {
		SDL_InitSubSystem(SDL_INIT_JOYSTICK);
		detectJoys();
	}
	~this() {
		foreach(joy; joysticks) {
			SDL_JoystickClose(joy);
		}
	}
	/**
	 * Adds a single inputbinding to the inputhandler.
	 */
	public void addBinding(BindingCode bc, InputBinding ib) @safe nothrow {
		CodeTreeSet* i = inputLookup.ptrOf(bc);
		if (i) 
			i.put(ib);
		else 
			inputLookup[bc] = CodeTreeSet([ib]);
	}
	/**
	 * Removes a single inputbinding from the inputhandler.
	 */
	public void removeBinding(BindingCode bc, InputBinding ib) @safe nothrow {
		CodeTreeSet* i = inputLookup.ptrOf(bc);
		if (i) {
			if (i.length == 1)
				inputLookup.remove(bc);
			else
				i.removeByElem(ib);
		}
	}
	/**
	 * Replaces the keycode lookup tree.
	 * Returns a copy of the current one as a backup.
	 */
	public InputBindingLookupTree replaceLookupTree(InputBindingLookupTree newTree) @safe nothrow {
		InputBindingLookupTree backup = inputLookup;
		inputLookup = newTree;
		return backup;
	}
	///Static CTOR to init joystick handling
	///Only one input handler should be made per application to avoid issues from SDL_Poll indiscriminately polling all events
	/+static this() {
		SDL_InitSubSystem(SDL_INIT_JOYSTICK);
	}+/
	/**
	 * Detects all connected joysticks.
	 */
	public void detectJoys() {
		import std.string : fromStringz;
		import std.conv : to;
		const int numOfJoysticks = SDL_NumJoysticks();
		for(int i ; i < numOfJoysticks ; i++){
			if(!joysticks.ptrOf(i)){
				SDL_Joystick* joy = SDL_JoystickOpen(i);
				if(joy) {
					joysticks[i] = joy;
					joyInfo[i] = JoyInfo(fromStringz(SDL_JoystickName(joy)).dup, SDL_JoystickNumButtons(joy), SDL_JoystickNumAxes(joy),
							SDL_JoystickNumHats(joy));
				}
			}
		}
	}
	/**
	 * Removes info related to disconnected joysticks.
	 */
	public void removeJoy(int i) {
		SDL_JoystickClose(joysticks[i]);
		joysticks.remove(i);
	}
	/**
	 * Starts text input handling.
	 */
	public void startTextInput(TextInputListener listener, bool reportTextEditingEvents = false, 
			Box textEditingArea = Box.init) {
		if (textInputListener !is null) textInputListener.dropTextInput();
		textInputListener = listener;
		statusFlags |= StatusFlags.TextInputEnable;
		if (reportTextEditingEvents) statusFlags |= StatusFlags.TI_ReportTextEditingEvents;
		SDL_StartTextInput();
		listener.initTextInput();
	}
	/**
	 * Stops text input handling.
	 */
	public void stopTextInput() {
		textInputListener.dropTextInput();
		SDL_StopTextInput();
		textInputListener = null;
		statusFlags = 0;
	}
	/**
	 * Initializes event recording.
	 */
	public void recordEvent(InputBinding code, bool delConflKeys, bool delConflCodes, bool cancelOnSysEsc, 
			bool allowMouseEvents) {
		recordedCode = code;
		statusFlags |= StatusFlags.CaptureEvent;
		if (delConflCodes) statusFlags |= StatusFlags.CE_DelConflCodes;
		if (delConflKeys) statusFlags |= StatusFlags.CE_DelConflKeys;
		if (cancelOnSysEsc) statusFlags |= StatusFlags.CE_CancelOnSysEsc;
		if (allowMouseEvents) statusFlags |= StatusFlags.CE_AllowMouse;
	}
	/**
	 * Enables an anykey event for once.
	 */
	public void expectAnyKeyEvent() {
		statusFlags |= StatusFlags.AnyKey;
	}
	/**
	 * Tests for input.
	 */
	public void test() {
		SDL_Event event;
		while(SDL_PollEvent(&event)) {
			BindingCode bc;
			bool release;
			float axisOffset;
			uint timestamp;
			switch(event.type) {
				case SDL_KEYUP:
					release = true;
					goto case SDL_KEYDOWN;
				case SDL_KEYDOWN:
					bc.buttonNum = cast(ushort)event.key.keysym.scancode;
					bc.deviceTypeID = Devicetype.Keyboard;
					bc.modifierFlags = keyModConv(event.key.keysym.mod);
					timestamp = event.key.timestamp;
					break;
				case SDL_JOYBUTTONUP:
					release = true;
					goto case SDL_JOYBUTTONDOWN;
				case SDL_JOYBUTTONDOWN:
					bc.deviceNum = cast(ubyte)event.jbutton.which;
					bc.deviceTypeID = Devicetype.Joystick;
					bc.buttonNum = event.jbutton.button;
					break;
				case SDL_JOYHATMOTION:
					bc.deviceNum = cast(ubyte)event.jhat.which;
					bc.deviceTypeID = Devicetype.Joystick;
					bc.buttonNum = event.jhat.value;
					bc.modifierFlags = JoyModifier.DPad;
					bc.extArea = event.jhat.hat;
					break;
				case SDL_JOYAXISMOTION:
					bc.deviceNum = cast(ubyte)event.jaxis.which;
					bc.deviceTypeID = Devicetype.Joystick;
					bc.buttonNum = event.jaxis.axis;
					bc.modifierFlags = JoyModifier.Axis;
					axisOffset = cast(real)event.jaxis.value / short.max;
					break;
				case SDL_MOUSEBUTTONUP:
					release = true;
					goto case SDL_MOUSEBUTTONDOWN;
				case SDL_MOUSEBUTTONDOWN:
					bc.deviceNum = cast(ubyte)event.button.which;
					bc.deviceTypeID = Devicetype.Mouse;
					bc.buttonNum = event.button.button;
					if (mouseListener) {
						mouseListener.mouseClickEvent(
								MouseEventCommons(event.button.timestamp, event.button.windowID, event.button.which),
								MouseClickEvent(event.button.x, event.button.y, event.button.button, event.button.clicks, 
								event.button.state == 1));
					}
					break;
				case SDL_MOUSEMOTION:
					if (mouseListener) {
						mouseListener.mouseMotionEvent(
								MouseEventCommons(event.motion.timestamp, event.motion.windowID, event.motion.which), 
								MouseMotionEvent(event.motion.state, event.motion.x, event.motion.y, event.motion.xrel, 
								event.motion.yrel));
					}
					break;
				case SDL_MOUSEWHEEL:
					if (mouseListener) {
						mouseListener.mouseWheelEvent(MouseEventCommons(event.wheel.timestamp, event.wheel.windowID, event.wheel.which),
								MouseWheelEvent(event.wheel.x, event.wheel.y));
					}
					break;
				case SDL_TEXTINPUT:
					import std.utf : toUTF32;
					import std.string : fromStringz;
					if (statusFlags & StatusFlags.TextInputEnable) {
						dstring eventText = toUTF32(fromStringz(event.text.text.ptr));
						textInputListener.textInputEvent(event.text.timestamp, event.text.windowID, eventText);
					}
					break;
				case SDL_TEXTEDITING:
					import std.utf : toUTF32;
					import std.string : fromStringz;
					if (statusFlags & StatusFlags.TI_ReportTextEditingEvents) {
						dstring eventText = toUTF32(fromStringz(event.edit.text.ptr));
						textInputListener.textEditingEvent(event.edit.timestamp, event.edit.windowID, eventText, event.edit.start, 
								event.edit.length);
					}
					break;
				case SDL_QUIT:
					if (systemEventListener) systemEventListener.onQuit();
					break;
				case SDL_JOYDEVICEADDED:
					detectJoys;
					if (systemEventListener) systemEventListener.controllerAdded(event.jdevice.which);
					break;
				case SDL_JOYDEVICEREMOVED:
					removeJoy(event.jdevice.which);
					if (systemEventListener) systemEventListener.controllerRemoved(event.jdevice.which); 
					break;
				default: break;
			}
			if (bc.base){
				if (!statusFlags) {	//Generate input event
					CodeTreeSet hashcodeSet = inputLookup[bc];
					if (hashcodeSet.length) {
						if (bc.isJoyAxis) {
							foreach (InputBinding key; hashcodeSet) {
								if (key.flags & key.IS_AXIS_AS_BUTTON) {
									if (key.deadzone[1] >= axisOffset || key.deadzone[0] <= axisOffset)
										inputListener.keyEvent(key.code, bc, timestamp, true);
									else
										inputListener.keyEvent(key.code, bc, timestamp, false);
								} else {
									inputListener.axisEvent(key.code, bc, timestamp, axisOffset);
								}
							}
						} else {
							foreach (InputBinding key; hashcodeSet) {
								/+foreach(InputListener il; inputListeners) il.keyEvent(key, bc, timestamp);+/
								inputListener.keyEvent(key.code, bc, timestamp, !release);
							}
						}
					}
				} else if (statusFlags & StatusFlags.TextInputEnable && bc.deviceTypeID == Devicetype.Keyboard && !release) {		//Generate text editing input
					switch(bc.buttonNum){
						case ScanCode.ENTER, ScanCode.ENTER2, ScanCode.NP_ENTER:
							textInputListener.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.Enter, 
									bc.modifierFlags);
							break;
						case ScanCode.ESCAPE:
							textInputListener.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.Escape, 
									bc.modifierFlags);
							break;
						case ScanCode.BACKSPACE, ScanCode.NP_BACKSPACE, ScanCode.ALTERASE:
							textInputListener.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.Backspace, 
									bc.modifierFlags);
							break;
						case ScanCode.UP:
							textInputListener.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.CursorUp, 
									bc.modifierFlags);
							break;
						case ScanCode.DOWN:
							textInputListener.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.CursorDown, 
									bc.modifierFlags);
							break;
						case ScanCode.LEFT:
							textInputListener.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.CursorLeft, 
									bc.modifierFlags);
							break;
						case ScanCode.RIGHT:
							textInputListener.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.CursorRight, 
									bc.modifierFlags);
							break;
						case ScanCode.INSERT:
							textInputListener.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.Insert, 
									bc.modifierFlags);
							break;
						case ScanCode.DELETE:
							textInputListener.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.Delete, 
									bc.modifierFlags);
							break;
						case ScanCode.HOME:
							textInputListener.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.Home, 
									bc.modifierFlags);
							break;
						case ScanCode.END:
							textInputListener.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.End, 
									bc.modifierFlags);
							break;
						case ScanCode.PAGEUP:
							textInputListener.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.PageUp, 
									bc.modifierFlags);
							break;
						case ScanCode.PAGEDOWN:
							textInputListener.textInputKeyEvent(event.key.timestamp, event.key.windowID, TextInputKey.PageDown, 
									bc.modifierFlags);
							break;
						default: break;
					}
				} else if (statusFlags & StatusFlags.CaptureEvent) {			//Record event as keybinding
					CodeTreeSet* hashcodeSet = inputLookup.ptrOf(bc);
					if (hashcodeSet && !(hashcodeSet.has(sysescCode) && statusFlags & StatusFlags.CE_CancelOnSysEsc)) {
						if (StatusFlags.CE_DelConflCodes) {
							BindingCode[] toRemove;
							foreach (BindingCode key, ref CodeTreeSet hashCodes; inputLookup) {
								hashCodes.removeByElem(recordedCode);
								if (!hashCodes.length) toRemove ~= key;
							}
							foreach (key; toRemove) {
								inputLookup.remove(key);
							}
						}
						if (hashcodeSet.length) {
							if (!(statusFlags & StatusFlags.CE_DelConflKeys)) hashcodeSet.put(recordedCode);
							else inputLookup[bc] = CodeTreeSet([recordedCode]);
						} else inputLookup[bc] = CodeTreeSet([recordedCode]);
					}
					statusFlags = 0;
				} else if (statusFlags & StatusFlags.AnyKey) {					//Any key event
					inputListener.keyEvent(anykeyCode, bc, timestamp, true);
					statusFlags = 0;
				}
			}
		}
	}
	/**
	 * Returns a default SysEsc binding.
	 */
	public static BindingCode getSysEscKey() @nogc @safe pure nothrow {
		import pixelperfectengine.system.input.scancode : ScanCode;
		const BindingCode bc = BindingCode(ScanCode.ESCAPE, 0, Devicetype.Keyboard, 0);
		return bc;
	}
}
