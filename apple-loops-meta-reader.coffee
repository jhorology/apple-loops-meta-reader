
assert = require 'assert'
events = require 'events'
util   = require 'util'
_      = require 'underscore'
br     = require 'binary-reader'
rc     = require 'read-chunk'

# supported chunk Ids
CHUNK_IDS = ['desc', 'info', 'uuid', 'pakt']

# supported chunk uuids
# meta info
META_UUID =  '29819273b5bf4aefb78d62d1ef90bb2c'
# transient markers
TRASIENTS_UUID =  '0352811b9d5d42e1882d6af61a6b330c'

module.exports.open = (p, options) ->
  new Reader p, options

module.exports.read = (p) ->
  data = {}
  buf = rc.sync p, 0, 8
  pos = 8
    
  _header buf, data
    
  buf = rc.sync p, pos, 12
  while buf.length is 12
    id = buf.toString 'ascii',0, 4
    if buf.readUInt32BE(4) isnt 0
      throw new Error 'chunk size exceeded the 32bit limit.'
    size = buf.readUInt32BE 8
    pos += 12
    buf = rc.sync p, pos, size
    _chunk id, buf, data
    pos += size
    buf = rc.sync p, pos, 12
  _calcTempo data
  _flatToSharp data
  _removeSlash data


class Reader extends events
  constructor: (p, opts) ->
    data = {}
    reader =  br.open p, opts
      .on 'error', (error) =>
        @emit 'error', error
      .on 'close', =>
        _calcTempo data
        _flatToSharp data
        _removeSlash data
        @emit 'data', data
      .on 'chunk', (id, buf) ->
        try
          _chunk id, buf, data
        catch error
          @cancel error
      # read CAF File Header
      .read 8, (bytesRead, buf) ->
        try
          if bytesRead isnt 8
            throw new Error "CAF header size error. bytesRead:#{bytesRead}"
          _header buf, data
        catch error
          @cancel error
        _asyncChunks reader
    @

_asyncChunks = (reader) ->
  reader.read 12, (bytesRead, buf) ->
    if bytesRead isnt 12
      @cancel new Error "chunk header size error. byteReads:#{bytesRead}"
    id = buf.toString 'ascii',0, 4
    if buf.readUInt32BE(4) isnt 0
      @cancel new Error 'chunk size exceeded the 32bit limit.'
    size = buf.readUInt32BE 8
    if CHUNK_IDS.indexOf(id) > -1
      @read size, (bytesRead, buf) ->
        if bytesRead isnt size
          @cancel new Error 'chunk size error'
          return
        @emit 'chunk', id, buf
        if @isEOF()
          @close()
        else
          _asyncChunks @
    else
      @seek size, current: true, ->
        if @isEOF()
          @close()
        else
          _asyncChunks @


_header = (buf, data) ->
  fileType = buf.toString 'ascii',0, 4
  if fileType isnt 'caff'
    throw new Error "unknown file type. type:#{fileType}"
    
  data.fileType = fileType
  data.fileVersion = buf.readUInt16BE 4
  data.fileFlags = buf.readUInt16BE 6
  data


_chunk = (id, buf, data) ->
  switch id
    when 'desc'
      data.audioFormat = _audioFormat buf
    when 'info'
      data.infomation = _information buf
    when 'pakt'
      data.packetTableHeader = _packetTableHeader buf
    when 'uuid'
      switch buf.toString 'hex', 0, 16
        when META_UUID
          data.meta = _metaInformation buf.slice 16
        when TRASIENTS_UUID
          data.transients = _transients buf.slice 16
  data

# parse Audio Description Chunk
# -------------
#
# struct CAFAudioFormat {
#     Float64 mSampleRate;
#     UInt32  mFormatID;
#     UInt32  mFormatFlags;
#     UInt32  mBytesPerPacket;
#     UInt32  mFramesPerPacket;
#     UInt32  mChannelsPerFrame;
#     UInt32  mBitsPerChannel;
# }
_audioFormat = (buf) ->
  sampleRate: buf.readDoubleBE 0
  formatId: buf.toString 'ascii', 8, 12
  formatFlags: buf.readUInt32BE 12
  bytesPerPacket: buf.readUInt32BE 16
  framesPerPacket: buf.readUInt32BE 20
  channelsPerFrames: buf.readUInt32BE 24
  bitsPerChannel: buf.readUInt32BE 28

