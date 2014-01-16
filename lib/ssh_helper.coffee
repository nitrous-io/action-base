fs = require 'fs'
tmp = require 'tmp'
childProcess = require 'child_process'

module.exports = class SSHHelper
  constructor: (@user, @host, @port, @key) ->

  writeKeyFile: (callback) -> # callback(err, sshArgs, deleteKeyFile)
    tmp.file (err, path, fd) =>
      fs.close(fd) if fd
      if err
        callback err
        return
      fs.writeFile path, @key, (err) =>
        if err
          fs.unlink path, ->
            callback err
          return
        sshArgs = [
          '-i', path
          '-o', 'UserKnownHostsFile=/dev/null'
          '-o', 'StrictHostKeyChecking=no'
          '-o', 'PubkeyAuthentication=yes'
          '-o', 'PasswordAuthentication=no'
          '-o', 'LogLevel=FATAL'
          '-p', "#{@port}"
          "#{@user}@#{@host}"
        ]
        deleteKeyFile = (callback) ->
          fs.unlink path, ->
            callback?()
        callback null, sshArgs, deleteKeyFile

  execCommand: (command, options, callback) -> # callback(err, stdout, stderr)
    if typeof options == 'function'
      callback = options
      options = {}

    timeout = options?.timeout || 20000

    @writeKeyFile (err, sshArgs, deleteKeyFile) ->
      if err
        callback err
        return
      sshArgs.push("export LC_ALL=en_US.UTF-8; #{command}")
      try
        childProcess.execFile '/usr/bin/ssh', sshArgs, timeout: timeout, (err, stdout, stderr) ->
          deleteKeyFile ->
            callback err, stdout, stderr
      catch err
        deleteKeyFile ->
          callback err

