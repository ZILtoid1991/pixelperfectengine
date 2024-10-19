module pixelperfectengine.system.input.handler;

//import bindbc.sdl;

import collections.treemap;
import collections.linkedlist;
import collections.commons : defaultHash;

public import pixelperfectengine.system.input.types;
public import pixelperfectengine.system.input.interfaces;
public import pixelperfectengine.graphics.common : Box;
import pixelperfectengine.system.input.scancode;

import IOTA = iota.controls;

/**
 * Converts and redirects inputs as events.
 * TODO: Refactor to use iota instead.
 */
public class InputHandler {
	shared static this(){
		IOTA.initInput(ConfigFlags.gc_Enable, OSConfigFlags.win_RawInput | OSConfigFlags.win_XInput);
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
	
	//alias JoyMap = TreeMap!(int, SDL_Joystick*);
	/**
	 * The main input lookup tree.
	 */
	protected InputBindingLookupTree	inputLookup;
	protected IOTA.GameController[]		gameControllers;
	///Contains pointers related to joystick handling
	//protected JoyMap					joysticks;
	///Contains info related to each joystick
	//protected JoyInfoMap				joyInfo;
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
		//NOTE: As of iota 0.3.0, x11 does not use any of the extra flags
		detectControllers();
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
	/**
	 * Detects all connected game controllers.
	 */
	private void detectControllers() {
		gameControllers.length = 0;
		foreach (InputDevice dev ; IOTA.devList) {
			IOTA.GameController gc = cast(IOTA.GameController)dev;
			if (gc !is null) {
				gameControllers ~= gc;
			}
		}
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
		//SDL_StartTextInput();
		IOTA.keyb.setTextInput = true;
		listener.initTextInput();
	}
	/**
	 * Stops text input handling.
	 */
	public void stopTextInput() {
		textInputListener.dropTextInput();
		//SDL_StopTextInput();
		IOTA.keyb.setTextInput = false;
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
		IOTA.InputEvent event;
		while(IOTA.poll(event)) {
			BindingCode bc;
			bool release;
			float axisOffset;
			IOTA.Timestamp timestamp;
			switch(event.type) {
				case IOTA.InputEventType.Keyboard:
					release = event.button.dir == 0;
					bc.buttonNum = cast(ushort)event.button.id;
					bc.deviceTypeID = Devicetype.Keyboard;
					bc.modifierFlags = cast(ubyte)event.button.aux;
					timestamp = event.timestamp;
					break;
				case IOTA.InputEventType.GCButton:
					release = event.button.dir == 0;
					bc.buttonNum = cast(ubyte)event.button.id;
					bc.deviceTypeID = Devicetype.Joystick;
					bc.deviceNum = event.source.devNum;
					timestamp = event.timestamp;
					break;
				/* case IOTA.InputEventType.GCHat:
					bc.deviceNum = cast(ubyte)event.jhat.which;
					bc.deviceTypeID = Devicetype.Joystick;
					bc.buttonNum = event.jhat.value;
					bc.modifierFlags = JoyModifier.DPad;
					bc.extArea = event.jhat.hat;
					break; */
				case IOTA.InputEventType.GCAxis:
					bc.deviceNum = cast(ubyte)event.source.devNum;
					bc.deviceTypeID = Devicetype.Joystick;
					bc.buttonNum = cast(ushort)event.axis.id;
					bc.modifierFlags = JoyModifier.Axis;
					axisOffset = event.axis.val;
					break;
				case IOTA.InputEventType.MouseClick:
					bc.deviceTypeID = Devicetype.Mouse;
					bc.buttonNum = event.mouseCE.button;
					if (mouseListener) {
						mouseListener.mouseClickEvent(
								MouseEventCommons(event.timestamp, IOTA.OSWindow.byRef(event.handle), cast(Mouse)event.source),
								MouseClickEvent(event.mouseCE.x, event.mouseCE.y, cast(ubyte)event.mouseCE.button, event.mouseCE.repeat, 
								event.mouseCE.dir == 1));
					}
					break;
				case IOTA.InputEventType.MouseMove:
					if (mouseListener) {
						mouseListener.mouseMotionEvent(
								MouseEventCommons(event.timestamp, IOTA.OSWindow.byRef(event.handle), cast(Mouse)event.source),
								MouseMotionEvent(event.mouseME.buttons, event.mouseME.x, event.mouseME.y, event.mouseME.xD, 
								event.mouseME.yD));
					}
					break;
				case IOTA.InputEventType.MouseScroll:
					//if (event.mouseSE.xS > 200 || event.mouseSE.xS < 200) event.mouseSE.xS = 0; //HADK: Get around iota (LDC2?) bug
					if (mouseListener) {
						mouseListener.mouseWheelEvent(
								MouseEventCommons(event.timestamp, IOTA.OSWindow.byRef(event.handle), cast(Mouse)event.source),
								MouseWheelEvent(mouseScrollNormalizer(event.mouseSE.xS) * 4, mouseScrollNormalizer(event.mouseSE.yS) * 16));
					}
					break;
				case IOTA.InputEventType.TextInput:
					import std.utf : toUTF32;
					import std.string : fromStringz;
					if (statusFlags & StatusFlags.TextInputEnable && !event.textIn.isDeadChar) {
						textInputListener.textInputEvent(event.timestamp, IOTA.OSWindow.byRef(event.handle), toUTF32(event.textIn.text));
					}
					break;
				case IOTA.InputEventType.TextCommand:
					if (statusFlags & StatusFlags.TextInputEnable) {
						textInputListener.textInputKeyEvent(event.timestamp, IOTA.OSWindow.byRef(event.handle), event.textCmd);
					}
					break;
				case IOTA.InputEventType.WindowResize:
					if (systemEventListener) {
						systemEventListener.windowResize(IOTA.OSWindow.byRef(event.handle), event.window.width, event.window.height);
					}
					break;
				/* case SDL_TEXTEDITING:
					import std.utf : toUTF32;
					import std.string : fromStringz;
					if (statusFlags & StatusFlags.TI_ReportTextEditingEvents) {
						dstring eventText = toUTF32(fromStringz(event.edit.text.ptr));
						textInputListener.textEditingEvent(event.edit.timestamp, event.edit.windowID, eventText, event.edit.start, 
								event.edit.length);
					}
					break; */
				case IOTA.InputEventType.ApplExit, IOTA.InputEventType.WindowClose:
					if (systemEventListener) systemEventListener.onQuit();
					break;
				case IOTA.InputEventType.DeviceAdded:
					detectControllers();
					if (systemEventListener) systemEventListener.inputDeviceAdded(event.source);
					break;
				case IOTA.InputEventType.DeviceRemoved:
					IOTA.removeInvalidatedDevices();
					if (systemEventListener) systemEventListener.inputDeviceRemoved(event.source); 
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
pragma(inline, true)
package int mouseScrollNormalizer(int i) @nogc @safe pure nothrow {
	if (i > 0) return 1;
	if (i < 0) return -1;
	return 0;
}