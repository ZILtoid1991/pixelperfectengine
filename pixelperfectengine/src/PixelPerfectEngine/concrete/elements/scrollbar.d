module PixelPerfectEngine.concrete.elements.scrollbar;

abstract class Slider : WindowElement{

	public int value, maxValue, barLength;
	public void delegate(Event ev) onScrolling;

	/**
	 * Returns the slider position. If barLenght > 1, then it returns the lower value.
	 */
	public @nogc @property int sliderPosition(){
		return value;
	}
	public @property int sliderPosition(int newval){
		if(newval < maxValue){
			value = newval;
			draw();
		}
		return value;
	}
}
/**
 * Vertical slider.
 */
public class VSlider : Slider{
	//public int[] brush;

	//private int value, maxValue, barLength;

	public this(int maxValue, int barLenght, string source, Coordinate coordinates){
		position = coordinates;
		//this.text = text;
		this.source = source;
		this.maxValue = maxValue;
		this.barLength = barLenght;
		output = new BitmapDrawer(position.width, position.height);
		brush ~= 6;
		brush ~= 8;
		//brush ~= 10;
		//draw();
	}
	public override void draw(){
		//draw background
		//Bitmap16Bit sliderStyle = elementContainer.getStyleBrush(brush[2]);
		//ushort backgroundColor = sliderStyle.readPixel(0,0), sliderColor = sliderStyle.readPixel(1,0);
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width, position.height);
		output.drawFilledRectangle(0, position.width , 0, position.height , getAvailableStyleSheet.getColor("windowinactive"));
		//draw upper arrow
		output.insertBitmap(0,0,getAvailableStyleSheet.getImage("upArrowA"));
		//draw lower arrow
		output.insertBitmap(0, position.height - getAvailableStyleSheet.getImage("downArrowA").height,getAvailableStyleSheet.getImage("downArrowA"));
		//draw slider
		if(maxValue > barLength){
			double sliderlength = position.height() - (getAvailableStyleSheet.getImage("upArrowA")).height*2, unitlength = sliderlength/maxValue;
			double sliderpos = unitlength * value, bl = unitlength * barLength;
			int posA = to!int(sliderpos) + getAvailableStyleSheet.getImage("upArrowA").height, posB = to!int(bl + sliderpos) + getAvailableStyleSheet.getImage("upArrowA").height;

			output.drawFilledRectangle(0,position.width,posA, posB, getAvailableStyleSheet.getColor("windowascent"));
		}
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}


	public override void onClick(int offsetX, int offsetY, int state, ubyte button){
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
				if(offsetY <= getAvailableStyleSheet.getImage("upArrowA").height){
					if(value != 0) value--;
				}else if(position.height-getAvailableStyleSheet.getImage("upArrowA").height <= offsetY){
					if(value < maxValue - barLength) value++;
				}else{
					offsetY -= getAvailableStyleSheet.getImage("upArrowA").height;
					double sliderlength = position.height() - (getAvailableStyleSheet.getImage("upArrowA").height*2), unitlength = sliderlength/maxValue;
					int v = to!int(offsetY / unitlength);
					//value = ((sizeY - (elementContainer.getStyleBrush(brush[1]).getY() * 2)) - offsetY) * (value / maxValue);
					if(v < maxValue - barLength) value = v;
					else value = maxValue - barLength;

				}
				draw();
				if(onScrolling !is null){
					onScrolling(new Event(source, null, null, null, null, value, EventType.SLIDER, null, this));
				}
			}else{
				if(onMouseLClickRel !is null){
					onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
			}
		}

	}
	public override void onScroll(int x, int y, int wX, int wY){

		if(x == 1){
			if(value != 0) value--;
		}else if(x == -1){
			if(value < maxValue - barLength) value++;
		}
		draw();
		if(onScrolling !is null){
			onScrolling(new Event(source, null, null, null, null, value, EventType.SLIDER, null, this));
		}
	}
	override public void onDrag(int x,int y,int relX,int relY,ubyte button) {
		value+=relY;
		if(value >= maxValue - barLength)
			value = maxValue;
		else if(value < 0)
			value = 0;
		draw();
		if(onScrolling !is null){
			onScrolling(new Event(source, null, null, null, null, value, EventType.SLIDER, null, this));
		}

	}
}
/**
 * Horizontal slider.
 */
