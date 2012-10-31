actionCipher = actionBase.actionCipher

describe 'actionCipher', ->
  it 'can encrypt and decrypt data', ->
    key = 'secret key'
    data = 'super secret data'
    base64 = /^[a-zA-Z\d\+\/=]+\n?$/

    [iv, encrypted] = actionCipher.encrypt key, data
    expect(data).not.to.equal encrypted
    expect(encrypted).to.match base64
    expect(iv).to.match base64

    [iv2, encrypted2] = actionCipher.encrypt key, data
    expect(data).not.to.equal encrypted2
    expect(encrypted2).to.match base64
    expect(iv2).to.match base64

    expect(iv).not.to.equal iv2
    expect(encrypted).not.to.equal encrypted2

    decrypted = actionCipher.decrypt key, iv, encrypted
    decrypted2 = actionCipher.decrypt key, iv2, encrypted2

    expect(decrypted).to.equal data
    expect(decrypted2).to.equal data

    [iv, encrypted] = actionCipher.encrypt key, 'top secret'
    expect(actionCipher.decrypt key, iv, encrypted).to.equal 'top secret'
    expect(->
      actionCipher.decrypt 'wrong key', iv, encrypted
    ).to.throw Error

