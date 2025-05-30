// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./utils/Types.sol";
import "./utils/Constant.sol";
import "./utils/Errors.sol";
import {IPay} from "./interfaces/IPay.sol";
import {Haltable} from "./Haltable.sol";
import {IAccountFactory} from "../interfaces/IAccountFactory.sol";
import {TransferHelper} from "./TransferHelper.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IConfig} from "../interfaces/IConfig.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title Pay
/// @notice Contract for handling cheques and related operations
contract Pay is IPay, Haltable, Pausable, Ownable, ReentrancyGuard {
    using TransferHelper for address;
    IConfig public immutable config;
    IAccountFactory public immutable accountFactory;

    mapping(uint256 => Cheque) public cheques;
    mapping(address => bool) public override isWhitelistedToken;
    uint128 public maxExpirationTime;

    /**
     * @param _factory The address of the account factory contract
     * @param _config The address of the configuration contract
     * @param _initialOwner The address of the initial contract owner
     */
    constructor(
        address _factory,
        address _config,
        address _initialOwner
    ) Ownable(_initialOwner) {
        accountFactory = IAccountFactory(_factory);
        config = IConfig(_config);
        maxExpirationTime = 30 days;
    }

    /**
     * @dev Fallback function to reject direct ETH transfers
     */
    receive() external payable {
        revert Rejected();
    }

    modifier onlyAllowedAccount() {
        if (!accountFactory.isValidAccount(msg.sender))
            revert InvalidAccount(msg.sender);
        _;
    }

    modifier onlyWhitelistedToken(address token) {
        if (!isWhitelistedToken[token]) revert InvalidToken(token);
        _;
    }

    /**
     * @dev Returns the name of the transit contract
     * @return The contract name as a string
     */
    function name() external pure returns (string memory) {
        return PAY_NAME;
    }

    /**
     * @dev Returns the version of the transit contract
     * @return The contract version as a string
     */
    function version() external pure returns (string memory) {
        return PAY_VERSION;
    }

    /**
     * @dev Validates if an account is registered with the account factory
     * @param account The address to validate
     * @return True if the account is valid, false otherwise
     */
    function isValidAccount(address account) private view returns (bool) {
        return accountFactory.isValidAccount(account);
    }

    /**
     * @dev Sends a new cheque with specified parameters
     * @param params The parameters for creating the cheque
     */
    function send(
        ChequeParams calldata params
    )
        external
        payable
        onlyAllowedAccount
        onlyWhitelistedToken(params.tokenAddress)
        whenNotPaused
        whenNotHalted
        nonReentrant
    {
        if (params.amount == 0) revert AmountError();

        if (params.tokenAddress == NATIVE_ETH) {
            if (msg.value != params.amount)
                revert ETHAmountError(params.amount, msg.value);
        } else {
            if (msg.value != 0) revert ETHAmountError(0, msg.value);

            params.tokenAddress.tokenTransferFrom(
                msg.sender,
                address(this),
                params.amount
            );
        }
        // (uint128 cancelTime, uint128 refundTime) = decodeExpiration(
        //     params.expiration
        // );

        // uint128 maxDeadline = uint128(block.timestamp) + maxExpirationTime;
        // if (refundTime > maxDeadline || cancelTime > maxDeadline)
        //     revert ExpirationTimeNotValid(refundTime, cancelTime, maxDeadline);

        // if (cheques[params.chequeID].amount != 0)
        //     revert ChequeExists(params.chequeID);

        Cheque memory cheque = Cheque({
            from: msg.sender,
            to: params.to,
            tokenAddress: params.tokenAddress,
            amount: params.amount,
            expiration: params.expiration,
            status: ChequeStatus.Created
        });
        cheques[params.chequeID] = cheque;

        emit ChequeSent(
            params.chequeID,
            msg.sender,
            params.to,
            params.tokenAddress,
            params.amount,
            params.expiration
        );
    }

    /**
     * @dev Decodes the expiration time into cancel and refund times
     * @param expirationTime The encoded expiration time
     * @return cancelTime The time after which the cheque can be cancelled
     * @return refundTime The time after which the cheque can be refunded
     */
    function decodeExpiration(
        uint256 expirationTime
    ) private pure returns (uint128 cancelTime, uint128 refundTime) {
        cancelTime = uint128(expirationTime >> 128);
        refundTime = uint128(expirationTime);
    }

    /**
     * @dev Claims a cheque by the recipient
     * Requirements:
     * - msg.sender is allowed address
     * - cheque.status == ChequeStatus.Created
     * - cheque.deadline < block.timestamp
     * - cheque.to == msg.sender
     * @param chequeID The ID of the cheque to claim
     */
    function claim(
        uint256 chequeID
    ) external onlyAllowedAccount whenNotPaused nonReentrant {
        Cheque memory cheque = cheques[chequeID];
        if (cheque.to != msg.sender)
            revert ClaimAddressError(cheque.to, msg.sender);

        _claim(chequeID, cheque);
    }

    /**
     * @dev Claims a cheque by the signature
     * Requirements:
     * - msg.sender is allowed address
     * - cheque.status == ChequeStatus.Created
     * - cheque.deadline < block.timestamp
     * - cheque.to == address(0): sender address must be eligible
     */
    function sharelinkClaim(
        uint256 chequeID,
        bytes calldata signature
    ) external onlyAllowedAccount whenNotPaused nonReentrant {
        Cheque memory cheque = cheques[chequeID];
        /// It requires checking if the signer EOA address is a valid claimer
        if (cheque.to != address(0))
            revert ClaimAddressError(cheque.to, msg.sender);

        uint256 expirationTime = uint256(bytes32(signature[0:32]));
        if (expirationTime < block.timestamp) {
            revert Expired(expirationTime, block.timestamp);
        }

        bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
            keccak256(
                abi.encode(
                    block.chainid,
                    address(this),
                    chequeID,
                    msg.sender,
                    expirationTime
                )
            )
        );

        address signer = ECDSA.recover(msgHash, signature[32:]);

        if (!config.isPaySigner(signer)) revert NotAllowed();

        _claim(chequeID, cheque);
    }

    /// @dev claim cheque amount
    /// Requirements
    /// - cheque.status == ChequeStatus.Created
    /// - cheque.deadline < block.timestamp
    function _claim(uint256 chequeID, Cheque memory cheque) internal {
        if (cheque.status != ChequeStatus.Created)
            revert ChequeStatusError(chequeID, cheque.status);

        (, uint128 refundTime) = decodeExpiration(cheque.expiration);
        if (refundTime < block.timestamp)
            revert ChequeExpired(chequeID, refundTime, block.timestamp);

        cheque.tokenAddress.tokenTransfer(msg.sender, cheque.amount);

        cheques[chequeID].status = ChequeStatus.Claimed;

        emit ChequeEvent(
            chequeID,
            cheque.from,
            cheque.to,
            cheque.tokenAddress,
            cheque.amount,
            ChequeStatus.Claimed
        );
    }

    /**
     * @dev Cancels a cheque by the sender
     * @param chequeID The ID of the cheque to cancel
     */
    function cancel(uint256 chequeID) external onlyAllowedAccount nonReentrant {
        Cheque memory cheque = cheques[chequeID];
        if (cheque.status != ChequeStatus.Created)
            revert ChequeStatusError(chequeID, cheque.status);

        (uint128 cancelTime, ) = decodeExpiration(cheque.expiration);
        if (cancelTime > block.timestamp) revert CancleError();

        if (cheque.from != msg.sender) revert AccessError(chequeID, msg.sender);

        cheque.tokenAddress.tokenTransfer(msg.sender, cheque.amount);

        cheques[chequeID].status = ChequeStatus.Canceled;

        emit ChequeEvent(
            chequeID,
            msg.sender,
            cheque.to,
            cheque.tokenAddress,
            cheque.amount,
            ChequeStatus.Canceled
        );
    }

    /**
     * @dev Refunds a single cheque
     * @param chequeID The ID of the cheque to refund
     */
    function refund(uint256 chequeID) external nonReentrant {
        _refund(chequeID);
    }

    /**
     * @dev Refunds multiple cheques in a batch
     * @param chequeIDs Array of cheque IDs to refund
     */
    function batchRefund(uint256[] memory chequeIDs) external nonReentrant {
        uint256 count = chequeIDs.length;
        for (uint256 i; i < count; ) {
            _refund(chequeIDs[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Updates the maximum expiration time for cheques
     * @param expirationTime The new maximum expiration time in seconds
     */
    function changeMaxExpirationTime(
        uint128 expirationTime
    ) external onlyOwner {
        if (expirationTime == 0) revert InvalidAmount();
        emit ChangeMaxExpirationTime(maxExpirationTime, expirationTime);

        maxExpirationTime = expirationTime;
    }

    /**
     * @dev Internal function to process a cheque refund
     * @param chequeID The ID of the cheque to refund
     */
    function _refund(uint256 chequeID) internal {
        Cheque memory cheque = cheques[chequeID];
        if (cheque.status != ChequeStatus.Created)
            revert ChequeStatusError(chequeID, cheque.status);

        (, uint128 refundTime) = decodeExpiration(cheque.expiration);
        if (refundTime > block.timestamp && msg.sender != cheque.to)
            revert ChequeNotExpired(chequeID, refundTime, block.timestamp);

        cheque.tokenAddress.tokenTransfer(cheque.from, cheque.amount);

        cheques[chequeID].status = ChequeStatus.Refunded;

        emit ChequeEvent(
            chequeID,
            cheque.from,
            cheque.to,
            cheque.tokenAddress,
            cheque.amount,
            ChequeStatus.Refunded
        );
    }

    /**
     * @notice Adds multiple tokens to whitelist
     * @param tokens Array of token addresses to whitelist
     */
    function addWhitelistedTokens(address[] memory tokens) external onlyOwner {
        uint256 length = tokens.length;
        for (uint256 i = 0; i < length; ) {
            address token = tokens[i];
            isWhitelistedToken[token] = true;

            unchecked {
                ++i;
            }
        }

        emit WhitelistTokenAdded(tokens);
    }

    /**
     * @notice Removes multiple tokens from whitelist
     * @param tokens Array of token addresses to remove
     */
    function removeWhitelistedTokens(
        address[] memory tokens
    ) external onlyOwner {
        uint256 length = tokens.length;
        for (uint256 i = 0; i < length; ) {
            address token = tokens[i];
            delete isWhitelistedToken[token];

            unchecked {
                ++i;
            }
        }

        emit WhitelistTokenRemoved(tokens);
    }

    /// @notice halt project, preventing certain operations
    /// @dev Can only be called by the contract owner
    function halt() external virtual onlyOwner {
        _halt();
    }

    /// @notice unhalt project, resuming normal contract operations
    /// @dev Can only be called by the contract owner
    function unhalt() external virtual onlyOwner {
        _unhalt();
    }

    /**
     * @dev Pauses all contract operations
     */
    function pause() external virtual onlyOwner {
        _pause();
    }

    /**
     * @dev Resumes all contract operations
     */
    function unpause() external virtual onlyOwner {
        _unpause();
    }
}
