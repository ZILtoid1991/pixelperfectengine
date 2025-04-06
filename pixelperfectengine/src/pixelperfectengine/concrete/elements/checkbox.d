module pixelperfectengine.concrete.elements.checkbox;

public import pixelperfectengine.concrete.elements.base;

/**
 * Implements a checkbox, that can take a binary choice option from the user.
 */
public class CheckBox : WindowElement, ISmallButton {
	public string		iconChecked = "checkBoxB";		///Sets the icon for checked positions
	public string		iconUnchecked = "checkBoxA";	///Sets the icon for unchecked positions
	public EventDeleg 	onToggle;
	/**
	 * Creates an instance of a checkbox with a text object.
	 * Params:
	 *   text = The text to be displayed besides the button.
	 *   source = The source of the events emitted by this object.
	 *   position = Defines where the element should be drawn.
	 *   checked = Initial state of the button.
	 */
	public this(Text text, string source, Box position, bool checked = false) {
		this.position = position;
		this.text = text;
		this.source = source;
		isChecked = checked;
	}
	/**
	 * Creates an instance of a checkbox with a default formatted text.
	 * Params:
	 *   text = The text to be displayed besides the button.
	 *   source = The source of the events emitted by this object.
	 *   position = Defines where the element should be drawn.
	 *   checked = Initial state of the button.
	 */
	public this(dstring text, string source, Box position, bool checked = false) {
		this(new Text(text, getStyleSheet().getChrFormatting("checkBox")), source, position, checked);
	}
	/**
	 * Creates a small button version of the checkbox for windows, toolbars, etc.
	 * Params:
	 *   iconChecked = The icon when the button is checked.
	 *   iconUnchecked = The icon when the button is unchecked.
	 *   source = The source of the events emitted by this object.
	 *   position = Defines where the element should be drawn.
	 *   checked = Initial state of the button.
	 */
	public this(string iconChecked, string iconUnchecked, string source, Box position, bool checked = false) {
		this.position = position;
		this.iconChecked = iconChecked;
		this.iconUnchecked = iconUnchecked;
		this.source = source;
		isChecked = checked;
	}
	public override void draw() {
		if (parent is null || state == ElementState.Hidden) return;
		parent.clearArea(position);
		StyleSheet ss = getStyleSheet;
		Bitmap8Bit icon = isChecked ? ss.getImage(iconChecked) : ss.getImage(iconUnchecked);
		
		parent.bitBLT(position.cornerUL, icon);
		
		if (text) {
			Coordinate textPos = position;
			textPos.left += ss.getImage(iconChecked).width + ss.drawParameters["TextSpacingSides"];
			parent.drawTextSL(textPos, text, Point(0, 0));
		}
		if (isFocused) {
			const int textPadding = ss.drawParameters["horizTextPadding"];
			parent.drawBoxPattern(position - textPadding, ss.pattern["blackDottedLine"]);
		}
		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(Box(position.left, position.top, position.left + icon.width - 1, position.top + icon.height - 1
					), ss.getImage("ElementDisabledPtrn"));
		}

		if (onDraw !is null) {
			onDraw();
		}
		parent.updateOutput(this);
	}
	
	
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		if (state != ElementState.Enabled) return;
		mce.x -= position.left;
		mce.y -= position.top;
		const int width = getStyleSheet().getImage(iconChecked).width;
		if (mce.button == MouseButtons.Left && mce.state == true && mce.x < width) {
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
	/**
	 * Sets the value of the checkbox to checked.
	 * Does not inwoke any events.
	 */
	public bool check() @trusted {
		flags |= IS_CHECKED;
		draw();
		return isChecked;
	}
	/**
	 * Sets the value of the checkbox to unchecked.
	 * Does not inwoke any events.
	 */
	public bool unCheck() @trusted {
		flags &= ~IS_CHECKED;
		draw();
		return isChecked;
	}
	/**
	 * Toggles the checkbox.
	 * Inwokes an `onToggle` event if delegate is set.
	 */
	public bool toggle() {
		if (isChecked) {
			unCheck;
		} else {
			check;
		}
		if (onToggle !is null) {
			onToggle(new Event(this, EventType.Toggle, SourceType.WindowElement));
		}
		return isChecked();
	}
	/**
	 * Toggles the checkbox to the given value.
	 * Inwokes an `onToggle` event if delegate is set.
	 */
	public bool toggle(bool val) {
		if (isChecked == val)
			return val;
		else
			return toggle();
	}
	///Returns true if the checkbox is a small button.
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
