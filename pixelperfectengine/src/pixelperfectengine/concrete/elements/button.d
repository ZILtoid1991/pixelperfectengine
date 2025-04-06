module pixelperfectengine.concrete.elements.button;

public import pixelperfectengine.concrete.elements.base;
/**
 * Implements a simple clickable window element for user input.
 */
public class Button : WindowElement {
	//private bool isPressed;
	//public bool enableRightButtonClick;
	//public bool enableMiddleButtonClick;
	/**
	 * Creates a Button with the default text formatting style.
	 * Params:
	 *   text = The text to be displayed on the button.
	 *   source = The source of the events emitted by this window element.
	 *   position = Defines where the button should be drawn.
	 */
	public this(dstring text, string source, Box position) {
		this(new Text(text,getStyleSheet.getChrFormatting("button")), source, position);
	}
	/**
	 * Creates a Button with the supplied Text object.
	 * Params:
	 *   text = The text to be displayed on the button. Can contain one or more icons.
	 *   source = The source of the events emitted by this window element.
	 *   position = Defines where the button should be drawn.
	 */
	public this(Text text, string source, Box position) {
		this.position = position;
		this.text = text;
		this.source = source;
		//output = new BitmapDrawer(coordinates.width, coordinates.height);
	}
	public override void draw() {
		if (parent is null || state == ElementState.Hidden) return;
		StyleSheet ss = getStyleSheet();
		parent.clearArea(position);
		if (isPressed) {
			
			with (parent) {
				drawFilledBox(position, ss.getColor("windowinactive"));
				drawLine(position.cornerUL, position.cornerUR, ss.getColor("windowdescent"));
				drawLine(position.cornerUL, position.cornerLL, ss.getColor("windowdescent"));
				drawLine(position.cornerLL, position.cornerLR, ss.getColor("windowascent"));
				drawLine(position.cornerUR, position.cornerLR, ss.getColor("windowascent"));
			}
		} else {
			
			with (parent) {
				drawFilledBox(position, ss.getColor("buttonTop"));
				drawLine(position.cornerUL, position.cornerUR, ss.getColor("windowascent"));
				drawLine(position.cornerUL, position.cornerLL, ss.getColor("windowascent"));
				drawLine(position.cornerLL, position.cornerLR, ss.getColor("windowdescent"));
				drawLine(position.cornerUR, position.cornerLR, ss.getColor("windowdescent"));
			}
		}
		if (isFocused) {
			const int textPadding = ss.drawParameters["horizTextPadding"];
			parent.drawBoxPattern(position - textPadding, ss.pattern["blackDottedLine"]);
		}
		parent.drawTextSL(position, text, Point(0, 0));
		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
		if (onDraw !is null) {
			onDraw();
		}
		parent.updateOutput(this);
	}
	
}
