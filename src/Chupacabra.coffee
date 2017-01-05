Redmine = require 'node-redmine'
config = require './config'
_ = require 'lodash'
async = require 'async'
fs = require 'fs'
path = require 'path'
moment = require 'moment'
Elastic = require 'elasticsearch-connector'

class Chupacabra

    statuses =
        5: 'Aberta'
        10: 'Aguardando Cliente'
        4: 'Análise'
        3: 'Backlog'
        18: 'Cancelada'
        2: 'Concluida'
        17: 'Deploying'
        13: 'Developing'
        11: 'Em Homologação'
        16: 'Ready for Deploy'
        12: 'Refined'
        19: 'Reprovada'
        1: 'To do'
        14: 'To Test'
        9: 'Trancada'
        15: 'Under System Test'

    filePath = path.join __dirname, 'diary'

    constructor: ->
        es = new Elastic config.es
        incursion =
            checkEngines: (callback) ->
                # checks if the es host is reachable
                es.ping (error, response) ->
                    unless response
                        return callback "Elasticsearch cluster is not accessible on host '#{hosts.es.host}:#{hosts.es.port}'. Are the configs ok?"
                    console.log 'Elasticsearch host ok.'
                    console.log 'Checking indexes...'
                    callback()
            checkHumanTarget: ['checkEngines', (results, callback) ->
                es.indexExists 'kms', callback
            ]
            preparingProbe: ['checkHumanTarget', (results, callback) ->
                if results.checkHumanTarget[1] is 200
                    console.log 'Index ok.'
                    return callback()
                console.log 'Index NOT FOUND. Creating...'
                mapping =
                    _default_:
                        dynamic_templates: [
                            raw:
                                match: "*"
                                match_mapping_type: "string"
                                mapping:
                                    type: "string"
                                    index: "not_analyzed"
                        ]
                es.createIndex index: 'kms', mapping: mapping, callback
            ]
            startIncursion: ['preparingProbe', (results, callback) =>
                console.log 'All check.'
                @insertProbe callback
            ]

        async.auto incursion, (err, results) =>
            return console.error err if err?
            @logIncursion results.startIncursion
            console.log 'Incursion done.'

    insertProbe: (cb) ->
        es = new Elastic config.es
        redmine = new Redmine config.redmine.host, apiKey: config.redmine.key
        offset =  @checkLastIncursion()
        console.log 'Acquiring new subjects...'
        redmine.issues status_id: 2, offset: offset, limit: 30, sort: 'id', (err, data) =>
            return console.error err if err?
            return cb 'No new issues.' if _.isEmpty(data.issues)
            console.log "I have selected #{data.issues.length} subjects."
            newIssues = _.map data.issues, 'id'
            process.stdout.write 'Getting detailed information'
            async.mapLimit newIssues, 50, (issueId, callback) ->
                redmine.get_issue_by_id issueId, {include: 'journals'}, (err, issueInfo) ->
                    process.stdout.write '.'
                    return callback err if err?
                    issue = _.omit issueInfo.issue, ['status', 'custom_fields', 'done_ratio', 'priority']
                    changelog = _.map issue.journals, (journal) ->
                        filtered = _.filter(journal.details, name: 'status_id')
                        _.map filtered, (item) ->
                            created: journal.created_on, status: statuses[item.new_value]
                    issue.changelog = _.flatten changelog
                    callback null, _.omit issue, 'journals'
            , (err, results) =>
                console.log ''
                return cb err if err?
                bulk = _.reduce results, (memo, issue) ->
                    memo +=
                        """
                        {create: {_index: "kms", _type: "task", _id: "#{issue.id}"}
                        #{JSON.stringify(issue)}

                        """
                , ''
                console.log 'Registering findings...'
                es.bulk bulk, (err, success) ->
                    return console.error err, success if err?
                    cb null, offset + newIssues.length

    checkLastIncursion: ->
        try
            diary = fs.readFileSync filePath, encoding: 'utf8'
        catch e
            # I don't care
        parseInt(diary) or 0

    logIncursion: (offset) ->
        fs.writeFileSync filePath, "#{offset}"

module.exports = new Chupacabra
