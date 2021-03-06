gulp        = require 'gulp'
coffeelint  = require 'gulp-coffeelint'
coffee      = require 'gulp-coffee'
istanbul    = require 'gulp-istanbul'
mocha       = require 'gulp-mocha'
runSequence = require 'run-sequence'
del         = require 'del'
watch       = require 'gulp-watch'
mocha       = require 'gulp-mocha'
  
gulp.task 'coffeelint', ->
  gulp.src ['./*.coffee', './test/*.coffee']
    .pipe coffeelint './coffeelint.json'
    .pipe coffeelint.reporter()

gulp.task 'coffee', ->
  gulp.src ['./apple-loops-meta-reader.coffee']
    .pipe coffee()
    .pipe gulp.dest './'

gulp.task 'default', (cb) -> runSequence.apply null, [
  'coffeelint'
  'coffee'
  cb
]

gulp.task 'watch', ->
  gulp.watch './**/*.coffee', ['default']
 
gulp.task 'clean', (cb) ->
  del ['./*.js', './**/*~'], force: true, cb

gulp.task 'test', ['default'], ->
  gulp.src './test/*.coffee', read: false
    .pipe mocha reporter: 'nyan'

