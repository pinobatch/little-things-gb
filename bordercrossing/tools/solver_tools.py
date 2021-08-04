#!/usr/bin/env python3
"""
Helper routines used by Pagination solvers
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
    port to Python 3; add Pagination.decant() convenience method
Aristide Grange, 2017-10
    initial release at https://github.com/pagination-problem/pagination
"""
from fractions import Fraction as F
from collections import Counter, OrderedDict
from functools import reduce
import json
import itertools
import re
import random

def make_sort():
    def process(stuff):
        if isinstance(stuff, dict):
            l = [(k, process(v)) for (k, v) in stuff.items()]
            return OrderedDict(sorted(l))
        if isinstance(stuff, list):
            return [process(x) for x in stuff]
        return stuff
    return process
sort = make_sort()

def testSetsToText(testSets):
    text = json.JSONEncoder(indent=2,default=lambda l:sorted(list(l))).encode(sort(testSets))
    text = re.sub(r'\[[\d,\s]+\]',lambda s: s.group(0).replace(" ","").replace("\n",""),text)
    return "\n ".join(text.split("\n"))


class Tile:

    def __init__(self, *symbols):
        if len(symbols) == 1:
            symbols = symbols[0]
            if isinstance(symbols,Tile):
                symbols = symbols.symbols
        self.symbols = sorted(list(symbols))
        self.size = len(self.symbols)
        self.hash = hash(tuple(self.symbols))
    
    def equals(self, *other):
        if len(other) == 1:
            other = other[0]
            if isinstance(other,Tile):
                other = other.symbols
        return set(self.symbols) == set(other)
    
    def __len__(self):
        return self.size
    
    def __hash__(self):
        return self.hash
    
    def __repr__(self):
        return "[%s]" % ",".join(str(symbol) for symbol in self)
    
    def __iter__(self):
        return iter(self.symbols)
    
    def canFitIn(self,batch):
        return batch.costWith(self) <= batch.capacity
    
    def weightedCostIn(self,batch):
        """ Weighted cost of the tile in the given batch (whether it already belongs to it or not). """
        try:
            return batch.weightedCosts[batch.index(self)]
        except ValueError:
            return sum(F(1,1+batch.weightBySymbol.get(symbol,0)) for symbol in self)
    

class Batch(list):
    
    def __init__(self, tiles=[],capacity=None):
        list.__init__(self,[(tile if isinstance(tile,Tile) else Tile(tile)) for tile in tiles])
        self.capacity = capacity
        self.__update()
    
    def __contains__(self, tile):
        return tile in self.tileSet
    
    def __repr__(self):
        return r"{%s}" % ",".join(repr(tile) for tile in self)
    
    def toList(self):
        return [tile.symbols for tile in self]
    
    def __update(self):
        self.tileSet = frozenset(self)
        self.tileHashesSet = frozenset(tile.hash for tile in self.tileSet)
        self.hash = hash(self.tileSet)
        self.symbols = reduce(lambda accu,tile:accu.union(tile),self,set())
        self.cost = len(self.symbols)
        self.weight = sum(len(tile) for tile in self)
        self.weightBySymbol = Counter(symbol for tile in self for symbol in tile)
        self.weightedCosts = [sum(F(1,self.weightBySymbol[symbol]) for symbol in tile) for tile in self]
        self.actualEfficiencies = [1-weightedCost/tile.size for (tile,weightedCost) in zip(self,self.weightedCosts)]
        self.getConnectedComponents = self.calculateConnectedComponents
    
    def add(self,tile):
        self.append(tile)
        self.__update()
    
    def __hash__(self):
        return self.hash
    
    def remove(self,tileOrIndex):
        """ Suppress a tile by index or value. """
        if type(tileOrIndex) is int:
            del(self[tileOrIndex])
        else:
            list.remove(self,tileOrIndex)
        self.__update()
    
    def costWith(self,tileOrBatch):
        """ Cost of the batch if the given tile was added. """
        if isinstance(tileOrBatch,Batch):
            return len(self.symbols.union(tileOrBatch.symbols))
        return len(self.symbols.union(tileOrBatch))
    
    def sizeLeft(self):
        return self.capacity - self.cost
    
    def isEmpty(self):
        return self.cost == 0
    
    def isConnected(self):
        tiles = self[:]
        seed = set(tiles.pop())
        while tiles:
            for (i,tile) in enumerate(tiles):
                if seed.intersection(tile):
                    seed.update(tile)
                    del tiles[i]
                    break
            else:
                return False
        return True
    
    def calculateConnectedComponents(self):
        tiles = self[:]
        self.connectedComponents = []
        while tiles:
            root = tiles.pop()
            connectedTiles = [root]
            symbols = set(root.symbols)
            oneMoreTime = True
            while oneMoreTime:
                remainingTiles = []
                oneMoreTime = False
                for candidate in tiles:
                    if symbols.intersection(candidate):
                        connectedTiles.append(candidate)
                        symbols.update(candidate.symbols)
                        oneMoreTime = True
                    else:
                        remainingTiles.append(candidate)
                tiles = remainingTiles
            self.connectedComponents.append(Batch(connectedTiles)) 
        self.getConnectedComponents = self.__getConnectedComponents
        return self.connectedComponents
    
    def __getConnectedComponents(self):
        return self.connectedComponents
    
    def getShuffledClone(self):
        tiles = self[:]
        random.shuffle(tiles)
        return Batch(tiles)
    

