module pixelperfectengine.concrete.elements.textbox;

public import pixelperfectengine.concrete.elements.base;

/**
 * Text input box.
 */
public class TextBox : WindowElement, TextInputListener {
	//protected bool enableEdit, insert;
	protected static enum	INSERT = 1<<9;
	protected static enum	ENABLE_TEXT_EDIT = 1<<10;
	protected size_t cursorPos;
	protected int horizTextOffset, cursorSel = -1;
	protected Text oldText;
	///Contains an input filter. or null if no filter is used.
	protected InputFilter filter;
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
	/**
	 * Sets an external input filter.
	 */
	public void setFilter (InputFilter f) {
		filter = f;
	}
	/**
	 * Sets an internal input filter
	 */
	public void setFilter (TextInputFieldType t) {
		final switch (t) with(TextInputFieldType) {
			case None:
				filter = null;
				break;
			case Text:
				filter = null;
				break;
			case ASCIIText:
				break;
			case Decimal:
				filter = new DecimalFilter!true();
				break;
			case Integer:
				filter = new IntegerFilter!true();
				break;
			case DecimalP:
				filter = new DecimalFilter!false();
				break;
			case IntegerP:
				filter = new IntegerFilter!false();
				break;
			case Hex:
				break;
			case Oct:
				break;
			case Bin:
				break;
		}
	}
	///Called when an object loses focus.
	public void focusLost() {
		flags &= ~IS_FOCUSED;
		if (flags & ENABLE_TEXT_EDIT) inputHandler.stopTextInput();
	}
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		if (!(flags & ENABLE_TEXT_EDIT)) inputHandler.startTextInput(this, false, position);
		super.passMCE(mec, mce);
	}
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		if (position.isBetween(mme.x, mme.y)) parent.requestCursor(StandardCursors.TextSelect);
		super.passMME(mec, mme);
	}
	public override void draw(){
		if (parent is null || state == ElementState.Hidden) return;
		StyleSheet ss = getStyleSheet();
		const int textPadding = ss.drawParameters["TextSpacingSides"];
		with (parent) {
			clearArea(position);
			drawBox(position, ss.getColor("windowascent"));
		}
		//draw cursor
		if (flags & ENABLE_TEXT_EDIT) {
			//calculate cursor first
			const leftmostCursorPos = cursorPos > cursorSel && cursorSel != -1 ? cursorSel : cursorPos;
			Box cursor = Box(position.left + textPadding, position.top + textPadding, position.left + textPadding, 
					position.bottom - textPadding);
			cursor.left += text.getWidth(0, leftmostCursorPos) - horizTextOffset;
			//cursor must be at least single pixel wide
			cursor.right = cursor.left;
			if (cursorSel != -1) {
				if (cursorSel > cursorPos) cursor.right += text.getWidth(cursorPos, cursorSel);
				else cursor.right += text.getWidth(cursorSel, cursorPos);
			} else if (flags & INSERT) {
				if (cursorPos < text.charLength) cursor.right += text.getWidth(cursorPos, cursorPos+1);
				else cursor.right += text.font.chars(' ').xadvance;
			} else {
				cursor.right++;
			}
			//Clamp down if cursor is wider than the text editing area
			cursor.right = cursor.right <= position.right - textPadding ? cursor.right : position.right - textPadding;
			cursor.right = cursor.right < position.left ? position.left + textPadding : cursor.right;
			cursor.left = cursor.left > cursor.right ? cursor.right : cursor.left;
			cursor.left = cursor.left < position.left ? position.left + textPadding : cursor.left;
			//Draw cursor
			parent.drawFilledBox(cursor, ss.getColor("selection"));
			
		}
		//draw text
		parent.drawTextSL(position - (textPadding + 1), text, Point(horizTextOffset, 0));
		if (isFocused) {
			parent.drawBoxPattern(position - textPadding, ss.pattern["blackDottedLine"]);
		}

		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}

		if (onDraw !is null) {
			onDraw();
		}
		parent.updateOutput(this);
	}
	/**
     * Passes text editing events to the target, alongside with a window ID and a timestamp.
     */
	public void textEditingEvent(Timestamp timestamp, OSWindow windowID, dstring text, int start, int length) {
		for (int i ; i < length ; i++) {
			this.text.overwriteChar(start + i, text[i]);
		}
		cursorPos = start + length;
	}
	private void deleteCharacter(size_t n){
		text.removeChar(n);
	}
	public void textInputEvent(Timestamp timestamp, OSWindow windowID, dstring text) {
		import pixelperfectengine.system.etc : removeUnallowedSymbols;
		if (filter) {
			filter.use(text);
			if (!text.length) return;
		}
		if (cursorSel != -1) {
			if (cursorSel > cursorPos) this.text.removeChar(cursorPos, cursorSel);
			else this.text.removeChar(cursorSel, cursorPos);
			cursorSel = -1;
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
		checkCursorPos();
		draw();
	}
	private void checkCursorPos() {
		const int textPadding = getStyleSheet.drawParameters["TextSpacingSides"];
		const Box textPos = Box(textPadding,(position.height / 2) - (this.text.font.size / 2) ,
				position.width - textPadding,position.height - textPadding);
		const int x = this.text.getWidth(), cursorPixelPos = this.text.getWidth(0, cursorPos);
		if (x > textPos.width) {
			if (cursorPos == this.text.charLength) {		// cursor is at last character
				horizTextOffset = x - textPos.width + textPadding;
			} else if (cursorPixelPos - horizTextOffset < 0) { // cursor would fall out at left hand side
				horizTextOffset = cursorPixelPos;
			} else if (cursorPixelPos - horizTextOffset > textPos.width) {	//cursor would fall out at right hand side
				horizTextOffset = cursorPixelPos - textPos.width + (textPadding * 2);
			}
		} else {
			horizTextOffset = 0;
		}
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
		cursorSel = cast(int)text.charLength;
		oldText = new Text(text);
		draw();
	}

	public void textInputKeyEvent(Timestamp timestamp, OSWindow window, TextCommandEvent command){
		switch(command.type) {
			case TextCommandType.Cancel:
				inputHandler.stopTextInput();
				break;
			case TextCommandType.NewLine, TextCommandType.NewPara:
				inputHandler.stopTextInput();
				//invokeActionEvent(new Event(source, null, null, null, text, text.length, EventType.TEXTINPUT));
				if(onTextInput !is null) onTextInput(new Event(this, text, EventType.TextInput, SourceType.PopUpElement));
				break;
			case TextCommandType.Delete:
				if (cursorSel != -1) {
					if (cursorSel > cursorPos) text.removeChar(cursorPos, cursorSel);
					else text.removeChar(cursorSel, cursorPos);
					cursorSel = -1;
				} else if (command.amount < 0){
					if(cursorPos > 0){
						deleteCharacter(cursorPos - 1);
						cursorPos--;
					}
				} else {
					deleteCharacter(cursorPos);
				}
				checkCursorPos();
				draw();
				break;
			case TextCommandType.Cursor:
				if (command.flags & TextCommandFlags.Select) {
					if (cursorSel == -1) cursorSel = cast(int)cursorPos;
					if (command.flags & TextCommandFlags.PerWord) {
						while (cursorSel + command.amount >= 0 && cursorSel + command.amount <= text.charLength) {
							cursorSel += command.amount;
							if (text.getChar(cursorSel) == ' ') break;
						} 
					} else if (cursorSel + command.amount >= 0 && cursorSel + command.amount <= text.charLength) {
						cursorSel += command.amount;
					}
				} else {
					if (cursorSel != -1) {
						if (command.amount > 0 && cursorSel > cursorPos)  cursorPos = cursorSel;
						else if (command.amount < 0 && cursorSel < cursorPos) cursorPos = cursorSel;
					}
					cursorSel = -1;
					if (command.flags & TextCommandFlags.PerWord) {
						while (cursorPos + command.amount >= 0 && cursorPos + command.amount <= text.charLength) {
							cursorPos += command.amount;
							if (text.getChar(cursorPos) == ' ') break;
						} 
					} else if(cursorPos + command.amount >= 0 && cursorPos + command.amount <= text.charLength) {
						cursorPos += command.amount;
					}
				}
				checkCursorPos();
				draw();
				break;
			case TextCommandType.Home:
				if (command.flags & TextCommandFlags.Select) {
					cursorSel = 0;
				} else {
					cursorSel = -1;
					cursorPos = 0;
				}
				checkCursorPos();
				draw();
				break;
			case TextCommandType.End:
				if (command.flags & TextCommandFlags.Select) {
					cursorSel = cast(int)(text.charLength);
				} else {
					cursorSel = -1;
					cursorPos = cast(int)text.charLength;
				}
				checkCursorPos();
				draw();
				break;
			case TextCommandType.Insert:
				flags ^= INSERT;
				draw();
				break;
			default:
				break;
		}
	}
	public bool isAcceptingTextInput() const {
		return (flags & ENABLE_TEXT_EDIT) != 0;
	}
}