# parse Information Chunk
# -------------
#
# struct CAFStringsChunk {
#    UInt32       mNumEntries;
#    CAFStringID  mStrings[kVariableLengthArray];
# }
#
_information = (buf) ->
  _stringsChunk buf

# parse Packet Table Header
# -------------
#
# struct CAFPacketTableHeader {
#     SInt64  mNumberPackets;
#     SInt64  mNumberValidFrames;
#     SInt32  mPrimingFrames;
#     SInt32  mRemainderFrames;
# }
#
_packetTableHeader = (buf) ->
  obj = {}
  if buf.readUInt32BE(0) isnt 0
    throw new Error 'packets size exceeded the 32bit limit.'
  obj.numberPackets = buf.readInt32BE 4
  if buf.readUInt32BE(8) isnt 0
    throw new Error 'valid frame size exceeded the 32bit limit.'
  obj.numberValidFrames = buf.readInt32BE 12
  obj.primingFrames = buf.readInt32BE 16
  obj.remainderFrames = buf.readInt32BE 20
  obj

# parse Meta Information
# -------------
#
# struct CAFInformation {
#     UInt8  mKey[kVariableLengthArray];
#     UInt8  mValue[kVariableLengthArray];
# }
#
_metaInformation = (buf) ->
  obj = _stringsChunk buf
  if _.isString obj.descriptors
    obj.descriptors = obj.descriptors.split ','
  if _.isString obj.beatCount
    obj.beatCount = parseInt obj.beatCount, 10
  obj

# parse Transients
# -------------
#
# struct CAFInformation {
#     UInt8  mKey[kVariableLengthArray];
#     UInt8  mValue[kVariableLengthArray];
# }
#
_transients = (buf) ->
  obj = {}
  # TODO unknown data
  obj.unknown = buf.toString 'hex', 0, 16
  entries = buf.readUInt32BE 16
  obj.markers =  for i in [0...entries]
    offset = 12 * i + 20
        # TODO unknown data always '0x00010000' ?
    unknown = buf.readUInt32BE offset
    if buf.readUInt32BE(offset + 4) isnt 0
      throw new Error 'transient frame position exceeded the 32bit limit.'
    position = buf.readUInt32BE(offset + 8)
    {unknown: unknown, framePosition: position}
  obj

# parse Strings Chunk
# -------------
#
# struct CAFStringsChunk {
#    UInt32       mNumEntries;
#    CAFStringID  mStrings[kVariableLengthArray];
# }
#
_stringsChunk = (buf) ->
  obj = {}
  entries = buf.readUInt32BE 0
  arry = buf
    .toString 'ascii', 4
    .split '\0'
  for i in [0...entries]
    obj[_normalize arry[i * 2]] = arry[i * 2 + 1]
  obj


# normalize property name
# -------------
_normalize = (arg) ->
  l = arg.split ' '
  out = for i in [0...l.length]
    "#{if i is 0 then l[i][0].toLowerCase() else l[i][0].toUpperCase()}#{l[i][1..]}"
  out.join ''

  
# calculate BPM.
# -------------
_calcTempo = (data) ->
  every = [
    _.isObject data.meta
    _.isNumber data.meta.beatCount
    _.isString data.meta.timeSignature
    _.isObject data.packetTableHeader
    _.isNumber data.packetTableHeader.numberValidFrames
    _.isObject data.audioFormat
    _.isNumber data.audioFormat.sampleRate
  ]
  if _.every(every)
    r = data.audioFormat.sampleRate
    b = data.meta.beatCount
    d = parseInt data.meta.timeSignature.split('/')[1]
    l = data.packetTableHeader.numberValidFrames
    data.meta.tempo = Math.floor (r * b * 240 / d / l)
  data

# change key signature flat to sharp
# -------------
_flatToSharp = (data) ->
  keySignature = data.meta.keySignature
  if _.isString(keySignature) and keySignature.length is 2
    if keySignature.slice(-1) is 'b'
      if keySignature[0] is 'A'
        keySignature = 'G#'
      else
        keySignature = "#{String.fromCharCode(keySignature.charCodeAt(0) - 1)}#"
      data.meta.keySignature = keySignature
    if keySignature.slice(-1) is 'c'
      keySignature = keySignature[0]
      data.meta.keySignature = keySignature
  data

# remove '/' from genre
# -------------
_removeSlash = (data) ->
  genre = data.meta.genre
  if _.isString(genre) && genre.indexOf('/') > -1
    data.meta.genre = genre.replace '/', ' '
  data
