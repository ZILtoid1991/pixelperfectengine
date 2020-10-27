module PixelPerfectEngine.concrete.popup.popuptextinput;

/**
 * Text input in pop-up fashion.
 */
public class PopUpTextInput : PopUpElement, TextInputListener{
	protected bool enableEdit, insert;
	protected size_t cursorPos;
	protected int horizTextOffset, select;
	public void delegate(Event ev) onTextInput;

	public this(string source, Text text, Coordinate position){
		this.source = source;
		this.text = text;
		this.position = position;
		enableEdit = true;
		output = new BitmapDrawer(position.width, position.height);
		inputhandler.startTextInput(this);
	}
	public override void draw(){
		output.drawFilledRectangle(0, position.width - 1, 0, position.height - 1, getStyleSheet().getColor("window"));
		output.drawRectangle(0, position.width - 1, 0, position.height - 1, getStyleSheet().getColor("windowascent"));
		const int textPadding = getStyleSheet.drawParameters["TextSpacingSides"];
		Coordinate textPos = Coordinate(textPadding,(position.height / 2) - (text.font.size / 2) ,
				position.width,position.height - textPadding);
		
		const int y = text.font.size;
		//if(x > textPos.width ) xOffset = horizTextOffset;
		//draw cursor
		if(enableEdit) {
			const int x0 = text.getWidth(0,cursorPos) + textPadding - horizTextOffset;
			if(!insert){
				output.drawLine(x0, x0, 2, 2 + y, getStyleSheet().getColor("selection"));
			}else{
				const int x1 = cursorPos == text.charLength ? text.font.chars(' ').xadvance :
						text.getWidth(cursorPos,cursorPos + 1);
				output.drawFilledRectangle(x0, x1 + x0, 2, 2 + y, getStyleSheet().getColor("selection"));
			}
		}

		
		output.drawSingleLineText(textPos, text, horizTextOffset);
		//parent.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}
	private void deleteCharacter(size_t n){
		text.removeChar(n);
	}
	public void textInputEvent(uint timestamp, uint windowID, dstring text){
		for(int j ; j < text.length ; j++){
			this.text.insertChar(cursorPos++, text[j]);
		}
		const int textPadding = getStyleSheet().drawParameters["TextSpacingSides"];
		const Coordinate textPos = Coordinate(textPadding,(position.height / 2) - (this.text.font.size / 2) ,
				position.width,position.height - textPadding);
		const int x = this.text.getWidth(), cursorPixelPos = this.text.getWidth(0, cursorPos);
		if(x > textPos.width) {
			 if(cursorPos == text.text.length) {
				horizTextOffset = x - textPos.width;
			 } else if(cursorPixelPos < horizTextOffset) { //Test for whether the cursor would fall out from the current text area
				horizTextOffset = cursorPixelPos;
			 } else if(cursorPixelPos > horizTextOffset + textPos.width) {
				horizTextOffset = horizTextOffset + textPos.width;
			 }
		}
		draw();
	}
	public void textInputKeyEvent(uint timestamp, uint windowID, TextInputKey key, ushort modifier = 0){
		switch(key){
			case TextInputKey.ESCAPE:
				inputhandler.stopTextInput(this);
				break;
			case TextInputKey.ENTER:
				inputhandler.stopTextInput(this);
				//invokeActionEvent(new Event(source, null, null, null, text, text.length, EventType.TEXTINPUT));
				if(onTextInput !is null)
					onTextInput(new Event(source, null, null, null, text, cast(int)text.charLength, EventType.TEXTINPUT, null, this));
				break;
			case TextInputKey.BACKSPACE:
				if(cursorPos > 0){
					deleteCharacter(cursorPos - 1);
					cursorPos--;
					draw();
				}
				break;
			case TextInputKey.DELETE:
				deleteCharacter(cursorPos);
				draw();
				break;
			case TextInputKey.CURSORLEFT:
				if(cursorPos > 0){
					--cursorPos;
					draw();
				}
				break;
			case TextInputKey.CURSORRIGHT:
				if(cursorPos < text.charLength){
					++cursorPos;
					draw();
				}
				break;
			case TextInputKey.INSERT:
				insert = !insert;
				draw();
				break;
			case TextInputKey.HOME:
				cursorPos = 0;
				draw();
				break;
			case TextInputKey.END:
				cursorPos = text.charLength;
				draw();
				break;
			default:
				break;

		}
	}
	public void dropTextInput(){
		parent.endPopUpSession();
		//inputHandler.stopTextInput(source);
		/*draw();
		invokeActionEvent(EventType.TEXTINPUT, 0, text);*/
	}
}
