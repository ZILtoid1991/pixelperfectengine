/*
 *		GPUblit
 *		GPU composing and drawing functions by Laszlo Szeremi
 */


__kernel void blitter2op32bit(__global uint* src, __global uint* dest){
	const int i = get_global_id (0);

	dest[i] = ((dest[i] == 0) & dest[i]) | src[i];
}

__kernel void blitter3op32bit(__global uint* src, __global uint* dest, __global uint* mask){
	const int i = get_global_id (0);

	dest[i] = (mask[i] & dest[i]) | src[i];
}

__kernel void blitter21op32bit(__global uint* src, __global uint* dest, __global uint* dest1){
	const int i = get_global_id (0);

	dest1[i] = ((dest[i] == 0) & dest[i]) | src[i];
}

__kernel void blitter31op32bit(__global uint* src, __global uint* dest, __global uint* mask, __global uint* dest1){
	const int i = get_global_id (0);

	dest1[i] = (mask[i] & dest[i]) | src[i];
}

__kernel void blitter2op16bit(__global ushort* src, __global ushort* dest){
	const int i = get_global_id (0);

	dest[i] = ((dest[i] == 0) & dest[i]) | src[i];
}

__kernel void blitter3op16bit(__global ushort* src, __global ushort* dest, __global ushort* mask){
	const int i = get_global_id (0);

	dest[i] = (mask[i] & dest[i]) | src[i];
}

__kernel void blitter21op16bit(__global ushort* src, __global ushort* dest, __global ushort* dest1){
	const int i = get_global_id (0);

	dest1[i] = ((dest[i] == 0) & dest[i]) | src[i];
}

__kernel void blitter31op16bit(__global ushort* src, __global ushort* dest, __global ushort* mask, __global ushort* dest1){
	const int i = get_global_id (0);

	dest1[i] = (mask[i] & dest[i]) | src[i];
}

__kernel void blitter2op8bit(__global uchar* src, __global uchar* dest){
	const int i = get_global_id (0);

	dest[i] = ((dest[i] == 0) & dest[i]) | src[i];
}

__kernel void blitter3op8bit(__global uchar* src, __global uchar* dest, __global uchar* mask){
	const int i = get_global_id (0);

	dest[i] = (mask[i] & dest[i]) | src[i];
}

__kernel void blitter21op8bit(__global uchar* src, __global uchar* dest, __global uchar* dest1){
	const int i = get_global_id (0);

	dest1[i] = ((dest[i] == 0) & dest[i]) | src[i];
}

__kernel void blitter31op8bit(__global uchar* src, __global uchar* dest, __global uchar* mask, __global uchar* dest1){
	const int i = get_global_id (0);

	dest1[i] = (mask[i] & dest[i]) | src[i];
}

__kernel void alphablend2op(__global uchar4* src, __global uchar4* dest){
	const int i = get_global_id (0);

	const ushort aS = src[i].a + 1;
	const ushort aD = 256 - src[i].a;
	dest[i] = (uchar4)(((dest[i] * aD) + (src[i] * aS))>>8);
}

__kernel void alphablend3op(__global uchar4* src, __global uchar4* dest, __global uchar4* mask){
	const int i = get_global_id (0);

	ushort aS = mask[i].a + 1;
	ushort aD = 256 - mask[i].a;
	dest[i] = (uchar4)(((dest[i] * aD) + (src[i] * aS))>>8);
}

__kernel void lookup8bitAndHScale(__global uchar* src, __global uchar4* dest, __global uchar4* pal, int hscale, int len, int offset, int palSel){
	//len<<=10;
	//offset<<=10;
	palSel<<=8;
	while(offset){
		int colorIndex = src[offset>>10] + palSel;
		dest[i] = pal[colorIndex];
		offset += hscale;
		len -= 1;
	}
}