public class HSlider : Slider{
	public this(int maxValue, int barLenght, string source, Coordinate coordinates){
		position = coordinates;
		//this.text = text;
		this.source = source;
		this.maxValue = maxValue;
		this.barLength = barLenght;

		output = new BitmapDrawer(position.width, position.height);
		brush ~= 14;
		brush ~= 16;
		//brush ~= 10;
		//draw();
	}
	public override void draw(){
		//draw background
		//Bitmap16Bit sliderStyle = elementContainer.getStyleBrush(brush[2]);
		//ushort backgroundColor = sliderStyle.readPixel(0,0), sliderColor = sliderStyle.readPixel(1,0);
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width, position.height);
		output.drawFilledRectangle(0, position.width , 0, position.height , getAvailableStyleSheet().getColor("windowinactive"));
		//draw left arrow
		output.insertBitmap(0,0,getAvailableStyleSheet.getImage("leftArrowA"));
		//draw right arrow
		output.insertBitmap(position.width - getAvailableStyleSheet.getImage("rightArrowA").width,0,getAvailableStyleSheet.getImage("rightArrowA"));
		//draw slider
		if(maxValue > barLength){
			double sliderlength = position.width() - (getAvailableStyleSheet.getImage("rightArrowA").width*2), unitlength = sliderlength/maxValue;
			double sliderpos = unitlength * value, bl = unitlength * barLength;

			int posA = to!int(sliderpos) + getAvailableStyleSheet.getImage("rightArrowA").height, posB = to!int(bl + sliderpos) + getAvailableStyleSheet.getImage("rightArrowA").height;

			output.drawFilledRectangle(posA, posB, 0, position.height(),getAvailableStyleSheet().getColor("windowascent"));
		}
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}
	public override void onClick(int offsetX, int offsetY, int state, ubyte button){
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
				if(offsetX <= getAvailableStyleSheet.getImage("rightArrowA").width){
					if(value != 0) value--;
				}
				else if(position.width-getAvailableStyleSheet.getImage("rightArrowA").width <= offsetX){
					if(value < maxValue - barLength) value++;
				}
				else{
					offsetX -= getAvailableStyleSheet.getImage("rightArrowA").width;
					double sliderlength = position.width() - (elementContainer.getStyleSheet.getImage("rightArrowA").width*2), unitlength = sliderlength/maxValue;
					int v = to!int(offsetX / unitlength);
					if(v < maxValue - barLength) value = v;
					else value = maxValue - barLength;
				}
				draw();
				if(onScrolling !is null){
					onScrolling(new Event(source, null, null, null, null, value, EventType.SLIDER, null, this));
				}
			}else{
				if(onMouseLClickRel !is null){
					onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK, null, this));
				}
			}
		}
	}
	public override void onScroll(int x, int y, int wX, int wY){
		if(y == -1){
			if(value != 0) value--;
		}else if(y == 1){
			if(value < maxValue - barLength) value++;
		}
		draw();
		if(onScrolling.ptr){
			onScrolling(new Event(source, null, null, null, null, value, EventType.SLIDER, null, this));
		}
	}
	override public void onDrag(int x,int y,int relX,int relY,ubyte button) {
		value+=relX;
		if(value >= maxValue - barLength)
			value = maxValue;
		else if(value < 0)
			value = 0;
		draw();
		if(onScrolling.ptr){
			onScrolling(new Event(source, null, null, null, null, value, EventType.SLIDER, null, this));
		}
	}

}
