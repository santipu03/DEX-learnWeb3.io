// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {
    address public cryptoDevTokenAddress;

    constructor(address _CryptoDevToken) ERC20("Crypto Dev LP Token", "CDLP") {
        require(_CryptoDevToken != address(0), "Token address is a null address");
        cryptoDevTokenAddress = _CryptoDevToken;
    }

    function addLiquidity(uint _amount) public payable returns (uint) {
        uint liquidityMinted;
        uint ethBalance = address(this).balance;
        uint tokenReserve = getReserve();
        ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);

        // If tokenReserve == 0, user is the first to add liquidity and he decides the ratio
        if (tokenReserve == 0) {
            cryptoDevToken.transferFrom(msg.sender, address(this), _amount);
            // liquidityMinted is equal to ethBalance bc is the first user in the pool, he has all the liquidity
            liquidityMinted = ethBalance;
            // give the sender the LP tokens equivalent to the ETH deposited
            _mint(msg.sender, liquidityMinted);
        } else {
            // If the reserve is not empty, we have to make sure the ratio tokens/ETH is correct
            // EthReserve should be the current ethBalance subtracted by the value of ether sent by the user in the current `addLiquidity` call
            uint ethReserve = ethBalance - msg.value;
            uint tokensToDeposit = (msg.value * tokenReserve) / (ethReserve);
            require(
                _amount >= tokensToDeposit,
                "Amount of tokens sent is less than the minimum tokens required"
            );
            // transfer only the tokens necessary for mantaining the ratio (tokensToDeposit)
            cryptoDevToken.transferFrom(msg.sender, address(this), tokensToDeposit);
            // give the sender the LP tokens equivalent to the liquidity minted in this call
            liquidityMinted = (totalSupply() * msg.value) / ethReserve;
            _mint(msg.sender, liquidityMinted);
        }
        return liquidityMinted;
    }

    function removeLiquidity(uint256 _amount) public returns (uint, uint) {}

    function getReserve() public view returns (uint256) {
        return ERC20(cryptoDevTokenAddress).balanceOf(address(this));
    }
}
