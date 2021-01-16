module PixelPerfectEngine.concrete.elements.menubar;

public import PixelPerfectEngine.concrete.elements.base;
public import PixelPerfectEngine.concrete.popup;

/**
 * Menubar containing menus in a tree-like structure.
 */
public class MenuBar : WindowElement {
	private PopUpMenuElement[] menus;
	//private wstring[] menuNames;
	private int[] menuWidths;
	//private PopUpHandler popUpHandler;
	private int select, usedWidth;
	public this(string source, Coordinate position, PopUpMenuElement[] menus){
		this.source = source;
		this.position = position;
		//this.popUpHandler = popUpHandler;
		this.menus = menus;
		select = -1;
		menuWidths.length = menus.length + 1;
		menuWidths[0] = position.left;
		for (size_t i ; i < menus.length ; i++) {
			menuWidths[i + 1] = menuWidths[i] + menus[i].text.getWidth;
		}
	}
	public override void draw() {
		StyleSheet ss = getStyleSheet();
		with (parent) {
			drawFilledBox(position, ss.getColor("window"));
			drawLine(position.cornerUL, position.cornerUR, ss.getColor("windowAscent"));
			drawLine(position.cornerUL, position.cornerLL, ss.getColor("windowAscent"));
			drawLine(position.cornerLL, position.cornerLR, ss.getColor("windowDescent"));
			drawLine(position.cornerUR, position.cornerLR, ss.getColor("windowDescent"));
		}
		if (select > -1) {
			parent.drawFilledBox(Box(menuWidths[select], position.top + 1, menuWidths[select + 1], position.bottom - 1), 
					ss.getColor("selection"));
		}
		foreach (size_t i, PopUpMenuElement menuItem ; menus) {
			parent.drawTextSL(Box(menuWidths[i], position.top, menuWidths[i+1], position.bottom), menuItem.text, Point(0,0));
		}
		/+Fontset!Bitmap8Bit f = ss.getFontset("default");
		if (output is null){
			usedWidth = 1;
			output = new BitmapDrawer(position.width(),position.height());
			foreach(m ; menus){
				usedWidth += m.text.getWidth() + (ss.drawParameters["MenuBarHorizPadding"] * 2);
				menuWidths ~= usedWidth;
				
				//writeln(m.text.getWidth());
			}
			output.drawFilledRectangle(0, position.width(), 0, position.height(), ss.getColor("window"));
			assert(menuWidths.length == menus.length + 1);
		}else{
			output.drawFilledRectangle(0, usedWidth, 0, position.height(), ss.getColor("window"));
		}
		if(select != -1){

		}
		int x;
		foreach(size_t i, m ; menus){
			x += ss.drawParameters["MenuBarHorizPadding"];
			//const int xAdv = m.text.getWidth();
			output.drawSingleLineText(Coordinate(menuWidths[i],position.top,menuWidths[i + 1],position.bottom), m.text);
			x += ss.drawParameters["MenuBarHorizPadding"];			
		}
		output.drawLine(0, 0, 0, position.height()-1, ss.getColor("windowascent"));
		output.drawLine(0, position.width()-1, 0, 0, ss.getColor("windowascent"));
		output.drawLine(0, position.width()-1, position.height()-1, position.height()-1, ss.getColor("windowdescent"));
		output.drawLine(position.width()-1, position.width()-1, 0, position.height()-1, ss.getColor("windowdescent"));
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}+/
	}
	private void redirectIncomingEvents(Event ev){
		if(onMouseLClick !is null){
			onMouseLClick(ev);
		}
	}
	

}
