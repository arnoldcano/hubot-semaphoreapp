# Entry point, just loads scripts from src directory

Fs   = require 'fs'
Path = require 'path'

module.exports = (robot) ->
  path = Path.resolve __dirname, 'src'
  robot.loadFile path, file for file in Fs.readdirSync(path)
