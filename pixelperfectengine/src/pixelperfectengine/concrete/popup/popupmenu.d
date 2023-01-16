module pixelperfectengine.concrete.popup.popupmenu;

import pixelperfectengine.concrete.popup.base;

/**
 * To create drop-down lists, menu bars, etc.
 */
public class PopUpMenu : PopUpElement {
	//private wstring[] texts;
	//private string[] sources;

	//private uint[int] hotkeyCodes;
	//protected Bitmap8Bit[int] icons;
	protected int width, height, select;
	PopUpMenuElement[] elements;
	public EventDeleg onMenuSelect;
	/**
	 * Creates a single PopUpMenu.
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

			//minwidth = (ss.drawParameters["PopUpMenuVertPadding"] * 2);
			//int width;
			foreach(e; elements){
				int newwidth = e.text.getWidth();// + (e is null) ? 0 : e.secondaryText.getWidth();
				if(e.secondaryText !is null) newwidth += e.secondaryText.getWidth() + ss.drawParameters["PopUpMenuMinTextSpace"];
				//assert(newwidth);
				//writeln(e.text.getWidth());
				if(newwidth > width){
					width = newwidth;
					//writeln(width);
				}
				height += e.text.font.size + (ss.drawParameters["PopUpMenuVertPadding"] * 2);
			}
			width += (ss.drawParameters["PopUpMenuHorizPadding"] * 2);
			height += ss.drawParameters["PopUpMenuVertPadding"] * 2;
			position = Box(0, 0, width - 1, height - 1);
			output = new BitmapDrawer(width, height);
		}
		Box position0 = Box(0, 0, width - 1, height - 1);
		output.drawFilledBox(position0, ss.getColor("window"));//output.drawFilledRectangle(0,width - 1,0,height - 1,ss.getColor("window"));

		if(select > -1){
			int y0 = cast(int)((height / elements.length) * select);
			int y1 = cast(int)((height / elements.length) + y0);
			output.drawFilledBox(Box(1, y0 + 1, position0.width - 1, y1 - 1), ss.getColor("selection")); //output.drawFilledRectangle(1, width - 1, y0 + 1, y1 + 1, ss.getColor("selection"));
		}


		int y = 1 + ss.drawParameters["PopUpMenuVertPadding"];
		foreach(e; elements){
			if(e.secondaryText !is null){
				/+output.drawColorText(width - ss.drawParameters["PopUpMenuHorizPadding"] - 1, y, e.secondaryText,
						ss.getFontset("default"), ss.getColor("PopUpMenuSecondaryTextColor"), FontFormat.RightJustified);+/
				//const int textLength = e.secondaryText.getWidth;
				const Box textPos = Box(ss.drawParameters["PopUpMenuHorizPadding"], y,
						position0.width - ss.drawParameters["PopUpMenuHorizPadding"], y + e.secondaryText.font.size);
				output.drawSingleLineText(textPos, e.secondaryText);
			}
			/+output.drawColorText(ss.drawParameters["PopUpMenuHorizPadding"] + iconWidth, y, e.text, ss.getFontset("default"),
					ss.getColor("normaltext"), 0);+/
			//const int textLength = e.text.getWidth;
			const Box textPos = Box(ss.drawParameters["PopUpMenuHorizPadding"], y,
					position0.width - ss.drawParameters["PopUpMenuHorizPadding"], y + e.text.font.size);
			output.drawSingleLineText(textPos, e.text);
			/+if(e.getIcon() !is null){
				//output.insertBitmap(ss.drawParameters["PopUpMenuHorizPadding"], y, e.getIcon());
			}+/
			y += e.text.font.size + (ss.drawParameters["PopUpMenuVertPadding"] * 2);
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
			mce.y /= height / elements.length;
			if(elements[mce.y].source == "\\submenu\\"){
				PopUpMenu m = new PopUpMenu(elements[mce.y].subElements, this.source, onMenuSelect);
				m.onMouseClick = onMouseClick;
				//parent.getAbsolutePosition()
				parent.addPopUpElement(m, position.left + width, position.top + mce.y * cast(int)(height / elements.length));
				//parent.closePopUp(this);
			}else{
				//invokeActionEvent(new Event(elements[offsetY].source, source, null, null, null, offsetY, EventType.CLICK));
				if(onMenuSelect !is null)
					onMenuSelect(new MenuEvent(this, SourceType.PopUpElement, elements[mce.y].text, mce.y, elements[mce.y].source));
				parent.endPopUpSession(this);
				//parent.closePopUp(this);
			}
		}

	}
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		if(!position.isBetween(mme.x, mme.y)){
			if(select != -1){
				select = -1;
				draw;
			}
		}else{
			mme.y -= position.top;
			mme.y /= height / elements.length;
			if(mme.y < elements.length){
				select = mme.y;
			}
			draw();
		}
	}

}
/**
* Defines a single MenuElement, also can contain multiple subelements.
*/
public class PopUpMenuElement {
	public string source;
	public Text text, secondaryText;
	//protected Bitmap8Bit icon;
	private PopUpMenuElement[] subElements;
	private ushort keymod;
	private int keycode;
	public int iconWidth;

	/**
	 * Generates a menu element with the supplied parameters.
	 * Uses the default formatting to initialize texts.
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
	 */
	public this(string source, Text text, Text secondaryText = null, PopUpMenuElement[] subElements = []) {
		this.source = source;
		this.text = text;
		this.secondaryText = secondaryText;
		this.subElements = subElements;
	}
	///DEPRECATED!
	///REMOVE BY VER 0.11!
	public Bitmap8Bit getIcon(){
		return text.icon;
	}
	///DEPRECATED!
	///REMOVE BY VER 0.11!
	public void setIcon(Bitmap8Bit icon){
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
