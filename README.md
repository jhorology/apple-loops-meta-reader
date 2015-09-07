## apple-loops-meta-reader

Apple Loops(*.caf) metadata reader for node.js.


### Build
```
    npm install
    gulp
```

### Test
```
    gulp test
```

### Usage

synchronous read operation
```javascript
var reader = require('apple-loops-meta-reader'),
    beautify = require('js-beautify');

var data = reader.read('Behold Brass & Wind 03.caf');
console.log(beautify(JSON.stringify(data), { indent_size: 2 }));
```

asynchronous read operation
```javascript
var reader = require('apple-loops-meta-reader'),
    beautify = require('js-beautify');

reader.open('Behold Brass & Wind 03.caf')
    .on('data', function(data){
        console.log(beautify(JSON.stringify(data), { indent_size: 2 }));
    })
    .on('error', function(error){
        console.error(error);
    });
```
gulp task
```coffeescript
path        = require 'path'
gulp        = require 'gulp'
data        = require 'gulp-data'
exec        = require 'gulp-exec'
appleLoops  = require 'apple-loops-meta-reader'

gulp.task 'default', ->
  gulp.src ["#{$.appleLoopsDir}/**/*.caf"]
    .pipe data (file) ->
      data =  appleLoops.read (file.path)

      # categolize using folder
      folder = $.distDir
      if data.meta.genre
        folder += "/#{data.meta.genre.replace('/',' ')}"
      else
        folder += '/unkown'
      if data.meta.category
        folder += "/#{data.meta.category.replace('/',' ')}"
      if data.meta.subcategory
        folder += "/#{data.meta.subcategory.replace('/',' ')}"
      data.m4aFolder = folder

      # add bpm and key to filename
      name = path.basename file.path, '.caf'
      if data.meta.tempo
        name += " #{data.meta.tempo}bpm"
      if data.meta.keySignature
        name += " #{data.meta.keySignature}"
      if data.meta.keyType
        name += " #{data.meta.keyType}"
      name += '.m4a'
      data.m4aFilePath = folder + '/' + name
      data
    .pipe exec [
      'mkdir -p "<%= file.data.m4aFolder %>"'
      'afconvert -v -f m4af -d 0 "<%= file.path %>" "<%= file.data.m4aFilePath %>"'
      ].join ' && '
    , $.exec.opts
    .pipe exec.reporter $.exec.reportOpts
```

example output
```javascript
{
  "fileType": "caff",
  "fileVersion": 1,
  "fileFlags": 0,
  "audioFormat": {
    "sampleRate": 44100,
    "formatId": "aac ",
    "formatFlags": 0,
    "bytesPerPacket": 0,
    "framesPerPacket": 1024,
    "channelsPerFrames": 2,
    "bitsPerChannel": 0
  },
  "packetTableHeader": {
    "numberPackets": 347,
    "numberValidFrames": 352800,
    "primingFrames": 2112,
    "remainderFrames": 416
  },
  "meta": {
    "beatCount": 8,
    "keySignature": "C#",
    "keyType": "major",
    "timeSignature": "4/4",
    "category": "Horn/Wind",
    "genre": "Orchestral",
    "descriptors": ["Ensemble", "Part", "Acoustic", "Dry", "Clean", "Cheerful", "Relaxed", "Grooving", "Melodic"],
    "tempo": 60
  },
  "infomation": {
    "copyright": "2004 PowerFX Systems AB",
    "artist": "EgoWorks"
  },
  "transients": {
    "unknown": "00000000000100000000000000000000",
    "markers": [{
      "unknown": 65536,
      "framePosition": 0
    }, {
      "unknown": 65536,
      "framePosition": 20805
    }, {
      "unknown": 65536,
      "framePosition": 40780
    }, {
      "unknown": 65536,
      "framePosition": 61585
    }, {
      "unknown": 65536,
      "framePosition": 176400
    }, {
      "unknown": 65536,
      "framePosition": 192775
    }, {
      "unknown": 65536,
      "framePosition": 212674
    }, {
      "unknown": 65536,
      "framePosition": 235495
    }, {
      "unknown": 65536,
      "framePosition": 352800
    }]
  }
}
```
