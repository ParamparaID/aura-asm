import glob
import os
import struct
import sys


def read_u32(data, off):
    return struct.unpack_from("<I", data, off)[0]


def main():
    pattern = r"C:\PR\aura-asm\build\win_x86_64\dumps\*.dmp"
    files = sorted(glob.glob(pattern), key=os.path.getmtime)
    if not files:
        print("No dump files found.")
        return 1

    path = files[-1]
    data = open(path, "rb").read()
    sig = read_u32(data, 0)
    if sig != 0x504D444D:
        print(f"Not a minidump: {path}")
        return 1

    nstreams = read_u32(data, 8)
    dir_rva = read_u32(data, 12)
    ex_stream = None
    mod_stream = None
    mem64_stream = None

    for i in range(nstreams):
        off = dir_rva + i * 12
        stype = read_u32(data, off)
        size = read_u32(data, off + 4)
        rva = read_u32(data, off + 8)
        if stype == 6:  # ExceptionStream
            ex_stream = (rva, size)
        elif stype == 4:  # ModuleListStream
            mod_stream = (rva, size)
        elif stype == 9:  # Memory64ListStream
            mem64_stream = (rva, size)

    print(f"Dump: {path}")
    print(f"Streams: {nstreams}")

    if not ex_stream:
        print("No exception stream.")
        return 1

    ex_rva, _ = ex_stream
    thread_id = read_u32(data, ex_rva)
    exc_code = read_u32(data, ex_rva + 8)
    exc_addr = struct.unpack_from("<Q", data, ex_rva + 24)[0]
    exc_nparams = read_u32(data, ex_rva + 32)
    exc_info0 = struct.unpack_from("<Q", data, ex_rva + 40)[0]
    exc_info1 = struct.unpack_from("<Q", data, ex_rva + 48)[0]
    print(f"ThreadId: {thread_id}")
    print(f"ExceptionCode: 0x{exc_code:08X}")
    print(f"ExceptionAddress: 0x{exc_addr:016X}")
    print(f"ExceptionParameters: {exc_nparams}")
    print(f"ExceptionInfo[0]: 0x{exc_info0:016X}")
    print(f"ExceptionInfo[1]: 0x{exc_info1:016X}")

    # MINIDUMP_EXCEPTION_STREAM ends with ThreadContext location descriptor.
    ctx_size = read_u32(data, ex_rva + 160)
    ctx_rva = read_u32(data, ex_rva + 164)
    if ctx_size >= 256:
        # x64 CONTEXT common offsets
        rax = struct.unpack_from("<Q", data, ctx_rva + 120)[0]
        rcx = struct.unpack_from("<Q", data, ctx_rva + 128)[0]
        rdx = struct.unpack_from("<Q", data, ctx_rva + 136)[0]
        rbx = struct.unpack_from("<Q", data, ctx_rva + 144)[0]
        rsp = struct.unpack_from("<Q", data, ctx_rva + 152)[0]
        rbp = struct.unpack_from("<Q", data, ctx_rva + 160)[0]
        rsi = struct.unpack_from("<Q", data, ctx_rva + 168)[0]
        rdi = struct.unpack_from("<Q", data, ctx_rva + 176)[0]
        rip = struct.unpack_from("<Q", data, ctx_rva + 248)[0]
        print(f"RIP: 0x{rip:016X}")
        print(f"RSP: 0x{rsp:016X}")
        print(f"RBP: 0x{rbp:016X}")
        print(f"RAX: 0x{rax:016X}")
        print(f"RBX: 0x{rbx:016X}")
        print(f"RCX: 0x{rcx:016X}")
        print(f"RDX: 0x{rdx:016X}")
        print(f"RSI: 0x{rsi:016X}")
        print(f"RDI: 0x{rdi:016X}")
    else:
        print("Thread context too small to decode x64 registers.")

    modules = []
    if mod_stream:
        mod_rva, _ = mod_stream
        mod_count = read_u32(data, mod_rva)
        for i in range(mod_count):
            off = mod_rva + 4 + i * 108
            base = struct.unpack_from("<Q", data, off)[0]
            size = read_u32(data, off + 8)
            name_rva = read_u32(data, off + 20)
            name_len = read_u32(data, name_rva)
            raw = data[name_rva + 4 : name_rva + 4 + name_len]
            name = raw.decode("utf-16le", errors="ignore")
            modules.append((name, base, size))
        print("KeyModules:")
        for n, b, s in modules:
            bn = os.path.basename(n).lower()
            if bn in ("aura_shell_win.exe", "kernel32.dll", "kernelbase.dll", "ntdll.dll", "user32.dll"):
                print(f"  {os.path.basename(n)} base=0x{b:016X} size=0x{s:X}")
    else:
        print("No module list stream.")

    def mod_for(addr):
        for n, b, s in modules:
            if b <= addr < b + s:
                return (n, b, s, addr - b)
        return None

    mhit = mod_for(exc_addr)
    if mhit:
        name, base, size, moff = mhit
        print(f"Module: {name}")
        print(f"ModuleBase: 0x{base:016X}")
        print(f"ModuleSize: 0x{size:X}")
        print(f"ModuleOffset: 0x{moff:X}")
    else:
        print("Module not found for exception address.")

    # Dump top stack entries from memory64 stream for return-address clues.
    if mem64_stream and 'rsp' in locals():
        mrva, _ = mem64_stream
        n_ranges = struct.unpack_from("<Q", data, mrva)[0]
        base_rva = struct.unpack_from("<Q", data, mrva + 8)[0]
        file_cursor = base_rva
        stack_range = None
        for i in range(n_ranges):
            roff = mrva + 16 + i * 16
            start = struct.unpack_from("<Q", data, roff)[0]
            sz = struct.unpack_from("<Q", data, roff + 8)[0]
            if start <= rsp < start + sz:
                stack_range = (start, sz, file_cursor)
                break
            file_cursor += sz

        if stack_range:
            start, sz, frva = stack_range
            rel = rsp - start
            print("StackTop:")
            for i in range(20):
                off = rel + i * 8
                if off + 8 > sz:
                    break
                val = struct.unpack_from("<Q", data, frva + off)[0]
                m = mod_for(val)
                if m:
                    n, b, _, moff = m
                    print(f"  +0x{i*8:02X}: 0x{val:016X}  ({os.path.basename(n)}+0x{moff:X})")
                else:
                    print(f"  +0x{i*8:02X}: 0x{val:016X}")
        else:
            print("RSP not found in Memory64 ranges.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
