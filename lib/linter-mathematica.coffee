{BufferedProcess, CompositeDisposable} = require 'atom'
path = require 'path'

module.exports =

	activate: (state) ->
		console.log path.join(__dirname, "scanfile.sh")
		console.log 'linter-mathematica loaded.'

	provideLinter: ->
		provider =
			grammarScopes: ['source.mathematica']
			scope: 'file'
			lintOnFly: false
			lint: (textEditor) =>
				return new Promise (resolve, reject) =>
					filePath = textEditor.getPath()
					results = []
					process = new BufferedProcess
						command: "java"
						args: ["-cp", path.join(__dirname, "fatjar.jar"), "FoxySheep", filePath]
						stdout: (output) ->
							lines = output.split('\n')
							lines.pop()
							for line in lines
								console.log(line)
								# Lines of form:
								# L 22 (C 1-3): Invalid use of a reserved word.
								# L 22 (C 32): Parse error at ')': usage might be invalid MATLAB syntax.
								regex = /W (true|false) L (\d+) \(C (\d+)-?(\d+)?\): (.*)/
								[_, isWarning, linenum, columnstart, columnend, message] = line.match(regex)
								
								if typeof columnend is 'undefined' then columnend = columnstart
								result = {
									range: [
										[linenum - 1, columnstart - 1],
										[linenum - 1, columnend - 1]
									]
									type: if isWarning is 'true' then "warning" else "error"
									text: message
									filePath: filePath
								}
								results.push result
						stderr: (output) ->
							console.log output
						exit: (code) ->
							console.log(code)
							return resolve [] unless code is 0
							return resolve [] unless results?
							resolve results

					process.onWillThrowError ({error,handle}) ->
						console.log error
						atom.notifications.addError "Failed to run Mathematica linter",
							detail: error
							dismissable: true
						handle()
						resolve []
