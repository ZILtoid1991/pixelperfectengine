module PixelPerfectEngine.concrete.elements.textbox;

public import PixelPerfectEngine.concrete.elements.base;

/**
 * Text input box
 */
public class TextBox : WindowElement, TextInputListener{
	//protected bool enableEdit, insert;
	protected static enum	INSERT = 1<<9;
	protected static enum	ENABLE_TEXT_EDIT = 1<<10;
	protected size_t cursorPos;
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
	/+public override void onClick(int offsetX, int offsetY, int state, ubyte button){
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
	}+/
	///Called when an object loses focus.
	public override void focusLost() {
		flags &= ~IS_FOCUSED;
		dropTextInput();
		inputHandler.stopTextInput();
		
	}
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		if (!(flags & ENABLE_TEXT_EDIT)) inputHandler.startTextInput(this);
		else {

		}
		super.passMCE(mec, mce);
	}
	public override void draw(){
		/+if(output.output.width != position.width || output.output.height != position.height)
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
		}+/
		StyleSheet ss = getStyleSheet();
		const int textPadding = ss.drawParameters["TextSpacingSides"];
		with (parent) {
			drawFilledBox(position, ss.getColor("window"));
			drawBox(position, ss.getColor("windowascent"));
		}
		//draw cursor
		if (flags & ENABLE_TEXT_EDIT) {
			//calculate cursor first
			Box cursor = Box(position.left, position.top + textPadding, position.left, position.bottom - textPadding);
			cursor.left += text.getWidth(0, cursorPos) - horizTextOffset;
			//cursor must be at least single pixel wide
			cursor.right = cursor.left;
			if (select) {
				cursor.right += text.getWidth(cursorPos, cursorPos + select);
			} else if (flags & INSERT) {
				if (cursorPos < text.charLength) cursor.right += text.getWidth(cursorPos, cursorPos+1);
				else cursor.right += text.font.chars(' ').xadvance;
			}
			//Clamp down if cursor is wider than the text editing area
			cursor.right = cursor.right <= position.right - textPadding ? cursor.right : position.right - textPadding;
			//Draw cursor
			parent.drawFilledBox(cursor, ss.getColor("selection"));
			
		}
		//draw text
		parent.drawTextSL(position - textPadding, text, Point(horizTextOffset, 0));
		if (isFocused) {
			parent.drawBoxPattern(position - textPadding, ss.pattern["blackDottedLine"]);
		}

		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
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

	public void dropTextInput() {
		flags &= ~ENABLE_TEXT_EDIT;
		horizTextOffset = 0;
		cursorPos = 0;
		//inputHandler.stopTextInput(source);
		draw();
		//invokeActionEvent(EventType.TEXTINPUT, 0, text);
		/+if(onTextInput !is null)
			onTextInput(new Event(source, null, null, null, text, 0, EventType.TEXTINPUT, null, this));+/
	}
	public void initTextInput() {
		flags |= ENABLE_TEXT_EDIT;
		select = cast(int)text.charLength;
		draw();
	}

	public void textInputKeyEvent(uint timestamp, uint windowID, TextInputKey key, ushort modifier = 0){
		switch(key) {
			case TextInputKey.ENTER:
				inputHandler.stopTextInput(this);
				if(onTextInput !is null)
					onTextInput(new Event(source, null, null, null, text, 0, EventType.TEXTINPUT, null, this));
				break;
			case TextInputKey.ESCAPE:
				text = oldText;
				inputHandler.stopTextInput(this);
				

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