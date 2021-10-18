module document;

import pixelperfectengine.map.mapdata;
import pixelperfectengine.map.mapformat;
import editorevents;
import clipboard;
import contmenu;
import windows.rasterwindow;
import pixelperfectengine.concrete.eventchainsystem;
import pixelperfectengine.concrete.interfaces : MouseEventReceptor;
import pixelperfectengine.concrete.types;
import pixelperfectengine.graphics.common : Color, Coordinate;
import pixelperfectengine.graphics.bitmap;
import pixelperfectengine.graphics.layers;
import pixelperfectengine.system.input : MouseButton, ButtonState, MouseClickEvent, MouseMotionEvent, MouseWheelEvent, 
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
		if (outputWindow) {
			outputWindow.disarmSelection();
			outputWindow.showSelection = false;
			outputWindow.updateRaster();
		}
	}
	/**
	 * Scrolls the selected layer by a given amount.
	 */
	public void scrollSelectedLayer (int x, int y) {
		if (selectedLayer in mainDoc.layeroutput) {
			mainDoc[selectedLayer].relScroll(x, y);
		}
		//outputWindow.updateRaster();
		updateSelection();
	}
	/**
	 * Sets the continuous scroll amounts.
	 */
	public void setContScroll (int x, int y) {
		sXAmount = x;
		sYAmount = y;
	}
	/**
	 * Moves the selected area by the given amounts.
	 */
	public void moveSelection(int x, int y) {
		if (selectedLayer in mainDoc.layeroutput) {
			if (getLayerInfo(selectedLayer).type == LayerType.Tile) {
				ITileLayer target = cast(ITileLayer)(mainDoc[selectedLayer]);
				const int tileWidth = target.getTileWidth, tileHeight = target.getTileHeight;
				areaSelection.relMove(x * tileWidth, y * tileHeight);
				mapSelection.relMove(x, y);
				updateSelection();
			}
		}
	}
	/**
	 * Updates the selection on the raster window.
	 */
	public void updateSelection() {
		if (selectedLayer in mainDoc.layeroutput) {
			const int sX = mainDoc[selectedLayer].getSX, sY = mainDoc[selectedLayer].getSY;
			Box onscreen = Box(sX, sY, sX + outputWindow.rasterX - 1, sY + outputWindow.rasterY - 1);
			if (onscreen.isBetween(areaSelection.cornerUL) || onscreen.isBetween(areaSelection.cornerUR) || 
					onscreen.isBetween(areaSelection.cornerLL) || onscreen.isBetween(areaSelection.cornerLR)) {
				outputWindow.selection = areaSelection;
				outputWindow.selection.relMove(sX * -1, sY * -1);

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
			outputWindow.updateRaster();
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
		if (selectedLayer in mainDoc.layeroutput) {
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
	public void tileMaterial_FlipHorizontal() {
		selectedMappingElement.attributes.horizMirror = !selectedMappingElement.attributes.horizMirror;
	}
	public void tileMaterial_FlipVertical(bool pos) {
		selectedMappingElement.attributes.vertMirror = pos;
	}
	public void tileMaterial_FlipVertical() {
		selectedMappingElement.attributes.vertMirror = !selectedMappingElement.attributes.vertMirror;
	}
	public void tileMaterial_Select(wchar id) {
		selectedMappingElement.tileID = id;
		//mode = EditMode.tilePlacement;
	}
	public void tileMaterial_Up() {
		selectedMappingElement.tileID++;
	}
	public void tileMaterial_Down() {
		selectedMappingElement.tileID--;
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
						if (selectedLayer !in mainDoc.layeroutput) return;	//Safety protection
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
					case MouseButton.Right:
						if (mce.state) prg.wh.addPopUpElement(createTilePlacementContextMenu(&onSelectContextMenuSelect));
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
							Box c = outputWindow.selection;
							if (getLayerInfo(selectedLayer).type != LayerType.init) {
								Layer l = mainDoc.layeroutput[selectedLayer];
								areaSelection = c;
								areaSelection.relMove(l.getSX, l.getSY);
								
								switch (getLayerInfo(selectedLayer).type) {
									case LayerType.Tile: 
										TileLayer tl = cast(TileLayer)l;
										const int tileWidth = tl.getTileWidth, tileHeight = tl.getTileHeight, 
												mapWidth = tl.getMX, mapHeight = tl.getMY;
										//calculate selected map area
										mapSelection.left = areaSelection.left / tileWidth;
										mapSelection.right = areaSelection.right / tileWidth; /+ + (areaSelection.right % tileWidth > 0 ? 1 : 0); +/
										mapSelection.top = areaSelection.top / tileHeight;
										mapSelection.bottom = areaSelection.bottom / tileHeight; /+ + (areaSelection.bottom % tileHeight > 0 ? 1 : 0); +/
										//Clamp map sizes between what map has
										import pixelperfectengine.system.etc : clamp;
										
										clamp(mapSelection.left, 0, mapWidth);
										clamp(mapSelection.right, 0, mapHeight);
										clamp(mapSelection.top, 0, mapWidth);
										clamp(mapSelection.bottom, 0, mapHeight);
										//adjust displayed selection to mapSelection
										areaSelection.left = mapSelection.left * tileWidth;
										areaSelection.right = (mapSelection.right + 1) * tileWidth;//areaSelection.right = mapSelection.right * tileWidth;
										areaSelection.top = mapSelection.top * tileHeight;
										areaSelection.bottom = (mapSelection.bottom + 1) * tileHeight;//areaSelection.bottom = mapSelection.bottom * tileHeight;								
										break;
									
									default:
										break;
								}
							}
							outputWindow.disarmSelection();
							outputWindow.showSelection = true;
							updateSelection();
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
					case MouseButton.Right:
						if (mce.state) prg.wh.addPopUpElement(createSelectContextMenu(&onSelectContextMenuSelect));
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
	
	public LayerInfo getLayerInfo(int pri) nothrow {
		foreach (key; layerList) {
			if (key.pri == pri)
				return key;
		}
		return LayerInfo.init;
	}
	/**
	 * Copies an area on a tilelayer to a MapClipboard item.
	 */
	protected MapClipboard.Item createMapClipboardItem() {
		MapClipboard.Item result;
		const LayerType lt = getLayerInfo(selectedLayer).type;
		if (lt == LayerType.Tile || lt == LayerType.TransformableTile) {
			result.map.length = mapSelection.area;
			result.width = mapSelection.width;
			result.height = mapSelection.height;
			ITileLayer tl = cast(ITileLayer)mainDoc.layeroutput[selectedLayer];
			for (int y ; y < mapSelection.height ; y++) {
				for (int x ; x < mapSelection.width; x++) {
					result.map[x + (mapSelection.width * y)] = tl.readMapping(mapSelection.left + x, mapSelection.top + y);
				}
			}
		}
		return result;
	}
	/**
	 * Creates a copy event if called.
	 * Uses the internal states of this document.
	 */
	public void copy() {
		switch (getLayerInfo(selectedLayer).type) {
			case LayerType.Tile, LayerType.TransformableTile:
				MapClipboard.Item area = createMapClipboardItem();
				prg.mapClipboard.addItem(area);
				break;
			default:
				break;
		}
		outputWindow.updateRaster();
	}
	/**
	 * Creates a cut event if called.
	 * Uses the internal states of this document.
	 */
	public void cut() {
		switch (getLayerInfo(selectedLayer).type) {
			case LayerType.Tile, LayerType.TransformableTile:
				MapClipboard.Item area = createMapClipboardItem();
				prg.mapClipboard.addItem(area);
				events.addToTop(new CutFromTileLayerEvent(cast(ITileLayer)mainDoc.layeroutput[selectedLayer], mapSelection));
				break;
			default:
				break;
		}
		outputWindow.updateRaster();
	}
	/**
	 * Deletes the selected area.
	 */
	public void deleteArea() {
		switch (getLayerInfo(selectedLayer).type) {
			case LayerType.Tile, LayerType.TransformableTile:
				events.addToTop(new CutFromTileLayerEvent(cast(ITileLayer)mainDoc.layeroutput[selectedLayer], mapSelection));
				break;
			default:
				break;
		}
		outputWindow.updateRaster();
	}
	/**
	 * Creates a paste event if called.
	 * Uses the internal states of this document.
	 */
	public void paste(size_t which = 0) {
		switch (getLayerInfo(selectedLayer).type) {
			case LayerType.Tile, LayerType.TransformableTile:
				events.addToTop(new PasteIntoTileLayerEvent(prg.mapClipboard.getItem(which), 
						cast(ITileLayer)(mainDoc.layeroutput[selectedLayer]), mapSelection.cornerUL, voidfill));
				break;
			default:
				break;
		}
		outputWindow.updateRaster();
	}
	/**
	 * Context menu for selection events go here
	 */
	protected void onSelectContextMenuSelect (Event ev) {
		MenuEvent me = cast(MenuEvent)ev;
		switch (me.itemSource) {
			case "copy":
				copy;
				break;
			case "cut":
				cut;
				break;
			case "paste":
				paste;
				break;
			case "flph":
				flipTilesHoriz();
				break;
			case "flpv":
				flipTilesVert();
				break;
			case "mirh":
				selMirrorHoriz();
				break;
			case "mirv":
				selMirrorVert();
				break;
			case "shp":
				break;
			case "hm":
				selectedMappingElement.attributes.horizMirror = !selectedMappingElement.attributes.horizMirror;
				break;
			case "vm":
				selectedMappingElement.attributes.vertMirror = !selectedMappingElement.attributes.vertMirror;
				break;
			case "p+":
				selectedMappingElement.paletteSel++;
				break;
			case "p-":
				selectedMappingElement.paletteSel--;
				break;
			default:
				break;
		}
	}
	/**
	 * Removes a tile from the material list.
	 */
	public void removeTile(int id) {
		if (mainDoc.layeroutput[selectedLayer])
			events.addToTop(new RemoveTile(id, this, selectedLayer));
	}
	/**
	 * Renames a tile on the material list.
	 */
	public void renameTile(int id, string name) {
		if (mainDoc.layeroutput[selectedLayer])
			events.addToTop(new RenameTile(id, this, selectedLayer, name));
	}
	/**
	 * Removes a layer.
	 */
	public void removeLayer() {
		if (mainDoc.layeroutput[selectedLayer])
			events.addToTop(new RemoveLayer(this, selectedLayer));
	}
	/**
	 * Renames a layer.
	 */
	public void renameLayer(string newName) {
		if (mainDoc.layeroutput[selectedLayer])
			events.addToTop(new RenameLayer(this, selectedLayer, newName));
	}
	/**
	 * Moves the priority of a layer.
	 */
	public void changeLayerPriority(int newPri) {
		if (mainDoc.layeroutput[newPri]) {
			prg.wh.message("Layer edit error!", "Layer priority is already in use or invalid!");
		} else if (mainDoc.layeroutput[selectedLayer]) {
			events.addToTop(new ChangeLayerPriority(this, selectedLayer, newPri));
		}
	}
	/**
	 * Mirrors selected items horizontally.
	 */
	public void selMirrorHoriz() {
		switch (getLayerInfo(selectedLayer).type) {
			case LayerType.Tile, LayerType.TransformableTile:
				events.addToTop(new MirrorSelHTL(cast(ITileLayer)(mainDoc.layeroutput[selectedLayer]), mapSelection));
				break;
			default:
				break;
		}
	}
	/**
	 * Mirrors selected items vertically.
	 */
	public void selMirrorVert() {
		switch (getLayerInfo(selectedLayer).type) {
			case LayerType.Tile, LayerType.TransformableTile:
				events.addToTop(new MirrorSelVTL(cast(ITileLayer)(mainDoc.layeroutput[selectedLayer]), mapSelection));
				outputWindow.updateRaster();
				break;
			default:
				break;
		}
	}
	/**
	 * Mirrors selected items horizontally and vertically.
	 */
	public void selMirrorBoth() {
		switch (getLayerInfo(selectedLayer).type) {
			case LayerType.Tile, LayerType.TransformableTile:
				events.addToTop(new MirrorSelBTL(cast(ITileLayer)(mainDoc.layeroutput[selectedLayer]), mapSelection));
				outputWindow.updateRaster();
				break;
			default:
				break;
		}
	}
	/**
	 * Flips selected tiles horizontally.
	 */
	public void flipTilesHoriz() {
		if (getLayerInfo(selectedLayer).type == LayerType.Tile || 
				getLayerInfo(selectedLayer).type == LayerType.TransformableTile) {
			events.addToTop(new FlipSelTilesH(cast(ITileLayer)(mainDoc.layeroutput[selectedLayer]), mapSelection));
			outputWindow.updateRaster();
		}
	}
	/**
	 * Flips selected tiles vertically.
	 */
	public void flipTilesVert() {
		if (getLayerInfo(selectedLayer).type == LayerType.Tile || 
				getLayerInfo(selectedLayer).type == LayerType.TransformableTile) {
			events.addToTop(new FlipSelTilesV(cast(ITileLayer)(mainDoc.layeroutput[selectedLayer]), mapSelection));
			outputWindow.updateRaster();
		}
	}
	/**
	 * Fills selected area with selected tile, using overwrite rules defined by the materiallist.
	 */
	public void fillSelectedArea() {
		if (getLayerInfo(selectedLayer).type == LayerType.Tile || 
				getLayerInfo(selectedLayer).type == LayerType.TransformableTile) {
			ITileLayer target = cast(ITileLayer)mainDoc.layeroutput[selectedLayer];
			if (voidfill) {
				events.addToTop(new WriteToMapVoidFill(target, mapSelection, selectedMappingElement));
			} else {
				events.addToTop(new WriteToMapOverwrite(target, mapSelection, selectedMappingElement));
			}
			outputWindow.updateRaster();
		}
	}
	/**
	 * Assigns an imported tilemap to the currently selected layer.
	 */
	public void assignImportedTilemap(MappingElement[] map, int w, int h) {
		if (getLayerInfo(selectedLayer).type == LayerType.Tile || 
				getLayerInfo(selectedLayer).type == LayerType.TransformableTile) {
			events.addToTop(new ImportLayerData(cast(ITileLayer)mainDoc.layeroutput[selectedLayer], mainDoc.layerData[selectedLayer], map, w, 
					h));
		}
	}
}
