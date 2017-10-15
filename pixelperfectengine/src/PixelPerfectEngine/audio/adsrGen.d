module PixelPerfectEngine.audio.adsrGen;

import PixelPerfectEngine.audio.common;
import std.bitmanip;

/**
 * Envelope generator states
 */
public enum ADSRState : ubyte{
	NULL,
	Attack,
	Decay,
	Sustain,
	Release
}

/**
 * Envelope generator data. All times in miliseconds.
 */
public struct ADSRData{
	ushort attack;	///Attack time.
	short attackShp;	///Attack shape. 0 = linear;
	ushort decay;	///Decay time.
	short decayShp;	///Decay shape. 0 = linear;
	ushort sustain;	///Sustain level.
	ushort susRate;	///Sustain rate. 0 means no loss of volume over time. Higher the value, the more volume being lost at a shorter period in the sustain phase.
	ushort release;	///Release time.
	short relShp;	///Release shape.
	mixin(bitfields!(
			bool, "sustainEnable", 1,
			ubyte, "reserved", 7));
}
/**
 * 4-stage envelope generator for various purposes and with various adjustment options.
 */
public class ADSREnvelopeGenerator : IEnvelopeGenerator{
	protected ADSRData data;
	protected ADSRState state;
	protected double currentValue, aDiff, dDiff, sDiff, sLevel, rDiff;
	public static double updateRate;	///miliseconds between two updates

	public this(ADSRData data){
		this.data = data;
		//double cycTime = 1 / cast(double)updateRate;
		aDiff = (cast(double)uint.max / cast(double)(1 + data.attack)) * updateRate;
		dDiff = (cast(double)uint.max / cast(double)(1 + data.decay)) * updateRate;
		sDiff = (cast(double)uint.max / cast(double)(1 + data.susRate)) * updateRate;
		rDiff = (cast(double)uint.max / cast(double)(1 + data.attack)) * updateRate;
		sLevel = (cast(double)uint.max / cast(double)ushort.max) * data.sustain;
	}

	public @nogc uint updateEnvelopeState(){
		switch(state){
			case ADSRState.Attack:
				if(data.attackShp){
				
				}else{
					if(aDiff + currentValue >= cast(double)uint.max){
						state = ADSRState.Decay;
						currentValue = cast(double)uint.max;
						return cast(uint)currentValue;
					} 
					currentValue += aDiff;
				}
				break;
			case ADSRState.Decay:
				if(data.attackShp){
					
				}else{
					if(currentValue - dDiff <= sLevel){
						state = data.sustainEnable ? ADSRState.Sustain : ADSRState.Release;
						currentValue = sLevel;
						return cast(uint)currentValue;
					}
					currentValue -= dDiff;
				}
				break;
			case ADSRState.Sustain:
				if(currentValue <= 0){
					state = ADSRState.NULL;
					return 0;
				}
				if(data.susRate){
					if(cast(double)currentValue - cast(double)sDiff <= 0){
						state = ADSRState.NULL;
						return 0;
					}
					currentValue -= sDiff;
				}
				break;
			case ADSRState.Release:
				if(!currentValue){
					state = ADSRState.NULL;
					return 0;
				}
				break;
			default:
				return 0;
		}
		return cast(uint)currentValue;
	}
	public @nogc void setKeyOn(){
		state = ADSRState.Attack;
	}
	public @nogc void setKeyOff(){
		state = ADSRState.Release;
	}
}