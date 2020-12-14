module PixelPerfectEngine.concrete.elements.checkbox;

public import PixelPerfectEngine.concrete.elements.base;

/**
 * A simple toggle button.
 */
public class CheckBox : WindowElement, ISmallButton {
	public string		iconChecked = "checkBoxB";		///Sets the icon for checked positions
	public string		iconUnchecked = "checkBoxA";	///Sets the icon for unchecked positions
	public EventDeleg onToggle;
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
		parent.clearArea(position);
		StyleSheet ss = getStyleSheet;
		/+output.drawColorText(getAvailableStyleSheet().getImage("checkBoxA").width, 0, text,
				getAvailableStyleSheet().getFontset("default"), getAvailableStyleSheet().getColor("normaltext"), 0);+/
		Bitmap8Bit icon = isChecked ? ss.getImage(iconChecked) : ss.getImage(iconUnchecked);
		
		parent.bitBLT(Point(0, 0), icon);
		
		if (text) {
			Coordinate textPos = position;
			textPos.left += ss.getImage(iconChecked).width + getAvailableStyleSheet.drawParameters["TextSpacingSides"];
			parent.drawTextSL(textPos, text, Point(0, 0));
		}
		if (isFocused) {
			const int textPadding = ss.drawParameters["horizTextPadding"];
			parent.drawBoxPattern(position - textPadding, ss.pattern["blackDottedLine"]);
		}
		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
	}
	/**
	 * Returns the current value (whether it's checked or not) as a boolean.
	 * DEPRECATED!
	 */
	public deprecated @nogc @property bool value(){
		return checked;
	}
	/**
	 * Sets the new value (whether it's checked or not) as a boolean.
	 * DEPRECATED!
	 */
	public deprecated @property bool value(bool b){
		if (b) check;
		else unCheck;
	}
	
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		const int width = getStyleSheet().getImage(iconChecked).width;
		if (mce.button == MouseButton.Left && mce.state == ButtonState.Pressed && mce.x < width) {
			if (isChecked) {
				unCheck;
			} else {
				check;
			}
			if (onToggle !is null) {
				onToggle(new Event(this, EventType.Toggle, SourceType.WindowElement));
			}
		}
		super.passMCE(mec, mce);
	}

	public bool check() @trusted {
		flags |= IS_CHECKED;
		draw();
		return isChecked;
	}
	
	public bool unCheck() @trusted {
		flags &= ~IS_CHECKED;
		draw();
		return isChecked;
	}
	public bool isSmallButtonHeight(int height) {
		if (text) return false;
		else if (position.width == height && position.height == height) return true;
		else return false;
	}
}
