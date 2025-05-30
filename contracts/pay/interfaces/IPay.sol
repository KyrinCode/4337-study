// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import {ChequeStatus} from "../utils/Types.sol";

/**
 * Interface for Pay contract that handles cheque-based fund transfers
 */
interface IPay {
    /**
     * Parameters required to create a cheque
     * @param chequeID Unique identifier for the cheque
     * @param to Recipient address (address(0) or non-zero address)
     * @param tokenAddress Token contract address (e.g. USDC)
     * @param amount Amount of tokens to transfer
     * @param expiration Expiration timestamp (uint128 cancel / uint128 refund)
     */
    struct ChequeParams {
        uint256 chequeID;
        address to; // address(0) / ! address(0)
        address tokenAddress; // USDC
        uint256 amount;
        uint256 expiration; // uint128 cancel / uint128 refund
    }

    /**
     * Represents a cheque in the system
     * @param from Sender address
     * @param to Recipient address
     * @param tokenAddress Token contract address
     * @param amount Amount of tokens
     * @param expiration Expiration timestamp
     * @param status Current status of the cheque
     */
    struct Cheque {
        address from;
        address to;
        address tokenAddress;
        uint256 amount;
        uint256 expiration;
        ChequeStatus status;
    }

    /**
     * Emitted when a new cheque is sent.
     * chequeId 12bytes + from 20 bytes  = 32bytes key
     * @param chequeID Unique identifier of the cheque
     * @param from Sender address
     * @param to Recipient address
     * @param tokenAddress Token contract address
     * @param amount Amount of tokens
     * @param expiration Expiration timestamp
     */
    event ChequeSent(
        uint256 indexed chequeID,
        address indexed from,
        address indexed to,
        address tokenAddress,
        uint256 amount,
        uint256 expiration
    );

    /**
     * Emitted when a cheque's status changes
     * @param chequeID Unique identifier of the cheque
     * @param from Sender address
     * @param to Recipient address
     * @param tokenAddress Token contract address
     * @param amount Amount of tokens
     * @param status New status of the cheque
     */
    event ChequeEvent(
        uint256 indexed chequeID,
        address indexed from,
        address indexed to,
        address tokenAddress,
        uint256 amount,
        ChequeStatus status
    );

    /**
     * Emitted when maximum expiration time is changed
     * @param oldExpirationTime Previous maximum expiration time
     * @param newExpirationTime New maximum expiration time
     */
    event ChangeMaxExpirationTime(
        uint256 oldExpirationTime,
        uint256 newExpirationTime
    );

    /**
     * @notice Emitted when tokens are added to whitelist
     * @param tokens Array of token addresses added
     */
    event WhitelistTokenAdded(address[] tokens);

    /**
     * @notice Emitted when tokens are removed from whitelist
     * @param tokens Array of token addresses removed
     */
    event WhitelistTokenRemoved(address[] tokens);

    /**
     * Returns the name of the contract
     * @return Contract name
     */
    function name() external view returns (string memory);

    /**
     * Returns the version of the contract
     * @return Contract version
     */
    function version() external view returns (string memory);

    /**
     * @notice Check if token is whitelist.
     * @return ture if token is whitelist;
     */
    function isWhitelistedToken(address token) external returns (bool);

    /**
     * Sends funds to the transit contract and generates a cheque
     * @param params Parameters for creating the cheque
     */
    function send(ChequeParams memory params) external payable;

    /**
     * Claims funds from a cheque in the transit contract
     * @param chequeID ID of the cheque to claim
     */
    function claim(uint256 chequeID) external;

    /**
     * Cancels an existing cheque
     * @param chequeID ID of the cheque to cancel
     */
    function cancel(uint256 chequeID) external;

    /**
     * Refunds funds from an expired cheque
     * @param chequeID ID of the cheque to refund
     */
    function refund(uint256 chequeID) external;

    /**
     * Refunds multiple expired cheques in a single transaction
     * @param chequeIDs Array of cheque IDs to refund
     */
    function batchRefund(uint256[] memory chequeIDs) external;

    /**
     * @notice Adds multiple token to whitelist
     * @param tokens Array of token addresses to whitelist
     */
    function addWhitelistedTokens(address[] memory tokens) external;

    /**
     * @notice Removes multiple tokens from whitelist
     * @param tokens Array of token addresses to remove
     */
    function removeWhitelistedTokens(address[] memory tokens) external;
}
