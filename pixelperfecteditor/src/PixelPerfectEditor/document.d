module document;

import PixelPerfectEngine.map.mapdata;
import PixelPerfectEngine.map.mapload;
import editorEvents;
///Individual document for parallel editing
public class MapDocument{
	UndoableStack	events;
	ExtendibleMap	mainDoc;
	string			mainDocFilename;
	Layer[int]		layers;
	int				selectedLayer;
	/**
	 * Loads the document from disk.
	 */
	public this(string filename){

	}
	public this(){
		events = new UndoableStack(20);
		mainDoc = new ExtendibleMap();
	}
}
