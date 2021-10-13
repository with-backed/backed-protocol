pragma solidity 0.8.6;

import '../interfaces/ITicketTypeSpecificSVGHelper.sol';
import "@openzeppelin/contracts/utils/Strings.sol";

contract TicketTypeSpecificSVGHelper is ITicketTypeSpecificSVGHelper {
    function backgroundColorsStyles(string memory collateralAsset, string memory loanAsset) external pure override virtual returns (string memory) {}
    function typeSpecificDetails(string memory id) external pure override virtual returns (string memory) {}

    function colorStyles(string memory primary, string memory secondary) internal pure returns (string memory){
        return string(
            abi.encodePacked(
                '.highlight-hue{stop-color:',
                addressStringToHSL(primary),
                '}',
                '.highlight-offset{stop-color:',
                addressStringToHSL(secondary),
                '}',
                '.rotate {-moz-transform: translateX(-50%) translateY(-50%) rotate(-90deg); -webkit-transform: translateX(-50%) translateY(-50%) rotate(-90deg); transform: translateX(-50%) translateY(-50%) rotate(-90deg);}'
            )
        );
    }

    function addressStringToHSL(string memory account) private pure returns (string memory){
        bytes32 hs = keccak256(abi.encodePacked(account));
        uint256 h = (uint256(uint8(hs[0])) + uint8(hs[1])) % 360;
        uint256 s = 60 + (uint8(hs[2]) % 30);
        uint256 l = 60 + (uint8(hs[3]) % 30);
        return string(
            abi.encodePacked(
                'hsl(',
                Strings.toString(h),
                ',',
                Strings.toString(s),
                '%,',
                Strings.toString(l),
                '%)'
            )
        );
    }
}