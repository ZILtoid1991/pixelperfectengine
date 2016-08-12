module system.advBitArray;

public class AdvancedBitArray{
	protected void[] rawData;
	private int lenght;

	this(int length){
		setLenght(lenght);

	}
	this(void[] data){
		rawData = data;
		lenght = data.length * 8;
	}
	//this(bool[] data){}

	public void setLenght(int l){
		this.lenght = lenght;
		if(l % 64 != 0){
			l += 64 - (l % 64);
		}
		rawData.length = l/8;
	}
	bool opEquals()(auto ref const AdvancedBitArray o) {  
		ulong *a = cast(ulong*)rawData.ptr; 
		ulong *b = cast(ulong*)o.rawData.ptr;
		for(int i; i < lenght / 8; i++){
			if(*(a+i)!=*(b+i)) return false;
		}
		return true;
	}
	T opBinary(string op)(T rhs){
		static if(op == "&"){
			ulong *a = cast(ulong*)rawData.ptr;
			ulong *b = cast(ulong*)rhs.rawData.ptr;
			void[] result = lenght / 8;
			for(int i; i < lenght / 64; i++){
				*cast(ulong*)(result.ptr + i) = *(a + i) & *(b + i);
			}
			return new AdvancedBitArray(result);
		}else static if(op == "|"){
			ulong *a = cast(ulong*)rawData.ptr;
			ulong *b = cast(ulong*)rhs.rawData.ptr;
			void[] result = lenght / 8;
			for(int i; i < lenght / 64; i++){
				*cast(ulong*)(result.ptr + i) = *(a + i) | *(b + i);
			}
			return new AdvancedBitArray(result);
		}else static if(op == "<<"){
			int byteShift = rhs / 8, bitShift = rhs % 8;
			ulong[] result;
			if(bitshift == 0){
				for(int i = byteShift; i + 1 < lenght / 8; i+=8){
					result ~= *cast(ulong*)(rawData.ptr + i);
				}
			}else{
				for(int i = byteShift; i + 1 < lenght / 8; i+=8){
					ulong a = *cast(ulong*)(rawData.ptr + i);
					ulong b = *cast(ulong*)(rawData.ptr + i + 8);
					a = a << bitShift;
					b = b >> (64 - bitShift);
					a &= b;
					result ~= a;
				}
			}
			return new AdvancedBitArray(cast(void[])(result));
		}else static if(op == ">>"){
			int byteShift = rhs / 8, bitShift = rhs % 8;
			ulong[] result;
			result.lenght = byteShift;
			if(bitshift == 0){
				for(int i; i < (lenght / 8) - byteShift; i+=8){
					result ~= *cast(ulong*)(rawData.ptr + i);
				}
			}else{
				for(int i; i < (lenght / 8) - byteShift; i+=8){
					ulong a = *cast(ulong*)(rawData.ptr + i);
					ulong b = i != 0 ? *cast(ulong*)(rawData.ptr + i + 8) : 0;
					a = a >> bitShift;
					b = b << (64 - bitShift);
					a &= b;
					result ~= a;
				}
			}
			return new AdvancedBitArray(cast(void[])(result));
		}else static assert(0, "Operator "~op~" not implemented");
	}
	/*int opIndexAssign(bool value, size_t index) {
		uint byteShift = size_t / 8, bitShift = size_t % 8;
		ubyte x = 1;
		return *cast(ubyte*)(rawData.ptr+byteShift) &= x << bitShift;
	}
	inout(bool) opIndex(size_t index) inout {
		uint byteShift = size_t / 8, bitShift = size_t % 8;
		//bool result;
		ubyte x = cast(ubyte)(rawData[byteShift]);
		x == x >> bitShift;
		return x % 2 == 1;
	}*/
}