module pixelperfectengine.system.input.types;

public import iota.controls.types;
public import iota.controls.keyboard : KeyboardModifiers;
public import iota.controls.mouse : MouseButtons, MouseButtonFlags;
public import iota.controls.gamectrl : GameControllerButtons, GameControllerAxes;


/// Modifier flags for joystick stuff, e.g. axes.
public enum JoyModifier : ubyte {
	Button		= 0x00,
	DPad		= 0x04,
	Axis		= 0x08,
	
}
/**
 * Determines input device types.
 * Currently 0-4 are used, 5-7 is reserved for future use.
 */
public enum Devicetype : ubyte {
	Keyboard	= 0,
	Joystick	= 1,	///Also used for gamepads, wheels, etc., that can be interpreted as such
	Mouse		= 2,
	Touchscreen	= 3,
	Pen			= 4,
}
/**
 * Keys used during text input.
 * Multiple enter and backspace keys are not threated as different entities in this case.
 */
/* public enum TextInputKey {
	init,
	Enter		= 1,
	Escape		= 2,
	Backspace	= 3,
	CursorUp	= 4,
	CursorDown	= 5,
	CursorLeft	= 6,
	CursorRight	= 7,
	Insert		= 8,
	Delete		= 9,
	Home		= 10,
	End			= 11,
	PageUp		= 12,
	PageDown	= 13
} */
/**
 * Mouse Buttons that are numbered by the engine.
 */
/* public enum MouseButton : ubyte {
	Left		= 1,
	Mid			= 2,
	Right		= 3,
	Next		= 4,
	Previous	= 5
} */
/**
 * Mouse Button flags.
 */
/* public enum MouseButtonFlags : uint {
	Left		= 1 << 0,
	Mid			= 1 << 1,
	Right		= 1 << 2,
	Next		= 1 << 3,
	Previous	= 1 << 4
} */
/**
 * Button states.
 */
/* public enum ButtonState : ubyte {
	Released	= 0,
	Pressed		= 1
} */

/**
 * Stores an easy to lookup code for input bindings in integer format.
 * Keybindings should be stored in the configuration file as a human-readable format, as this struct
 * might change in the future if more things need to be added
 */
public struct BindingCode {
	/**
	 * The basis for all comparison.
	 * bits 0-8: Button/axis number.
	 * bits 9-16: Modifier flags.
	 * bits 17-19: Device type ID.
	 * bits 20-23: Device number.
	 * bits 24-31: Extended area.
	 */
	uint base;
	/**
	 * Modifier flags.
	 * bits 0-8: Unused.
	 * bits 9-16: Keymod ignore.
	 * bits 17-31: Unused.
	 */
	uint flags;
	///Standard CTOR
	this(uint base) @nogc @safe pure nothrow {
		this.base = base;
	}
	///CTOR with individual values
	this(ushort _buttonNum, ubyte _modifierFlags, ubyte _deviceTypeID, ubyte _deviceNum, ubyte _keymodIgnore = 0) 
			@nogc @safe pure nothrow {
		buttonNum = _buttonNum;
		modifierFlags = _modifierFlags;
		deviceTypeID = _deviceTypeID;
		deviceNum = _deviceNum;
		keymodIgnore = _keymodIgnore;
	}
	/// Returns the button number portion of the code.
	@property ushort buttonNum() @nogc @safe pure nothrow const {
		return cast(ushort)(base & 0x1_FF);
	}
	/// Sets the button number portion of the code.
	@property ushort buttonNum(ushort val) @nogc @safe pure nothrow {
		base &= ~0x00_00_01_FF;
		base |= val & 0x1_FF;
		return cast(ushort)(base & 0x1_FF);
	}
	/// Returns the modifier flag portion of the code.
	@property ubyte modifierFlags() @nogc @safe pure nothrow const {
		return cast(ubyte)(base >>> 9);
	}
	/// Sets the modifier flag portion of the code.
	@property ubyte modifierFlags(ubyte val) @nogc @safe pure nothrow {
		base &= ~0x00_01_FE_00;
		base |= val << 9;
		return cast(ubyte)(base >>> 9);
	}
	/// Returns the keymod ignore code.
	@property ubyte keymodIgnore() @nogc @safe pure nothrow const {
		return cast(ubyte)(flags >>> 9);
	}
	/// Sets the keymod ignore code.
	@property ubyte keymodIgnore(ubyte val) @nogc @safe pure nothrow {
		flags &= ~0x00_01_FE_00;
		flags |= val << 9;
		return cast(ubyte)(flags >>> 9);
	}
	/// Returns the device type ID portion of the code.
	@property ubyte deviceTypeID() @nogc @safe pure nothrow const {
		return cast(ubyte)((base >>> 17) & 0b0000_0111);
	}
	/// Sets the device type ID portion of the code.
	@property ubyte deviceTypeID(ubyte val) @nogc @safe pure nothrow {
		base &= ~0x00_0E_00_00;
		base |= (val & 0b0000_0111) << 17;
		return cast(ubyte)((base >>> 17) & 0b0000_0111);
	}
	/// Returns the device type ID portion of the code.
	@property ubyte deviceNum() @nogc @safe pure nothrow const {
		return cast(ubyte)((base >>> 20) & 0x0f);
	}
	/// Sets the device type ID portion of the code.
	@property ubyte deviceNum(ubyte val) @nogc @safe pure nothrow {
		base &= ~0x00_F0_00_00;
		base |= (val & 0x0f) << 20;
		return cast(ubyte)((base >>> 20) & 0x0f);
	}
	///Returns the extended area value.
	@property ubyte extArea() @nogc @safe pure nothrow const {
		return cast(ubyte)(base >> 24);
	}
	///Sets the extended area value.
	@property ubyte extArea(ubyte val) @nogc @safe pure nothrow {
		base &= ~0xFF_00_00_00;
		base |= val << 24;
		return cast(ubyte)(base >> 24);
	}
	///Returns the keymod ignore flags
	///Return whether the binding code is a joy axis
	@property bool isJoyAxis() @nogc @safe pure nothrow {
		return deviceTypeID == Devicetype.Joystick && modifierFlags == JoyModifier.Axis;
	}
	int opCmp(const BindingCode other) @nogc @safe pure nothrow const {
		const uint baseLH = base | flags | other.flags;
		const uint baseRH = other.base | flags | other.flags;
		if(baseLH > baseRH) return 1;
		else if(baseLH < baseRH) return -1;
		else return 0;
	}
	bool opEquals(const BindingCode other) @nogc @safe pure nothrow const {
		const uint baseLH = base | flags | other.flags;
		const uint baseRH = other.base | flags | other.flags;
		return baseLH == baseRH;
	}
	size_t toHash() const @nogc @safe pure nothrow {
		
	}
}
/**
 * Defines a single Input Binding.
 */
