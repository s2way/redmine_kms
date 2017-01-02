Redmine = require 'node-redmine'
config = require './config'

class Chupacabra

    constructor: ->
        red = new Redmine config.host, apiKey: config.key
        red.projects {}, (err, data) ->
            console.log err, data
module.exports = new Chupacabra
