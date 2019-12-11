pragma solidity ^0.4.16;

contract A {
    function tuple() returns(uint, string) {
        return (1, "Hi");
    }

    function getOne() returns(uint) {
        uint a;
        (a,) = tuple();
        return a;
    }
}
