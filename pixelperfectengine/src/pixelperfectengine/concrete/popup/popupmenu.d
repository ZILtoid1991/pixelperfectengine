module pixelperfectengine.concrete.popup.popupmenu;

import pixelperfectengine.concrete.popup.base;

/**
 * To create drop-down lists, menu bars, etc.
 */
public class PopUpMenu : PopUpElement {
	protected int width, height, select;
	PopUpMenuElement[] elements;
	public EventDeleg onMenuSelect;
	/**
	 * Creates a single PopUpMenu.
	 * Params:
	 *   elements = entries for the menu.
	 *   source = source identifier.
	 *   onMenuSelect = event delegate called on item selection.
	 */
	public this(PopUpMenuElement[] elements, string source, EventDeleg onMenuSelect){
		this.elements = elements;
		this.source = source;
		//this. iconWidth = iconWidth;
		select = -1;
		this.onMenuSelect = onMenuSelect;
	}
	public override void draw(){
		StyleSheet ss = getStyleSheet();
		if(output is null){
			foreach(e; elements){
				int newwidth;// = e.text.getWidth();
				if(e.text !is null) newwidth = e.text.getWidth();
				if(e.secondaryText !is null) newwidth += e.secondaryText.getWidth() + ss.drawParameters["PopUpMenuMinTextSpace"];
				if(newwidth > width){
					width = newwidth;
				}
				if(e.text !is null) height += e.text.getHeight + (ss.drawParameters["PopUpMenuVertPadding"] * 2);
				else height += ss.drawParameters["PopUpMenuSeparatorSize"];
			}
			width += (ss.drawParameters["PopUpMenuHorizPadding"] * 2);
			height += ss.drawParameters["PopUpMenuVertPadding"] * 2;
			position = Box(0, 0, width - 1, height - 1);
			output = new BitmapDrawer(width, height);
		}
		Box position0 = Box(0, 0, width - 1, height - 1);
		output.drawFilledBox(position0, ss.getColor("window"));//output.drawFilledRectangle(0,width - 1,0,height - 1,ss.getColor("window"));

		/* if(select > -1){
			int y0 = cast(int)((height / elements.length) * select);
			int y1 = cast(int)((height / elements.length) + y0);
			output.drawFilledBox(Box(1, y0 + 1, position0.width - 1, y1 - 1), ss.getColor("selection")); //output.drawFilledRectangle(1, width - 1, y0 + 1, y1 + 1, ss.getColor("selection"));
		} */


		int y = 1 + ss.drawParameters["PopUpMenuVertPadding"];
		foreach(size_t i, PopUpMenuElement e; elements){
			if (e.text !is null) {	//Draw normal menuelement
						
				const Box textPos = Box(ss.drawParameters["PopUpMenuHorizPadding"], y,
						position0.width - ss.drawParameters["PopUpMenuHorizPadding"], y + e.text.getHeight());
				if (select == i) {
					output.drawFilledBox(Box(textPos.left, textPos.top + 1, textPos.right, textPos.bottom - 1), 
							ss.getColor("selection"));
				}
				output.drawSingleLineText(textPos, e.text);
				if (e.secondaryText !is null) {
				
					const Box textPos0 = Box(ss.drawParameters["PopUpMenuHorizPadding"], y,
							position0.width - ss.drawParameters["PopUpMenuHorizPadding"], y + e.secondaryText.getHeight());
					output.drawSingleLineText(textPos0, e.secondaryText);
				}
				y += e.text.getHeight() + (ss.drawParameters["PopUpMenuVertPadding"] * 2);
			} else {				//Draw separator
				const int linePoint = ss.drawParameters["PopUpMenuSeparatorSize"] / 2 + 
						(ss.drawParameters["PopUpMenuSeparatorSize"] & 1);
				output.drawLine(Point(ss.drawParameters["PopUpMenuHorizPadding"], y + linePoint), 
						Point(position.width - ss.drawParameters["PopUpMenuHorizPadding"] - 1, y + linePoint),
						ss.getColor("windowinactive"));
				y += ss.drawParameters["PopUpMenuSeparatorSize"];
			}
		}

		//output.drawRectangle(1,1,height-1,width-1,ss.getColor("windowascent"));
		/+output.drawLine(0,0,0,height-1,ss.getColor("windowascent"));
		output.drawLine(0,width-1,0,0,ss.getColor("windowascent"));
		output.drawLine(0,width-1,height-1,height-1,ss.getColor("windowdescent"));
		output.drawLine(width-1,width-1,0,height-1,ss.getColor("windowdescent"));+/
		with (output) {
			drawLine(position0.cornerUL, position0.cornerUR, ss.getColor("windowascent"));
			drawLine(position0.cornerUL, position0.cornerLL, ss.getColor("windowascent"));
			drawLine(position0.cornerLL, position0.cornerLR, ss.getColor("windowdescent"));
			drawLine(position0.cornerUR, position0.cornerLR, ss.getColor("windowdescent"));
		}
		if(onDraw !is null){
			onDraw();
		}
	}
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		if (mce.state) {
			mce.y -= position.top;
			/* mce.y /= height / elements.length;
			mce.y = mce.y >= elements.length ? cast(int)elements.length - 1 : mce.y; */
			int num, vPos = 1 + getStyleSheet().drawParameters["PopUpMenuVertPadding"];
			foreach (PopUpMenuElement key; elements) {
				if (key.text !is null) {
					vPos += key.text.getHeight() + getStyleSheet.drawParameters["PopUpMenuVertPadding"] * 2;
				} else {
					vPos += getStyleSheet.drawParameters["PopUpMenuSeparatorSize"];
				}
				if (vPos > mce.y) {
					break;
				} else {
					num++;
				}
			}
			if (num >= elements.length) return;
			if (elements[num].source == "\\submenu\\") {
				PopUpMenu m = new PopUpMenu(elements[num].subElements, this.source, onMenuSelect);
				m.onMouseClick = onMouseClick;
				//parent.getAbsolutePosition()
				parent.addPopUpElement(m, position.left + width, position.top + vPos - elements[num].text.getHeight);
				//parent.closePopUp(this);
			} else if (elements[num].text !is null) {
				//invokeActionEvent(new Event(elements[offsetY].source, source, null, null, null, offsetY, EventType.CLICK));
				if(onMenuSelect !is null)
					onMenuSelect(new MenuEvent(this, SourceType.PopUpElement, elements[num].text, num, elements[num].source));
				parent.endPopUpSession(this);
				//parent.closePopUp(this);
			}
		}

	}
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		if (!position.isBetween(mme.x, mme.y)) {
			if(select != -1){
				select = -1;
			}
		} else {
			int num, vPos = 1 + getStyleSheet().drawParameters["PopUpMenuVertPadding"];
			mme.y -= position.top;
			foreach (PopUpMenuElement key; elements) {
				if (key.text !is null) {
					vPos += key.text.getHeight() + getStyleSheet.drawParameters["PopUpMenuVertPadding"] * 2;
				} else {
					vPos += getStyleSheet.drawParameters["PopUpMenuSeparatorSize"];
				}
				if (vPos > mme.y) { 
					select = num;
					break;
				}
				num++;
				
			}
		}
		draw();
	}

}
/**
* Defines a single MenuElement, also can contain multiple subelements.
*/
public class PopUpMenuElement {
	public string source;					///Source identifier.
	public Text text, secondaryText;		///Primary and secondary display texts
	//protected Bitmap8Bit icon;
	private PopUpMenuElement[] subElements;	///Any child element the menu may have
	//private ushort keymod;
	//private int keycode;
	//public int iconWidth;

