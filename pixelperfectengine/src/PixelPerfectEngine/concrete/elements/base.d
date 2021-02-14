module PixelPerfectEngine.concrete.elements.base;

public import PixelPerfectEngine.concrete.interfaces;
public import PixelPerfectEngine.concrete.types.stylesheet;
public import PixelPerfectEngine.concrete.types.event;
public import PixelPerfectEngine.system.input.handler;
//import PixelPerfectEngine.system.input.types : MouseMotionEvent;


/**
 * Definies values about whether a WindowElement is enabled or not.
 */
public enum ElementState : ubyte {
	Enabled				=	0,	///Means the element is enabled.
	DisabledWOGray		=	1,	///Disabled without grayout, should be only used by elements contained within
	Disabled			=	2,	///Means the element is disabled
}
alias EventDeleg = void delegate(Event ev);
/**
 * All Window elements inherit from this class. Provides basic interfacing with containers.
 */
abstract class WindowElement : Focusable, MouseEventReceptor {
    public static InputHandler inputHandler;	///Common input handler, must be set upon program initialization for text input, etc.
    ///Contains the position of the element.
    ///Should be only modified with functions to ensure consistency.
	protected Box			position;
    ///Points to the container for two-way communication
	public ElementContainer	parent;
	///Contains the text of the element if any.
    ///Should be modified with functions to ensure redraws.
	protected Text			text;
    /**
     * Passed with other event informations when event is caused.
     * Can be something like the name of the instance.
     *
     * Should not be modified after creation.
     */
	protected string		source;
    ///Contains various status flags.
    protected uint			flags;
	protected static enum	ENABLE_MOUSE_PRESS = 1<<3;
	protected static enum	ENABLE_MCLICK_FLAG = 1<<4;
	protected static enum	ENABLE_RCLICK_FLAG = 1<<5;
	protected static enum	IS_PRESSED = 1<<6;
	protected static enum	IS_CHECKED = 1<<7;
	protected static enum	IS_FOCUSED = 1<<8;
	protected static enum	IS_LHS = 1<<30;
    ///Sets a custom style for this element.
    ///If not set, then it'll get the style from it's parent.
	public StyleSheet		customStyle;
	//protected ElementState _state;

	
	//public static PopUpHandler popUpHandler;	///Common pop-up handler
	//public static StyleSheet styleSheet;		///Basic stylesheet, all elements default to this if no alternative found

	//public static void delegate() onDraw;		///Called when drawing is finished

	public EventDeleg 		onMouseLClick;	///Called on left mouseclick released
	public EventDeleg 		onMouseRClick;	///Called on right mouseclick released
	public EventDeleg 		onMouseMClick;	///Called on middle mouseclick released
	public EventDeleg 		onMouseMove;	///Called if mouse is moved on object
	public EventDeleg 		onMouseScroll;	///Called if mouse is scrolled on object
	
