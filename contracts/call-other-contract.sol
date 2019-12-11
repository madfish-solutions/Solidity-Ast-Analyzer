pragma solidity ^0.4.16;

contract OtherContract {
  function OtherContracts(address) {}

  function bar() public {}
}

contract MyContract {
  OtherContract other;
  function MyContract(address otherAddress) {
    other = OtherContract(otherAddress);
  }
  function foo() {
    other.bar();
  }
}