// SPDX-License-Identifier: MIT
// Watermark: Frenki - Initial Creator of This Clone Code

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// If using Solidity < 0.8.0, uncomment and import SafeMath
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Interface for PancakeSwap Router (V2)
interface IPancakeSwapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address); // Should be WBNB on BSC

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

     function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

// Interface for PancakeSwap Factory (V2)
interface IPancakeSwapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

/**
 * @title ExampleToken
 * @dev BEP20 token similar to BabyDoge with Reflection, Auto LP, and Fee features.
 * Watermark: Frenki
 */
contract ExampleToken is Context, IERC20, Ownable {
    // If using Solidity < 0.8.0, uncomment this line
    // using SafeMath for uint256;

    // --- State Variables ---

    // Token Properties
    string private _name = "Example Token"; // CHANGE TOKEN NAME HERE
    string private _symbol = "EXAMPLE";     // CHANGE TOKEN SYMBOL HERE
    uint8 private _decimals = 9;            // Standard BabyDoge = 9

    // Balances & Allowances (Standard ERC20 + Reflection)
    mapping(address => uint256) private _rOwned; // Reflected balance
    mapping(address => uint256) private _tOwned; // True balance (will differ due to reflection)
    mapping(address => mapping(address => uint256)) private _allowances;

    // Exclusions
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcludedFromReward;
    address[] private _excludedFromReward; // Array for efficient iteration (though less gas-efficient for checking)

    // Supply
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal; // Actual total supply
    uint256 private _rTotal; // Reflected total supply (used for reward calculation)
    uint256 private _tFeeTotal;

    // Fees (Similar to BabyDoge: total 10% -> 5% Reflection, 5% LP)
    // You can modify this if you want a separate fee for marketing/charity wallets
    uint256 public _taxFee = 5;          // Fee for reflection to holders
    uint256 public _liquidityFee = 5;    // Fee for auto-LP
    uint256 private _previousTaxFee = _taxFee;
    uint256 private _previousLiquidityFee = _liquidityFee;

    // PancakeSwap & Liquidity
    IPancakeSwapV2Router02 public immutable pancakeswapV2Router;
    address public immutable pancakeswapV2Pair;
    bool private inSwapAndLiquify; // Flag to prevent re-entrancy
    bool public swapAndLiquifyEnabled = true;
    uint256 public numTokensSellToAddToLiquidity = 500000 * (10**uint256(_decimals)); // Minimum number of tokens in the contract to trigger swap & liquify (adjust!)

    // Events
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived, // Should be BNB on BSC
        uint256 tokensIntoLiquidity
    );
    event FeesChanged(uint256 newTaxFee, uint256 newLiquidityFee);


    // Modifier to prevent re-entrancy during swap & liquify
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    // --- Constructor ---
    // Watermark: Frenki - Initial Constructor
    constructor (address routerAddress) {
        // Change Initial Total Supply As Desired (Example: 1 Quadrillion)
        _tTotal = 1000000000 * (10**6) * (10**uint256(_decimals)); // 1,000,000,000,000,000
        _rTotal = (MAX - (MAX % _tTotal));

        // Initialize PancakeSwap Router (Use V2 Router Address for BSC Mainnet/Testnet)
        // BSC Mainnet Router V2: 0x10ED43C718714eb63d5aA57B78B54704E256024E
        // BSC Testnet Router V2: 0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        // Make sure this address is CORRECT!
        pancakeswapV2Router = IPancakeSwapV2Router02(routerAddress);

        // Create Pair in PancakeSwap Factory
        address factoryAddress = pancakeswapV2Router.factory();
        pancakeswapV2Pair = IPancakeSwapV2Factory(factoryAddress).createPair(address(this), pancakeswapV2Router.WETH()); // WETH() in interface, but should be WBNB on BSC

        // Give initial supply to the deployer (owner)
        _rOwned[_msgSender()] = _rTotal;
        _tOwned[_msgSender()] = _tTotal; // Assign true balance as well

        // Exclude owner and contract address from fee by default
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        // Exclude owner, contract, and pair address from reward by default
        _isExcludedFromReward[owner()] = true;
        _excludedFromReward.push(owner());
        _isExcludedFromReward[address(this)] = true;
         _excludedFromReward.push(address(this));
        _isExcludedFromReward[pancakeswapV2Pair] = true;
        _excludedFromReward.push(pancakeswapV2Pair);


        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    // --- BEP20 Standard Functions ---

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    // Customized balanceOf function for Reflection
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcludedFromReward[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        // Decrease allowance after transfer
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked { // Solidity ^0.8.0
             _approve(sender, _msgSender(), currentAllowance - amount);
        }
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
         unchecked { // Solidity ^0.8.0
             _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    // --- Reflection & Fee Logic ---
    // Watermark: Frenki - Core Reflection and Fee Logic

    // Calculates the actual token value from the reflected value
    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate = _getRate();
        // Solidity ^0.8.0 handles division by zero if _rTotal is 0 (though unlikely after constructor)
        if (currentRate == 0) return 0;
        return rAmount / currentRate;
    }

    // Calculates the current reflection rate
    function _getRate() internal view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        // Avoid division by zero if tSupply is 0 (should not happen after mint)
        if (tSupply == 0) return _rTotal; // Or another reasonable default
        return rSupply / tSupply;
    }

    // Gets the current reflected and actual supply (after excluding rewards)
    function _getCurrentSupply() internal view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excludedFromReward.length; i++) {
            address excludedAddr = _excludedFromReward[i];
            if (_rOwned[excludedAddr] > rSupply || _tOwned[excludedAddr] > tSupply) {
                 // If inconsistency occurs (shouldn't happen), return total values
                 return (_rTotal, _tTotal);
            }
            // Safe subtraction is inherent in Solidity ^0.8.0 unless unchecked{} is used
            rSupply = rSupply - _rOwned[excludedAddr];
            tSupply = tSupply - _tOwned[excludedAddr];
        }
        // Avoid cases where rSupply or tSupply becomes zero if all tokens are held by excluded addresses
        // If tSupply becomes 0, the rate calculation in _getRate handles it.
        if (rSupply == 0 || tSupply == 0) return (_rTotal, _tTotal); // Return original totals to prevent division by zero issues downstream
        return (rSupply, tSupply);
    }

    // Core transfer function handling fees, reflection, and swap/liquify
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // If either party is excluded from fee, perform a standard transfer
        if (_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]) {
            _tokenTransfer(sender, recipient, amount, false); // false = don't takeFee
            return;
        }

        // Swap & Liquify Logic
        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinimumTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;

        if (
            overMinimumTokenBalance &&
            !inSwapAndLiquify && // Don't trigger if already in swap process
            sender != pancakeswapV2Pair && // Don't trigger on buy transactions from the pair
            swapAndLiquifyEnabled
        ) {
            // Limit the number of tokens swapped to prevent it being too large (e.g., according to numTokensSellToAddToLiquidity)
            uint256 tokenAmountToSwap = numTokensSellToAddToLiquidity;
            if(contractTokenBalance < tokenAmountToSwap) { // Just in case balance changed
                 tokenAmountToSwap = contractTokenBalance;
            }
            swapAndLiquify(tokenAmountToSwap);
        }

        // Perform transfer with fee
        _tokenTransfer(sender, recipient, amount, true); // true = takeFee
    }

    // Actual internal token transfer function
    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
         // If no fee, perform a regular transfer
        if (!takeFee) {
            removeAllFee();
        }

        // Check if sender/recipient is excluded from reward
        bool senderExcluded = _isExcludedFromReward[sender];
        bool recipientExcluded = _isExcludedFromReward[recipient];

        // Get balances before transfer based on exclusion status
        uint256 senderBalance = senderExcluded ? _tOwned[sender] : _rOwned[sender];
        require(senderBalance >= (senderExcluded ? amount : amount * _getRate()), "Transfer amount exceeds balance");


        if (senderExcluded && recipientExcluded) {
            // Transfer between 2 excluded accounts (true balance)
             _tOwned[sender] = _tOwned[sender] - amount; // Unchecked due to prior balance check
            _tOwned[recipient] = _tOwned[recipient] + amount;
            emit Transfer(sender, recipient, amount);
        } else if (senderExcluded && !recipientExcluded) {
            // Transfer from excluded to non-excluded
            _tOwned[sender] = _tOwned[sender] - amount; // Unchecked due to prior balance check
            (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(amount);
            _rOwned[recipient] = _rOwned[recipient] + rTransferAmount; // Add to recipient's reflected balance
            _takeLiquidity(tLiquidity); // Take liquidity fee
            _reflectFee(rFee, tFee);    // Process reflection fee
            emit Transfer(sender, recipient, tTransferAmount);
        } else if (!senderExcluded && recipientExcluded) {
             // Transfer from non-excluded to excluded
            (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(amount);
            _rOwned[sender] = _rOwned[sender] - rAmount; // Decrease sender's reflected balance (Unchecked due to prior balance check)
            _tOwned[recipient] = _tOwned[recipient] + tTransferAmount; // Add to excluded recipient's true balance
            _takeLiquidity(tLiquidity);
            _reflectFee(rFee, tFee);
            emit Transfer(sender, recipient, tTransferAmount);
        } else {
             // Transfer between 2 non-excluded accounts
            (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(amount);
            _rOwned[sender] = _rOwned[sender] - rAmount; // Decrease sender's reflected balance (Unchecked due to prior balance check)
            _rOwned[recipient] = _rOwned[recipient] + rTransferAmount; // Add to recipient's reflected balance
             _takeLiquidity(tLiquidity);
             _reflectFee(rFee, tFee);
             emit Transfer(sender, recipient, tTransferAmount);
        }

         // Restore fees if they were previously zeroed out
        if (!takeFee) {
            restoreAllFee();
        }
    }


    // Calculates the fee amounts and transfer amount based on the total amount
    // Watermark: Frenki - Fee Calculation
    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tFee, uint256 tLiquidity) = _calculateFees(tAmount);
        // Solidity ^0.8.0 handles underflow check
        uint256 tTransferAmount = tAmount - tFee - tLiquidity;

        uint256 currentRate = _getRate();
        // Handle potential multiplication overflow if rate is extremely high (unlikely but safe)
        uint256 rAmount = 0;
        uint256 rFee = 0;
        uint256 rLiquidity = 0;
        uint256 rTransferAmount = 0;

        if (currentRate > 0) { // Prevent division by zero or multiplication issues if rate is 0
            rAmount = tAmount * currentRate;
            rFee = tFee * currentRate;
            rLiquidity = tLiquidity * currentRate; // Reflected liquidity fee (sent to the contract)
             // Solidity ^0.8.0 handles underflow check
            rTransferAmount = rAmount - rFee - rLiquidity;
        } else {
            // If rate is 0 (e.g., tSupply is 0), handle reflected values appropriately
             // This case should ideally not happen in a live contract with supply
             tTransferAmount = tAmount; // No fees possible if rate is 0
        }


        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity);
    }

    // Calculates the tax (reflection) fee and liquidity fee
    function _calculateFees(uint256 amount) private view returns (uint256 taxFee, uint256 liquidityFee) {
        // Ensure total fee does not exceed 100%
        // This check might be better placed in setFees function to prevent setting invalid fees
        // require(_taxFee + _liquidityFee <= 100, "Total fee cannot exceed 100%");

        taxFee = (amount * _taxFee) / 100;
        liquidityFee = (amount * _liquidityFee) / 100;
        return (taxFee, liquidityFee);
    }

    // Processes reflection fee: increases total fee and decreases reflected supply
    function _reflectFee(uint256 rFee, uint256 tFee) private {
        // Decrease reflected supply (effectively rewarding holders)
        // Safe subtraction inherent in Solidity ^0.8.0
        if (_rTotal >= rFee) {
            _rTotal = _rTotal - rFee;
        } else {
            _rTotal = 0; // Prevent underflow in unlikely edge cases
        }
        _tFeeTotal = _tFeeTotal + tFee; // Accumulate total fee (for tracking if needed)
    }

     // Sends the liquidity fee to this contract (in reflected form)
    function _takeLiquidity(uint256 tLiquidity) private {
         if (tLiquidity == 0) return; // No liquidity fee
         uint256 currentRate = _getRate();
         if (currentRate == 0) return; // Cannot calculate reflected amount if rate is 0

         uint256 rLiquidity = tLiquidity * currentRate;

         // Send reflected liquidity fee to this contract
         // This contract must be excluded from reward so its _rOwned doesn't increase automatically
         // and its _tOwned can be tracked manually during swapAndLiquify
         if (!_isExcludedFromReward[address(this)]) {
             // If not already excluded (should be in constructor), exclude now
             // This is important so the contract balance isn't affected by reflection
             _excludeFromReward(address(this)); // Uses internal function
         }
         _rOwned[address(this)] = _rOwned[address(this)] + rLiquidity;
         // Update tOwned balance manually because it's excluded from reward
         _tOwned[address(this)] = _tOwned[address(this)] + tLiquidity;
    }

    // Temporarily removes all fees (for fee-less transfers)
    function removeAllFee() private {
        if(_taxFee == 0 && _liquidityFee == 0) return; // Not needed if already 0
        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _taxFee = 0;
        _liquidityFee = 0;
    }

    // Restores fees to their previous values
    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
    }

    // Internal approve function
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

     // --- Swap and Liquify Logic ---
    // Watermark: Frenki - Auto LP Logic

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // Split half of the contract balance to swap for BNB
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half; // Solidity ^0.8.0 safe subtraction

        // Capture the contract's current BNB balance before the swap
        uint256 initialBNBBalance = address(this).balance;

        // Swap 'half' amount of tokens to BNB
        // Function name is WETH on router but it's for BNB on BSC
        _swapTokensForBNB(half);

        // How much BNB did we just receive?
        // Solidity ^0.8.0 safe subtraction
        uint256 newBNBBalance = address(this).balance - initialBNBBalance;

        // Add liquidity to PancakeSwap
        if (otherHalf > 0 && newBNBBalance > 0) {
             _addLiquidity(otherHalf, newBNBBalance);
              emit SwapAndLiquify(half, newBNBBalance, otherHalf);
        } else {
            // Handle edge case where swap might fail or yield 0 BNB,
            // or if otherHalf is 0 (shouldn't happen if contractTokenBalance > 0)
            // Consider emitting an event or logging this scenario
        }

    }

    // Swap tokens to BNB (via WBNB pair)
    function _swapTokensForBNB(uint256 tokenAmount) private {
        if (tokenAmount == 0) return; // Nothing to swap
        // Generate the pancakeswap pair path of token -> WBNB
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeswapV2Router.WETH(); // WETH() is used for WBNB on BSC Router V2

        try pancakeswapV2Router.approve(address(pancakeswapV2Router), type(uint256).max) {
             // some routers require approving max, others don't. This is safer.
             // Fallback to specific amount if max fails (though unlikely)
        } catch {
              _approve(address(this), address(pancakeswapV2Router), tokenAmount);
        }

        // Make the swap
        try pancakeswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB (you might want to add slippage control here)
            path,
            address(this), // Send BNB to this contract
            block.timestamp
        ) {
             // Reset approval to 0 after swap attempt
             try pancakeswapV2Router.approve(address(pancakeswapV2Router), 0) {} catch {} // Best effort reset
        } catch Error(string memory reason) {
             // Handle potential swap failure (e.g., emit event, log reason)
              try pancakeswapV2Router.approve(address(pancakeswapV2Router), 0) {} catch {} // Best effort reset
              revert(reason);
        } catch (bytes memory /*lowLevelData*/) {
            // Handle other potential low-level failures
             try pancakeswapV2Router.approve(address(pancakeswapV2Router), 0) {} catch {} // Best effort reset
             revert("Swap failed");
        }


    }

    // Add liquidity to PancakeSwap
    function _addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
         if (tokenAmount == 0 || bnbAmount == 0) return; // Cannot add zero liquidity

         // Approve router to spend tokens
         try pancakeswapV2Router.approve(address(pancakeswapV2Router), type(uint256).max) {
         } catch {
              _approve(address(this), address(pancakeswapV2Router), tokenAmount);
         }

        // Add the liquidity
        try pancakeswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable for minimums, set desired if needed
            0, // slippage is unavoidable for minimums, set desired if needed
            owner(), // LP tokens sent to the owner (deployer) - IMPORTANT: consider sending to a dead address or locking them
            block.timestamp
        ){
             // Reset approval to 0 after adding liquidity attempt
             try pancakeswapV2Router.approve(address(pancakeswapV2Router), 0) {} catch {} // Best effort reset
        } catch Error(string memory reason) {
            // Handle potential add liquidity failure
             try pancakeswapV2Router.approve(address(pancakeswapV2Router), 0) {} catch {} // Best effort reset
             revert(reason);
        } catch (bytes memory /*lowLevelData*/) {
            // Handle other potential low-level failures
             try pancakeswapV2Router.approve(address(pancakeswapV2Router), 0) {} catch {} // Best effort reset
            revert("Add liquidity failed");
        }
    }

     // Fallback function to receive BNB from router when swapping
    receive() external payable {}

    // --- Owner Functions ---
    // Watermark: Frenki - Owner Specific Functions

    // Exclude account from receiving rewards (reflection)
    function excludeFromReward(address account) public onlyOwner {
        require(account != address(0), "Cannot exclude zero address");
        require(account != pancakeswapV2Pair, "Cannot exclude PancakeSwap Pair from rewards (breaks LP)"); // Usually pair should be excluded by default
        require(!_isExcludedFromReward[account], "Account is already excluded");

        // Important: when excluding, transfer _tOwned from _rOwned for accurate balance
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcludedFromReward[account] = true;
        _excludedFromReward.push(account); // Add to array
         // _rTotal and _tTotal update implicitly via _getCurrentSupply calls
    }

     // Internal function to handle exclusion logic used in constructor and public function
    function _excludeFromReward(address account) internal {
        if(_isExcludedFromReward[account]) return; // Already excluded

        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcludedFromReward[account] = true;
        _excludedFromReward.push(account);
    }

    // Include account back into rewards (reflection)
    function includeInReward(address account) external onlyOwner {
        require(_isExcludedFromReward[account], "Account is not excluded");
        // Remove from _excludedFromReward array (this can be gas-expensive)
        bool found = false;
        for (uint256 i = 0; i < _excludedFromReward.length; i++) {
            if (_excludedFromReward[i] == account) {
                _excludedFromReward[i] = _excludedFromReward[_excludedFromReward.length - 1];
                _excludedFromReward.pop();
                found = true;
                break;
            }
        }
        require(found, "Account not found in excluded list for removal"); // Should not happen if require above passed

         // Convert _tOwned back to _rOwned
         uint256 currentRate = _getRate();
         if (currentRate > 0) {
             _rOwned[account] = _tOwned[account] * currentRate;
         } else {
              _rOwned[account] = 0; // Or handle appropriately if rate is 0
         }
        _tOwned[account] = 0; // Reset tOwned as it's now calculated from rOwned
        _isExcludedFromReward[account] = false;
         // _rTotal and _tTotal update implicitly via _getCurrentSupply calls
    }

    // Exclude account from paying transaction fees
    function excludeFromFee(address account) public onlyOwner {
        require(account != address(0), "Cannot exclude zero address");
        require(!_isExcludedFromFee[account], "Account is already excluded from fee");
        _isExcludedFromFee[account] = true;
    }

    // Include account back into paying transaction fees
    function includeInFee(address account) public onlyOwner {
        require(_isExcludedFromFee[account], "Account is not excluded from fee");
        _isExcludedFromFee[account] = false;
    }

    // Set new transaction fee percentages
    function setFees(uint256 newTaxFee, uint256 newLiquidityFee) external onlyOwner {
        // Set a reasonable upper limit for total fees
        require(newTaxFee + newLiquidityFee <= 25, "Total fee cannot exceed 25%"); // Safety limit
        _taxFee = newTaxFee;
        _liquidityFee = newLiquidityFee;
        emit FeesChanged(newTaxFee, newLiquidityFee);
    }

    // Enable/disable the swapAndLiquify mechanism
    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

     // Update the minimum number of tokens required to trigger swapAndLiquify
    function setNumTokensSellToAddToLiquidity(uint256 _numTokensNoDecimals) public onlyOwner {
         require(_numTokensNoDecimals > 0, "Threshold must be greater than 0");
         // Convert to the amount including decimals
         numTokensSellToAddToLiquidity = _numTokensNoDecimals * (10**uint256(_decimals));
    }

     // --- Utility Functions ---

     // Check if an address is excluded from reward
     function isExcludedFromReward(address account) public view returns (bool) {
         return _isExcludedFromReward[account];
     }

      // Check if an address is excluded from fee
     function isExcludedFromFee(address account) public view returns (bool) {
         return _isExcludedFromFee[account];
     }

     // Returns the total reflection fees collected (if tracking is needed)
     function totalFees() public view returns (uint256) {
         return _tFeeTotal;
     }

     // Function to retrieve other BEP20 tokens potentially sent to this contract (rescue)
    function rescueToken(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(this), "Cannot rescue self token");
        require(IERC20(tokenAddress).transfer(owner(), amount), "Token rescue transfer failed");
    }

    // Function to retrieve BNB that might have been sent directly (rescue)
    function rescueBNB(uint256 amount) external onlyOwner {
         require(address(this).balance >= amount, "Insufficient BNB balance for rescue");
         payable(owner()).transfer(amount);
    }
}

// --- OpenZeppelin Contracts (Minimal Include) ---
// You need to install @openzeppelin/contracts: npm install @openzeppelin/contracts
// Or import via URL in Remix: e.g., import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC20/IERC20.sol";

// File: @openzeppelin/contracts/utils/Context.sol
// Provides context information, primarily the message sender (_msgSender)
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol
// Provides basic access control mechanism where there is an owner account
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() {
        _transferOwnership(_msgSender());
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol
// Interface of the ERC20 standard as defined in the EIP.
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
