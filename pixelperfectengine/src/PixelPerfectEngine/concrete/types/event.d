module PixelPerfectEngine.concrete.types.event;

import PixelPerfectEngine.concrete.elements.base;
import PixelPerfectEngine.concrete.popup.base;
public import PixelPerfectEngine.system.input.types;

import PixelPerfectEngine.concrete.elements.listview : ListViewItem;

/**
 * Defines an event in the GUI.
 */
public class Event {
	///The origin of the event
	public Object		 	sender;
	///Auxilliary event data (secondary sender, selection, etc)
	///Type can be checked with classinfo.
	public Object			aux;
	///The type of this event
	public EventType		type;
	///The type of the sender
	public SourceType		srcType;
	///Default CTOR
	this (Object sender, EventType type, SourceType srcType) @nogc @safe pure nothrow {
		this.sender = sender;
		this.type = type;
		this.srcType = srcType;
	}
	///Ditto
	this (Object sender, Object aux, EventType type, SourceType srcType) @nogc @safe pure nothrow {
		this.sender = sender;
		this.aux = aux;
		this.type = type;
		this.srcType = srcType;
	}
}
/**
 * Defines a cell editing event.
 */
public class CellEditEvent : Event {
	///The number of row that was edited
	public int				row;
	///The number of column that was edited
	public int				column;
	///Default CTOR
	this (Object sender, Object aux, int row, int column) @nogc @safe pure nothrow {
		super(sender, aux, EventType.CellEdit, SourceType.WindowElement);
		this.row = row;
		this.column = column;
	}
	///Returns the edited text of the cell
	public Text text() @trusted @nogc pure nothrow {
		ListViewItem getListViewItem() @system @nogc pure nothrow {
			return cast(ListViewItem)aux;
		}
		return getListViewItem()[column].text;
	}
}
/**
 * Defines a mouse event in the GUI.
 */
public class MouseEvent : Event {
	///Stores mouseclick event data
	MouseClickEvent			mce;
	///Stores mousewheel event data (direction, etc)
	MouseWheelEvent			mwe;
	///Mouse motion event values
	///Mouse scroll event position is stored here
	MouseMotionEvent		mme;
	///Common values for mouse events
	MouseEventCommons		mec;
	///Default CTOR
	///Any other fields should be set after construction
	this (Object sender, EventType type, SourceType srcType) @nogc @safe pure nothrow {
		super(sender, type, srcType);
	}
}
/**
 * Defines a file event (save, open, etc.)
 */
public class FileEvent : Event {
	string		path;		///The path where the file is found or being written to.
	string		filename;	///The name of the target file.
	string		extension;	///The selected file extension.
	///Default CTOR
	this (Object sender, SourceType srcType, string path, string filename, string extension) @nogc @safe pure nothrow {
		super(sender, EventType.File, srcType);
		this.path = path;
		this.filename = filename;
		this.extension = extension;
	}
	/**
	 * Returns the full path.
	 */
	public string getFullPath() @safe pure nothrow const {
		import std.path : extension;
		if (extension(filename).length)
			return path ~ filename;
		else
			return path ~ filename ~ this.extension;
	}
}
/**
 * Defines a menu event.
 */
public class MenuEvent : Event {
	Text		text;		///Text of the selected menu item.
	size_t		itemNum;	///Number of the selected item.
	string		itemSource;	///Source ID of the menu item.
	///Default CTOR
	this (Object sender, SourceType srcType, Text text, size_t itemNum, string itemSource) {
		super(sender, EventType.Menu, srcType);
		this.text = text;
		this.itemNum = itemNum;
		this.itemSource = itemSource;
	}
}
/**
 * Defines event types.
 * Mouse events and file events have data that can be accessed via extra fields in an inherited class.
 * Selection uses the aux field.
 * Text input and other value change events should be checked on the source for value changes.
 */
public enum EventType {
	MouseMotion,
	MouseClick,
	MouseScroll,
	Menu,
	TextInput,
	File,
	Selection,
	Toggle,
	CellEdit,
}
/**
 * Defines source types.
 */
public enum SourceType {
	WindowElement,
	RadioButtonGroup,
	DialogWindow,
	PopUpElement,
}