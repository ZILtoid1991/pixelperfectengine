module pixelperfectengine.concrete.elements.menubar;

public import pixelperfectengine.concrete.elements.base;
public import pixelperfectengine.concrete.popup;

/**
 * Menubar containing menus in a tree-like structure.
 */
public class MenuBar : WindowElement {
	private PopUpMenuElement[] menus;
	//private wstring[] menuNames;
	private int[] menuWidths;
	//private PopUpHandler popUpHandler;
	private int select, usedWidth;
	public EventDeleg onMenuEvent;
	public this(string source, Box position, PopUpMenuElement[] menus, StyleSheet customStyle = null){
		this.customStyle = customStyle;
		this.source = source;
		this.position = position;
		//this.popUpHandler = popUpHandler;
		this.menus = menus;
		select = -1;
		menuWidths.length = menus.length + 1;
		menuWidths[0] = position.left;
		const int spacing = 2 * getStyleSheet().drawParameters["MenuBarHorizPadding"];
		for (size_t i ; i < menus.length ; i++) {
			menuWidths[i + 1] = menuWidths[i] + menus[i].text.getWidth + spacing;
		}
	}
	public override void draw() {
		StyleSheet ss = getStyleSheet();
		with (parent) {
			drawFilledBox(position, ss.getColor("window"));
			drawLine(position.cornerUL, position.cornerUR, ss.getColor("windowascent"));
			drawLine(position.cornerUL, position.cornerLL, ss.getColor("windowascent"));
			drawLine(position.cornerLL, position.cornerLR, ss.getColor("windowdescent"));
			drawLine(position.cornerUR, position.cornerLR, ss.getColor("windowdescent"));
		}
		if (select > -1) {
			parent.drawFilledBox(Box(menuWidths[select], position.top + 1, menuWidths[select + 1], position.bottom - 1), 
					ss.getColor("selection"));
		}
		foreach (size_t i, PopUpMenuElement menuItem ; menus) {
			parent.drawTextSL(Box(menuWidths[i], position.top, menuWidths[i+1], position.bottom), menuItem.text, Point(0,0));
		}
		if (onDraw !is null) {
			onDraw();
		}
	}
	private void redirectIncomingEvents(Event ev){
		if(onMenuEvent !is null){
			onMenuEvent(ev);
		}
	}
	///Passes mouse click event
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		if (state != ElementState.Enabled) return;
		if (mce.state) {
			for (int i ; i < menus.length ; i++) {
				if (menuWidths[i] < mce.x && menuWidths[i + 1] > mce.x) {
					select = i;
					draw;
					Coordinate c = parent.getAbsolutePosition(this);
					parent.addPopUpElement(new PopUpMenu(menus[i].getSubElements, source, &redirectIncomingEvents), c.left + 
							menuWidths[i], c.bottom);
					super.passMCE(mec, mce);
					return;
				}
			}
		}
		select = -1;
		super.passMCE(mec, mce);
	}
	///Passes mouse move event
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		if (position.isBetween(mme.x, mme.y)) {
			for (int i ; i < menus.length ; i++) {
				if (menuWidths[i] < mme.x && menuWidths[i + 1] > mme.x) {
					select = i;
					draw;
					return;
				}
			}
		}
		select = -1;
		draw;
		super.passMME(mec, mme);
	}
	///Called when an object loses focus.
	public override void focusTaken() {
		select = -1;
		super.focusTaken();
	}
}
