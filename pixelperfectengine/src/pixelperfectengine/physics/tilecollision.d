module pixelperfectengine.physics.tilecollision;

import pixelperfectengine.graphics.layers.interfaces : ITileLayer;
import collections.treemap;
public import pixelperfectengine.physics.common;

/** 
 * Test objects against a tilemap.
 *
 * When called, it either tests all or a selected set of objects against the tilemap, then returns 4 lists of the tiles 
 * encountered if they haven't been registered to the "exclutedTiles" set.
 *
 * Note: Might get removed in the future.
 */
public class TileCollisionDetector {
	alias ExcludedTileset = TreeMap!(wchar, void);
	protected int		contextID;
	ObjectMap			objects;	///Contains all the objects (collision shapes are not used)
	ITileLayer			source;		///Contains a pointer to the source tile layer
	//ExcludedTileset		excludedTiles;///Contains a set of all excluded tiles (contains 0xffff by default)
	/** 
	 * Called upon an object to tile collision event.
	 */
	protected void delegate(TileCollisionEvent)			objectToTileCollision;
	public this(void delegate(TileCollisionEvent) objectToTileCollision, int contextID, ITileLayer source) @safe nothrow {
		this.contextID = contextID;
		this.objects = objects;
		this.source = source;
		//excludedTiles.put(0xffff);
	}
	public void testAll() {
		foreach (int iA, ref CollisionShape shA; objects) {
			testSingle(iA, &shA);
		}
	}
	public void testSingle(int objectID) {
		testSingle(objectID, objects.ptrOf(objectID));
	}
	protected final void testSingle(int iA, CollisionShape* shA) {
		const int tW = source.getTileWidth, tH = source.getTileHeight;
		TileCollisionEvent event = TileCollisionEvent(shA, contextID, iA, 0, 0, []);
		for (int tY = shA.position.top ; tY <= shA.position.bottom ; tY+=tH) {
			for (int tX = shA.position.left ; tX <= shA.position.right ; tX+=tW) {
				event.overlapList ~= source.tileByPixel(tX, tY);
			}
			event.numTilesV++;		//TODO: Replace it immediately once you find something better
		}
		for (int tX = shA.position.left ; tX <= shA.position.right ; tX+=tH) event.numTilesH++;		//TODO: Replace it immediately once you find something better
		//if (event.overlapList.length) 
		objectToTileCollision(event);
	}
}
/** 
 * Lists all the tiles overlapped by the given object's prelimiters
 * Params:
 *   object = The object's prelimiters.
 *   layer = The ITileLayer, that contains the tile information.
 * Returns: An array of the tiles overlapped by the object, with the tiles being in order of left-to-right,
 * top-to-bottom. This means the top-left tile is the first one.
 */
public MappingElement2[] getAllOverlappingTiles(Box object, ITileLayer layer) @safe nothrow {
	const int tW = layer.getTileWidth, tH = layer.getTileHeight;
	MappingElement2[] overlapList;
	int tY = object.top;
	while (tY <= object.bottom) {
		int tX = object.left;
		while (tX <= object.right) {
			overlapList ~= layer.tileByPixel(tX, tY);
			tX += tX % tH == 0 ? tH : tH - (tX % tH);
		}
		tY += tY % tW == 0 ? tW : tW - (tY % tW);
	}
	return overlapList;
}
