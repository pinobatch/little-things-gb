#!/usr/bin/env python3
"""
Copyright 2020 Damian Yerrick

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""
"""Changelog

Damian Yerrick, 2020-07
    add example of practical use of the solver
"""
import solve_overload

testcases = [
    (7, "abcde def efg hijk"),
    (5, "a1 357 a2 468"),
    (4, "12 13 23 ab ac bc"),
    (5, "12 345 126 378"),
    (4, "123 124 134 234 12a 12b 1ab 2ab 34a 34b 3ab 4ab"),
    (5, "123 14 567 189"),
    (5, "0 123 45 167 89"),
]

for cap, cels in testcases:
    job = {"capacity": cap, "tiles": cels.split()}
    pages = solve_overload.run(job)
    pages.decant()
    # Result is a sequence of pages, where each page is a
    # sequence of cels, where each cel is a sequence of symbols
    print("solver_test: %s fills %d pages of size %d"
          % (cels, len(pages), cap))
    print(pages)
