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

public class ImportDialog : Window, ActionListener { 
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
		super(Coordinate(0, 0, 225, 225), "Import bitmap"w);
		label1 = new Label("ID:"w, "label1", Coordinate(5, 22, 70, 40));
		bitmapID = new TextBox(""w, "bitmapID", Coordinate(80, 20, 220, 40));
		paletteID = new TextBox("default"w, "paletteID", Coordinate(80, 45, 220, 65));
		label2 = new Label("Palette:"w, "label2", Coordinate(5, 47, 75, 65));
		chkBPal = new CheckBox("Import palette from file"w, "chkBPal", Coordinate(5, 70, 220, 90));
		radioButtonGroup1 = new RadioButtonGroup("Bitdepth:"w, "radioButtonGroup1", Coordinate(5, 95, 220, 195),[ "1bit"w, "4bit"w, "8bit"w, "16bit"w, "32bit"w], 16, 0);
		buttonOk = new Button("Ok"w, "buttonOk", Coordinate(145, 200, 220, 220));
		buttonClose = new Button("Close"w, "buttonClose", Coordinate(65, 200, 135, 220));
		addElement(label1, EventProperties.MOUSE);
		addElement(bitmapID, EventProperties.MOUSE);
		addElement(paletteID, EventProperties.MOUSE);
		addElement(label2, EventProperties.MOUSE);
		addElement(chkBPal, EventProperties.MOUSE);
		addElement(radioButtonGroup1, EventProperties.MOUSE);
		addElement(buttonOk, EventProperties.MOUSE);
		buttonOk.al ~= this;
		buttonClose.al ~= this;
		addElement(buttonClose, EventProperties.MOUSE);
		this.c = c;
	}
	override public void actionEvent(Event event) {
		switch(event.source){
			case "buttonOk":
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
				parent.closeWindow(this);
				break;
			case "buttonClose":
				parent.closeWindow(this);
				break;
			default: 
				break;
		}
	}
	
}