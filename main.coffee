Watcher = require('beetles').dontLetMeDown
config =
    executor: './src/Chupacabra.coffee'
    timeout: process.env.TIMEOUT or 30000
    period: 30000
    observerTimeout: process.env.OBSERVER_TIMEOUT or 30000
watcher = new Watcher config
watcher.start()
