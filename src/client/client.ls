errorController = ($scope,Errors) ->
  $scope.errors = Errors

  $scope.clear = ->
    Errors.length = 0

gameController = ($scope,Match,Player,Move,ErrorHandler) ->
  clear = ->
    $scope.status = "Idle..."
    $scope.playerA = {name:'bob'}
    $scope.playerB = {name:'sue'}
    $scope.match_id = ""
    $scope.state_number = 0

  clear!

  $scope.abort = ->
    clear!

  $scope.start = ->
    $scope.status = "In progress..."

    Match.create {game_id:'ttt'},(amatch) ->
      $scope.match_id = amatch.match_id
      Player.save {match_id:$scope.match_id},$scope.playerA ,(player)->
        $scope.playerA.match_key = player.match_key
        Player.save {match_id:$scope.match_id},$scope.playerB ,(player)->
          $scope.playerB.match_key = player.match_key
          Match.get {match_id:$scope.match_id},(amatch) ->
            $scope.state_number = amatch.current_state.state_number
            $scope.board = amatch.current_state._private.board
            $scope.playerA.role = amatch.role_map[$scope.playerA.match_key]
            $scope.playerB.role = amatch.role_map[$scope.playerB.match_key]
            $scope.playerA.moves = amatch.current_state.valid_moves[$scope.playerA.role]
            $scope.playerB.moves = amatch.current_state.valid_moves[$scope.playerB.role]

            $scope.playerA.selected_move = $scope.playerA.moves[0]
            $scope.playerB.selected_move = $scope.playerB.moves[0]

          ,ErrorHandler
        ,ErrorHandler
      ,ErrorHandler
    ,ErrorHandler

  $scope.submit = ->
    Move.submit {match_id:$scope.match_id,match_key:$scope.playerA.match_key}
    ,{state_number:$scope.state_number,move_index:$scope.playerA.selected_move.id},(amatch) ->
      Move.submit {match_id:$scope.match_id,match_key:$scope.playerB.match_key}
      ,{state_number:$scope.state_number,move_index:$scope.playerB.selected_move.id},(amatch) ->

          if amatch.current_state.finished
            $scope.status = "Finshed ..."

          $scope.board = amatch.current_state._private.board
          $scope.state_number = amatch.current_state.state_number
          $scope.playerA.moves = amatch.current_state.valid_moves[$scope.playerA.role]
          $scope.playerB.moves = amatch.current_state.valid_moves[$scope.playerB.role]

          $scope.playerA.selected_move = $scope.playerA.moves[0]
          $scope.playerB.selected_move = $scope.playerB.moves[0]
      ,ErrorHandler
    ,ErrorHandler


apiFactory = ($resource,ErrorHandler) ->
  do
    findMatches: (params, cb) ->
      $resource '/api/v1/matches', null
      .query params, cb, ErrorHandler


    startMatch: (params, cb) ->
      $resource '/api/v1/matches/:match_id', null
      .save params, cb, ErrorHandler


    joinMatch: (params, player, cb) ->
      $resource '/api/v1/matches/:match_id/players', null
      .save params, player, cb, ErrorHandler

    getMatchState: (params, cb) ->
      $resource '/api/v1/matches/:match_id', null
      .get params, cb, ErrorHandler

    makeMove: (params, move) ->
      new Promise (resolve,reject) ->
        $resource 'api/v1/matches/:match_id/moves', null
        .save params, move, resolve, (err)->
          ErrorHandler err
          reject err


matchFactory = ($resource) ->
  $resource '/api/v1/matches/:match_id',null, do
    'create' :
      method : 'POST'
    'update' :
      method : 'PUT'

playerFactory = ($resource) ->
  $resource '/api/v1/matches/:match_id/players',null, do
    'join' :
      method : 'POST'

moveFactory = ($resource) ->
  $resource '/api/v1/matches/:match_id/moves',null, do
    'submit' :
      method : 'POST'


errorHandlerFactory = (Errors) ->
  (err) ->
    console.log err
    Errors.push err.data.message


config = ($routeProvider) ->
  $routeProvider
  .when '/', do
    templateUrl: 'ttt.html'
    controller: 'tttController'

  .when '/exp', do
    templateUrl: 'ttt_experimental.html'
    controller: gameController
  .otherwise do
    redirectTo: '/'


app = angular.module 'gameApp',['ngResource','ngRoute']
app.controller 'gameController', ['$scope','Match','Player','Move','ErrorHandler',gameController]

app.controller 'tttController', tttControllerSpec

app.controller 'errorController', ['$scope','Errors',errorController]

app.factory 'Api',['$resource','ErrorHandler',apiFactory]

app.factory 'Match',['$resource',matchFactory]
app.factory 'Player',['$resource',playerFactory]
app.factory 'Move',['$resource',moveFactory]
app.factory 'ErrorHandler',['Errors',errorHandlerFactory]
app.value 'Errors',[]


app.config ['$routeProvider',config]
