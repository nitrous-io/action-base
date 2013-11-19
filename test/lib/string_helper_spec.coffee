stringHelper = actionBase.stringHelper

describe 'stringHelper', ->
  describe '.escape', ->
    context 'when given a string', ->
      it 'replaces single quotes with single quotes surrounded by double quotes surrounded by single quotes and encloses the entire string in single quotes', ->
        expect(stringHelper.escape "3'o clock at harry's").to.equal "'3'\"'\"'o clock at harry'\"'\"'s'"

    context 'when given a non-string object', ->
      it 'returns null', ->
        expect(stringHelper.escape()).to.be.null
        expect(stringHelper.escape null).to.be.null
        expect(stringHelper.escape undefined).to.be.null
        expect(stringHelper.escape true).to.be.null
        expect(stringHelper.escape 123).to.be.null
        expect(stringHelper.escape {}).to.be.null
