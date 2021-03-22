#!/usr/bin/env python3
"""
ca65 .dbg to bgb .sym translator
Copyright 2019, 2021 Damian Yerrick
License: zlib
"""
import sys
import argparse

rom_header_size = 0
prgbanksize = 16384

def int_if_nonnone_else_none(x):
    return int(x, 0) if x is not None else None

def int_0_if_str_else_int(x):
    return int(x, 0) if isinstance(x, str) else int(x)

def read_unused(data):
    runbyte, runlength, runthreshold = 0xC9, 0, 32
    runs = []
    for addr, value in enumerate(data):
        if value != runbyte:
            if runlength >= runthreshold:
                yield (addr - runlength, addr, runbyte)
            runbyte, runlength = value, 0
        runlength += 1
    if runlength >= runthreshold:
        yield (len(data) - runlength, len(data), runbyte)

def load_dbgfile(filename):
    syms = []
    segs = {}
    scopes = {}
    with open(filename, "r") as infp:
        for line in infp:
            line = line.rstrip().split("\t", 1)
            nvp = dict(kv.split("=", 1) for kv in line[1].split(","))
            if line[0] == 'sym':
                if 'val' not in nvp: continue
                if 'seg' not in nvp and nvp['type'] != 'equ':
                    print("no seg in sym", nvp)
                syms.append([
                    nvp.get('name').strip('"'),
                    nvp.get('type'),
                    int_if_nonnone_else_none(nvp.get('seg')),
                    int_if_nonnone_else_none(nvp.get('val')),
                    int_if_nonnone_else_none(nvp.get('size')),
                    int_if_nonnone_else_none(nvp.get('scope'))
                ])

            elif line[0] == 'seg':
                objid, objname = int(nvp['id']), nvp['name'].strip('"')
                segs[objid] = nvp

            elif line[0] == 'scope':
                objid, objname = int(nvp['id']), nvp['name'].strip('"')
                scopes[objid] = objname
    return syms, segs, scopes

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("DBGNAME")
    p.add_argument("-o", "--output", metavar="SYMFILE", default="-")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    syms, segs, scopes = load_dbgfile(args.DBGNAME)
    lines = ["; Generated using dbgtosym.py by PinoBatch"]
    for name, symtype, seg, val, size, scope in syms:
        if scope is None and name.startswith("@LOCAL"): continue
        if symtype != 'lab': continue
        if scope is None:
            print("no scope for name %s, symtype %s, seg %s, val %s, size %s"
                  % (name, symtype, seg, val, size), file=sys.stderr)
        scopename = scopes[scope]
        namewithscope = ".".join((scopename, name)) if scopename else name
        seg = segs[seg]
        ooffs = int_0_if_str_else_int(seg.get('ooffs', 0))
        banknum = (ooffs - rom_header_size) // prgbanksize
        lines.append("%02X:%04X %s" % (banknum, val, namewithscope))
    lines = "\n".join(lines)
    if args.output == '-':
        print(lines)
    else:
        with open(args.output, "w") as outfp:
            print(lines, file=outfp)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main(["readsym.py", "../nosuchthing.dbg"])
    else:
        main()
