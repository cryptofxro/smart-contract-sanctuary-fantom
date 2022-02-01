// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./IReservesInteractor.sol";
import "./ReservesInteractorBase.sol";

contract ReservesInteractor is ReservesInteractorBase, IReservesInteractor {

    /**
     * Reduces all reserves for all markets of the given lending network.
     * @param len The unitroller address
     */
    function reduceAllReserves(address len) override external {
        address[] memory markets = IComptrollerForReservesInteractor(len).getAllMarkets();
        uint length = markets.length;

        for (uint i; i < length; i++) {
            reduceMarketReservesInternal(markets[i]);
        }
    }

    /**
     * Reduces all reserves for all markets of the given lending network.
     * @param market The unitroller address
     */
    function reduceReserves(address market) external override returns (uint reservesReduced) {
        reservesReduced = reduceMarketReservesInternal(market);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

interface IReservesInteractor {
    function reduceAllReserves(address len) external;
    function reduceReserves(address market) external returns (uint reduceReserves);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./IReservesInteractor.sol";

interface IMarketForReservesInteractor {
    function totalReserves() external returns (uint);
    function underlying() external returns (address);

    /**
     * Returns error code
     */
    function accrueInterest() external returns (uint);

    /**
     * Returns error code
     */
    function _reduceReserves(uint reduceAmount) external returns (uint);
}

interface IComptrollerForReservesInteractor {
    function getAllMarkets() external view returns (address[] memory);
}

contract ReservesInteractorBase {

    /**
     * Reduces all reserves for the given market.
     * @param market The market address
     */
    function reduceMarketReservesInternal(address market) internal returns (uint reservesReduced) {
          uint accrueInterestErr = IMarketForReservesInteractor(market).accrueInterest();
          require(accrueInterestErr == 0, "Accrue interest error");

        uint currentReserves = IMarketForReservesInteractor(market).totalReserves();
        reservesReduced = currentReserves;

        if (reservesReduced == 0) {
            return 0;
        } else {
            uint reduceReservesErr = IMarketForReservesInteractor(market)._reduceReserves(reservesReduced);
            require(reduceReservesErr == 0, "Reduce reserves error");
        }
    }
}