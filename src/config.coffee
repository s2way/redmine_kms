module.exports =
    redmine:
        host: 'http://help.s2way.com:3000'
        key: '8931687dc430de3ddd2776e95588f979ae474673'
    es:
        host: process.env.ES_HOST or 'localhost'
        port: process.env.ES_PORT or 9200
        keepAlive: true # default is true
        timeout: process.env.ES_TIMEOUT or 30000 # default is 30000
