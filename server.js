var http = require('http')
var fs = require('fs')

const express = require('express')

const port = 8080


const app = express()

app.set('view engine', 'ejs')
app.use(express.urlencoded())
app.get("/", function(req, res, next){
    res.render('index', { texDt: "bluh" })
})

app.get("/wheel", function(req, res, next){
    res.render('wheel')
})
app.post("/wheel", function(req, res, next){
  // get params
  console.log("wheelName")
  console.log(req.body.wheelName)
  // validate params
  if(req.body.wheelName == "Wheel"){
    paramsValid = true
  }else{
    paramsValid = false
  }
  if(!paramsValid){
    console.log("Param Err")
    res.render("wheel", {wheelName: req.body.wheelName})
    return
  }
  // start process..
  // get pid..
  // redirect to progress/pid
  res.redirect("/progress/99")
})

app.get("/progress/:pid", function(req, res, next){
    pid = req.params.pid
    res.send('pid was ' + req.params.pid)
})

app.get("/download/", function(req, res, next){
  res.download("wheel.stl")
})


app.listen(port)


/*
//create a server object:
const server  = http.createServer(function (req, res) {

  fs.readFile("index.html", function(error, data){
    if(error){
      res.writeHead(404)
      res.write('Error: File Not Found')
    }else{
      res.writeHead(200, { 'Content-Type': 'text/html'})
      res.write(data)
    }
    res.end()
  })
})

server.listen(port, function(error){
  if(error){
    console.log("Error " + error)
  }else{
      console.log("server is listening on " + port)
  }
})
*/
