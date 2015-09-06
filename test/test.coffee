assert = require 'assert'
_      = require 'underscore'
reader = require '../apple-loops-meta-reader'

APPLE_LOOPS_DIR = '/Library/Audio/Apple Loops/Apple/'


describe 'Apple Loops Meta Reader:', ->

  describe 'Sync:', ->
    it 'tempo: none, key: none, file: Barbeque Blues Short.caf', ->
      data = reader.read "#{APPLE_LOOPS_DIR}iLife Sound Effects/Jingles/Barbeque Blues Short.caf"
      assert.ok _.isObject data
      assert.ok _.isObject data.meta
      assert.ok _.isUndefined data.meta.tempo
      assert.ok _.isUndefined data.meta['key signature']
      assert.ok _.isUndefined data.meta['key type']
      
    it 'tempo: 190bpm, key: none, file: DnB Roller Beat.caf', ->
      data = reader.read "#{APPLE_LOOPS_DIR}Jam Pack Remix Tools/DnB Roller Beat.caf"
      assert.ok _.isObject data
      assert.ok _.isObject data.meta
      assert.equal data.meta.tempo, 190
      assert.ok _.isUndefined data.meta['key signature']
      assert.ok _.isUndefined data.meta['key type']

  describe 'Async:', ->
    it 'async read bpm: 60, key: C# major, file: Behold Brass & Wind 03.caf', (done) ->
      data = reader.open "#{APPLE_LOOPS_DIR}Jam Pack Symphony Orchestra/Behold Brass & Wind 03.caf"
        .on 'data', (data) ->
          assert.ok _.isObject data
          assert.ok _.isObject data.meta
          assert.equal data.meta.tempo, 60
          assert.equal data.meta['key signature'], 'C#'
          assert.equal data.meta['key type'], 'major'
          done()
          
    it 'async read bpm: 40, key: D both, file: Eastern Storm Violin 10.caf', (done) ->
      data = reader.open "#{APPLE_LOOPS_DIR}Jam Pack World Music/Eastern Storm Violin 10.caf"
        .on 'data', (data) ->
          assert.ok _.isObject data
          assert.ok _.isObject data.meta
          assert.equal data.meta.tempo, 40
          assert.equal data.meta['key signature'], 'D'
          assert.equal data.meta['key type'], 'both'
          done()
          
    it 'async-read tempo: 100bpm, key: A# neither, file: Adversary All.caf', (done) ->
      data = reader.open "#{APPLE_LOOPS_DIR}Jam Pack Symphony Orchestra/Adversary All.caf"
        .on 'data', (data) ->
          assert.ok _.isObject data
          assert.ok _.isObject data.meta
          assert.equal data.meta.tempo, 100
          assert.equal data.meta['key signature'], 'A#'
          assert.equal data.meta['key type'], 'neither'
          done()
