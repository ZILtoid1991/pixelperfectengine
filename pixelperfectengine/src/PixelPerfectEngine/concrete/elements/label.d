module PixelPerfectEngine.concrete.elements.label;


public class Label : WindowElement {
	public this(dstring text, string source, Coordinate coordinates) {
		this(new Text(text, getAvailableStyleSheet().getChrFormatting("label")), source, coordinates);
	}
	public this(Text text, string source, Coordinate coordinates) {
		position = coordinates;
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(coordinates.width, coordinates.height);
		//draw();
	}
	public override void draw() {
		//output = new BitmapDrawer(position.width, position.height);
		/+output.drawColorText(0, 0, text, getAvailableStyleSheet().getFontset("default"),
				getAvailableStyleSheet().getColor("normaltext"), 0);+/
		const int textPadding = getAvailableStyleSheet.drawParameters["TextSpacingSides"];
		const Coordinate textPos = Coordinate(textPadding,(position.height / 2) - (text.font.size / 2), position.width, 
				position.height - textPadding);
		output.drawSingleLineText(textPos, text);
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}
	public override void setText(dstring s) {
		output.destroy();
		output = new BitmapDrawer(position.width, position.height);
		super.setText(s);
	}
	public override void setText(Text s) {
		output.destroy();
		output = new BitmapDrawer(position.width, position.height);
		super.setText(s);
		//draw();
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
				if(onMouseLClickPre !is null){
					onMouseLClickPre(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
			}else{
				if(onMouseLClickRel !is null){
					onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
			}
		}

	}
}
