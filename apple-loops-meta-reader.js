(function() {
  var CHUNK_IDS, META_UUID, Reader, TRANSIENTS_UUID, _, _asyncChunks, _audioFormat, _calcTempo, _chunk, _flatToSharp, _header, _information, _metaInformation, _normalize, _packetTableHeader, _stringsChunk, _transients, assert, br, events, rc, util,
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty;

  assert = require('assert');

  events = require('events');

  util = require('util');

  _ = require('underscore');

  br = require('binary-reader');

  rc = require('read-chunk');

  CHUNK_IDS = ['desc', 'info', 'uuid', 'pakt'];

  META_UUID = '29819273b5bf4aefb78d62d1ef90bb2c';

  TRANSIENTS_UUID = '0352811b9d5d42e1882d6af61a6b330c';

  module.exports.open = function(p, options) {
    return new Reader(p, options);
  };

  module.exports.read = function(p) {
    var buf, data, id, pos, size;
    data = {};
    buf = rc.sync(p, 0, 8);
    pos = 8;
    _header(buf, data);
    buf = rc.sync(p, pos, 12);
    while (buf.length === 12) {
      id = buf.toString('ascii', 0, 4);
      if (buf.readUInt32BE(4) !== 0) {
        throw new Error('chunk size exceeded the 32bit limit.');
      }
      size = buf.readUInt32BE(8);
      pos += 12;
      buf = rc.sync(p, pos, size);
      _chunk(id, buf, data);
      pos += size;
      buf = rc.sync(p, pos, 12);
    }
    _calcTempo(data);
    return _flatToSharp(data);
  };

  Reader = (function(superClass) {
    extend(Reader, superClass);

    function Reader(p, opts) {
      var data, reader;
      data = {};
      reader = br.open(p, opts).on('error', (function(_this) {
        return function(error) {
          return _this.emit('error', error);
        };
      })(this)).on('close', (function(_this) {
        return function() {
          _calcTempo(data);
          _flatToSharp(data);
          return _this.emit('data', data);
        };
      })(this)).on('chunk', function(id, buf) {
        var error, error1;
        try {
          return _chunk(id, buf, data);
        } catch (error1) {
          error = error1;
          return this.cancel(error);
        }
      }).read(8, function(bytesRead, buf) {
        var error, error1;
        try {
          if (bytesRead !== 8) {
            throw new Error("CAF header size error. bytesRead:" + bytesRead);
          }
          _header(buf, data);
        } catch (error1) {
          error = error1;
          this.cancel(error);
        }
        return _asyncChunks(reader);
      });
      this;
    }

    return Reader;

  })(events);

  _asyncChunks = function(reader) {
    return reader.read(12, function(bytesRead, buf) {
      var id, size;
      if (bytesRead !== 12) {
        this.cancel(new Error("chunk header size error. byteReads:" + bytesRead));
      }
      id = buf.toString('ascii', 0, 4);
      if (buf.readUInt32BE(4) !== 0) {
        this.cancel(new Error('chunk size exceeded the 32bit limit.'));
      }
      size = buf.readUInt32BE(8);
      if (CHUNK_IDS.indexOf(id) > -1) {
        return this.read(size, function(bytesRead, buf) {
          if (bytesRead !== size) {
            this.cancel(new Error('chunk size error'));
            return;
          }
          this.emit('chunk', id, buf);
          if (this.isEOF()) {
            return this.close();
          } else {
            return _asyncChunks(this);
          }
        });
      } else {
        return this.seek(size, {
          current: true
        }, function() {
          if (this.isEOF()) {
            return this.close();
          } else {
            return _asyncChunks(this);
          }
        });
      }
    });
  };

  _header = function(buf, data) {
    var fileType;
    fileType = buf.toString('ascii', 0, 4);
    if (fileType !== 'caff') {
      throw new Error("unknown file type. type:" + fileType);
    }
    data.fileType = fileType;
    data.fileVersion = buf.readUInt16BE(4);
    data.fileFlags = buf.readUInt16BE(6);
    return data;
  };

  _chunk = function(id, buf, data) {
    switch (id) {
      case 'desc':
        data.audioFormat = _audioFormat(buf);
        break;
      case 'info':
        data.information = _information(buf);
        break;
      case 'pakt':
        data.packetTableHeader = _packetTableHeader(buf);
        break;
      case 'uuid':
        switch (buf.toString('hex', 0, 16)) {
          case META_UUID:
            data.meta = _metaInformation(buf.slice(16));
            break;
          case TRANSIENTS_UUID:
            data.transients = _transients(buf.slice(16));
        }
    }
    return data;
  };

  _audioFormat = function(buf) {
    return {
      sampleRate: buf.readDoubleBE(0),
      formatId: buf.toString('ascii', 8, 12),
      formatFlags: buf.readUInt32BE(12),
      bytesPerPacket: buf.readUInt32BE(16),
      framesPerPacket: buf.readUInt32BE(20),
      channelsPerFrames: buf.readUInt32BE(24),
      bitsPerChannel: buf.readUInt32BE(28)
    };
  };

  _information = function(buf) {
    return _stringsChunk(buf);
  };

  _packetTableHeader = function(buf) {
    var obj;
    obj = {};
    if (buf.readUInt32BE(0) !== 0) {
      throw new Error('packets size exceeded the 32bit limit.');
    }
    obj.numberPackets = buf.readInt32BE(4);
    if (buf.readUInt32BE(8) !== 0) {
      throw new Error('valid frame size exceeded the 32bit limit.');
    }
    obj.numberValidFrames = buf.readInt32BE(12);
    obj.primingFrames = buf.readInt32BE(16);
    obj.remainderFrames = buf.readInt32BE(20);
    return obj;
  };

  _metaInformation = function(buf) {
    var obj;
    obj = _stringsChunk(buf);
    if (_.isString(obj.descriptors)) {
      obj.descriptors = obj.descriptors.split(',');
    }
    if (_.isString(obj.beatCount)) {
      obj.beatCount = parseInt(obj.beatCount, 10);
    }
    return obj;
  };

  _transients = function(buf) {
    var entries, i, obj, offset, position, unknown;
    obj = {};
    obj.unknown = buf.toString('hex', 0, 16);
    entries = buf.readUInt32BE(16);
    obj.markers = (function() {
      var j, ref, results;
      results = [];
      for (i = j = 0, ref = entries; 0 <= ref ? j < ref : j > ref; i = 0 <= ref ? ++j : --j) {
        offset = 12 * i + 20;
        unknown = buf.readUInt32BE(offset);
        if (buf.readUInt32BE(offset + 4) !== 0) {
          throw new Error('transient frame position exceeded the 32bit limit.');
        }
        position = buf.readUInt32BE(offset + 8);
        results.push({
          unknown: unknown,
          framePosition: position
        });
      }
      return results;
    })();
    return obj;
  };

  _stringsChunk = function(buf) {
    var arry, entries, i, j, obj, ref;
    obj = {};
    entries = buf.readUInt32BE(0);
    arry = buf.toString('ascii', 4).split('\0');
    for (i = j = 0, ref = entries; 0 <= ref ? j < ref : j > ref; i = 0 <= ref ? ++j : --j) {
      obj[_normalize(arry[i * 2])] = arry[i * 2 + 1];
    }
    return obj;
  };

  _normalize = function(arg) {
    var i, l, out;
    l = arg.split(' ');
    out = (function() {
      var j, ref, results;
      results = [];
      for (i = j = 0, ref = l.length; 0 <= ref ? j < ref : j > ref; i = 0 <= ref ? ++j : --j) {
        results.push("" + (i === 0 ? l[i][0].toLowerCase() : l[i][0].toUpperCase()) + l[i].slice(1));
      }
      return results;
    })();
    return out.join('');
  };

  _calcTempo = function(data) {
    var b, d, l, r, ref, ref1, ref2, ref3, ref4;
    b = (ref = data.meta) != null ? ref.beatCount : void 0;
    d = parseInt((ref1 = data.meta) != null ? (ref2 = ref1.timeSignature) != null ? ref2.split('/')[1] : void 0 : void 0);
    l = (ref3 = data.packetTableHeader) != null ? ref3.numberValidFrames : void 0;
    r = (ref4 = data.audioFormat) != null ? ref4.sampleRate : void 0;
    if (_.every([b, d, l, r], function(num) {
      return _.isNumber(num);
    })) {
      data.meta.tempo = Math.floor(r * b * 240 / d / l);
    }
    return data;
  };

  _flatToSharp = function(data) {
    var keySignature;
    keySignature = data.meta.keySignature;
    if (_.isString(keySignature) && keySignature.length === 2) {
      if (keySignature.slice(-1) === 'b') {
        if (keySignature[0] === 'A') {
          keySignature = 'G#';
        } else {
          keySignature = (String.fromCharCode(keySignature.charCodeAt(0) - 1)) + "#";
        }
        data.meta.keySignature = keySignature;
      }
      if (keySignature.slice(-1) === 'c') {
        keySignature = keySignature[0];
        data.meta.keySignature = keySignature;
      }
    }
    return data;
  };

}).call(this);
