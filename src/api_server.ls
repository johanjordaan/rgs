_ = require 'prelude-ls'
Q = require 'q'
express = require 'express'
bodyParser = require 'body-parser'

app = express()

# Configure express
#app.use logging 'dev'
app.use bodyParser.json()

server = (require 'http').createServer app

LISTEN_PORT = 4000

server.listen LISTEN_PORT, ->
   console.log "rgs API Server - Listening on port #{LISTEN_PORT}"




######## DB Initialisation
mongo = require 'mongoskin'

db_name = "mongodb://localhost/rgs"
db = mongo.db db_name, {native_parser:true}
db.bind 'matches'


######## Game registration
ttt = require './ttt'

games =
  ttt:
    * game_id: 'ttt'
      description: 'Tic-Tac-Toe'
      options: {db:db, game_id:'ttt',required_players:2}
      module: ttt
  ttt_fast:
    * game_id: 'ttt_fast'
      description: 'Tic-Tac-Toe(fast)'
      options: {db:db,game_id:'ttt_fast',required_players:2}
      module: ttt

games_list = games |> _.values |> _.map (game) -> { game_id: game.game_id, description: game.description }


######## General methods
utils = require './utils'

create_match = (game_id) ->
  deferred = Q.defer()

  options = games[game_id].options
  new_match =
    match_id: utils.generate_token {}
    game_id: options.game_id
    status: "open"
    required_players: options.required_players
    players: []

  options.db.matches.save new_match, (err,saved_match) ->
    | err? => deferred.reject err
    | otherwise => deferred.resolve saved_match

  deferred.promise

# Removes the player key from the player list
sanitize_players = (player_list) ->
  player_list |> _.map (player) -> delete player.player_key

######## Rest Interface

# Get a list of games
app.get '/api/v1/games', (req, res) ->
  res.status(200).send games_list

# Get a list of matches
# Request parameter filters : game_status
# If no open matches exist then a new open one is created
app.get '/api/v1/games/:game_id/matches', (req, res) ->
  game_id = req.param 'game_id'

  db.matches.find( { game_id: game_id } ).toArray (err, matches) ->
    | err? => res.status(200).send err
    | otherwise =>
      open_matches = matches |> _.filter (m) -> m.status == "open"

      if open_matches.length <= 0
        create_match(game_id).then (new_match) ->
          matches.push new_match
          res.status(200).send matches
        , (err) ->
          res.status(200).send err
      else
        res.status(200).send matches

# Get a list of player for a match
app.get '/api/v1/games/:game_id/matches/:match_id/players', (req, res) ->
  game_id = req.param 'game_id'
  match_id = req.param 'match_id'

  db.matches.findOne { match_id: match_id }, (err, amatch) ->
    res.status(200).send amatch.players |> sanitize_players

# get the match details
app.get '/api/v1/games/:game_id/matches/:match_id', (req, res) ->
  game_id = req.param 'game_id'
  match_id = req.param 'match_id'

  db.matches.findOne { match_id: match_id }, (err, amatch) ->
    | err? => res.status(200).send err
    | otherwise => res.status(200).send amatch

# Add a player to the match (join the match)
# User has to post a structure with { player_key: player_name }
# Player is returned a player_match_key, this has to be presented to make a
# move or to get player specic data on turns
app.post '/api/v1/games/:game_id/matches/:match_id/players', (req, res) ->
  game_id = req.param 'game_id'
  match_id = req.param 'match_id'
  player = req.body

  player.match_key = utils.generate_token {}

  db.matches.findOne { match_id: match_id }, (err, amatch) ->
    | err? => res.status(200).send err
    | amatch.players.length < amatch.required_players =>
      amatch.players.push player
      db.matches.save amatch, (err,saved_match) ->
        | err? => res.status(200).send err
        | otherwise => res.status(200).send { match_key: player.match_key }
    | otherwise =>
      games[game_id].module.start_match amatch
      res.status(200).send { status: "Match full"}


# Get the turns in the match
# A turn here is meant as in a turn for a player to react. Inside the game the
# concept of a game might exist but it is not nescesary corelated turj in this
# context
# Request parameter filters : current_turn=true
# Request parameter : match_key - if not presented then only public data is returned,
# these restrictions only hold if a game is in progress. Afterwards
app.get '/api/v1/games/:game_id/matches/:match_id/turns', (req, res) ->
  game_id = req.param 'game_id'
  match_id = req.param 'match_id'
  match_key = req.param 'match_key'

  res.send 200, [
    * turn_id: 1
      player_id: 1
      match_key: match_key
      valid_moves: [
        * move_id: 1
          description: "Attack Alberta with 2 armies"
        * move_id: 2
          description: "Attack Alberta with 1 armies"
      ]
      move_made:1
      status:"valid"    #Timeout(random move is made)
  ]

# Updates the turn
# Need to send json { selected_move : <move_id> }
# Match key neesd to be present in order to make a valid move
app.put '/api/v1/games/:game_id/matches/:match_id/turns/:turn_id', (req, res) ->
  game_id = req.param 'game_id'
  match_id = req.param 'match_id'
  turn_id = req.param 'turn_id'
  match_key = req.param 'match_key'

  res.send 200, {}
