
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
    
  data['file type'] = fileType
  data['file version'] = buf.readUInt16BE 4
  data['file flags'] = buf.readUInt16BE 6
  data


_chunk = (id, buf, data) ->
  switch id
    when 'desc'
      data['audio format'] = _audioFormat buf
    when 'info'
      data['infomation'] = _information buf
    when 'pakt'
      data['packet table header'] = _packetTableHeader buf
    when 'uuid'
      switch buf.toString 'hex', 0, 16
        when META_UUID
          data['meta'] = _metaInformation buf.slice 16
        when TRASIENTS_UUID
          data['transients'] = _transients buf.slice 16
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
  'sample rate': buf.readDoubleBE 0
  'format id': buf.toString 'ascii', 8, 12
  'format flags': buf.readUInt32BE 12
  'bytes per packet': buf.readUInt32BE 16
  'frames per packet': buf.readUInt32BE 20
  'channels per frames': buf.readUInt32BE 24
  'bits per channel': buf.readUInt32BE 28

# parse Information Chunk
# -------------
#
# struct CAFStringsChunk {
#    UInt32       mNumEntries;
#    CAFStringID  mStrings[kVariableLengthArray];
# }
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
_packetTableHeader = (buf) ->
  obj = {}
  if buf.readUInt32BE(0) isnt 0
    throw new Error 'packets size exceeded the 32bit limit.'
  obj['number packates'] = buf.readInt32BE 4
  if buf.readUInt32BE(8) isnt 0
    throw new Error 'valid frame size exceeded the 32bit limit.'
  obj['number valid frames'] = buf.readInt32BE 12
  obj['priming frames'] = buf.readInt32BE 16
  obj['remainder frames'] = buf.readInt32BE 20
  obj

# parse Meta Information
# -------------
#
# struct CAFInformation {
#     UInt8  mKey[kVariableLengthArray];
#     UInt8  mValue[kVariableLengthArray];
# }
_metaInformation = (buf) ->
  obj = _stringsChunk buf
  if _.isString obj.descriptors
    obj.descriptors = obj.descriptors.split ','
  if _.isString obj['beat count']
    obj['beat count'] = parseInt obj['beat count'], 10
  obj

# parse Transients
# -------------
#
# struct CAFInformation {
#     UInt8  mKey[kVariableLengthArray];
#     UInt8  mValue[kVariableLengthArray];
# }
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
    {unknown: unknown, 'frame position': position}
  obj

# parse Strings Chunk
# -------------
#
# struct CAFStringsChunk {
#    UInt32       mNumEntries;
#    CAFStringID  mStrings[kVariableLengthArray];
# }
_stringsChunk = (buf) ->
  obj = {}
  entries = buf.readUInt32BE 0
  arry = buf
    .toString 'ascii', 4
    .split '\0'
  for i in [0...entries]
    obj[arry[i * 2]] = arry[i * 2 + 1]
  obj


# calculate BPM.
# -------------
_calcTempo = (data) ->
  beatCount = data.meta['beat count']
  timeSignature = data.meta['time signature']
  numberValidFrames = data['packet table header']['number valid frames']
  sampleRate = data['audio format']['sample rate']
  every = [
    _.isNumber beatCount
    _.isString timeSignature
    _.isNumber numberValidFrames
    _.isNumber sampleRate
  ]
  if _.every(every)
    denominator = parseInt timeSignature.split('/')[1]
    data.meta.tempo = Math.floor (sampleRate * beatCount * 240 / denominator / numberValidFrames)
  data

# change key signature flat to sharp
# -------------
_flatToSharp = (data) ->
  keySignature = data.meta['key signature']
  if _.isString(keySignature) and keySignature.length is 2 and keySignature.slice(-1) is 'b'
    if keySignature[0] is 'A'
      keySignature = 'G#'
    else
      keySignature = "#{String.fromCharCode(keySignature.charCodeAt(0) - 1)}#"
    data.meta['key signature'] = keySignature
  data

# remove '/' from genre
# -------------
_removeSlash = (data) ->
  genre = data.meta['genre']
  if _.isString(genre) && genre.indexOf('/') > -1
    data.meta['genre'] = genre.replace '/', ' '
  data
