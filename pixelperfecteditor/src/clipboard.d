module clipboard;

import pixelperfectengine.graphics.layers.base : MappingElement;

/**
 * Implements a clipboard for maps, with history.
 */
public class MapClipboard {
    /**
     * A single entry in the clipboard.
     */
    public struct Item {
        public int      width;  ///The width of the selected area
        public int      height; ///The height of the selected area
        public MappingElement[] map;///The map that is being copied/cutted
    }
    ///List of items on the clipboard
    protected Item[]    items;
    /**
     * Creates an instance of this class, with the given number of maximum items.
     */
    public this(size_t historyLength) @safe nothrow pure {
        items.length = historyLength;
    }
    ///Adds a new element to the clipboard.
    public void addItem(Item i) @safe nothrow pure {
        items = i ~ items[1..$-1];
    }
    ///Returns the n-th element from the clipboard.
    public Item getItem(size_t n) @nogc @safe pure nothrow {
        return items[n];
    }
}