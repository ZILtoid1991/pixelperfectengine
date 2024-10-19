module pixelperfectengine.concrete.popup.popuptextinput;

public import pixelperfectengine.concrete.popup.base;

/**
 * Text input in pop-up fashion.
 */
public class PopUpTextInput : PopUpElement, TextInputListener {
	protected bool enableEdit, insert;
	protected size_t cursorPos;
	protected int horizTextOffset, cursorSel;
	public void delegate(Event ev) onTextInput;

	public this(string source, Text text, Box position, EventDeleg onTextInput = null){
		this.source = source;
		this.text = text;
		this.position = position;
		this.onTextInput = onTextInput;
		enableEdit = true;
		output = new BitmapDrawer(position.width, position.height);
		inputhandler.startTextInput(this, false, position);
	}
	public override void draw() {
		StyleSheet ss = getStyleSheet();
		const Box mainPos = Box.bySize(0, 0, position.width, position.height);
		synchronized {
			output.drawFilledBox(Box.bySize(1, 1, position.width - 1, position.height - 1), ss.getColor("window"));
			output.drawBox(mainPos, ss.getColor("windowascent"));
		}
		const int textPadding = getStyleSheet.drawParameters["TextSpacingSides"];
		Box textPos = Box(textPadding, (position.height / 2) - (text.font.size / 2), position.width - textPadding,
				position.height - textPadding);
		
		const int y = text.font.size;
		//if(x > textPos.width ) xOffset = horizTextOffset;
		//draw cursor
		if(enableEdit) {
			//calculate cursor first
			const leftmostCursorPos = cursorPos > cursorSel && cursorSel != -1 ? cursorSel : cursorPos;
			Box cursor = Box(textPadding, textPadding, textPadding, position.height - textPadding);
			cursor.left += text.getWidth(0, leftmostCursorPos) - horizTextOffset;
			//cursor must be at least single pixel wide
			cursor.right = cursor.left;
			if (cursorSel != -1) {
				if (cursorSel > cursorPos) cursor.right += text.getWidth(cursorPos, cursorSel);
				else cursor.right += text.getWidth(cursorSel, cursorPos);
			} else if (insert) {
				if (cursorPos < text.charLength) cursor.right += text.getWidth(cursorPos, cursorPos+1);
				else cursor.right += text.font.chars(' ').xadvance;
			} else {
				cursor.right++;
			}
			//Clamp down if cursor is wider than the text editing area
			cursor.right = cursor.right <= position.width - textPadding ? cursor.right : position.width - textPadding;
			cursor.right = cursor.right < 0 ? textPadding : cursor.right;
			cursor.left = cursor.left > cursor.right ? cursor.right : cursor.left;
			cursor.left = cursor.left < 0 ? textPadding : cursor.left;
			//Draw cursor
			output.drawFilledBox(cursor, ss.getColor("selection"));
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
	public void textInputEvent(Timestamp timestamp, OSWindow window, dstring text){
		for(int j ; j < text.length ; j++){
			this.text.insertChar(cursorPos++, text[j]);
		}
		checkCursorPos();
		draw();
	}
	/**
     * Passes text editing events to the target, alongside with a window ID and a timestamp.
     */
	public void textEditingEvent(Timestamp timestamp, OSWindow window, dstring text, int start, int length) {
		for (int i ; i < length ; i++) {
			this.text.overwriteChar(start + i, text[i]);
		}
		cursorPos = start + length;
	}
	/**
     * Passes text input key events to the target, e.g. cursor keys.
     */
	public void textInputKeyEvent(Timestamp timestamp, OSWindow window, TextCommandEvent command) {
		switch(command.type) {
			case TextCommandType.Cancel:
				inputhandler.stopTextInput();
				break;
			case TextCommandType.NewLine, TextCommandType.NewPara:
				inputhandler.stopTextInput();
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
				//flags ^= INSERT;
				//draw();
				break;
			default:
				break;

		}
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
				horizTextOffset = cursorPixelPos - textPos.width - textPadding;
			}
		} else {
			horizTextOffset = 0;
		}
	}
	public void dropTextInput(){
		parent.endPopUpSession(this);
		
	}
	public void initTextInput() {
	}
}
