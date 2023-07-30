module test1.sampleman;

import pixelperfectengine.concrete.window;
import pixelperfectengine.audio.base.types;
import pixelperfectengine.audio.base.func;
import pixelperfectengine.audio.base.config;
import std.math : floor, nearbyint;
import std.conv;
import test1.app;
import test1.editorevents;

public class WaveformViewer : WindowElement {
	int[] waveform;
	public this(string source, Box position) {
		this.source = source;
		this.position = position;
	}
	public void setWaveform(const(ubyte)[] src, WaveFormat fmt) {
		DecoderWorkpad wp;
		switch (fmt.format) {		
			case AudioFormat.PCM:
				if (fmt.bitsPerSample == 8) {
					waveform.length = src.length;
					decode8bitPCM(cast(const(ubyte)[])src, waveform, wp);
				} else if (fmt.bitsPerSample == 16) {
					waveform.length = src.length / 2;
					decode16bitPCM(cast(const(short)[])src, waveform, wp);
				}
				break;
			case AudioFormat.ADPCM, AudioFormat.IMA_ADPCM:
				waveform.length = src.length * 2;
				decode4bitIMAADPCM(ADPCMStream(src.dup, src.length*2), waveform, wp);
				break;
			case AudioFormat.DIALOGIC_OKI_ADPCM, AudioFormat.OKI_ADPCM:
				waveform.length = src.length * 2;
				decode4bitDialogicADPCM(ADPCMStream(src.dup, src.length*2), waveform, wp);
				break;
			case AudioFormat.MULAW:
				waveform.length = src.length;
				decodeMuLawStream(cast(const(ubyte)[])src, waveform, wp);
				break;
			case AudioFormat.ALAW:
				waveform.length = src.length;
				decodeALawStream(cast(const(ubyte)[])src, waveform, wp);
				break;
			default:
				return;
		}
	}
	public override void draw() {
		if (parent is null) return;
		StyleSheet ss = getStyleSheet();
		parent.clearArea(position);
		parent.drawBox(position, 24);
		if (waveform.length) {
			real ratio = cast(real)waveform.length / position.width;
			const int divident = ushort.max / position.height() * -1;
			{
				Point o = Point(0, position.height / 2);
				parent.drawLine(position.cornerUL + o, position.cornerUR + o, 23);
			}
			Point p0 = Point(position.left, (waveform[0] / divident) + position.top + (position.height / 2));
			for (int i ; i < position.width - 1 ; i++) {
				/+Point p0 = 
						Point(i + position.left, 
						(waveform[cast(size_t)nearbyint(i * ratio)] / divident) + position.top + (position.height / 2));+/
				const Point p1 =
						Point(i + position.left + 1, 
						(waveform[cast(size_t)nearbyint(i * ratio) + 1] / divident) + position.top + (position.height / 2));
				parent.drawLine(p0, p1, 0x1F);
				p0 = p1;
			}

			if (isFocused) {
				const int textPadding = ss.drawParameters["horizTextPadding"];
				parent.drawBoxPattern(position - textPadding, ss.pattern["blackDottedLine"]);
			}
		}
		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
		if (onDraw !is null) {
			onDraw();
		}
	}
}

public class SampleMan : Window {
	ListView listView_sampleList;
	Button button_load;
	Button button_slice;
	Button button_remove;
	Label label_info;
	Label label_format;
	Label label_slmpR;
	Label label_len;
	WaveformViewer wfv;
	
	AudioDevKit adk;

	WaveFileData[] waveFileData;
	string path;

