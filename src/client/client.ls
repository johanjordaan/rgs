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

    Match.create {game_id:'ttt'},(res) ->
      $scope.match_id = res.match.match_id
      Player.save {match_id:$scope.match_id},$scope.playerA ,(res)->
        $scope.playerA.match_key = res.match_key
        Player.save {match_id:$scope.match_id},$scope.playerB ,(res)->
          $scope.playerB.match_key = res.match_key
          Match.get {match_id:$scope.match_id},(res) ->
            $scope.state_number = res.match.current_state.state_number
            $scope.board = res.match.current_state._private.board
            $scope.playerA.role = res.match.role_map[$scope.playerA.match_key]
            $scope.playerB.role = res.match.role_map[$scope.playerB.match_key]
            $scope.playerA.moves = res.match.current_state.valid_moves[$scope.playerA.role]
            $scope.playerB.moves = res.match.current_state.valid_moves[$scope.playerB.role]

            $scope.playerA.selected_move = $scope.playerA.moves[0]
            $scope.playerB.selected_move = $scope.playerB.moves[0]

          ,ErrorHandler
        ,ErrorHandler
      ,ErrorHandler
    ,ErrorHandler

  $scope.submit = ->
    Move.submit {match_id:$scope.match_id,match_key:$scope.playerA.match_key}
    ,{state_number:$scope.state_number,move_index:$scope.playerA.selected_move.id},(res) ->
      Move.submit {match_id:$scope.match_id,match_key:$scope.playerB.match_key}
      ,{state_number:$scope.state_number,move_index:$scope.playerB.selected_move.id},(res) ->

          if res.match.current_state.finished
            $scope.status = "Finshed ..."

          $scope.board = res.match.current_state._private.board
          $scope.state_number = res.match.current_state.state_number
          $scope.playerA.moves = res.match.current_state.valid_moves[$scope.playerA.role]
          $scope.playerB.moves = res.match.current_state.valid_moves[$scope.playerB.role]

          $scope.playerA.selected_move = $scope.playerA.moves[0]
          $scope.playerB.selected_move = $scope.playerB.moves[0]
      ,ErrorHandler
    ,ErrorHandler



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


errorHandlerFactory = (Errors)->
  (err) ->
    Errors.push err.data.message


app = angular.module 'gameApp',['ngResource']
app.controller 'gameController', ['$scope','Match','Player','Move','ErrorHandler',gameController]
app.controller 'errorController', ['$scope','Errors',errorController]
app.factory 'Match',['$resource',matchFactory]
app.factory 'Player',['$resource',playerFactory]
app.factory 'Move',['$resource',moveFactory]
app.factory 'ErrorHandler',['Errors',errorHandlerFactory]
app.value 'Errors',[]