	/**
	 * Generates a menu element with the supplied parameters.
	 * Uses the default formatting to initialize texts.
	 * Params:
	 *   source = source identifier.
	 *   text = primary text, forced to be left justified.
	 *   secondaryText = secondary text, forced to be right justified.
	 *   subElements = any child elements for further submenus.
	 */
	public this(string source, dstring text, dstring secondaryText = "", PopUpMenuElement[] subElements = null) {
		StyleSheet ss = globalDefaultStyle;
		Text st;
		if (secondaryText.length) {
			st = new Text(secondaryText, ss.getChrFormatting("popUpMenuSecondary"));
		}
		this(source, new Text(text, ss.getChrFormatting("popUpMenu")), st, subElements);
	}
	/**
	 * Generates a menu element with the supplied parameters.
	 * Text formatting can be supplied with the objects.
	 * Params:
	 *   source = source identifier.
	 *   text = primary text, forced to be left justified.
	 *   secondaryText = secondary text, forced to be right justified.
	 *   subElements = any child elements for further submenus.
	 */
	public this(string source, Text text, Text secondaryText = null, PopUpMenuElement[] subElements = []) {
		this.source = source;
		this.text = text;
		this.secondaryText = secondaryText;
		this.subElements = subElements;
	}
	///Creates an empty separator element.
	public static PopUpMenuElement createSeparator() {
		Text nulltext = null;
		return new PopUpMenuElement("\\separator\\", nulltext, nulltext);
	}
	///DEPRECATED!
	///REMOVE BY VER 0.11!
	public deprecated Bitmap8Bit getIcon(){
		return text.icon;
	}
	///DEPRECATED!
	///REMOVE BY VER 0.11!
	public deprecated void setIcon(Bitmap8Bit icon){
		text.icon = icon;
	}
	///Returns all subelements of this menu element.
	public PopUpMenuElement[] getSubElements() {
		return subElements;
	}
	/**
	 * Assigns this current object's all subelements at once.
	 */
	public void loadSubElements(PopUpMenuElement[] e){
		subElements = e;
	}
	/**
	 * Gets the subelement at the given index.
	 */
	public PopUpMenuElement opIndex(size_t i){
		return subElements[i];
	}
	/**
	 * Sets the subelement at the given index.
	 */
	public PopUpMenuElement opIndexAssign(PopUpMenuElement value, size_t i){
		subElements[i] = value;
		return value;
	}
	/**
	 * Implements appending to the last position of the underlying array.
	 */
	public PopUpMenuElement opOpAssign(string op)(PopUpMenuElement value){
		static if(op == "~"){
			subElements ~= value;
			return value;
		}else static assert("Operator " ~ op ~ " not supported!");
	}
	///Returns the lenght of the underlying array.
	public size_t getLength(){
		return subElements.length;
	}
	///Sets the lenght of the underlying array.
	public void setLength(int l){
		subElements.length = l;
	}

}
