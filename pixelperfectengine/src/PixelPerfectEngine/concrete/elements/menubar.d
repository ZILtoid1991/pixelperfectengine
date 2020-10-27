module PixelPerfectEngine.concrete.elements.menubar;

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
		menuWidths = [0];
	}
	public override void draw() {
		StyleSheet ss = getAvailableStyleSheet();
		Fontset!Bitmap8Bit f = ss.getFontset("default");
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
		}
	}
	private void redirectIncomingEvents(Event ev){
		if(onMouseLClickPre !is null){
			onMouseLClickPre(ev);
		}
	}
	override public void onClick(int offsetX,int offsetY,int state,ubyte button){
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

		if(offsetX < usedWidth && button == MouseButton.LEFT && state == ButtonState.PRESSED){
			for(int i = cast(int)menuWidths.length - 1 ; i >= 0 ; i--){
				if(menuWidths[i] < offsetX){
					PopUpMenu p = new PopUpMenu(menus[i].getSubElements(), menus[i].source);
					//p.al = al;
					p.onMouseClick = onMouseLClickPre;//&redirectIncomingEvents;
					Coordinate c = elementContainer.getAbsolutePosition(this);
					popUpHandler.addPopUpElement(p, c.left + menuWidths[i], position.height());
					return;
				}
			}
		}

	}

}
