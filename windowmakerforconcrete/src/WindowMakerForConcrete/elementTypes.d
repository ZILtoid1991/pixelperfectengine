module elementTypes;

import std.conv;
import std.stdio;

import PixelPerfectEngine.concrete.elements;
import PixelPerfectEngine.graphics.common;
import PixelPerfectEngine.system.inputHandler;

public class ElementParameter{
	string name;
	int type;
	wstring text;
	int numeric;
	public this(){}
}

public enum ElementValueParameter{
	OpensANewWindow,
	None,
	Text,
	Description,
	Numeric
}

public void loadParametersIntoListbox(ListBox l, ElementParameter[] data){
	ListBoxItem[] newItems;
	/*newItems ~= new ListBoxItem(["text", data["text"]], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["name", data["name"]], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["source", data["source"]], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["icon", data["icon"]], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["top", data["Coordinate.top"]], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["bottom", data["Coordinate.bottom"]], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["left", data["Coordinate.left"]], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["right", data["Coordinate.right"]], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["CSS.borderWidth", data["CSS.borderWidth"]], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["CSS.borderColorA", data["CSS.borderColorA"]], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["CSS.borderColorB", data["CSS.borderColorB"]], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["CSS.button", data["CSS.button"]], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["CSS.buttonPressed", data["CSS.buttonPressed"]], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["CSS.fontType", data["CSS.fontType"]], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["CSS.fontColor", data["CSS.fontColor"]], [TextInputType.DISABLE, TextInputType.TEXT]);*/
	foreach(s ; data){
		//writeln(s.name,";",s.text,";",s.numeric);
		newItems ~= new ListBoxItem([to!wstring(s.name), s.type == ElementValueParameter.Numeric ? to!wstring(s.numeric) : s.text], [TextInputType.DISABLE, s.type == ElementValueParameter.None || s.type == ElementValueParameter.OpensANewWindow ? TextInputType.DISABLE : TextInputType.TEXT]);
	}
	l.updateColumns(newItems);
}

/*public void loadLabelParametersIntoListbox(ListBox l, Coordinate initialPosition, string initialName){
	ListBoxItem[] newItems;
	newItems ~= new ListBoxItem(["text", data["text"]], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["name", data["name"]], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["source", data["source"]], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["top", data["Coordinate.top"]], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["bottom", data["Coordinate.bottom"]], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["left", data["Coordinate.left"]], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["right", data["Coordinate.right"]], [TextInputType.DISABLE, TextInputType.DECIMAL]);
	newItems ~= new ListBoxItem(["CSS.fontType", data["CSS.fontType"]], [TextInputType.DISABLE, TextInputType.TEXT]);
	newItems ~= new ListBoxItem(["CSS.fontColor", data["CSS.fontColor"]], [TextInputType.DISABLE, TextInputType.TEXT]);
}*/