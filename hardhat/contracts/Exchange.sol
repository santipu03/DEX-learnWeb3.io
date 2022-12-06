// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {
    address public cryptoDevTokenAddress;

    constructor(address _CryptoDevToken) ERC20("CryptoDev LP Token", "CDLP") {
        require(_CryptoDevToken != address(0), "Token address passed is a null address");
        cryptoDevTokenAddress = _CryptoDevToken;
    }

    /**
     * @dev Adds liquidity to the exchange.
     */
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

    /**
     * @dev Returns the amount Eth/Crypto Dev tokens that would be returned to the user
     * in the swap
     */
    function removeLiquidity(uint _amount) public returns (uint, uint) {
        require(_amount > 0, "_amount should be greater than zero");

        uint ethReserve = address(this).balance;
        uint256 tokenReserve = getReserve();
        uint _totalSupply = totalSupply();

        uint ethAmount = (_amount * ethReserve) / _totalSupply;
        uint cryptoDevTokenAmount = (_amount * tokenReserve) / _totalSupply;

        // Burn the sent LP tokens from the user's wallet to remove them from totalSupply()
        _burn(msg.sender, _amount);
        // Transfer the ethAmount to user
        (bool sent, ) = payable(msg.sender).call{value: ethAmount}("");
        require(sent, "Failed to send ETH");
        // Transfer `cryptoDevTokenAmount` of Crypto Dev tokens to user
        ERC20(cryptoDevTokenAddress).transfer(msg.sender, cryptoDevTokenAmount);
        return (ethAmount, cryptoDevTokenAmount);
    }

    /**
     * @dev Returns the amount Eth/Crypto Dev tokens that would be returned to the user
     * in the swap
     */
    function getAmountOfTokens(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");
        // We are charging a fee of `1%`
        uint256 inputAmountWithFee = inputAmount * 99;
        // The formula is Δy = (y * Δx) / (x + Δx)
        // Δy in our case is `tokens to be received`
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 100) + inputAmountWithFee;
        return numerator / denominator;
    }

    /**
     * @dev Swaps Eth for CryptoDev Tokens
     */
    function ethToCryptoDevToken(uint _minTokens) public payable {
        uint256 tokenReserve = getReserve();
        uint256 ethReserve = address(this).balance - msg.value;
        uint256 tokensBought = getAmountOfTokens(msg.value, ethReserve, tokenReserve);
        require(tokensBought >= _minTokens, "insufficient output amount");
        // Transfer the `Crypto Dev` tokens to the user
        ERC20(cryptoDevTokenAddress).transfer(msg.sender, tokensBought);
    }

    /**
     * @dev Swaps CryptoDev Tokens for Eth
     */
    function cryptoDevTokenToEth(uint _tokensSold, uint _minEth) public {
        uint256 tokenReserve = getReserve();
        uint256 ethReserve = address(this).balance;
        uint256 ethBought = getAmountOfTokens(_tokensSold, tokenReserve, ethReserve);
        require(ethBought >= _minEth, "insufficient output amount");
        // Transfer `Crypto Dev` tokens from the user's address to the contract
        ERC20(cryptoDevTokenAddress).transferFrom(msg.sender, address(this), _tokensSold);
        // send the `ethBought` to the user from the contract
        (bool sent, ) = payable(msg.sender).call{value: ethBought}("");
        require(sent, "Transfer ETH failed");
    }

    /**
     * @dev Returns the amount of `Crypto Dev Tokens` held by the contract
     */
    function getReserve() public view returns (uint) {
        return ERC20(cryptoDevTokenAddress).balanceOf(address(this));
    }
}
