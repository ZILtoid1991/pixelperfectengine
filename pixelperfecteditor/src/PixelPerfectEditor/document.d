module document;

import PixelPerfectEngine.map.mapdata;
import PixelPerfectEngine.map.mapformat;
import editorEvents;
import rasterWindow;
import PixelPerfectEngine.concrete.eventChainSystem;
import PixelPerfectEngine.graphics.common : Color, Coordinate;
import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.system.inputHandler : MouseButton, ButtonState;
import std.stdio;

import app;
///Individual document for parallel editing
public class MapDocument {
	/**
	 * Specifies the current edit mode
	 */
	public enum EditMode {
		selectDragScroll,
		tilePlacement,
		boxPlacement,
		spritePlacement,
	}
	UndoableStack		events;		///Per document event stack
	MapFormat			mainDoc;	///Used to reduce duplicate data as much as possible
	//ABitmap[] delegate() imageReturnFunc;
	Color[] delegate(MapDocument sender) paletteReturnFunc;	///Used for adding the palette for the document
	int					selectedLayer;	///Indicates the currently selected layer
	RasterWindow		outputWindow;	///Window used to output the screen data
	EditMode			mode;			///Mose event mode selector
	protected int		prevMouseX;		///Previous mouse X position
	protected int		prevMouseY;		///Previous mouse Y position
	protected MappingElement	selectedMappingElement;	///Currently selected mapping element to write, including mirroring properties, palette selection, and priority attributes
	protected bool		voidfill;		///If true, tilePlacement overrides only transparent (0xFFFF) tiles.
	/**
	 * Loads the document from disk.
	 */
	public this(string filename) @trusted {

	}
	///New from scratch
	public this(string docName, int resX, int resY) @trusted {
		events = new UndoableStack(20);
		mainDoc = new MapFormat(docName, resX, resY);
	}
	///Returns the next available layer number.
	public int nextLayerNumber() @safe {
		int result = selectedLayer;
		bool found;
		do {
			if (mainDoc[result] is null)
				found = true;
			else
				result++;
		} while (!found);
		return result;
	}
	///Puts the loaded tiles onto a TileLayer
	public void addTileSet(int layer, ABitmap[ushort] tiles) @trusted {
		ITileLayer itl = cast(ITileLayer)mainDoc[layer];
		foreach (i ; tiles.byKey) {
			itl.addTile(tiles[i], i);
		}
	}
	///Ditto
	public void addTileSet(int layer, ABitmap[] tiles) @trusted {
		ITileLayer itl = cast(ITileLayer)mainDoc[layer];
		for (ushort i ; i < tiles.length ; i++) {
			itl.addTile(tiles[i], i);
		}
	}
	/**
	 * Pass mouse events here.
	 */
	public void passMouseEvent(int x, int y, int state, ubyte button) {
		//Normal mode:
		//left : drag layer/select ; right : menu ; middle : quick nav ; other buttons : user defined
		//TileLayer placement mode:
		//left : placement ; right : menu ; middle : delete ; other buttons : user defined
		final switch (mode) {
			case EditMode.selectDragScroll:
				switch (button) {
					case MouseButton.LEFT:
						//Test if an object is being hit by the cursor. If yes, then select the object. If not, then initialize drag layer mode.
						break;
					case MouseButton.MID:
						//Enable quicknav mode. Scroll the layer by delta/10 for each frame. Stop if button is released.
						break;
					default:
						break;
				}
				break;
			case EditMode.tilePlacement:
				switch (button) {
					case MouseButton.LEFT:
						//Record the first cursor position upon mouse button press, then initialize either a single or zone write for the selected tile layer.
						if (state == ButtonState.PRESSED) {
							prevMouseX = x;
							prevMouseY = y;
						} else {
							ITileLayer target = cast(ITileLayer)(mainDoc[selectedLayer]);
							x = (x + mainDoc[selectedLayer].getSX) / target.getTX;
							y = (y + mainDoc[selectedLayer].getSY) / target.getTY;
							prevMouseX = (prevMouseX + mainDoc[selectedLayer].getSX) / target.getTX;
							prevMouseY = (prevMouseY + mainDoc[selectedLayer].getSY) / target.getTY;
							Coordinate c;
							if (x > prevMouseX){
								c.left = prevMouseX;
								c.right = x;
							} else {
								c.left = x;
								c.right = prevMouseX;
							}
							if (y > prevMouseY){
								c.top = prevMouseY;
								c.bottom = y;
							} else {
								c.top = y;
								c.bottom = prevMouseY;
							}

							if (voidfill) {
								if (c.width == 1 && c.height == 1) {
									if (target.readMapping(c.left, c.top).tileID == 0xFFFF)
										target.writeMapping(c.left, c.top, selectedMappingElement);
								} else {
									for (int y0 = c.top ; y0 <= c.bottom ; y0++){
										for (int x0 = c.left ; x0 <= c.right ; x0++) {
											if (target.readMapping(x0, y0).tileID == 0xFFFF)
												target.writeMapping(x0, y0, selectedMappingElement);
										}
									}
								}
							} else {
								if (c.width == 1 && c.height == 1) {
									target.writeMapping(c.left, c.top, selectedMappingElement);
								} else {
									for (int y0 = c.top ; y0 <= c.bottom ; y0++){
										for (int x0 = c.left ; x0 <= c.right ; x0++) {
											target.writeMapping(x0, y0, selectedMappingElement);
										}
									}
								}
							}
						}
						break;
					case MouseButton.MID:
						//Record the first cursor position upon mouse button press, then initialize either a single or zone delete for the selected tile layer.
						if (state == ButtonState.PRESSED) {
							prevMouseX = x;
							prevMouseY = y;
						} else {

						}
						break;
					case MouseButton.RIGHT:
						//Open quick menu with basic edit options and ability of toggling both vertically and horizontally.
						break;
					default:
						break;
				}
				break;
			case EditMode.spritePlacement:
				break;
			case EditMode.boxPlacement:
				break;
		}
	}
	public void updateMaterialList () {
		if (mainDoc[selectedLayer] !is null) {
			if (prg.wh.materialList !is null) {
				TileInfo[] list = mainDoc.getTileInfo(selectedLayer);
				//writeln(list.length);
				prg.wh.materialList.updateMaterialList(list);
			}
		}
	}
	public void updateLayerList () {
		if (prg.wh.layerList !is null) {
			LayerInfo[] list = mainDoc.getLayerInfo;
			prg.wh.layerList.updateLayerList(list);
			//prg.wh.layerlist
		}
	}
	public void onSelection () {
		updateLayerList;
		updateMaterialList;
	}
}
