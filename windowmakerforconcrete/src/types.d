module types;

public import PixelPerfectEngine.concrete.elements;

public enum ValueType {
	String,
	StringArray,
	WString,
	WStringArray,
	Int,
	Bool,
}
public enum ElementType {
	NULL,
	Label,
	Button,
	SmallButton,
	TextBox,
	ListView,
	RadioButton,
	CheckBox,
	HSlider,
	VSlider,
	Panel,
	MenuBar,
}
public enum EditMode {
	Default,
	Placement,
	Move,
}
/**
 * Stores the pointer to the element, its name and type
 */
public struct ElementInfo {
	WindowElement		element;		///The pointer to the element itself.
	string				name;			///The name of the element.
	string				type;			///The type of the element.
	bool opEquals(const ElementInfo other) const @nogc @safe pure nothrow {
		return this.name == other.name;
	}
}