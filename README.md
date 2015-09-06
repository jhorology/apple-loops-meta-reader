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

- synchronous read operation
```javascript
var reader = require('apple-loops-meta-reader'),
    beautify = require('js-beautify');
var data = reader.read('/Library/Audio/Apple Loops/Apple/Jam Pack Voices/Vinnie Lyric 29.caf');
console.log(beautify(JSON.stringify(data), { indent_size: 2 }));
```

- asynchronous read operation
```javascript
reader.open('/Library/Audio/Apple Loops/Apple/Jam Pack World Music/Eastern Storm Violin 10.caf')
    .on('data', function(data){
        console.log(beautify(JSON.stringify(data), { indent_size: 2 }));
    })
    .on('error', function(error){
        console.error(error);
    });
```

- example output
```javascript
{
  "file type": "caff",
  "file version": 1,
  "file flags": 0,
  "audio format": {
    "sample rate": 44100,
    "format id": "aac ",
    "format flags": 0,
    "bytes per packet": 0,
    "frames per packet": 1024,
    "channels per frames": 2,
    "bits per channel": 0
  },
  "infomation": {},
  "packet table header": {
    "number packates": 113,
    "number valid frames": 113574,
    "priming frames": 2112,
    "remainder frames": 26
  },
  "meta": {
    "beat count": 8,
    "key signature": "A",
    "key type": "major",
    "time signature": "4/4",
    "category": "Vocals",
    "subcategory": "Male",
    "genre": "Rock Blues",
    "descriptors": ["Single", "Part", "Processed", "Clean", "Cheerful", "Grooving", "Melodic"],
    "collection": "Jam Pack Voices",
    "tempo": 186
  },
  "transients": {
    "unknown": "00000000000100000032000100000000",
    "markers": [{
      "unknown": 65536,
      "frame position": 0
    }, {
      "unknown": 65536,
      "frame position": 24818
    }, {
      "unknown": 65536,
      "frame position": 40907
    }, {
      "unknown": 65536,
      "frame position": 47074
    }, {
      "unknown": 65536,
      "frame position": 78423
    }, {
      "unknown": 65536,
      "frame position": 113574
    }]
  }
}
```
