_ = require 'prelude-ls'
Q = require 'q'
express = require 'express'
bodyParser = require 'body-parser'

utils = require './utils'

app = express()

# Configure express
#app.use logging 'dev'
app.use bodyParser.json()

server = (require 'http').createServer app

LISTEN_PORT = 4000

######## DB Initialisation
mongo = require 'mongoskin'
db_name = "mongodb://localhost/rgs"
db = mongo.db db_name, {native_parser:true}
db.bind 'matches'
db.bind 'match_states'


if require.main == module
  server.listen LISTEN_PORT, ->
     console.log "rgs API Server - Listening on port #{LISTEN_PORT}"
else
  module.exports = (test_db) ->
    if test_db?
      db := test_db
      db.bind 'matches'
      db.bind 'match_states'
    app

######## Game registration
ttt = require './ttt'

games =
  ttt:
    * game_id: 'ttt'
      description: 'Tic-Tac-Toe'
      options: {game_id:'ttt',required_players:2}
      module: ttt
  ttt_fast:
    * game_id: 'ttt_fast'
      description: 'Tic-Tac-Toe(fast)'
      options: {game_id:'ttt_fast',required_players:2}
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
    required_players: options.required_players
    status: "open"
    players: []
    moves: []      # List of {role,move_index,state_id}
    current_state: {}

  db.matches.save new_match, (err,saved_match) ->
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

# get the match details
app.get '/api/v1/games/:game_id/matches/:match_id', (req, res) ->
  game_id = req.param 'game_id'
  match_id = req.param 'match_id'

  #todo : players and other stuff like moves etc needs to be sanaitised
  # this is to prevent private game data from being leaked
  #
  db.matches.findOne { match_id: match_id }, (err, amatch) ->
    | err? => res.status(200).send err
    | otherwise => res.status(200).send amatch


# Get the states in the match
# Inside the game the concept of a game might exist but it is not nescesary corelated turj in this
# context
# Request parameter filters : current_turn=true
# Request parameter : match_key - if not presented then only public data is returned,
# these restrictions only hold if a game is in progress. Afterwards
app.get '/api/v1/games/:game_id/matches/:match_id/states', (req, res) ->
  game_id = req.param 'game_id'
  match_id = req.param 'match_id'
  match_key = req.param 'match_key'


  db.match_states.find({ match_id: match_id }).sort({state_number:1}).toArray (err, match_states) ->
    | err? => res.status(200).send err
    | otherwise =>
      res.status(200).send match_states


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
    | err? => res.status(400).send err
    | amatch.players.length < amatch.required_players =>
      # Add the player to the list and start the match if there is enough players
      #
      amatch.players.push player
      switch amatch.players.length == amatch.required_players
      | true =>
        # Start a new match
        #
        amatch.initial_state = games[game_id].module.initial_game_state 2
        amatch.role_map = [p.match_key for p in amatch.players] |> utils.shuffle |> _.zip amatch.initial_state.roles |> _.pairs-to-obj
      | otherwise =>
        # Just update the player list
        #

      # Save the match and the initial state
      #
      db.matches.save amatch, (err,saved_match) ->
        | err? => res.status(400).send err
        | amatch.players.length < amatch.required_players =>
        | otherwise =>
          # Save the initial state
          #
          amatch.initial_state.state_number = 0
          db.match_states.save amatch.initial_state, (err,saved_state) ->
            | err? => res.status(400).send err
            | otherwise => res.status(200).send { match_key: player.match_key }

    | otherwise => res.status(200).send { status: "Match full"}




# Update the match with a move. The move is the index of the last state in the
# game.
# Match key neesd to be present in order to make a valid move
# The player with the correct match_key has to be tha active player
# and the move has to be a valid move. Here valid is defined as within the list of moves
# In order to handle simultanious moves all playes has yo submit a move,it should be the
# nop move if there is not moves for you for this tuen. This also measn that all players
# will get al least the nop move.
#
app.put '/api/v1/games/:game_id/matches/:match_id/', (req, res) ->
  game_id = req.param 'game_id'
  match_id = req.param 'match_id'
  turn_id = req.param 'turn_id'
  match_key = req.param 'match_key'

  res.send 200, {}
