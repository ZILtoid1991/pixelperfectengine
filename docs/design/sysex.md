Manufacturer ID: [00] 7D

# 7 Bit Universal MIDI Sysex commands

|Code            |Function                                                                                               |
|----------------|-------------------------------------------------------------------------------------------------------|
|0x00            |Null command                                                                                           |
|0x01 nn         |Suspend channel nn while keeping its statuses.                                                         |
|0x02 nn         |Resume channel nn without resetting its statuses.                                                      |
|0x03 nn M0 M1 M2|Store channel nn state as preset on preset M0 in bank M1-M2(MSB-LSB). If M values not supplied, then the currently selected preset will be overwritten|