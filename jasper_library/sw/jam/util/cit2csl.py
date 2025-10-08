#!/usr/bin/env python

# Convert a CASPER core_info.tab file to its binary CSL representation.
# Outputs as either a binary file (default) or a memory file (use `-m`)
# suitable for use 3ith Xilinx's `updatemem` utility.  For now the address in
# the memory file is fixed at 0x1f000, but it would be easy to add a command
# line option to allow the user to specify this if/when needed.
#
# core_info.tab files contain lines describing how CASPER yellow blocks are
# mapped into the memory space of a CAPER FPGA design.  Historically, each line
# is a core_info.tab file consists of four fields: device name, access mode,
# offset, and length.  Modern core_info.tab files have a fifth field that
# indicates the type of yellow block.  Clients can use this block type
# information to determine how to interpret the contents of the block's memory
# region.
#
# When converting a core_info.tab file to its binary CSL representation, the
# device names are the strings of the CSL.  The payload of each CSL entry
# consist of offset/mode, length, and type code.  Offset/mode is the four byte
# offset within the FPGA memory space with the least significant bit being a
# read-only flag.  Because FPGA devices are always at 4-byte aligned offsets,
# the two least significant bits are implicitly 0 so these bits can be used to
# carry additional information such as a read-only flag.  If the device is
# read-only (i.e. unwritable) then the offset's LSb will be a '1'.  The length
# field is also stored as four bytes.  The type code field is stored as a
# single byte.
#
# The offset and length fields are stored in network byte order (big endian).

import re
import os
import sys
import struct
import fileinput

import argparse

def make_data(address=0x1f000, choose_bin=False, cit_file=None):
    lines = []
    with fileinput.input(files(cit_file)) as f:
        # Read and parse lines
        # Lines have 4 or 5 fields: dev mode offset length [typecode]
        for line in f:
            words = line.split()
            dev = words[0]
            mode = words[1]
            offset = int(words[2], 16)
            if mode == '1':
                offset |= 1
            length = int(words[3], 16)
            if len(words) < 5:
                # Missing type defaults to 0 (register)
                typecode = 0
            else:
                typecode = int(words[4], 16)
          
            lines.append([dev, [offset, length, typecode]])

    # Sort lines
    lines.sort()

    payload_length = 9
    csl = b''
    prev = ''

    for (dev, entry) in lines:
        reuse = min(len(prev), len(dev))
        for i in range(reuse):
            if prev[i] != dev[i]:
                reuse = i
                break

        tail = dev[reuse:]
        if len(csl) == 0:
            reuse = payload_length

        #print(reuse, len(tail), tail, entry, dev)
        csl += struct.pack('>BB%dsIIB' % len(tail), reuse, len(tail), tail.encode('utf-8'), *entry)

        prev = dev

    # Append list terminator
    csl += b'\0\0'

    # Prepend length
    csl = struct.pack('>H', len(csl)) + csl
    return csl

def make_file(address, choose_bin, cit_file, output_file):
    csl = make_data(address, choose_bin, cit_file)
    with open(output_file, "wb") as f:
        if choose_bin:
            # Output CSL as binary
            output_file.write(csl)
        else:
            # Output CSL as memory
            output_file('@%08X\n' % address)
            # Pad csl with 3 nul bytes (is this really necessary?)
            csl += b'\0\0\0'
            # Split csl into lines of 1 to 32 bytes, rounding up the number of lines
            n_lines = (len(csl) + 31) // 32
            for line_n in range(n_lines):
                try:
                    line = csl[32*line_n : 32*(line_n+1)]
                except IndexError:
                    line = csl[32*line_n : ]
            
                #sys.stderr.writelines(len(line))
                output_file.write('   ')
                for byte in line:
                    output_file.write(' %02X' % byte)
                output_file.write('\n')

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Convert core_info.tab to CSL form.', prog=os.path.basename(__file__))
    parser.add_argument('-a', '--address', action='store',
                        default=0x1f000, type=lambda x: int(x,0),
                        help='Starting address for memory file')
    parser.add_argument('-b', '--bin', action='store_true',
                        help='Output binary file rather than memory file')
    parser.add_argument('cit_file', nargs='?', default=None,
                        help='A core_info.tab file')
    args = parser.parse_args()

    csl = make_data(args.address, args.bin, args.cit_file)
    if choose_bin:
        # Output CSL as binary
        sys.stdout.buffer.write(csl)
    else:
        # Output CSL as memory file
        print(('@%08X' % address))
        # Pad csl with 3 nul bytes (is this really necessary?)
        csl += b'\0\0\0'
        # Split csl into lines of 1 to 32 bytes, rounding up the number of lines
        n_lines = (len(csl) + 31) // 32
        for line_n in range(n_lines):
            try:
                line = csl[32*line_n : 32*(line_n+1)]
            except IndexError:
                line = csl[32*line_n : ]
        
            #sys.stderr.writelines(len(line))
            sys.stdout.write('   ')
            for byte in line:
                sys.stdout.write(' %02X' % byte)
            sys.stdout.write('\n')

