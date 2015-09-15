path        = require 'path'
gulp        = require 'gulp'
coffeelint  = require 'gulp-coffeelint'
data        = require 'gulp-data'
exec        = require 'gulp-exec'
del         = require 'del'
appleLoops  = require 'apple-loops-meta-reader'

$ =
 appleLoopsDir: '/Library/Audio/Apple Loops/Apple'
 distDir: 'dist'
 exec:
   opts:
     continueOnError: off             # default = off, on means don't emit error event
     pipeStdout: off                  # default = off, on means stdout is written to file.contents
     customTemplatingThing: undefined # content passed to gutil.template()
   reportOpts:
     err: on                          # default = on, off means don't write err
     stderr: on                       # default = on, off means don't write stderr
     stdout: on                       # default = on, off means don't write stdout
   
gulp.task 'coffeelint', ->
  gulp.src ['./*.coffee']
    .pipe coffeelint './coffeelint.json'
    .pipe coffeelint.reporter()

gulp.task 'clean', (cb) ->
  del [$.distDir, './**/*~'], force: true, cb

gulp.task 'default', ->
  gulp.src ["#{$.appleLoopsDir}/**/*.caf"]
    .pipe data (file) ->
      data =  appleLoops.read (file.path)

      # categolize using folder
      folder = $.distDir
      if data.meta.genre
        folder += "/#{data.meta.genre.replace('/',' ')}"
      else
        folder += '/unknown'
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




