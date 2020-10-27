module PixelPerfectEngine.concrete.elements.textbox;


public class TextBox : WindowElement, TextInputListener{
	protected bool enableEdit, insert;
	protected size_t pos;
	protected int horizTextOffset, select;
	protected Text oldText;
	//public int brush, textpos;
	//public TextInputHandler tih;
	public void delegate(Event ev) onTextInput;
	public this(dstring text, string source, Coordinate coordinates) {
		this(new Text(text, getAvailableStyleSheet().getChrFormatting("textBox")), source, coordinates);
	}
	public this(Text text, string source, Coordinate coordinates) {
		position = coordinates;
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(coordinates.width, coordinates.height);
		//inputHandler.addTextInputListener(source, this);
		//insert = true;
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
		if(!enableEdit && state == ButtonState.PRESSED && button == MouseButton.LEFT){
			//invokeActionEvent(EventType.READYFORTEXTINPUT, 0);
			enableEdit = true;
			inputHandler.startTextInput(this);
			oldText = new Text(text);
			draw();
		}
	}
	public override void draw(){
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width, position.height);
		output.drawFilledRectangle(0, position.width - 1, 0, position.height - 1, 
				getAvailableStyleSheet().getColor("window"));
		output.drawRectangle(0, position.width - 1, 0, position.height - 1, 
				getAvailableStyleSheet().getColor("windowascent"));
		const int textPadding = getAvailableStyleSheet.drawParameters["TextSpacingSides"];
		Coordinate textPos = Coordinate(textPadding,(position.height / 2) - (text.font.size / 2) ,
				position.width,position.height - textPadding);
		
		const int y = text.font.size;
		//if(x > textPos.width ) xOffset = horizTextOffset;
		//draw cursor
		if(enableEdit) {
			const int x0 = text.getWidth(0,pos) + textPadding - horizTextOffset;
			if(!insert){
				output.drawLine(x0, x0, 2, 2 + y, getAvailableStyleSheet().getColor("selection"));
			}else{
				const int x1 = pos == text.charLength ? text.font.chars(' ').xadvance :
						text.getWidth(pos,pos + 1);
				output.drawFilledRectangle(x0, x1 + x0, 2, 2 + y, getAvailableStyleSheet().getColor("selection"));
			}
		}

		
		output.drawSingleLineText(textPos, text, horizTextOffset);
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}

	private void deleteCharacter(size_t n){
		text.removeChar(n);
	}
	public void textInputEvent(uint timestamp, uint windowID, dstring text){

		for(int j ; j < text.length ; j++){
			this.text.insertChar(pos++, text[j]);
		}
		const int textPadding = getAvailableStyleSheet.drawParameters["TextSpacingSides"];
		const Coordinate textPos = Coordinate(textPadding,(position.height / 2) - (this.text.font.size / 2) ,
				position.width,position.height - textPadding);
		const int x = this.text.getWidth(), cursorPixelPos = this.text.getWidth(0, pos);
		if(x > textPos.width) {
			 if(pos == text.text.length) {
				horizTextOffset = x - textPos.width;
			 } else if(cursorPixelPos < horizTextOffset) { //Test for whether the cursor would fall out from the current text area
				horizTextOffset = cursorPixelPos;
			 } else if(cursorPixelPos > horizTextOffset + textPos.width) {
				horizTextOffset = horizTextOffset + textPos.width;
			 }
		}
		draw();
	}

	public void dropTextInput(){
		enableEdit = false;
		horizTextOffset = 0;
		//inputHandler.stopTextInput(source);
		draw();
		//invokeActionEvent(EventType.TEXTINPUT, 0, text);
		/+if(onTextInput !is null)
			onTextInput(new Event(source, null, null, null, text, 0, EventType.TEXTINPUT, null, this));+/
	}


	public void textInputKeyEvent(uint timestamp, uint windowID, TextInputKey key, ushort modifier = 0){
		switch(key) {
			case TextInputKey.ENTER:
				enableEdit = false;
				inputHandler.stopTextInput(this);
				draw();
				if(onTextInput !is null)
					onTextInput(new Event(source, null, null, null, text, 0, EventType.TEXTINPUT, null, this));
				break;
			case TextInputKey.ESCAPE:
				enableEdit = false;
				inputHandler.stopTextInput(this);
				text = oldText;
				draw();
				break;
			case TextInputKey.BACKSPACE:
				if(pos > 0){
					deleteCharacter(pos - 1);
					pos--;
					draw();
				}
				break;
			case TextInputKey.DELETE:
				deleteCharacter(pos);
				draw();
				break;
			case TextInputKey.CURSORLEFT:
				if(pos > 0){
					--pos;
					draw();
				}
				break;
			case TextInputKey.CURSORRIGHT:
				if(pos < text.charLength){
					++pos;
					draw();
				}
				break;
			case TextInputKey.HOME:
				pos = 0;
				draw();
				break;
			case TextInputKey.END:
				pos = text.charLength;
				draw();
				break;
			case TextInputKey.INSERT:
				insert = !insert;
				draw();
				break;
			default:
				break;
		}
	}
}