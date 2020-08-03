module types;

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
	ListBox,
	RadioButton,
	CheckBox,
	HSlider,
	VSlider,
	MenuBar,
}
public enum EditMode {
	Default,
	Placement,
	Move,
}