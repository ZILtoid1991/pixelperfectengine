module pixelperfectengine.collision.tilecollision;

import pixelperfectengine.graphics.layers.interfaces : ITileLayer;
import collections.treemap;
public import pixelperfectengine.collision.common;

/** 
 * Test objects against a tilemap along its edges.
 *
 * When called, it either tests all or a selected set of objects against the tilemap, then returns 4 lists of the tiles 
 * encountered if they haven't been registered to the "exclutedTiles" set.
 */
public class TileCollisionDetector {
	alias ExcludedTileset = TreeMap!(wchar, void);
	protected int		contextID;
	ObjectMap			objects;	///Contains all the objects (collision shapes are not used)
	ITileLayer			source;		///Contains a pointer to the source tile layer
	ExcludedTileset		excludedTiles;///Contains a set of all excluded tiles (contains 0xffff by default)
	/** 
	 * Called upon an object to tile collision event.
	 */
	protected void delegate(TileCollisionEvent)			objectToTileCollision;
	public this(void delegate(TileCollisionEvent) objectToTileCollision, int contextID, ITileLayer source) @safe nothrow {
		this.contextID = contextID;
		this.objects = objects;
		this.source = source;
		excludedTiles.put(0xffff);
	}
}