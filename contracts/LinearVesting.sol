// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "hardhat/console.sol";

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

library SafeMath {
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

interface IERC20 {
    
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract LinearVesting is Ownable {
  using SafeMath for uint256;

  mapping (uint256 => uint256) private _starts;
  mapping (uint256 => uint256) private _redeemeds;
  mapping (uint256 => uint256) private _durations;
  mapping (uint256 => uint256) private _totalBalances;
  mapping (uint256 => address) private _benficiaries;
  mapping (uint256 => address) private _vestTokenAddrs;
  mapping (address => mapping (address => mapping (address => bool))) private isMinting;
  uint256 private curScheduleID = 0;

  function beneficiary(uint256 scheduleID) public view returns (address) {
    return _benficiaries[scheduleID];
  }

  function start(uint256 scheduleID) public view returns (uint256) {
    return _starts[scheduleID];
  }

  function duration(uint256 scheduleID) public view returns (uint256) {
    return _durations[scheduleID];
  }

  function redeemed(uint256 scheduleID) public view returns (uint256) {
    return _redeemeds[scheduleID];
  }

  function getCurScheduleID() public view returns (uint256) {
    return curScheduleID;
  }

  function getLastScheduleID() public view returns (uint256) {
    return curScheduleID == 0 ? 0 : curScheduleID - 1;
  }

  function redeem(uint256 scheduleID) public {
    uint256 unredeemed = _redeemableAmount(scheduleID);
    require(unredeemed > 0, "LinearVesting: no amount are due");
    _redeemeds[scheduleID] = _redeemeds[scheduleID].add(unredeemed);

    IERC20 token = IERC20(_vestTokenAddrs[scheduleID]);
    token.transfer(_benficiaries[scheduleID], unredeemed);
  }

  function _redeemableAmount(uint256 scheduleID) private view returns (uint256) {
    return _vestedAmount(scheduleID).sub(_redeemeds[scheduleID]);
  }

  function _vestedAmount(uint256 scheduleID) private view returns (uint256) {
    uint256 totalBalance = _totalBalances[scheduleID];

    if (block.timestamp >= _starts[scheduleID].add(_durations[scheduleID])) {
        return totalBalance;
    } else {
        return totalBalance.mul(block.timestamp.sub(_starts[scheduleID])).div(_durations[scheduleID]);
    }
  }

  function mint(address tokenAddr, address toAddr, uint256 time) public {
    require (tokenAddr != address(0), "LinearVesting: tokenAddress can't be zero.");
    require (toAddr != address(0), "LinearVesting: to address can't be zero.");
    require (time > 0, "LinearVesting: Vesting duration time must be bigger than zero.");
    IERC20 token = IERC20(tokenAddr);
    uint256 balance = token.balanceOf(_msgSender());
    console.log("isMinting is %s", isMinting[_msgSender()][toAddr][tokenAddr]);
    require (isMinting[_msgSender()][toAddr][tokenAddr] == false, "LinearVesting: Same transaction is running.");
    require (balance > 0, "LinearVesting: Vesting amount must be bigger than zero.");

    token.transferFrom(_msgSender(), address(this), balance);
    _totalBalances[curScheduleID] = balance;
    _starts[curScheduleID] = block.timestamp;
    _durations[curScheduleID] = time;
    _benficiaries[curScheduleID] = toAddr;
    _vestTokenAddrs[curScheduleID] = tokenAddr;
    curScheduleID ++;
    isMinting[_msgSender()][toAddr][tokenAddr] = true;
  } 

}
