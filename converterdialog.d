module converterdialog;

import windowing.window;
import windowing.elements;

import map.mapload;

import system.etc;

import extbmp.extbmp;

import converter;

public class ConverterDialog : Window, ActionListener{
	private ListBox imageList, fileList;
	private string[] files;
	public this(InputHandler inputhandler, MapHandler mh = null){
		this(Coordinate(0,0,640,480), "XMP Converter Toolkit");
		Button [] buttons;
		if(mh !is null){

			files = mh.getAllFilenames();
			fileList = new ListBox("fileList",Coordinate(4,20,204,101), ListBoxColumn("Filename",[""]), [256], 15);
		}else{

		}
		buttons ~= new Button("New File","newfile", Coordinate(210,20,294,39));
		buttons ~= new Button("Load File","loadfile", Coordinate(210,50,294,69));
		buttons ~= new Button("Save File","savefile", Coordinate(210,80,294,99));
	}

	public this(Coordinate size, wstring title){
		super(size, title);
	}
	public void actionEvent(string source, int type, int value, wstring message){}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
}