import PixelPerfectEngine.concrete.window;

public class NewTileLayerDialog : Window {
	Label label0;
	TextBox textBox_TS;
	Button button_TSBrowse;
	Label label1;
	Label label2;
	TextBox textBox_TX;
	TextBox textBox_TY;
	Label label3;
	Button button_MSB;
	TextBox textBox_MS;
	CheckBox CheckBox_embed;
	Label label4;
	Label label5;
	TextBox textBox_MX;
	TextBox textBox_MY;
	Button button_Create;
	public this(){
		super(Coordinate(0, 0, 165, 224 ), "Create New Tile Layer"d);
		label0 = new Label("Tile source:"d, "label0", Coordinate(5, 22, 71, 40));
		addElement(label0);
		textBox_TS = new TextBox("none"d, "textBox_TS", Coordinate(5, 41, 160, 59));
		addElement(textBox_TS);
		button_TSBrowse = new Button("Browse"d, "button_TSBrowse", Coordinate(70, 21, 160, 39));
		addElement(button_TSBrowse);
		label1 = new Label("Tile Width:"d, "label1", Coordinate(5, 62, 70, 79));
		addElement(label1);
		label2 = new Label("Tile Height:"d, "label2", Coordinate(5, 82, 70, 99));
		addElement(label2);
		textBox_TX = new TextBox("8"d, "textBox_TX", Coordinate(80, 61, 160, 79));
		addElement(textBox_TX);
		textBox_TY = new TextBox("8"d, "textBox_TY", Coordinate(80, 81, 160, 99));
		addElement(textBox_TY);
		label3 = new Label("Map source:"d, "label3", Coordinate(5, 102, 70, 118));
		addElement(label3);
		button_MSB = new Button("Browse"d, "button_MSB", Coordinate(70, 101, 160, 119));
		addElement(button_MSB);
		textBox_MS = new TextBox("none"d, "textBox_MS", Coordinate(5, 121, 160, 139));
		addElement(textBox_MS);
		CheckBox_embed = new CheckBox("Embed as BASE64"d, "CheckBox_embed", Coordinate(5, 142, 160, 160));
		addElement(CheckBox_embed);
		label4 = new Label("Map Width:"d, "label4", Coordinate(5, 162, 70, 178));
		addElement(label4);
		label5 = new Label("Map Height:"d, "label5", Coordinate(5, 182, 70, 198));
		addElement(label5);
		textBox_MX = new TextBox("64"d, "textBox_MX", Coordinate(70, 161, 160, 179));
		addElement(textBox_MX);
		textBox_MY = new TextBox("64"d, "textBox_MY", Coordinate(70, 181, 160, 199));
		addElement(textBox_MY);
		button_Create = new Button("Create"d, "button_Create", Coordinate(70, 201, 160, 219));
		addElement(button_Create);
	}
	private void button_TSBrowse_onClick(Event ev){
		parent.addWindow(new FileDialog("Import Tile Source"d, "fileDialog_TSBrowse", &fileDialog_TSBrowse_event,
				[FileDialog.FileAssociationDescriptor("PPE Map file", ["*.pmp"])], "./"));
	}
	private void fileDialog_TSBrowse_event(Event ev){

	}
	private void button_MSBrowse_onClick(Event ev){
		parent.addWindow(new FileDialog("Import Tile Source"d, "fileDialog_MSBrowse", &fileDialog_MSBrowse_event,
				[FileDialog.FileAssociationDescriptor("PPE Map file", ["*.pmp"]),
				FileDialog.FileAssociationDescriptor("PPE Binary Map file", ["*.map"])], "./"));
	}
	private void fileDialog_MSBrowse_event(Event ev){

	}
	private void button_Create_onClick(Event ev){

	}
}
