const { execFile } = require('child_process')
const bodyParser = require('body-parser')
const nunjucks = require('nunjucks')
const express = require('express')

const app = express()

app.use(bodyParser.urlencoded({ extended: true }))
app.use(bodyParser.json())

nunjucks.configure('views', {
    express: app,
    autoescape: false,
    noCache: true
})

app.set('view engine', 'njk')

app.get('/', (req, res) => {
    return res.render('index')
})

app.post('/stress', (req, res) => {
    console.log(req.body)
    const cpu = req.body.cpu
    const timeout = req.body.timeout
    execFile('/usr/bin/stress', ['--cpu', cpu, '--timeout', timeout])
    return res.render('stress', {cpu, timeout})
})


const PORT = 3000
app.listen(PORT, () => { 
    console.log(`Listening on port ${PORT}`) 
})