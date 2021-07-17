module document;

import PixelPerfectEngine.map.mapdata;
import PixelPerfectEngine.map.mapformat;
import editorevents;
import windows.rasterwindow;
import PixelPerfectEngine.concrete.eventChainSystem;
import PixelPerfectEngine.concrete.interfaces : MouseEventReceptor;
import PixelPerfectEngine.concrete.types : CursorType;
import PixelPerfectEngine.graphics.common : Color, Coordinate;
import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.system.input : MouseButton, ButtonState, MouseClickEvent, MouseMotionEvent, MouseWheelEvent, 
		MouseEventCommons, MouseButtonFlags;
import std.stdio;

import app;
///Individual document for parallel editing
public class MapDocument : MouseEventReceptor {
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
	Box					mapSelection;	///Contains the selected map area parameters
	Box					areaSelection;	///Contains the selected layer area parameters in pixels
	RasterWindow		outputWindow;	///Window used to output the screen data
	EditMode			mode;			///Mose event mode selector
	LayerInfo[]			layerList;		///Local layerinfo for data lookup
	string				filename;		///Null if not yet saved, otherwise name of the target file
	protected int		prevMouseX;		///Previous mouse X position
	protected int		prevMouseY;		///Previous mouse Y position

	public int			sXAmount;		///Continuous X scroll amount
	public int			sYAmount;		///Continuous Y scroll amount
	protected uint		flags;			///Various status flags combined into one.
	protected static enum	VOIDFILL_EN = 1<<0;	///If set, tilePlacement overrides only transparent (0xFFFF) tiles.
	protected static enum	LAYER_SCROLL = 1<<1;///If set, then layer is being scrolled.
	protected static enum	PLACEMENT = 1<<2;	///To solve some "debounce" issues around mouse click releases
	protected static enum	DISPL_SELECTION = 1<<3;	///If set, then selection is shown
	protected MappingElement	selectedMappingElement;	///Currently selected mapping element to write, including mirroring properties, palette selection, and priority attributes
	//public bool			voidfill;		///If true, tilePlacement overrides only transparent (0xFFFF) tiles.
	/**
	 * Loads the document from disk.
	 */
	public this(string filename) @trusted {
		mainDoc = new MapFormat(File(filename));
		events = new UndoableStack(20);
		mode = EditMode.selectDragScroll;
	}
	///New from scratch
	public this(string docName, int resX, int resY) @trusted {
		events = new UndoableStack(20);
		mainDoc = new MapFormat(docName, resX, resY);
		mode = EditMode.selectDragScroll;
	}
	///Returns the next available layer number.
	public int nextLayerNumber() @safe {
		int result = selectedLayer;
		do {
			if (mainDoc[result] is null)
				return result;
			result++;
		} while (true);
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
	 * Clears selection area.
	 */
	public void clearSelection() {
		
	}
	/**
	 * Scrolls the selected layer by a given amount.
	 */
	public void scrollSelectedLayer (int x, int y) {
		if (mainDoc[selectedLayer] !is null) {
			mainDoc[selectedLayer].relScroll(x, y);
		}
		outputWindow.updateRaster();
	}
	/**
	 * Sets the continuous scroll amounts.
	 */
	public void setContScroll (int x, int y) {
		sXAmount = x;
		sYAmount = y;
	}
	/**
	 * Updates the selection on the raster window.
	 */
	public void updateSelection() {
		if (mainDoc[selectedLayer] !is null) {
			const int sX = mainDoc[selectedLayer].getSX, sY = mainDoc[selectedLayer].getSY;
			Box onscreen = Box(sX, sY, sX + outputWindow.rasterX - 1, sY + outputWindow.rasterY - 1);
			if (onscreen.isBetween(areaSelection.cornerUL) || onscreen.isBetween(areaSelection.cornerUR) || 
					onscreen.isBetween(areaSelection.cornerLL) || onscreen.isBetween(areaSelection.cornerLR)) {
				outputWindow.selection = areaSelection;
				outputWindow.selection.move(sX * -1, sY * -1);

				outputWindow.selection.left = outputWindow.selection.left < 0 ? 0 : outputWindow.selection.left;
				outputWindow.selection.left = outputWindow.selection.left >= outputWindow.rasterX ? outputWindow.rasterX - 1 : 
						outputWindow.selection.left;
				outputWindow.selection.right = outputWindow.selection.right < 0 ? 0 : outputWindow.selection.right;
				outputWindow.selection.right = outputWindow.selection.right >= outputWindow.rasterX ? outputWindow.rasterX - 1 : 
						outputWindow.selection.right;
				
				outputWindow.selection.top = outputWindow.selection.top < 0 ? 0 : outputWindow.selection.top;
				outputWindow.selection.top = outputWindow.selection.top >= outputWindow.rasterY ? outputWindow.rasterY - 1 : 
						outputWindow.selection.top;
				outputWindow.selection.bottom = outputWindow.selection.bottom < 0 ? 0 : outputWindow.selection.bottom;
				outputWindow.selection.bottom = outputWindow.selection.bottom >= outputWindow.rasterX ? outputWindow.rasterX - 1 : 
						outputWindow.selection.bottom;
			} else {
				outputWindow.selection = Box (0, 0, -1, -1);
			}
		}
	}
	/**
	 * Scrolls the selected layer by the amount set.
	 * Should be called for every frame.
	 */
	public void contScrollLayer () {
		if(sXAmount || sYAmount){
			scrollSelectedLayer (sXAmount, sYAmount);
		}
	}
	/**
	 * Updates the material list for the selected layer.
	 */
	public void updateMaterialList () {
		if (mainDoc[selectedLayer] !is null) {
			if (prg.materialList !is null) {
				TileInfo[] list = mainDoc.getTileInfo(selectedLayer);
				//writeln(list.length);
				prg.materialList.updateMaterialList(list);
			}
		}
	}
	/**
	 * Updates the layers for this document.
	 */
	public void updateLayerList () {
		layerList = mainDoc.getLayerInfo;
		if (prg.layerList !is null) {
			prg.layerList.updateLayerList(layerList);
			//prg.wh.layerlist
		}
	}
	public void onSelection () {
		updateLayerList;
		updateMaterialList;
	}
	public void tileMaterial_FlipHorizontal(bool pos) {
		selectedMappingElement.attributes.horizMirror = pos;
	}
	public void tileMaterial_FlipVertical(bool pos) {
		selectedMappingElement.attributes.vertMirror = pos;
	}
	public void tileMaterial_Select(wchar id) {
		selectedMappingElement.tileID = id;
		mode = EditMode.tilePlacement;

	}
	public ushort tileMaterial_PaletteUp() {
		selectedMappingElement.paletteSel++;
		return selectedMappingElement.paletteSel;
	}
	public ushort tileMaterial_PaletteDown() {
		selectedMappingElement.paletteSel--;
		return selectedMappingElement.paletteSel;
	}
	public @property bool voidfill() @nogc @safe pure nothrow {
		return flags & VOIDFILL_EN;
	}
	public @property bool voidfill(bool val) @nogc @safe pure nothrow {
		if (val) flags |= VOIDFILL_EN;
		else flags &= ~VOIDFILL_EN;
		return flags & VOIDFILL_EN;
	}
	
	public void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		int x = mce.x, y = mce.y;

		final switch (mode) with (EditMode) {
			case tilePlacement:
				switch (mce.button) {
					case MouseButton.Left:			//Tile placement
						//Record the first cursor position upon mouse button press, then initialize either a single or zone write for the selected tile layer.
						if (mce.state) {
							prevMouseX = x;
							prevMouseY = y;
							flags |= PLACEMENT;
						} else if (flags & PLACEMENT) {
							flags &= ~PLACEMENT;
							ITileLayer target = cast(ITileLayer)(mainDoc[selectedLayer]);
							const int tileWidth = target.getTileWidth, tileHeight = target.getTileHeight;
							const int hScroll = mainDoc[selectedLayer].getSX, vScroll = mainDoc[selectedLayer].getSX;
							x = (x + hScroll) / tileWidth;
							y = (y + vScroll) / tileHeight;
							prevMouseX = (prevMouseX + hScroll) / tileWidth;
							prevMouseY = (prevMouseY + vScroll) / tileHeight;
							Box c;
							
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
										events.addToTop(new WriteToMapSingle(target, c.left, c.top, selectedMappingElement));
								} else {
									events.addToTop(new WriteToMapVoidFill(target, c, selectedMappingElement));
								}
							} else {
								if (c.width == 1 && c.height == 1) {
									events.addToTop(new WriteToMapSingle(target, c.left, c.top, selectedMappingElement));
								} else {
									events.addToTop(new WriteToMapOverwrite(target, c, selectedMappingElement));
								}
							}
						}
						outputWindow.updateRaster();
						break;
					case MouseButton.Mid:			//Tile deletion
						//Record the first cursor position upon mouse button press, then initialize either a single or zone delete for the selected tile layer.
						if (mce.state) {
							prevMouseX = x;
							prevMouseY = y;
							flags |= PLACEMENT;
						} else if (flags & PLACEMENT) {
							flags &= ~PLACEMENT;
							ITileLayer target = cast(ITileLayer)(mainDoc[selectedLayer]);
							x = (x + mainDoc[selectedLayer].getSX) / target.getTileWidth;
							y = (y + mainDoc[selectedLayer].getSY) / target.getTileHeight;
							prevMouseX = (prevMouseX + mainDoc[selectedLayer].getSX) / target.getTileWidth;
							prevMouseY = (prevMouseY + mainDoc[selectedLayer].getSY) / target.getTileHeight;

							Box c;

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

							if (c.width == 1 && c.height == 1) {
								events.addToTop(new WriteToMapSingle(target, c.left, c.top, MappingElement(0xFFFF)));
							} else {
								events.addToTop(new WriteToMapOverwrite(target, c, MappingElement(0xFFFF)));
							}
						}
						outputWindow.updateRaster();
						break;
					default:
						break;
				}
				break;
			case selectDragScroll:
				switch (mce.button) {
					case MouseButton.Left:
						
						//Initialize drag select
						if (mce.state) {
							prevMouseX = x;
							prevMouseY = y;
							outputWindow.armSelection;
							outputWindow.selection.left = x;
							outputWindow.selection.top = y;
							outputWindow.selection.right = x;
							outputWindow.selection.bottom = y;
						} else {
							outputWindow.disarmSelection;
							Box c;

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
							
							if (getLayerInfo(selectedLayer).type != LayerType.init) {
								Layer l = mainDoc.layeroutput[selectedLayer];
								areaSelection = c;
								areaSelection.move(l.getSX, l.getSY);
								
								switch (getLayerInfo(selectedLayer).type) {
									case LayerType.Tile: //If TileLayer is selected, recalculate coordinates to the nearest valid points
										TileLayer tl = cast(TileLayer)l;
										areaSelection.left = (areaSelection.left / tl.getTileWidth) * tl.getTileWidth;
										areaSelection.top = (areaSelection.top / tl.getTileHeight) * tl.getTileHeight;
										areaSelection.right = (areaSelection.right / tl.getTileWidth) * tl.getTileWidth/+ + 
												(areaSelection.right % tl.getTileWidth ? 1 : 0)+/;
										areaSelection.bottom = (areaSelection.bottom / tl.getTileHeight) * tl.getTileHeight/+ +
												(areaSelection.bottom % tl.getTileHeight ? 1 : 0)+/;
										break;
									
									default:
										break;
								}
							}

							outputWindow.showSelection = true;
						}
						break;
					case MouseButton.Mid:
						
						if (mce.state) {
							outputWindow.requestCursor(CursorType.Hand);
							prevMouseX = x;
							prevMouseY = y;
							outputWindow.moveEn = true;
						} else {
							outputWindow.requestCursor(CursorType.Arrow);
							outputWindow.moveEn = false;
						}
						//scrollSelectedLayer(prevMouseX - x, prevMouseY - y);

						prevMouseX = x;
						prevMouseY = y;
						break;
					default:
						break;
				}
				break;
			case boxPlacement:
				break;
			case spritePlacement:
				break;
		}
	}
	
	public void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		final switch (mode) with (EditMode) {
			case selectDragScroll:
				switch (mme.buttonState) {
					case MouseButtonFlags.Left:
						Box s;
						if (prevMouseX < mme.x) {
							s.left = prevMouseX;
							s.right = mme.x;
						} else {
							s.left = mme.x;
							s.right = prevMouseX;
						}
						if (prevMouseY < mme.y) {
							s.top = prevMouseY;
							s.bottom = mme.y;
						} else {
							s.top = mme.y;
							s.bottom = prevMouseY;
						}
						outputWindow.selection = s;
						outputWindow.updateRaster();
						break;
					case MouseButtonFlags.Mid:
						scrollSelectedLayer(prevMouseX - mme.x, prevMouseY - mme.y);
						prevMouseX = mme.x;
						prevMouseY = mme.y;
						outputWindow.updateRaster();
						break;
					default:
						break;
				}
				break;
			case tilePlacement:
				break;
			case boxPlacement:
				break;
			case spritePlacement:
				break;
		}
	}
	
	public void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		if (outputWindow.isSelectionArmed())
			scrollSelectedLayer(mwe.x, mwe.y);
	}
	
	protected LayerInfo getLayerInfo(int pri) nothrow {
		foreach (key; layerList) {
			if (key.pri == pri)
				return key;
		}
		return LayerInfo.init;
	}
}
