#!/usr/bin/env python3
"""
Pagination solver: Overload and Remove with Presort
Copyright 2016, 2017 Aristide Grange, Imed Kacem, Sébastien Martin

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

Damian Yerrick, 2019-10
	port to Python 3; add quiet option to skip printing name
Aristide Grange, 2017-10
	initial release at https://github.com/pagination-problem/pagination
"""
import solver_tools

name = "ReplacementPresort"

def run(testSet, quiet=True):
	pages = solver_tools.Pagination(testSet["capacity"], '' if quiet else name)
	pool = [solver_tools.Tile(tile) for tile in testSet["tiles"]]
	pool.sort(key=lambda tile:tile.size,reverse=True)
	for tile in pool:
		tile.forbiddenPages = []
	tile = pool.pop(0)
	# print "Place tile %s on empty page" % tile
	pages.newPage(tile)
	while pool:
		tile = pool.pop(0)
		# print "Forbidden pages: %s" % str([pages.index(page) for page in tile.forbiddenPages])
		candidates = set(pages).difference(tile.forbiddenPages)
		if not candidates:
			# print "Place tile %s on empty page %s " % (tile,len(pages))
			pages.newPage(tile)
			continue
		costs = ((tile.weightedCostIn(page),page) for page in candidates)
		(bestWeightedCost,bestPage) = min(costs, key=lambda x: x[0])
		if bestWeightedCost == len(tile):
			# print "Place tile %s on empty page %s " % (tile,len(pages))
			pages.newPage(tile)
			continue
		# print "Add tile %s on page %s" % (tile,pages.index(bestPage))
		bestPage.add(tile)
		while bestPage.cost > pages.capacity:
			# print "Page %s exceeded!" % pages.index(bestPage)
			minEfficiency = min(bestPage.actualEfficiencies)
			maxEfficiency = max(bestPage.actualEfficiencies)
			# print (minEfficiency,maxEfficiency)
			if minEfficiency == maxEfficiency:
				break
			tile = bestPage[bestPage.actualEfficiencies.index(minEfficiency)]
			# print "Remove tile %s from page %s" % (tile,pages.index(bestPage))
			bestPage.remove(tile)
			tile.forbiddenPages.append(bestPage)
			pool.append(tile)
		# print "Page %s not saturated." % pages.index(bestPage)
	for i in range(len(pages)-1,-1,-1):
		if pages[i].cost > pages.capacity:
			pool.extend(pages.pop(i)[:])
	for tile in pool:
		for page in pages:
			if tile.canFitIn(page):
				page.add(tile)
				break
		else:
			pages.newPage(tile)
	# print pages
	return pages