	string moduleName;
	//TextBox textBox0;
	public this(AudioDevKit adk) {
		moduleName = adk.selectedModID;
		this.adk = adk;

		super(Box(0, 0, 520, 322), "Sample manager ["d ~ moduleName.to!dstring ~ "]"d);
		listView_sampleList = new ListView(new ListViewHeader(16, [40, 120, 250], ["ID" ,"name" ,"file source"]), null, 
				"listView0", Box(5, 20, 335, 185));
		button_load = new Button("Load"d, "button0", Box(340, 20, 440, 40));
		button_slice = new Button("Slice"d, "button1", Box(340, 45, 440, 65));
		button_remove = new Button("Remove"d, "button0", Box(340, 70, 440, 90));
		label_info = new Label("Info:"d, "label0", Box(340, 95, 500, 115));
		label_format = new Label("Format:"d, "label1", Box(340, 118, 512, 138));
		label_slmpR = new Label("Orig. samplerate:"d, "label2", Box(340, 140, 512, 160));
		label_len = new Label("Length:"d, "label3", Box(340, 162, 512, 182));
		//textBox0 = new TextBox("Placeholder"d, "textBox0", Box(4, 190, 516, 318));
		wfv = new WaveformViewer("wfv", Box(4, 190, 516, 318));

		addElement(listView_sampleList);
		addElement(button_load);
		addElement(button_slice);
		addElement(button_remove);
		addElement(label_info);
		addElement(label_format);
		addElement(label_slmpR);
		addElement(label_len);
		addElement(wfv);

		button_load.onMouseLClick = &button_load_onClick;
		button_slice.onMouseLClick = &button_slice_onClick;
		button_remove.onMouseLClick = &button_remove_onClick;
		listView_sampleList.onItemSelect = &listView_sampleList_onSelect;
		listView_sampleList.onTextInput = &listView_sampleList_onTextEdit;
		listView_sampleList.editEnable = true;

		refreshSampleList();
	}
	protected void refreshSampleList() {
		waveFileData = adk.mcfg.getWaveFileList(moduleName);
		listView_sampleList.clear();
		foreach (WaveFileData key; waveFileData) {
			listView_sampleList ~= new ListViewItem(16, [to!dstring(key.id), to!dstring(key.name), to!dstring(key.path)], 
					[TextInputFieldType.None, TextInputFieldType.ASCIIText, TextInputFieldType.None]);
		}
		listView_sampleList.refresh();
	}
	protected void listView_sampleList_onSelect(Event ev) {
		if (listView_sampleList.value >= 0) {
			import pixelperfectengine.audio.base.modulebase;
			ModuleConfig mcfg = adk.mcfg;
			AudioModule am = mcfg.getModule(moduleName);
			wfv.setWaveform(am.getWaveformData(listView_sampleList.value), am.getWaveformDataFormat(listView_sampleList.value));
			wfv.draw();
			WaveFormat wf = am.getWaveformDataFormat(listView_sampleList.value);
			dstring format;
			switch(wf.format) {
				case AudioFormat.PCM:
					if (wf.bitsPerSample == 8) {
						format = "PCM 8Bit U"d;
					} else if (wf.bitsPerSample == 16) {
						format = "PCM 16Bit S"d;
					}
					break;
				case AudioFormat.ADPCM, AudioFormat.IMA_ADPCM:
					format = "IMA ADPCM 4Bit"d;
					break;
				case AudioFormat.DIALOGIC_OKI_ADPCM, AudioFormat.OKI_ADPCM:
					format = "Dialogic ADPCM"d;
					break;
				case AudioFormat.MULAW:
					format = "Mu-Law ADPCM"d;
					break;
				case AudioFormat.ALAW:
					format = "A-Law ADPCM"d;
					break;
				default:
					format = "UNKNOWN";
					break;
			}
			label_format.setText("Format: "d ~ format);
			label_slmpR.setText("Orig. samplerate:"d ~ to!dstring(wf.samplerate));
			label_len.setText("Length:"d ~ to!dstring(wfv.waveform.length));
		}
	}
	protected void listView_sampleList_onTextEdit(Event ev) {
		CellEditEvent cev = cast(CellEditEvent)ev;
		if (listView_sampleList.value >= 0) {
			WaveFileData wfd = waveFileData[listView_sampleList.value];
			adk.eventStack.addToTop(new RenameSample(adk.mcfg, moduleName, wfd.id, to!string(cev.text.toDString)));
		}
	}
	protected void button_load_onClick(Event ev) {
		import pixelperfectengine.concrete.dialogs.filedialog;
		handler.addWindow(new FileDialog("Add sample"d, "sampleLoad", &onSampleLoad, 
				[FileDialog.FileAssociationDescriptor("Wave file", [".wav"]), 
				FileDialog.FileAssociationDescriptor("Dialogic ADPCM file", [".vox", ".ad4"])], "./"));
	}
	protected void onSampleLoad(Event ev) {
		import pixelperfectengine.concrete.dialogs.textinputdialog;
		FileEvent fev = cast(FileEvent)ev;
		path = fev.getFullPath();
		handler.addWindow(new TextInputDialog(Box.bySize(0, 0, 500, 120), &onSampleCreate, "sampleID", "Add sample", 
				"Sample ID?"));
	}
	protected void onSampleCreate(Text tx) {
		try {
			const int sampleID = to!int(tx.toDString);
			//check if sample exists
			foreach (WaveFileData key; waveFileData) {
				if (key.id == sampleID) return;
			}
			adk.eventStack.addToTop(new AddSampleFile(adk.mcfg, moduleName, sampleID, path));
			refreshSampleList();
		} catch (Exception e) {

		}
	}
	protected void button_slice_onClick(Event ev) {
		handler.addWindow(new SliceDialog(&onSliceCreate));
	}
	protected void onSliceCreate(int id, int begin, int end) {
		if (listView_sampleList.value >= 0) {
			const int src = waveFileData[listView_sampleList.value].id;
			const int len = end - begin;
			adk.eventStack.addToTop(new AddSampleSlice(adk.mcfg, moduleName, id, src, begin, len));
			refreshSampleList();
		}
	}
	protected void button_remove_onClick(Event ev) {
		if (listView_sampleList.value >= 0) {
			const int selID = waveFileData[listView_sampleList.value].id;
			adk.eventStack.addToTop(new RemoveSample(adk.mcfg, moduleName, selID));
			refreshSampleList();
		}
	}
}

