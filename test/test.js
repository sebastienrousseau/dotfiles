const chai = require('chai')
var expect = require('chai').expect
describe('Array', function() {
  describe('indexOf()', function() {
      it("dovrebbe tornare -1 quando l'elemento non è presente", function() {
          expect([1,2,3].indexOf(4)).to.equal(-1)
      })
  })
})