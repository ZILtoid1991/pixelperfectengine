module PixelPerfectEngine.concrete.elements.radiobutton;
/**
 * Implements a single radio button.
 * Needs to be grouped to used.
 * Equality is checked by comparing `source`, so give each RadioButton a different source value.
 */
public class RadioButton : WindowElement, IRadioButton {
	protected IRadioButtonGroup		group;		///The group which this object belongs to.
	protected bool					_isLatched;		///The state of the RadioButton
	public string					iconLatched = "radioButtonB";		///Sets the icon for latched positions
	public string					iconUnlatched = "radioButtonA";	///Sets the icon for unlatched positions
	public this(Text text, string source, Coordinate coordinates, IRadioButtonGroup group = null) {
		position = coordinates;
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(position.width, position.height);
		group.add(this);
	}
	///Ditto
	public this(dstring text, string source, Coordinate coordinates, IRadioButtonGroup group = null) {
		this(new Text(text, getAvailableStyleSheet().getChrFormatting("checkBox")), source, coordinates, group);
	}
	///Ditto
	public this(string source, Coordinate coordinates, IRadioButtonGroup group = null) {
		position = coordinates;
		this.source = source;
		output = new BitmapDrawer(position.width, position.height);
		group.add(this);
	}
	override public void draw() {
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width, position.height);
		output.drawRectangle(getAvailableStyleSheet().getImage(iconUnlatched).width, output.output.width - 1, 0,
				output.output.height - 1, 0x0);
		if(text) {
			const int textPadding = getAvailableStyleSheet.drawParameters["TextSpacingSides"];
			const Coordinate textPos = Coordinate(textPadding +	getAvailableStyleSheet().getImage(iconUnlatched).width,
					(position.height / 2) - (text.font.size / 2), position.width, position.height - textPadding);
			output.drawSingleLineText(textPos, text);
		}
		/+output.drawColorText(getAvailableStyleSheet().getImage("checkBoxA").width, 0, text,
				getAvailableStyleSheet().getFontset("default"), getAvailableStyleSheet().getColor("normaltext"), 0);+/
		if(_isLatched) {
			output.insertBitmap(0, 0, getAvailableStyleSheet().getImage(iconLatched));
		} else {
			output.insertBitmap(0, 0, getAvailableStyleSheet().getImage(iconUnlatched));
		}
		elementContainer.drawUpdate(this);
		if(onDraw !is null) {
			onDraw();
		}
	}
	public override void onClick(int offsetX, int offsetY, int state, ubyte button) {
		if(state == ButtonState.PRESSED){
			switch(button){
				case MouseButton.LEFT:
					if(group !is null) {
						group.latch(this);
					}
					if(onMouseLClickPre !is null)
						onMouseLClickPre(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
					break;
				case MouseButton.RIGHT:
					if(onMouseRClickPre !is null)
						onMouseRClickPre(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
					break;
				case MouseButton.MID:
					if(onMouseMClickPre !is null)
						onMouseMClickPre(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
					break;
				default: break;
			}
		}else{
			switch(button){
				case MouseButton.LEFT:
					if(onMouseLClickRel !is null)
						onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
					break;
				case MouseButton.RIGHT:
					if(onMouseRClickRel !is null)
						onMouseRClickRel(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
					break;
				case MouseButton.MID:
					if(onMouseMClickRel !is null)
						onMouseMClickRel(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
					break;
				default: break;
			}
		}
	}
	/**
	 * If the radio button is pressed, then it sets to unpressed. Does nothing otherwise.
	 */
	public void latchOff() @trusted {
		if(_isLatched) {
			_isLatched = false;
			draw();
		}
	}
	/**
	 * Sets the radio button into its pressed state.
	 */
	public void latchOn() @trusted {
		if(!_isLatched) {
			_isLatched = true;
			draw();
		}
	}
	/**
	 * Returns the current state of the radio button.
	 * True: Pressed.
	 * False: Unpressed.
	 */
	public @property bool isLatched() @nogc @safe pure nothrow const {
		return _isLatched;
	}
	/**
	 * Sets the group of the radio button.
	 */
	public void setGroup(IRadioButtonGroup group) @safe @property {
		this.group = group;
	}
	public bool equals(IRadioButton rhs) @safe pure @nogc nothrow const {
		WindowElement we = cast(WindowElement)rhs;
		return source == we.source;
	}
	public string value() @property @safe @nogc pure nothrow const {
		return source;
	}
}

/**
 * Radio Button Group implementation.
 * Can send events via it's delegates.
 */
public class RadioButtonGroup : IRadioButtonGroup {
	alias RadioButtonSet = LinkedList!(IRadioButton, false, "a.equals(b)");
	protected RadioButtonSet radioButtons;
	protected IRadioButton latchedButton;
	protected size_t _value;
	///Empty ctor
	public this() @safe pure nothrow @nogc {
		
	}
	/**
	 * Creates a new group with some starting elements from a compatible range.
	 */
	public this(R)(R range) @safe {
		foreach (key; range) {
			radioButtons.put(key);
		}
	}
	/**
	 * Adds a new RadioButton to the group.
	 */
	public void add(IRadioButton rg) @safe {
		radioButtons.put(rg);
		rg.setGroup(this);
	}
	/**
	 * Removes the given RadioButton from the group.
	 */
	public void remove(IRadioButton rg) @safe {
		radioButtons.removeByElem(rg);
		rg.setGroup(null);
	}
	/**
	 * Latches the group.
	 */
	public void latch(IRadioButton sender) @safe {
		latchedButton = sender;
		foreach(elem; radioButtons) {
			elem.latchOff;
		}
		sender.latchOn;
	}
	/**
	 * Returns the value of this group.
	 */
	public @property string value() const @nogc @safe pure nothrow {
		if(latchedButton !is null) return latchedButton.value;
		else return null;
	}
}