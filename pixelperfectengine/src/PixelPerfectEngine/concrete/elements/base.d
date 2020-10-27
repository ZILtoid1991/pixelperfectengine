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
	protected Coordinate	position;
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
		elementContainer.clearArea(this);
		draw();
	}
	public void setText(dstring s) {
		text.text = s;
		text.next = null;
		elementContainer.clearArea(this);
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
	public Coordinate getPosition() {
		return position;
	}
	public Coordinate setPosition(Coordinate position) {
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
	public @property bool mousePressEvent() @nogc @safe pure nothrow {
		return flags & ENABLE_MOUSE_PRESS;
	}
	public @property bool mouseMClickEvent() @nogc @safe pure nothrow {
		return flags & ENABLE_MCLICK_FLAG;
	}
	public @property bool mouseRClickEvent() @nogc @safe pure nothrow {
		return flags & ENABLE_RCLICK_FLAG;
	}
	public @property bool mousePressEvent(bool val) @nogc @safe pure nothrow {
		if (val) flags |= ENABLE_MOUSE_PRESS;
		else flags &= ~ENABLE_MOUSE_PRESS;
		return flags & ENABLE_MOUSE_PRESS;
	}
	public @property bool mouseMClickEvent(bool val) @nogc @safe pure nothrow {
		if (val) flags |= ENABLE_MCLICK_FLAG;
		else flags &= ~ENABLE_MCLICK_FLAG;
		return flags & ENABLE_MCLICK_FLAG;
	}
	public @property bool mouseRClickEvent(bool val) @nogc @safe pure nothrow {
		if (val) flags |= ENABLE_RCLICK_FLAG;
		else flags &= ~ENABLE_RCLICK_FLAG;
		return flags & ENABLE_RCLICK_FLAG;
	}
	/**
	 * Returns the next available StyleSheet.
	 */
	public StyleSheet getStyleSheet() {
		if(customStyle !is null){
			return customStyle;
		}
		if(parent !is null){
			return parent.getStyleSheet();
		}
		return null;
	}
	
	public void focusGiven() {
		flags |= IS_FOCUSED;
		draw;
	}
	
	public void focusLost() {
		flags &= ~IS_FOCUSED;
		draw;
	}
	
	public void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		
	}
	
	public void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		
	}
	
	public void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		
	}
	
}
