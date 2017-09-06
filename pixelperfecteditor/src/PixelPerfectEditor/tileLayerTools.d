module tileLayerTools;

import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.graphics.common;
import editor;

public class TileLayerTools : Window, ActionListener {
	private ListBox sourceList;
	private Editor e;
	private TextBox layerName, scrollX, scrollY;
	private Label label_layerName, label_scrollX, label_scrollY, posX, posY;
	public this(Editor e){
		this.e = e;
		super(Coordinate(0,0,640,480), "TileLayer Tools");
		ListBoxHeader lbh = new ListBoxHeader(["Filename","BitmapID","TileID","Desc"],[128,128,64,160]);
		sourceList = new ListBox("sourceList",Coordinate(0,0,480,300),[],lbh,16);
		Button add = new Button("Add","add",Coordinate(0,0,0,0));
		Button remove = new Button("Remove","rem",Coordinate(0,0,0,0));
		Button autoload = new Button("Autoload","autoload",Coordinate(0,0,0,0));
		Button edit = new Button("Edit","edit",Coordinate(0,0,0,0));

	}
	public void actionEvent(Event event){
		switch (event.source){
			case "autoload":
				parent.addWindow(new FileDialog("Autoload tiles","autoloadDialog",this,[FileDialog.FileAssociationDescriptor("PixelPerfectEngine XMP file", ["*.xmp"])], ""));
				break;
			default: 
				break;
		}
	}
}