	protected MouseMotionEvent		lastMousePosition;	///Stores the last known mouse position for future reference
    ///Returns the text of this element.
	public @nogc Text getText(){
		return text;
	}
    public void setText(Text s) {
		text = s;
		//parent.clearArea(position);
		draw();
	}
	public void setText(dstring s) {
		text.text = s;
		text.next = null;
		//parent.clearArea(position);
		draw();
	}
	/**
	 * Sets whether the element is enabled or not.
	 */
	public @property ElementState state(ElementState state) {
		flags &= ~0x3;
		flags |= cast(ubyte)state;
		draw();
		return state;
	}
	/**
	 * Returns whether the element is enabled or not.
	 */
	public @property ElementState state() @nogc @safe const pure nothrow {
		return cast(ElementState)(flags & 0x3);
	}
	public void setParent(ElementContainer parent) {
		this.parent = parent;
	}
	/**
	 * Updates the output. Every subclass must override it.
	 */
	public abstract void draw();
	public Box getPosition() {
		return position;
	}
	public Box setPosition(Box position) {
		this.position = position;
		draw;
		return position;
	}
	/**
	 * Returns the source string.
	 */
	@property public string getSource(){
		return source;
	}
	/**
	 * Returns true if the element will generate events on mouse press and mouse release.
	 * By default, only release is used.
	 */
	public @property bool mousePressEvent() @nogc @safe pure nothrow {
		return flags & ENABLE_MOUSE_PRESS ? true : false;
	}
	/**
	 * Returns true if middle mouse button events are enabled.
	 */
	public @property bool mouseMClickEvent() @nogc @safe pure nothrow {
		return flags & ENABLE_MCLICK_FLAG ? true : false;
	}
	/**
	 * Returns true if right mouse button events are enabled.
	 */
	public @property bool mouseRClickEvent() @nogc @safe pure nothrow {
		return flags & ENABLE_RCLICK_FLAG ? true : false;
	}
	/**
	 * Returns true if the element will generate events on mouse press and mouse release.
	 * By default, only release is used.
	 */
	public @property bool mousePressEvent(bool val) @nogc @safe pure nothrow {
		if (val) flags |= ENABLE_MOUSE_PRESS;
		else flags &= ~ENABLE_MOUSE_PRESS;
		return flags & ENABLE_MOUSE_PRESS ? true : false;
	}
	/**
	 * Returns true if middle mouse button events are enabled.
	 */
	public @property bool mouseMClickEvent(bool val) @nogc @safe pure nothrow {
		if (val) flags |= ENABLE_MCLICK_FLAG;
		else flags &= ~ENABLE_MCLICK_FLAG;
		return flags & ENABLE_MCLICK_FLAG ? true : false;
	}
	/**
	 * Returns true if right mouse button events are enabled.
	 */
	public @property bool mouseRClickEvent(bool val) @nogc @safe pure nothrow {
		if (val) flags |= ENABLE_RCLICK_FLAG;
		else flags &= ~ENABLE_RCLICK_FLAG;
		return flags & ENABLE_RCLICK_FLAG ? true : false;
	}
	/**
	 * Returns the next available StyleSheet.
	 */
	public StyleSheet getStyleSheet() {
		if(customStyle !is null) return customStyle;
		else if(parent !is null) return parent.getStyleSheet();
		else return globalDefaultStyle;
	}
	///Called when an object receives focus.
	public void focusGiven() {
		flags |= IS_FOCUSED;
		draw;
	}
	///Called when an object loses focus.
	public void focusTaken() {
		flags &= ~IS_FOCUSED;
		draw;
	}
	///Cycles the focus on a single element.
	///Returns -1 if end is reached, or the number of remaining elements that
	///are cycleable in the direction.
	public int cycleFocus(int direction) {
		return -1;
	}
	///Passes key events to the focused element when not in text editing mode.
	public void passKey(uint keyCode, ubyte mod) {
		
	}
	/**
	 * Returns whether the element is focused
	 */
	public @property bool isFocused() @nogc @safe pure nothrow const {
		return flags & IS_FOCUSED ? true : false;
	}
	/**
	 * Returns whether the element is pressed
	 */
	public @property bool isPressed() @nogc @safe pure nothrow const {
		return flags & IS_PRESSED ? true : false;
	}
	/**
	 * Returns whether the element is checked
	 */
	public @property bool isChecked() @nogc @safe pure nothrow const {
		return flags & IS_CHECKED ? true : false;
	}
	protected @property bool isChecked(bool val) @nogc @safe pure nothrow {
		if (val) flags |= IS_CHECKED;
		else flags &= ~IS_CHECKED;
		return flags & IS_CHECKED ? true : false;
	}
	public void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		parent.requestFocus(this);
		if (mce.state == ButtonState.Pressed) {
			if (mce.button == MouseButton.Left) flags |= IS_PRESSED;
			if (!(flags & ENABLE_MOUSE_PRESS)) return;
		} else if (mce.button == MouseButton.Left) {
			flags &= ~IS_PRESSED;
		}
		MouseEvent me = new MouseEvent(this, EventType.MouseClick, SourceType.WindowElement);
		me.mec = mec;
		me.mce = mce;
		switch (mce.button) {
			case MouseButton.Left:
				if (onMouseLClick !is null)
					onMouseLClick(me);
				break;
			case MouseButton.Right:
				if (onMouseRClick !is null)
					onMouseRClick(me);
				break;
			case MouseButton.Mid:
				if (onMouseMClick !is null)
					onMouseMClick(me);
				break;
			default:
				break;
		}
		draw;
	}
	
	public void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		
		if (onMouseMove !is null) {
			MouseEvent me = new MouseEvent(this, EventType.MouseMotion, SourceType.WindowElement);
			me.mme = mme;
			me.mec = mec;
			onMouseMove(me);
		}
	}
	
	public void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		if (onMouseScroll !is null) {
			MouseEvent me = new MouseEvent(this, EventType.MouseScroll, SourceType.WindowElement);
			me.mec = mec;
			me.mwe = mwe;
			onMouseScroll(me);
		}
	}
	
}
