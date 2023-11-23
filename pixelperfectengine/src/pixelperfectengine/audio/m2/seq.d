module pixelperfectengine.audio.m2.seq;

public import pixelperfectengine.audio.m2.types;
public import pixelperfectengine.audio.base.midiseq : Sequencer;
public import pixelperfectengine.audio.base.modulebase;
import collections.treemap;

public class SequencerM2 : Sequencer {
    public TreeMap!(uint, AudioModule) modTrgt;
    public M2Song songdata;

    public void lapseTime(Duration amount) @nogc nothrow {
        foreach (size_t i, ref uint ptrnSlID ; songdata.activePtrnNums) {
            if (ptrnSlID != PATTERN_SLOT_INACTIVE_ID) {
                advancePattern(songdata.ptrnSl[i], amount);
            }
        }
    }
    private void advancePattern(ref M2PatternSlot ptrn, Duration amount) @nogc nothrow {
        if ((ptrn.timeToWait -= amount) <= hnsecs(0)) {

        }
    }
    private bool hasUsefulDataLeft(uint[] patternData) @nogc nothrow pure const {
        if (patternData.length == 0) return false;
        foreach (key; patternData) {
            DataReaderHelper data = DataReaderHelper(key);
            if (data.bytes[0] != 0x00 || data.bytes[0] != 0xff) return true;    //Has at least one potential command.
        }
        return false;
    }
    private void emitMIDIData(uint[] data, uint targetID) @nogc nothrow pure const {

    }
}