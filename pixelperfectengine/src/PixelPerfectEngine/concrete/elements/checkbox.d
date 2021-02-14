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
		isChecked = checked;
	}
	///Ditto
	public this(dstring text, string source, Coordinate coordinates, bool checked = false) {
		this(new Text(text, getStyleSheet().getChrFormatting("checkBox")), source, coordinates, checked);
	}
	///CTOR for small button version
	public this(string iconChecked, string iconUnchecked, string source, Coordinate coordinates, bool checked = false) {
		position = coordinates;
		this.iconChecked = iconChecked;
		this.iconUnchecked = iconUnchecked;
		this.source = source;
		isChecked = checked;
	}
	public override void draw() {
		parent.clearArea(position);
		StyleSheet ss = getStyleSheet;
		Bitmap8Bit icon = isChecked ? ss.getImage(iconChecked) : ss.getImage(iconUnchecked);
		
		parent.bitBLT(position.cornerUL, icon);
		
		if (text) {
			Coordinate textPos = position;
			textPos.left += ss.getImage(iconChecked).width + ss.drawParameters["TextSpacingSides"];
			parent.drawTextSL(textPos, text, position.cornerUL);
		}
		if (isFocused) {
			const int textPadding = ss.drawParameters["horizTextPadding"];
			parent.drawBoxPattern(position - textPadding, ss.pattern["blackDottedLine"]);
		}
		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
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
	///Returns true if left side justified, false otherwise.
	public bool isLeftSide() @nogc @safe pure nothrow const {
		return flags & IS_LHS ? true : false;
	}
	///Sets the small button to the left side if true.
	public bool isLeftSide(bool val) @nogc @safe pure nothrow {
		if (val) flags |= IS_LHS;
		else flags &= ~IS_LHS;
		return flags & IS_LHS ? true : false;
	}
}
