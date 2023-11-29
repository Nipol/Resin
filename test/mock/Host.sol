//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../src/IResin.sol";

/**
 * @title   Host
 * @author  yoonsung.eth
 * @notice  해당 컨트랙트는 유저에게 NFT를 발행할 수 있는 권한을 줍니다.
 * @dev     1. NFT의 발행권한이 해당 컨트랙트에 있을것
 *          2. 레진 소모 권한이 해당 컨트랙트에 있을것
 */
contract Host {
    // 생성할 토큰 정보
    uint256 constant TOKEN_INFO = 19900124;
    // 소모할 레진 포인트 수량
    uint16 constant RESIN_CONSUME = 80;
    // 레진 컨트랙트 주소
    IResin re;
    // 해당 컨트랙트의 소유자 주소
    address immutable owner;

    // 이미 특정 주소가 NFT를 발행했는지 확인
    mapping(address => bool) public isMinted;

    constructor(address resin) {
        re = IResin(resin);
        owner = msg.sender;
    }

    function mint(bytes calldata signature) external {
        // 이 함수를 호출한 사용자가 이미 NFT를 발행했다면 호출 실패합니다.
        if (isMinted[msg.sender]) revert();

        // stored chainid
        uint256 chainId;

        // load chainid
        assembly {
            chainId := chainid()
        }

        // 컨트랙트 오너가 서명할 데이터 대상, hID = hash(토큰 아이디 + 함수 실행 주소 + 이 컨트랙트 주소 + 체인아이디)
        // 해당 ID는 충분히
        bytes32 hID = keccak256(abi.encode(TOKEN_INFO, msg.sender, address(this), chainId));

        // 서명 데이터를 v, r, s로 풀어서 메모리에 저장합니다.
        uint8 v;
        bytes32 r;
        bytes32 s;

        assembly {
            calldatacopy(mload(0x40), signature.offset, 0x20)
            calldatacopy(add(mload(0x40), 0x20), add(signature.offset, 0x20), 0x20)
            calldatacopy(add(mload(0x40), 0x5f), add(signature.offset, 0x40), 0x2)

            // check signature malleability
            if gt(mload(add(mload(0x40), 0x20)), 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
                mstore(0x0, 0x01)
                return(0x0, 0x20)
            }

            r := mload(mload(0x40))
            s := mload(add(mload(0x40), 0x20))
            v := mload(add(mload(0x40), 0x40))
        }

        // 서명 데이터로 복원된 공개키를 해당 컨트랙트의 소유자와 비교하여 틀리면 함수 실패
        if (ecrecover(hID, v, r, s) != owner) revert();

        // 포인트 소각
        re.consumeFrom(msg.sender, RESIN_CONSUME);

        // NFT 발행
        // n.mint(TOKEN_INFO, msg.sender);

        // NFT가 발행되었다는 기록
        isMinted[msg.sender] = true;
    }
}
