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