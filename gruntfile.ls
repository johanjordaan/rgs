_ = require 'prelude-ls'
module.exports = (grunt) ->
  grunt.initConfig do
    pkg: grunt.file.readJSON 'package.json'

    uglify:
      options:
        banner: '/*! <%= pkg.name %> <%= grunt.template.today("yyyy-mm-dd") %> */\n'
      build:
        src: 'src/<%= pkg.name %>.js'
        dest: 'build/<%= pkg.name %>.min.js'

    livescript:
      adminServer:
        files:
           'dist/admin_server.js': 'src/admin_server.ls'
           'dist/utils.js': 'src/utils.ls'
           'dist/ttt.js': 'src/ttt.ls'

      apiServer:
        files:
           'dist/api_server.js': 'src/api_server.ls'
           'dist/ttt.js': 'src/ttt.ls'
      client:
        files:
           'dist/client/client.js': 'client/src/*.ls'
      tests:
        files:
          'test/ttt.tests.js': 'src/test/ttt.tests.ls'



    watch:
      serverSourceChanges:
        files:
           'src/*.ls'
        tasks: ['livescript' 'mochaTest']
      frontEndChanges:
        files:
           'client/src/*.ls'
           'client/*.html'
        tasks: ['livescript:client' 'copy:frontEndStatic' 'mochaTest']
      testChanges:
        files:
           'src/test/*.ls'
        tasks: ['livescript:tests' 'mochaTest']


    concurrent:
      apiAndAdmin:
        tasks: ['watch:frontEndChanges' 'watch:serverSourceChanges' 'nodemon:adminServer' 'nodemon:apiServer']
        options:
           logConcurrentOutput: true
      api:
        tasks: ['watch:frontEndChanges' 'watch:serverSourceChanges' 'nodemon:apiServer']
        options:
           logConcurrentOutput: true
      admin:
        tasks: ['watch:frontEndChanges' 'watch:serverSourceChanges' 'nodemon:adminServer']
        options:
           logConcurrentOutput: true
      tests:
        tasks: ['watch:frontEndChanges' 'watch:serverSourceChanges' 'watch:testChanges' ]
        options:
           logConcurrentOutput: true



    nodemon:
      adminServer:
        script: 'dist/admin_server.js'
        options:
           pwd: 'dist'
      apiServer:
        script: 'dist/api_server.js'
        options:
           pwd: 'dist'

    copy:
      frontEndStatic:
        files: [
         * expand: true
           cwd: 'client/'
           src: ['*.html']
           dest: 'dist/client/'
         * expand: true
           cwd: 'client/'
           src: ['libs/**']
           dest: 'dist/client/'
        ]

    bowercopy:
      options:
        srcPrefix: 'bower_components'
      scripts:
        options:
           destPrefix: 'dist/client/libs'
        files:
           'angular/angular.js': 'angular/angular.js'
           'angular/angular-route.js': 'angular-route/angular-route.js'

    forever:
      adminServer:
        options:
           index: 'dist/admin_server.js'
           logDir: 'logs/'
      apiServer:
        options:
           index: 'dist/api_server.js'
           logDir: 'logs/'

    mochaTest:
      test:
        options:
          reporter: 'dot'
        src: ['test/**/*.js']


  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-livescript'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-concurrent'
  grunt.loadNpmTasks 'grunt-nodemon'
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-bowercopy'
  grunt.loadNpmTasks 'grunt-forever'
  grunt.loadNpmTasks 'grunt-mocha-test'

  grunt.registerTask 'devmon',  ['concurrent:apiAndAdmin']
  grunt.registerTask 'apimon',  ['concurrent:api']
  grunt.registerTask 'adminmon',['concurrent:admin']
  grunt.registerTask 'test',    ['concurrent:tests']
  grunt.registerTask 'default', ['livescript' 'copy:frontEndStatic' 'bowercopy']