public class SliceDialog : Window {
	Label label_newID;
	Label label_from;
	Label label_to;
	TextBox textBox_newID;
	TextBox textBox_from;
	TextBox textBox_to;
	Button button_create;
	void delegate(int id, int begin, int end) onCreate;
	public this(void delegate(int id, int begin, int end) onCreate) {
		this.onCreate = onCreate;
		super(Box.bySize(0,0,125,120), "Create new slice");
		label_newID = new Label("New ID:", "label_newID", Box(5,20,55,40));
		label_from = new Label("From:", "label_from", Box(5,45,55,65));
		label_to = new Label("To:", "label_to", Box(5,70,55,90));
		textBox_newID = new TextBox("", "textBox_newID", Box(55, 20, 120, 40));
		textBox_from = new TextBox("", "textBox_from", Box(55, 45, 120, 65));
		textBox_to = new TextBox("", "textBox_to", Box(55, 70, 120, 90));
		button_create = new Button("Create", "button_create", Box(60, 95, 120, 115));

		textBox_newID.setFilter(TextInputFieldType.IntegerP);
		textBox_from.setFilter(TextInputFieldType.IntegerP);
		textBox_to.setFilter(TextInputFieldType.IntegerP);

		addElement(label_newID);
		addElement(label_from);
		addElement(label_to);
		addElement(textBox_newID);
		addElement(textBox_from);
		addElement(textBox_to);
		addElement(button_create);
		button_create.onMouseLClick = &button_create_onClick;
	}
	protected void button_create_onClick(Event ev) {
		onCreate(to!int(textBox_newID.getText.toDString), to!int(textBox_from.getText.toDString), 
				to!int(textBox_to.getText.toDString));
		close();
	}
}