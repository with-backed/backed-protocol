pragma solidity 0.8.6;

library HexStrings {
    bytes16 internal constant ALPHABET = '0123456789abcdef';

    function partialHexString(uint160 value) internal pure returns (string memory) {
        uint8 length = 3;
        bytes memory buffer = new bytes(2 * length + 5);
        buffer[0] = '0';
        buffer[1] = 'x';
        uint8 offset = 2 * length + 1;
        // remove values not in partial length
        value >>= 4 * (40 - (length * 2));
        for (uint8 i = offset; i > 1; --i) {
            buffer[i] = ALPHABET[value & 0xf];
            value >>= 4;
        }
        require(value == 0, 'HexStrings: hex length insufficient');
        // uint8 offset 
        buffer[offset + 1] = '.';
        buffer[offset + 2] = '.';
        buffer[offset + 3] = '.';
        return string(buffer);
    }

    /// @notice Converts a `uint160` to its ASCII `string` hexadecimal representation with fixed length.
    /// @dev Credit to Open Zeppelin under MIT license 
    /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/243adff49ce1700e0ecb99fe522fb16cff1d1ddc/contracts/utils/Strings.sol#L55
    function toHexString(uint160 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = '0';
        buffer[1] = 'x';
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = ALPHABET[value & 0xf];
            value >>= 4;
        }
        require(value == 0, 'HexStrings: hex length insufficient');
        return string(buffer);
    }
}