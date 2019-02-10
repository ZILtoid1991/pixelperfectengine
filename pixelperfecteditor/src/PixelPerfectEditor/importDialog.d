/*
 * PixelPerfectEditor, importDialog module
 *
 * Copyright 2017, under Boost License
 *
 * by Laszlo Szeremi
 */

module importDialog;

import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.graphics.common;

import std.conv;

import converterdialog;

public class ImportDialog : Window {
	Label label1;
	TextBox bitmapID;
	TextBox paletteID;
	Label label2;
	CheckBox chkBPal;
	RadioButtonGroup radioButtonGroup1;
	Button buttonOk;
	Button buttonClose;
	ConverterDialog c;
	this(ConverterDialog c){
		super(Coordinate(0, 0, 225, 225), "Import bitmap"d);
		label1 = new Label("ID:"d, "label1", Coordinate(5, 22, 70, 40));
		bitmapID = new TextBox(""d, "bitmapID", Coordinate(80, 20, 220, 40));
		paletteID = new TextBox("default"d, "paletteID", Coordinate(80, 45, 220, 65));
		label2 = new Label("Palette:"d, "label2", Coordinate(5, 47, 75, 65));
		chkBPal = new CheckBox("Import palette from file"d, "chkBPal", Coordinate(5, 70, 220, 90));
		radioButtonGroup1 = new RadioButtonGroup("Bitdepth:"d, "radioButtonGroup1", Coordinate(5, 95, 220, 195),[ "1bit"d,
				"4bit"d, "8bit"d, "16bit"d, "32bit"d], 16, 0);
		buttonOk = new Button("Ok"d, "buttonOk", Coordinate(145, 200, 220, 220));
		buttonClose = new Button("Close"d, "buttonClose", Coordinate(65, 200, 135, 220));
		addElement(label1, EventProperties.MOUSE);
		addElement(bitmapID, EventProperties.MOUSE);
		addElement(paletteID, EventProperties.MOUSE);
		addElement(label2, EventProperties.MOUSE);
		addElement(chkBPal, EventProperties.MOUSE);
		addElement(radioButtonGroup1, EventProperties.MOUSE);
		addElement(buttonOk, EventProperties.MOUSE);
		buttonOk.onMouseLClickRel = &buttonOk_mouseLClickRel;
		buttonClose.onMouseLClickRel = &buttonClose_mouseLClickRel;
		addElement(buttonClose, EventProperties.MOUSE);
		this.c = c;
	}
	private void buttonOk_mouseLClickRel(Event ev) {
		string bitDepth;
		switch(radioButtonGroup1.value){
			case 1:
				bitDepth = "4bit";
				break;
			case 2:
				bitDepth = "8bit";
				break;
			case 3:
				bitDepth = "16bit";
				break;
			case 4:
				bitDepth = "32bit";
				break;
			default:
				bitDepth = "1bit";
				break;
		}
		c.singleImport(to!string(bitmapID.getText()), to!string(paletteID.getText()), chkBPal.value, bitDepth);
		close();
	}
	private void buttonClose_mouseLClickRel(Event ev){
		close();
	}
}
