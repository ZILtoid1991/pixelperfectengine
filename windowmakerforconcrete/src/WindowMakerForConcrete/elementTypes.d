module elementTypes;

import std.conv;

import PixelPerfectEngine.concrete.elements;
import PixelPerfectEngine.graphics.common;
import PixelPerfectEngine.system.inputHandler;

public void loadButtonParametersIntoListbox(ListBox l, Coordinate initialPosition, string initialName){
	ListBoxItem[] newItems;
	newItems ~= new ListBoxItem(["text", ""], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["name", to!wstring(initialName)], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["source", to!wstring(initialName)], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["top", ""], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["bottom", ""], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["left", ""], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["right", ""], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["CSS.borderWidth", ""], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["CSS.borderColorA", ""], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["CSS.borderColorB", ""], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["CSS.button", ""], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["CSS.buttonPressed", ""], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["CSS.fontType", ""], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["CSS.fontColor", ""], [TextInputType.DISABLE, TextInputType.TEXT]);
}

public void loadLabelParametersIntoListbox(ListBox l, Coordinate initialPosition, string initialName){
	ListBoxItem[] newItems;
	newItems ~= new ListBoxItem(["text", ""], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["name", to!wstring(initialName)], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["source", to!wstring(initialName)], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["top", ""], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["bottom", ""], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["left", ""], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["right", ""], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["CSS.fontType", ""], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["CSS.fontColor", ""], [TextInputType.DISABLE, TextInputType.TEXT]);
}