#!/usr/bin/env python
import os, sys, argparse
from PIL import Image

def parse_argv(argv):
    p = argparse.ArgumentParser()
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main("./v3conv.py ".split())
    else:
        main()
