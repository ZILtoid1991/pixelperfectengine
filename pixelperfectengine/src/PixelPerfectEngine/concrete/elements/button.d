module PixelPerfectEngine.concrete.elements.button;

public import PixelPerfectEngine.concrete.elements.base;

public class Button : WindowElement {
	private bool isPressed;
	public bool enableRightButtonClick;
	public bool enableMiddleButtonClick;
	public this(dstring text, string source, Box position) {
		this(new Text(text,getStyleSheet.getChrFormatting("button")), source, position);
	}
	public this(Text text, string source, Box position) {
		this.position = position;
		this.text = text;
		this.source = source;
		//output = new BitmapDrawer(coordinates.width, coordinates.height);
	}
	public override void draw() {
		StyleSheet ss = getStyleSheet();
		parent.clearArea(position);
		if (isPressed) {
			/+output.drawFilledRectangle(1, position.width()-1, 1,position.height()-1, getAvailableStyleSheet().getColor("windowinactive"));
			output.drawLine(0, position.width()-1, 0, 0, getAvailableStyleSheet().getColor("windowdescent"));
			output.drawLine(0, 0, 0, position.height()-1, getAvailableStyleSheet().getColor("windowdescent"));
			output.drawLine(0, position.width()-1, position.height()-1, position.height()-1, getAvailableStyleSheet().getColor("windowascent"));
			output.drawLine(position.width()-1, position.width()-1, 0, position.height()-1, getAvailableStyleSheet().getColor("windowascent"));+/
			with (parent) {
				drawFilledBox(position, ss.getColor("windowinactive"));
				drawLine(position.cornerUL, position.cornerUR, ss.getColor("windowdescent"));
				drawLine(position.cornerUL, position.cornerLL, ss.getColor("windowdescent"));
				drawLine(position.cornerLL, position.cornerLR, ss.getColor("windowascent"));
				drawLine(position.cornerUR, position.cornerLR, ss.getColor("windowascent"));
			}
		} else {
			/+output.drawFilledRectangle(1, position.width()-1, 1,position.height()-1, getAvailableStyleSheet().getColor("window"));
			output.drawLine(0, position.width()-1, 0, 0, getAvailableStyleSheet().getColor("windowascent"));
			output.drawLine(0, 0, 0, position.height()-1, getAvailableStyleSheet().getColor("windowascent"));
			output.drawLine(0, position.width()-1, position.height()-1, position.height()-1, getAvailableStyleSheet().getColor("windowdescent"));
			output.drawLine(position.width()-1, position.width()-1, 0, position.height()-1, getAvailableStyleSheet().getColor("windowdescent"));+/
			with (parent) {
				drawFilledBox(position, ss.getColor("window"));
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
	}
	
}