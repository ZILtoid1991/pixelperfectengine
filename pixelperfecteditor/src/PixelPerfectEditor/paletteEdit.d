module paletteEdit;
import PixelPerfectEngine.concrete.elements;
import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.graphics.common;
import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.extbmp.extbmp;
import PixelPerfectEngine.system.etc;
/+
public class PaletteEditor : Window, ActionListener{
	private SmallButton[16] plusR, minusR, plusG, minusG, plusB, minusB, plusA, minusA;
	private Button nextPage, prevPage, addColor;
	private Label[16] r, g, b, a;
	private ubyte[] palette;
	private Label red, green, blue, alpha, rangeA, rangeB, rangeADisp, rangeBDisp;
	public this() {
		super(Coordinate(0,0,368,322),"PaletteEditor",["MenuButtonA","SaveButtonA","LoadButtonA"]);
		for (int i; i < 16; i++){
			r[i] = new Label("00","null",Coordinate(112,32+(i * 16),144,48+(i * 16)));
			g[i] = new Label("00","null",Coordinate(176,32+(i * 16),208,48+(i * 16)));
			b[i] = new Label("00","null",Coordinate(240,32+(i * 16),272,48+(i * 16)));
			a[i] = new Label("00","null",Coordinate(304,32+(i * 16),336,48+(i * 16)));
			plusR[i] = new SmallButton("plusA","plusB","rP" ~ intToHex(i),Coordinate(80,32+(i * 16),96,48+(i * 16)));
			minusR[i] = new SmallButton("minusA","minusB","rN" ~ intToHex(i),Coordinate(96,32+(i * 16),112,48+(i * 16)));
			plusG[i] = new SmallButton("plusA","plusB","gP" ~ intToHex(i),Coordinate(144,32+(i * 16),160,48+(i * 16)));
			minusG[i] = new SmallButton("minusA","minusB","gP" ~ intToHex(i),Coordinate(160,32+(i * 16),176,48+(i * 16)));
			plusB[i] = new SmallButton("plusA","plusB","bP" ~ intToHex(i),Coordinate(208,32+(i * 16),224,48+(i * 16)));
			minusB[i] = new SmallButton("minusA","minusB","bP" ~ intToHex(i),Coordinate(224,32+(i * 16),240,48+(i * 16)));
			plusA[i] = new SmallButton("plusA","plusB","aP" ~ intToHex(i),Coordinate(272,32+(i * 16),288,48+(i * 16)));
			minusA[i] = new SmallButton("minusA","minusB","aP" ~ intToHex(i),Coordinate(288,32+(i * 16),304,48+(i * 16)));
			plusR[i].al ~= this;
			minusR[i].al ~= this;
			plusG[i].al ~= this;
			minusG[i].al ~= this;
			plusB[i].al ~= this;
			minusB[i].al ~= this;
			plusA[i].al ~= this;
			minusA[i].al ~= this;
			addElement(r[i],EventProperties.MOUSE);
			addElement(g[i],EventProperties.MOUSE);
			addElement(b[i],EventProperties.MOUSE);
			addElement(a[i],EventProperties.MOUSE);
			addElement(plusR[i],EventProperties.MOUSE);
			addElement(minusR[i],EventProperties.MOUSE);
			addElement(plusG[i],EventProperties.MOUSE);
			addElement(minusG[i],EventProperties.MOUSE);
			addElement(plusB[i],EventProperties.MOUSE);
			addElement(minusB[i],EventProperties.MOUSE);
			addElement(plusA[i],EventProperties.MOUSE);
			addElement(minusA[i],EventProperties.MOUSE);
		}
		red = new Label("Red:","null",Coordinate(080,16,144,32));
		addElement(red, 0);
		green = new Label("Green:","null",Coordinate(144,16,208,32));
		addElement(green, 0);
		blue = new Label("Blue:","null",Coordinate(208,16,272,32));
		addElement(blue, 0);
		alpha = new Label("Alpha:","null",Coordinate(272,16,336,32));
		addElement(alpha, 0);
		rangeA = new Label("Range A:","null", Coordinate(8,286,88,304));
		addElement(rangeA, 0);
		rangeA = new Label("Range B:","null", Coordinate(8,304,88,320));
		addElement(rangeB, 0);
		rangeADisp = new Label("0000 - 0000","null", Coordinate(88,286,168,304));
		addElement(rangeADisp, 0);
		rangeBDisp = new Label("0000 - 0000","null", Coordinate(88,304,168,320));
		addElement(rangeBDisp, 0);
		addColor = new Button("Add Color","addcolor", Coordinate(286,300,366,320));
		addColor.al ~= this;
		addElement(addColor,EventProperties.MOUSE);
		nextPage = new Button("Next","nextpage", Coordinate(240,300,284,320));
		nextPage.al ~= this;
		addElement(nextPage,EventProperties.MOUSE);
		prevPage = new Button("Prev","prevpage", Coordinate(198,300,238,320));
		prevPage.al ~= this;
		addElement(prevPage,EventProperties.MOUSE);
	}
	override public void actionEvent(Event event) {
		if(event.source.length == 3){
			
		}
	}
	
}
+/
public class ColorDisplay : WindowElement{
	Bitmap32Bit paletteDisplay, selectionDisplay;
	public this(){
	
	}
	override public void draw() {
		
	}
	public void onPaletteUpdate(ubyte* palette, int length, int offsetA, int offsetB){
		
	}
}