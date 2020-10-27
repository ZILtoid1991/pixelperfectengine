module PixelPerfectEngine.concrete.elements.smallbutton;

public class SmallButton : WindowElement {
	public string			iconPressed, iconUnpressed;
	private bool			_isPressed;
	//protected IRadioButtonGroup		radioButtonGroup;	//If set, the element works like a radio button

	//public int brushPressed, brushNormal;

	public this(string iconPressed, string iconUnpressed, string source, Coordinate coordinates){
		position = coordinates;

		//this.text = text;
		this.source = source;
		this.iconPressed = iconPressed;
		this.iconUnpressed = iconUnpressed;
		output = new BitmapDrawer(coordinates.width, coordinates.height);
		//brushPressed = 1;
		//draw();
	}
	public override void draw(){
		output.drawFilledRectangle(0, position.width()-1, 0,position.height()-1, 0);
		if(_isPressed){
			output.insertBitmap(0,0,getAvailableStyleSheet().getImage(iconPressed));
		}else{
			output.insertBitmap(0,0,getAvailableStyleSheet().getImage(iconUnpressed));
		}
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}
	public override void onClick(int offsetX, int offsetY, int state, ubyte button){
		if(state == ButtonState.PRESSED){
			switch(button){
				case MouseButton.LEFT:
					_isPressed = true;
					draw();
					if(onMouseLClickPre !is null)
						onMouseLClickPre(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
					break;
				case MouseButton.RIGHT:
					if(onMouseRClickPre !is null)
						onMouseRClickPre(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
					break;
				case MouseButton.MID:
					if(onMouseMClickPre !is null)
						onMouseMClickPre(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
					break;
				default: break;
			}
		}else{
			switch(button){
				case MouseButton.LEFT:
					_isPressed = false;
					draw();
					if(onMouseLClickRel !is null)
						onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
					break;
				case MouseButton.RIGHT:
					if(onMouseRClickRel !is null)
						onMouseRClickRel(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
					break;
				case MouseButton.MID:
					if(onMouseMClickRel !is null)
						onMouseMClickRel(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
					break;
				default: break;
			}
		}
		

	}
	
	
}
