module PixelPerfectEngine.concrete.elements.base;

public import PixelPerfectEngine.concrete.interfaces;
import PixelPerfectEngine.system.input.handler;
import PixelPerfectEngine.system.input.types : MouseMotionEvent;

/**
 * Definies values about whether a WindowElement is enabled or not.
 */
public enum ElementState : ubyte {
	Enabled				=	0,	///Means the element is enabled.
	DisabledWOGray		=	1,	///Disabled without grayout, should be only used by elements contained within
	Disabled			=	2,	///Means the element is disabled
}
/**
 * All Window elements inherit from this class. Provides basic interfacing with containers.
 */
abstract class WindowElement : Focusable {
    public static InputHandler inputHandler;	///Common input handler, must be set upon program initialization
    ///Contains the position of the element.
    ///Should be only modified with functions to ensure consistency.
	protected Coordinate position;
    ///Points to the container for two-way communication
	public ElementContainer parent;
	///Contains the text of the element if any.
    ///Should be modified with functions to ensure redraws.
	protected Text text;
    /**
     * Passed with other event informations when event is caused.
     * Can be something like the name of the instance.
     *
     * Should not be modified after creation.
     */
	protected string source;
    ///Contains various status flags.
    protected uint flags;
    ///Sets a custom style for this element.
    ///If not set, then it'll get the style from it's parent.
	public StyleSheet customStyle;
	//protected ElementState _state;

	
	//public static PopUpHandler popUpHandler;	///Common pop-up handler
	//public static StyleSheet styleSheet;		///Basic stylesheet, all elements default to this if no alternative found

	public static void delegate() onDraw;		///Called when drawing is finished

	public void delegate(Event ev) onMouseLClickRel;	///Called on left mouseclick released
	public void delegate(Event ev) onMouseRClickRel;	///Called on right mouseclick released
	public void delegate(Event ev) onMouseMClickRel;	///Called on middle mouseclick released
	public void delegate(Event ev) onMouseHover;		///Called if mouse is on object
	public void delegate(Event ev) onMouseMove;			///Called if mouse is moved on object
	public void delegate(Event ev) onMouseLClickPre;	///Called on left mouseclick pressed
	public void delegate(Event ev) onMouseRClickPre;	///Called on right mouseclick pressed
	public void delegate(Event ev) onMouseMClickPre;	///Called on middle mouseclick pressed
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

	@property @nogc @safe nothrow public Coordinate getPosition() {
		return position;
	}
	/**
	 * Updates the output. Every subclass must override it.
	 */
	public abstract void draw();

	
	
	public dstring getTextDString() {
		return text.toDString();
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
	 * Returns the next available StyleSheet.
	 */
	public StyleSheet getAvailableStyleSheet() {
		if(customStyle !is null){
			return customStyle;
		}
		if(elementContainer !is null){
			
		}
		return styleSheet;
	}

	public void setCustomStyle(StyleSheet s) {
		customStyle = s;
	}
	/**
	 * Returns whether the element is enabled or not.
	 */
	public @property ElementState state() @nogc @safe const pure nothrow {
		return _state;
	}
	/**
	 * Sets whether the element is enabled or not.
	 */
	public @property ElementState state(ElementState _state) @nogc @safe pure nothrow {
		return this._state = _state;
	}
	/**
	 * Returns the source string.
	 */
	@property public string getSource(){
		return source;
	}
}