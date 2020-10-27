module PixelPerfectEngine.concrete.elements.checkbox;

/**
 * A simple toggle button.
 */
public class CheckBox : WindowElement, ICheckBox{
	protected bool		checked;
	public string		iconChecked = "checkBoxB";		///Sets the icon for checked positions
	public string		iconUnchecked = "checkBoxA";	///Sets the icon for unchecked positions
	public void delegate(Event ev) onToggle;
	///CTOR for checkbox with text
	public this(Text text, string source, Coordinate coordinates, bool checked = false) {
		position = coordinates;
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(position.width, position.height);
		this.checked = checked;
		//draw();
	}
	///Ditto
	public this(dstring text, string source, Coordinate coordinates, bool checked = false) {
		this(new Text(text, getAvailableStyleSheet().getChrFormatting("checkBox")), source, coordinates, checked);
	}
	///CTOR for small button version
	public this(string iconChecked, string iconUnchecked, string source, Coordinate coordinates, bool checked = false) {
		position = coordinates;
		this.iconChecked = iconChecked;
		this.iconUnchecked = iconUnchecked;
		this.source = source;
		output = new BitmapDrawer(position.width, position.height);
		this.checked = checked;
	}
	public override void draw() {
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width, position.height);
		output.drawRectangle(getAvailableStyleSheet().getImage(iconUnchecked).width, output.output.width - 1, 0,
				output.output.height - 1, 0x0);
		if(text) {
			const int textPadding = getAvailableStyleSheet.drawParameters["TextSpacingSides"];
			const Coordinate textPos = Coordinate(textPadding +	getAvailableStyleSheet().getImage(iconUnchecked).width,
					(position.height / 2) - (text.font.size / 2), position.width, position.height - textPadding);
			output.drawSingleLineText(textPos, text);
		}
		/+output.drawColorText(getAvailableStyleSheet().getImage("checkBoxA").width, 0, text,
				getAvailableStyleSheet().getFontset("default"), getAvailableStyleSheet().getColor("normaltext"), 0);+/
		if(checked){
			output.insertBitmap(0, 0, getAvailableStyleSheet().getImage(iconChecked));
		}else{
			output.insertBitmap(0, 0, getAvailableStyleSheet().getImage(iconUnchecked));
		}
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}

	public override void onClick(int offsetX, int offsetY, int state, ubyte button){
		if(button == MouseButton.RIGHT){
			if(state == ButtonState.PRESSED){
				if(onMouseRClickPre !is null){
					onMouseRClickPre(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
			}else{
				if(onMouseRClickRel !is null){
					onMouseRClickRel(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
			}
		}else if(button == MouseButton.MID){
			if(state == ButtonState.PRESSED){
				if(onMouseMClickPre !is null){
					onMouseMClickPre(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
			}else{
				if(onMouseMClickRel !is null){
					onMouseMClickRel(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
			}
		}else{
			if(state == ButtonState.PRESSED){
				checked = !checked;
				draw();
				if(onMouseLClickPre !is null){
					onMouseLClickPre(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
				if(onToggle !is null){
					onToggle(new Event(source, null, null, null, null, checked ? 1 : 0, EventType.CHECKBOX, null, this));
				}
			}else{
				if(onMouseLClickRel !is null){
					onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
			}
		}
	}
	/**
	 * Returns the current value (whether it's checked or not) as a boolean.
	 * DEPRECATED!
	 */
	public @nogc @property bool value(){
		return checked;
	}
	/**
	 * Sets the new value (whether it's checked or not) as a boolean.
	 * DEPRECATED!
	 */
	public @property bool value(bool b){
		checked = b;
		draw();
		return checked;
	}
	
	public @property bool isChecked() @safe pure @nogc nothrow const {
		return checked;
	}
	
	public bool check() @trusted {
		checked = true;
		draw();
		return checked;
	}
	
	public bool unCheck() @trusted {
		checked = false;
		draw();
		return checked;
	}
	
}
