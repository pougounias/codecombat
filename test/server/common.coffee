# import this at the top of every file so we're not juggling connections
# and common libraries are available

GLOBAL._ = require('lodash')
_.str = require('underscore.string')
_.mixin(_.str.exports())
GLOBAL.mongoose = require 'mongoose'
mongoose.connect('mongodb://localhost/coco_unittest')
path = require('path')

models_path = [
  '../../server/articles/Article'
  '../../server/campaigns/Campaign'
  '../../server/campaigns/CampaignStatus'
  '../../server/levels/Level'
  '../../server/levels/components/LevelComponent'
  '../../server/levels/systems/LevelSystem'
  '../../server/levels/drafts/LevelDraft'
  '../../server/levels/sessions/LevelSession'
  '../../server/levels/thangs/LevelThangType'
  '../../server/users/User'
]

for m in models_path
  model = path.basename(m)
  #console.log('model=' + model)
  GLOBAL[model] = require m

async = require 'async'

GLOBAL.clearModels = (models, done) ->

  funcs = []
  for model in models
    if model is User
      unittest.users = {}
    wrapped = (m) -> (callback) ->
      m.remove {}, (err) ->
        callback(err, true)
    funcs.push(wrapped(model))

  async.parallel funcs, (err, results) ->
    done(err)

GLOBAL.saveModels = (models, done) ->

  funcs = []
  for model in models
    wrapped = (m) -> (callback) ->
      m.save (err) ->
        callback(err, true)
    funcs.push(wrapped(model))

  async.parallel funcs, (err, results) ->
    done(err)

GLOBAL.simplePermissions = [target:'public', access:'owner']
GLOBAL.ObjectId = mongoose.Types.ObjectId
GLOBAL.request = require 'request'

GLOBAL.unittest = {}
unittest.users = unittest.users or {}

unittest.getNormalJoe = (done, force) ->
  unittest.getUser('normal@jo.com', 'food', done, force)
unittest.getOtherSam = (done, force) ->
  unittest.getUser('other@sam.com', 'beer', done, force)
unittest.getAdmin = (done, force) ->
  unittest.getUser('admin@afc.com', '80yqxpb38j', done, force)

unittest.getUser = (email, password, done, force) ->
  # Creates the user if it doesn't already exist.

  return done(unittest.users[email]) if unittest.users[email] and not force
  request = require 'request'
  request.post getURL('/auth/logout'), ->
    req = request.post(getURL('/db/user'), (err, response, body) ->
      throw err if err
      User.findOne({email:email}).exec((err, user) ->
        if password is '80yqxpb38j'
          user.set('permissions', [ 'admin' ])
          user.save (err) ->
            wrapUpGetUser(email, user, done)
        else
          wrapUpGetUser(email, user, done)
      )
    )
    form = req.form()
    form.append('email', email)
    form.append('password', password)

wrapUpGetUser = (email, user, done) ->
  unittest.users[email] = user
  return done(unittest.users[email])

GLOBAL.getURL = (path) ->
  return 'http://localhost:3001' + path

GLOBAL.loginJoe = (done) ->
  request.post getURL('/auth/logout'), ->
    unittest.getNormalJoe (user) ->
      req = request.post(getURL('/auth/login'), (error, response) ->
        expect(response.statusCode).toBe(200)
        done(user)
      )
      form = req.form()
      form.append('username', 'normal@jo.com')
      form.append('password', 'food')

GLOBAL.loginSam = (done) ->
  request.post getURL('/auth/logout'), ->
    unittest.getOtherSam (user) ->
      req = request.post(getURL('/auth/login'), (error, response) ->
        expect(response.statusCode).toBe(200)
        done(user)
      )
      form = req.form()
      form.append('username', 'other@sam.com')
      form.append('password', 'beer')

GLOBAL.loginAdmin = (done) ->
  request.post getURL('/auth/logout'), ->
    unittest.getAdmin (user) ->
      req = request.post(getURL('/auth/login'), (error, response) ->
        expect(response.statusCode).toBe(200)
        done(user)
      )
      form = req.form()
      form.append('username', 'admin@afc.com')
      form.append('password', '80yqxpb38j')
      # find some other way to make the admin object an admin... maybe directly?

GLOBAL.dropGridFS = (done) ->
  if mongoose.connection.readyState is 2
    mongoose.connection.once 'open', ->
      _drop(done)
  else
    _drop(done)

_drop = (done) ->
  files = mongoose.connection.db.collection('media.files')
  files.remove {}, ->
    chunks = mongoose.connection.db.collection('media.chunks')
    chunks.remove {}, ->
      done()
