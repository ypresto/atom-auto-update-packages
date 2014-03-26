path = require 'path'
glob = require 'glob'
{BufferedProcess} = require 'atom'

INSTALLATION_LINE_PATTERN = /^Installing +([^@]+)@(\S+).+\s+(\S+)$/

module.exports =
  activate: (state) ->
    atom.workspaceView.command 'auto-update-packages:update-now', =>
      @updatePackages()

  deactivate: ->

  updatePackages: ->
    @runApmUpgrade (log) =>
      entries = @parseLog(log)
      summary = @generateSummary(entries)
      return unless summary
      @notify
        title: 'Atom Package Updates'
        message: summary
        sender: 'com.github.atom'

  runApmUpgrade: (callback) ->
    command = atom.packages.getApmPath()
    args = ['upgrade', '--no-confirm', '--no-color']

    log = ''

    stdout = (data) ->
      log += data

    exit = (exitCode) ->
      callback(log)

    new BufferedProcess({command, args, stdout, exit})

  # Parsing the output of apm is a dirty way, but using atom-package-manager directly via JavaScript
  # is probably more brittle than parsing the output since it's a private package.
  # /Applications/Atom.app/Contents/Resources/app/apm/node_modules/atom-package-manager
  parseLog: (log) ->
    lines = log.split('\n')

    for line in lines
      matches = line.match(INSTALLATION_LINE_PATTERN)
      continue unless matches?
      [_match, name, version, result] = matches

      'name': name
      'version': version
      'isInstalled': result == '\u2713'

  generateSummary: (entries) ->
    successfulEntries = entries.filter (entry) ->
      entry.isInstalled
    return null unless successfulEntries.length > 0

    names = successfulEntries.map (entry) ->
      entry.name

    summary = @generateEnumerationExpression(names)
    summary += if successfulEntries.length == 1 then ' has' else ' have'
    summary += ' been updated automatically.'
    summary

  generateEnumerationExpression: (items) ->
    expression = ''

    for item, index in items
      if index > 0
        if index + 1 < items.length
          expression += ', '
        else
          expression += ' and '

      expression += item

    expression

  notify: (notification) ->
    command = @getTerminalNotifierPath()
    return console.log("terminal-notifier is not found.") unless command

    args = []
    for key, value of notification
      args.push("-#{key}", value)

    new BufferedProcess({command, args})

  getTerminalNotifierPath: ->
    unless @cachedTerminalNotifierPath == undefined
      return @cachedTerminalNotifierPath

    pattern = path.join(__dirname, '..', 'vendor', '**', 'terminal-notifier')
    paths = glob.sync(pattern)

    @cachedTerminalNotifierPath =
      if paths.length == 0
        null
      else
        paths[0]
