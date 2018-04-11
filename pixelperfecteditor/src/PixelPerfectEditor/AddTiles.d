import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.graphics.common;

public class NewWindow : Window{ 
	ListBox listBox_Added;
	ListBox listBox_Available;
	Button button_Add;
	Button button_Remove;
	Button button_Finish;
	Button button_ABI;
	Label label1;
	Label label2;
	Label label3;
	TextBox textBox_Name;
	TextBox textBox_ID;
	Label label4;
	this(){
		super(Coordinate(0, 0, 485, 340), "New project"w);
		listBox_Added = new ListBox("listBox_Added",Coordinate(5, 20, 245, 225), null, new ListBoxHeader(["Col0"w, "Col1"w, ], [40, 40, ]), 16);
		addElement(listBox_Added, EventProperties.MOUSE);
		listBox_Available = new ListBox("listBox_Available",Coordinate(250, 20, 480, 225), null, new ListBoxHeader(["Col0"w, "Col1"w, ], [40, 40, ]), 16);
		addElement(listBox_Available, EventProperties.MOUSE);
		button_Add = new Button("Add"w, "button_Add", Coordinate(335, 230, 405, 250));
		addElement(button_Add, EventProperties.MOUSE);
		button_Remove = new Button("Remove"w, "button_Remove", Coordinate(410, 230, 480, 250));
		addElement(button_Remove, EventProperties.MOUSE);
		button_Finish = new Button("Finish"w, "button_Finish", Coordinate(410, 255, 480, 275));
		addElement(button_Finish, EventProperties.MOUSE);
		button_ABI = new Button("Add by instrinct"w, "button_ABI", Coordinate(250, 255, 405, 275));
		addElement(button_ABI, EventProperties.MOUSE);
		label1 = new Label("Name:"w, "label1", Coordinate(5, 232, 66, 248));
		addElement(label1, EventProperties.MOUSE);
		label2 = new Label("ID:"w, "label2", Coordinate(5, 257, 68, 273));
		addElement(label2, EventProperties.MOUSE);
		label3 = new Label("Instrinct: foretag####aftertag"w, "label3", Coordinate(5, 282, 400, 300));
		addElement(label3, EventProperties.MOUSE);
		textBox_Name = new TextBox("NULL"w, "textBox_Name", Coordinate(55, 230, 330, 250));
		addElement(textBox_Name, EventProperties.MOUSE);
		textBox_ID = new TextBox("0x0000"w, "textBox_ID", Coordinate(55, 255, 150, 275));
		addElement(textBox_ID, EventProperties.MOUSE);
		label4 = new Label("Replace # with d, h, o depending on the numbering system"w, "label4", Coordinate(5, 307, 479, 323));
		addElement(label4, EventProperties.MOUSE);
	}
}