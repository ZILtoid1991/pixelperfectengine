module PixelPerfectEngine.concrete.elements.button;

public class Button : WindowElement {
	private bool isPressed;
	public bool enableRightButtonClick;
	public bool enableMiddleButtonClick;
	public this(dstring text, string source, Coordinate coordinates) {
		this(new Text(text,getAvailableStyleSheet.getChrFormatting("button")), source, coordinates);
	}
	public this(Text text, string source, Coordinate coordinates) {
		position = coordinates;
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(coordinates.width, coordinates.height);
	}
	public override void draw() {
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width(), position.height());
		if(isPressed){
			output.drawFilledRectangle(1, position.width()-1, 1,position.height()-1, getAvailableStyleSheet().getColor("windowinactive"));
			output.drawLine(0, position.width()-1, 0, 0, getAvailableStyleSheet().getColor("windowdescent"));
			output.drawLine(0, 0, 0, position.height()-1, getAvailableStyleSheet().getColor("windowdescent"));
			output.drawLine(0, position.width()-1, position.height()-1, position.height()-1, getAvailableStyleSheet().getColor("windowascent"));
			output.drawLine(position.width()-1, position.width()-1, 0, position.height()-1, getAvailableStyleSheet().getColor("windowascent"));
		}else{
			output.drawFilledRectangle(1, position.width()-1, 1,position.height()-1, getAvailableStyleSheet().getColor("window"));
			output.drawLine(0, position.width()-1, 0, 0, getAvailableStyleSheet().getColor("windowascent"));
			output.drawLine(0, 0, 0, position.height()-1, getAvailableStyleSheet().getColor("windowascent"));
			output.drawLine(0, position.width()-1, position.height()-1, position.height()-1, getAvailableStyleSheet().getColor("windowdescent"));
			output.drawLine(position.width()-1, position.width()-1, 0, position.height()-1, getAvailableStyleSheet().getColor("windowdescent"));
		}

		/+output.drawColorText(position.width/2, position.height/2, text, getAvailableStyleSheet().getFontset("default"),
				getAvailableStyleSheet().getColor("normaltext"), FontFormat.HorizCentered | FontFormat.VertCentered);+/
		const int textPadding = getAvailableStyleSheet.drawParameters["TextSpacingSides"];
		const Coordinate textPos = Coordinate(textPadding,(position.height / 2) - (text.font.size / 2) ,position.width,
				position.height - textPadding);
		output.drawSingleLineText(textPos, text);
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}
	public override void onClick(int offsetX, int offsetY, int state, ubyte button){
		if(button == MouseButton.RIGHT && enableRightButtonClick){
			if(state == ButtonState.PRESSED){
				isPressed = true;
				draw();
				//invokeActionEvent(EventType.CLICK, -1);
				if(onMouseRClickPre !is null){
					onMouseRClickPre(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
			}else{
				isPressed = false;
				draw();
				//invokeActionEvent(EventType.CLICK, 0);
				if(onMouseRClickRel !is null){
					onMouseRClickRel(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
			}
		}else if(button == MouseButton.MID && enableMiddleButtonClick){
			if(state == ButtonState.PRESSED){
				isPressed = true;
				draw();
				//invokeActionEvent(EventType.CLICK, -1);
				if(onMouseMClickPre !is null){
					onMouseMClickPre(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
			}else{
				isPressed = false;
				draw();
				//invokeActionEvent(EventType.CLICK, 0);
				if(onMouseMClickRel !is null){
					onMouseMClickRel(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
			}
		}else{
			if(state == ButtonState.PRESSED){
				isPressed = true;
				draw();
				//invokeActionEvent(EventType.CLICK, -1);
				if(onMouseLClickPre !is null){
					onMouseLClickPre(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
			}else{
				isPressed = false;
				draw();
				//invokeActionEvent(EventType.CLICK, 0);
				if(onMouseLClickRel !is null){
					onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
			}
		}

	}
}