{BufferedProcess, CompositeDisposable, Point, TextBuffer} = require 'atom'
path = require 'path'

module.exports =

	activate: (state) ->
		console.log 'linter-mathematica loaded.'

	provideLinter: ->
		provider =
			grammarScopes: ['source.mathematica']
			scope: 'file'
			lintOnFly: false
			lint: (textEditor) =>
				return new Promise (resolve, reject) =>
					filePath = textEditor.getPath()
					buffer = new TextBuffer()
					buffer.setText(textEditor.getText())
					warnings = []
					errors = []
					results = []
					process = new BufferedProcess
						command: "java"
						args: ["-cp", path.join(__dirname, "mmparser.jar"), "FoxySheep", filePath]
						stdout: (output) ->
							lines = output.split('\n')
							lines.pop()
							for line in lines
								# Lines of form:
								# W warning C charStart: description
								# W true C 22: Invalid use of a reserved word.
								# W false C 22: Parse error at ')': usage might be invalid mathematica syntax.
								regex = /W (true|false) C (\d+): (.*)/
								[_, isWarning, charOffset, message] = line.match(regex)
								
								position = buffer.positionForCharacterIndex(charOffset)
								result = {
									range: [
										position.toArray(),
										position.toArray()
									]
									type: if isWarning is 'true' then "warning" else "error"
									text: message
									filePath: filePath
								}
								if isWarning is 'true' then warnings.push result else errors.push result
							results = errors.concat(warnings)
							results
						stderr: (output) ->
							atom.notifications.addError "Failed to lint file",
								detail: output
								dismissable: true
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
