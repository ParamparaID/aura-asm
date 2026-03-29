import struct, zlib
d = open("tests/data/test_image.png", "rb").read()
p = 8
idat = b""
while p < len(d):
    l = struct.unpack(">I", d[p : p + 4])[0]
    t = d[p + 4 : p + 8]
    chunk = d[p + 8 : p + 8 + l]
    p += 12 + l
    if t == b"IDAT":
        idat += chunk
    if t == b"IEND":
        break
raw = zlib.decompress(idat)
print("idat", len(idat), "raw", len(raw), raw.hex())
