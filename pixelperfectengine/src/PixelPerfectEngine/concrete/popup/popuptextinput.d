module pixelperfectengine.concrete.popup.popuptextinput;

public import pixelperfectengine.concrete.popup.base;

/**
 * Text input in pop-up fashion.
 */
public class PopUpTextInput : PopUpElement, TextInputListener {
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
		inputhandler.startTextInput(this, false, position);
	}
	public override void draw(){
		StyleSheet ss = getStyleSheet();
		const Box mainPos = Box(0,0,position.width - 1, position.height - 1);
		output.drawFilledBox(mainPos, ss.getColor("window"));
		output.drawBox(mainPos, ss.getColor("windowascent"));
		const int textPadding = getStyleSheet.drawParameters["TextSpacingSides"];
		Coordinate textPos = Coordinate(textPadding,(position.height / 2) - (text.font.size / 2) ,
				position.width,position.height - textPadding);
		
		const int y = text.font.size;
		//if(x > textPos.width ) xOffset = horizTextOffset;
		//draw cursor
		if(enableEdit) {
			const int x0 = text.getWidth(0,cursorPos) + textPadding - horizTextOffset;
			if(!insert){
				//output.drawLine(x0, x0, 2, 2 + y, getStyleSheet().getColor("selection"));
				output.drawLine(Point(x0, 2), Point(x0, 2 + y), ss.getColor("selection"));
			}else{
				const int x1 = cursorPos == text.charLength ? text.font.chars(' ').xadvance :
						text.getWidth(cursorPos,cursorPos + 1);
				//output.drawFilledRectangle(x0, x1 + x0, 2, 2 + y, getStyleSheet().getColor("selection"));
				output.drawFilledBox(Box(x0, 2, x1, 2 + y), ss.getColor("selection"));
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
			 if(cursorPos == this.text.text.length) {
				horizTextOffset = x - textPos.width;
			 } else if(cursorPixelPos < horizTextOffset) { //Test for whether the cursor would fall out from the current text area
				horizTextOffset = cursorPixelPos;
			 } else if(cursorPixelPos > horizTextOffset + textPos.width) {
				horizTextOffset = horizTextOffset + textPos.width;
			 }
		}
		draw();
	}
	/**
     * Passes text editing events to the target, alongside with a window ID and a timestamp.
     */
	public void textEditingEvent(uint timestamp, uint windowID, dstring text, int start, int length) {
		for (int i ; i < length ; i++) {
			this.text.overwriteChar(start + i, text[i]);
		}
		cursorPos = start + length;
	}
	/**
     * Passes text input key events to the target, e.g. cursor keys.
     */
	public void textInputKeyEvent(uint timestamp, uint windowID, TextInputKey key, ushort modifier = 0){
		switch(key){
			case TextInputKey.Escape:
				inputhandler.stopTextInput();
				break;
			case TextInputKey.Enter:
				inputhandler.stopTextInput();
				//invokeActionEvent(new Event(source, null, null, null, text, text.length, EventType.TEXTINPUT));
				if(onTextInput !is null)
					onTextInput(new Event(this, text, EventType.TextInput, SourceType.PopUpElement));
				break;
			case TextInputKey.Backspace:
				if(cursorPos > 0){
					deleteCharacter(cursorPos - 1);
					cursorPos--;
					draw();
				}
				break;
			case TextInputKey.Delete:
				deleteCharacter(cursorPos);
				draw();
				break;
			case TextInputKey.CursorLeft:
				if(cursorPos > 0){
					--cursorPos;
					draw();
				}
				break;
			case TextInputKey.CursorRight:
				if(cursorPos < text.charLength){
					++cursorPos;
					draw();
				}
				break;
			case TextInputKey.Insert:
				insert = !insert;
				draw();
				break;
			case TextInputKey.Home:
				cursorPos = 0;
				draw();
				break;
			case TextInputKey.End:
				cursorPos = text.charLength;
				draw();
				break;
			default:
				break;

		}
	}
	public void dropTextInput(){
		parent.endPopUpSession(this);
		
	}
	public void initTextInput() {
	}
}