public struct InputBinding {
	uint		code;			///Code being sent out to the target, should be a MurmurhashV3/32 code.
	uint		flags;			///Stores additional properties of the input binding.
	float[2]	deadzone;		///The deadzone, if the binding is an axis.
	static enum IS_AXIS_AS_BUTTON = 1<<0;	///If set in the flags field, then it treats the axis as a button.
	///Default CTOR
	this(uint code, uint flags = 0, float[2] deadzone = [0.0, 0.0]) @nogc @safe pure nothrow {
		this.code = code;
		this.flags = flags;
		this.deadzone = deadzone;
	}
	///CTOR that creates code from string
	this(string code, uint flags = 0, float[2] deadzone = [0.0, 0.0]) @nogc @safe pure nothrow {
		import collections.commons : defaultHash;
		this.code = defaultHash(code);
		this.flags = flags;
		this.deadzone = deadzone;
	}
	int opCmp(const InputBinding other) const @nogc @safe pure nothrow {
		if (code > other.code) return 1;
		else if (code < other.code) return -1;
		else return 0;
	}

	int opCmp(const uint other) const @nogc @safe pure nothrow {
		if (code > other) return 1;
		else if (code < other) return -1;
		else return 0;
	}
}	
/**
 * Common values for mouse events.
 */
public struct MouseEventCommons {
	Timestamp		timestamp;		///Timestamp of the event
	uint			windowID;		///Identifies the window where the event originated
	uint			mouseID;		///Identifies the mouse that generated the event
}
/**
 * Packs mouseclick event information into a single struct.
 */
public struct MouseClickEvent {
	import std.bitmanip : bitfields;
	int				x;				///X position of where the event happened
	int				y;				///Y position of where the event happened
	ubyte			button;			///The button that generated the event
	ubyte			clicks;			///The amount of clicks
	bool			state;			///Button state. Might be replaced in the future with flags.
}
/**
 * Packs mousewheel event information into a single struct.
 */
public struct MouseWheelEvent {
	int				x;				///Horizontal scrolling
	int				y;				///Vertical scrolling
}
/**
 * Packs mousemotion event information into a single struct.
 */
public struct MouseMotionEvent {
	uint			buttonState;	///State of the buttons
	int				x;				///Horizontal position of the cursor
	int				y;				///Vertical position of the cursor
	int				relX;			///Horizontal amount of mouse movement
	int				relY;			///Vertical amount of mouse movement
}