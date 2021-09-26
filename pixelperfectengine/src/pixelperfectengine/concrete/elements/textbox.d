module pixelperfectengine.concrete.elements.textbox;

public import pixelperfectengine.concrete.elements.base;

/**
 * Text input box
 */
public class TextBox : WindowElement, TextInputListener {
	//protected bool enableEdit, insert;
	protected static enum	INSERT = 1<<9;
	protected static enum	ENABLE_TEXT_EDIT = 1<<10;
	protected size_t cursorPos;
	protected int horizTextOffset, select;
	protected Text oldText;
	///List of allowed characters if length is not null.
	///Can be used for numeric-only inputs.
	public dstring 			allowedChars;
	///Symbols for positive integer inputs.
	public static immutable dstring INTEGER_POS = "0123456789";
	///Symbols for integer inputs.
	public static immutable dstring INTEGER = "-0123456789";
	///Symbols for decimal inputs.
	public static immutable dstring DECIMAL = ".-0123456789";
	//public int brush, textpos;
	//public TextInputHandler tih;
	public void delegate(Event ev) onTextInput;
	public this(dstring text, string source, Coordinate coordinates) {
		this(new Text(text, getStyleSheet().getChrFormatting("textBox")), source, coordinates);
	}
	public this(Text text, string source, Coordinate coordinates) {
		position = coordinates;
		this.text = text;
		this.source = source;
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
	public void focusLost() {
		flags &= ~IS_FOCUSED;
		dropTextInput();
		inputHandler.stopTextInput();
		
	}
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		if (!(flags & ENABLE_TEXT_EDIT)) inputHandler.startTextInput(this, false, position);
		super.passMCE(mec, mce);
	}
	public override void draw(){
		
		StyleSheet ss = getStyleSheet();
		const int textPadding = ss.drawParameters["TextSpacingSides"];
		with (parent) {
			clearArea(position);
			drawBox(position, ss.getColor("windowascent"));
		}
		//draw cursor
		if (flags & ENABLE_TEXT_EDIT) {
			//calculate cursor first
			Box cursor = Box(position.left + textPadding, position.top + textPadding, position.left + textPadding, position.bottom - textPadding);
			cursor.left += text.getWidth(0, cursorPos) - horizTextOffset;
			//cursor must be at least single pixel wide
			cursor.right = cursor.left;
			if (select) {
				cursor.right += text.getWidth(cursorPos, cursorPos + select);
			} else if (flags & INSERT) {
				if (cursorPos < text.charLength) cursor.right += text.getWidth(cursorPos, cursorPos+1);
				else cursor.right += text.font.chars(' ').xadvance;
			} else {
				cursor.right++;
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

		if (onDraw !is null) {
			onDraw();
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
	public void textInputEvent(uint timestamp, uint windowID, dstring text) {
		import pixelperfectengine.system.etc : removeUnallowedSymbols;
		if (allowedChars.length) {
			text = removeUnallowedSymbols(text, allowedChars);
			if (!text.length) return;
		}
		if (select) {
			this.text.removeChar(cursorPos, select);
			select = 0;
			for(int j ; j < text.length ; j++){
				this.text.insertChar(cursorPos++, text[j]);
			}
		} else if (flags & INSERT) {
			for(int j ; j < text.length ; j++){
				this.text.overwriteChar(cursorPos++, text[j]);
			}
		} else {
			for(int j ; j < text.length ; j++){
				this.text.insertChar(cursorPos++, text[j]);
			}
		}
		const int textPadding = getStyleSheet.drawParameters["TextSpacingSides"];
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
		oldText = new Text(text);
		draw();
	}

	public void textInputKeyEvent(uint timestamp, uint windowID, TextInputKey key, ushort modifier = 0){
		switch(key) {
			case TextInputKey.Enter:
				inputHandler.stopTextInput();
				if(onTextInput !is null)
					onTextInput(new Event(this, text, EventType.TextInput, SourceType.WindowElement));
					//onTextInput(new Event(source, null, null, null, text, 0, EventType.T, null, this));
				break;
			case TextInputKey.Escape:
				text = oldText;
				inputHandler.stopTextInput();
				

				break;
			case TextInputKey.Backspace:
				if (select) {
					for (int i ; i < select ; i++) {
						deleteCharacter(cursorPos - 1);
						cursorPos--;
					}
					select = 0;
				} else if (cursorPos > 0) {
					deleteCharacter(cursorPos - 1);
					cursorPos--;
					draw();
				}
				break;
			case TextInputKey.Delete:
				if (select) {
					for (int i ; i < select ; i++) {
						deleteCharacter(cursorPos);
					}
					select = 0;
				} else {
					deleteCharacter(cursorPos);
				}
				draw();
				break;
			case TextInputKey.CursorLeft:
				if (modifier != KeyModifier.Shift) {
					select = 0;
					if(cursorPos > 0){
						--cursorPos;
						draw();
					}
				}
				break;
			case TextInputKey.CursorRight:
				if (modifier != KeyModifier.Shift) {
					select = 0;
					if(cursorPos < text.charLength){
						++cursorPos;
						draw();
					}
				}
				break;
			case TextInputKey.Home:
				if (modifier != KeyModifier.Shift) {
					select = 0;
					cursorPos = 0;
					draw();
				}
				break;
			case TextInputKey.End:
				if (modifier != KeyModifier.Shift) {
					select = 0;
					cursorPos = text.charLength;
					draw();
				}
				break;
			case TextInputKey.Insert:
				flags ^= INSERT;
				draw();
				break;
			default:
				break;
		}
	}
}