class Pagination(list):
    
    def __init__(self, capacity, algoName=None):
        self.capacity = capacity
        list.__init__(self,Batch(capacity=capacity))
        self.algoName = algoName
        if algoName:
            print("%s:" % algoName, end=" ")
    
    def newPage(self,stuff=None):
        """ Create a new page with a tile, a batch of tiles, or nothing at all (by default). """
        if stuff is None:
            stuff = []
        elif isinstance(stuff,Tile):
            stuff = [stuff]
        self.append(Batch(stuff,capacity=self.capacity))
    
    def __repr__(self):
        return "\n".join("page %s: %s symbols %s" % (pageIndex,page.cost,page) for (pageIndex,page) in enumerate(self))
    
    def toList(self):
        return [page.toList() for page in self]
    
    def decantPages(self):
        targetIndex = 0
        while targetIndex < len(self):
            sourceIndex = targetIndex + 1
            while sourceIndex < len(self):
                if self[targetIndex].costWith(self[sourceIndex]) <= self.capacity:
                    self[targetIndex] = Batch(self[targetIndex]+self[sourceIndex])
                    del self[sourceIndex]
                    # print("d3", end=" ")
                else:
                    sourceIndex += 1
            targetIndex += 1
    
    def decantConnectedComponents(self):
        targetIndex = 0
        while targetIndex < len(self):
            sourceIndex = targetIndex + 1
            while sourceIndex < len(self):
                for cc in self[sourceIndex].getConnectedComponents():
                    if self[targetIndex].costWith(cc) <= self.capacity:
                        # print("d2", end=" ")
                        for tile in cc:
                            self[targetIndex].add(tile)
                            self[sourceIndex].remove(tile)
                if self[sourceIndex].isEmpty():
                    del self[sourceIndex]
                else:
                    sourceIndex += 1
            targetIndex += 1
    
    def decantTiles(self):
        targetIndex = 0
        while targetIndex < len(self):
            sourceIndex = targetIndex + 1
            while sourceIndex < len(self):
                for tile in self[sourceIndex]:
                    if self[targetIndex].costWith(tile) <= self.capacity:
                        # print("d1", end=" ")
                        self[targetIndex].add(tile)
                        self[sourceIndex].remove(tile)
                if self[sourceIndex].isEmpty():
                    del self[sourceIndex]
                else:
                    sourceIndex += 1
            targetIndex += 1

    def decant(self):
        """Try to improve a pagination by rearranging pages and tiles."""
        self.decantPages()
        self.decantConnectedComponents()
        self.decantTiles()
    
    def moveTile(self,source,target,tile):
        target.add(tile)
        source.remove(tile)
        if source.isEmpty():
            self.remove(source)
    
    def mergePages(self,source,target):
        """ Make a single page of two. """
        self[self.index(target)] = Batch(source+target)
        self.remove(source)
    
    def getCost(self):
        return sum(page.cost for page in self)
    
    def isValid(self):
        for page in self:
            if page.cost > self.capacity:
                return False
        return True
    
    def pageIndexOfTile(self,tile):
        for (pageIndex,page) in enumerate(self):
            if tile.hash in page.tileHashesSet:
                return pageIndex
        raise ValueError("Tile %s not in pagination:\n%s" % (tile,self))
    
    def getInfo(self,refTiles):
        indexForHashes = {hash(tuple(sorted(tile))):i for (i,tile) in enumerate(refTiles)}
        result = {}
        result["paginations"] = []
        for page in self:
            result["paginations"].append([indexForHashes[tile.hash] for tile in page])
        result["pageCount"] = len(self)
        result["pages"] = [page.symbols for page in self]
        return result
    
    def indexOfPageWithMaxWeightedCost(self):
        minWeightedCost = 1.01 
        indexMin = None
        for (i,page) in enumerate(self):
            wc = float(page.cost)/page.weight
            if wc < minWeightedCost:
                minWeightedCost = wc
                indexMin = i
        return indexMin

class BatchesUpTo(Pagination):

    def __init__(self,testSet,batchMaxSize):
        Pagination.__init__(self,testSet)
        capacity = testSet["capacity"]
        for batchSize in range(batchMaxSize):
            for selectedTiles in itertools.combinations(testSet["tiles"],batchSize+1):
                batch = Batch(selectedTiles,capacity)
                if batch.cost <= capacity and batch.isConnected():
                    self.newPage(batch)
    
    def suppressBatchesContainingTile(self,tile):
        self[:] = [batch for batch in self if tile not in batch] # modify in-place
