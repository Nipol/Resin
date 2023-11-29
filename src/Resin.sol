//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title   Resin
 * @author  yoonsung.eth
 * @notice
 */
contract Resin {
    // 사용자의 포인트 정보를 저장하는 구조체
    // EVM은 256 비트 단위로 저장하므로, 한 번에 저장 및 로드를 할 수 있도록 160bit로 맞췄습니다.
    struct Point {
        // 최대 220 포인트
        uint16 balance;
        // 최대 1400 예비 포인트
        uint16 rBalance;
        // 마지막 접근 시간
        uint128 lastAccess;
    }

    // 최대 포인트 수량
    uint16 constant MAX_POINT = 220;

    // 최대 예비 포인트 수량
    uint16 constant MAX_RESERVE_POINT = 1_400;

    // 포인트 회복 시간
    uint128 constant RECOVERY_TIME = 8 minutes;

    // 예비 포인트 회복 시간
    uint128 constant RECOVERY_RESERVE_TIME = 15 minutes;

    // EIP712 Typing Structures
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 public constant POINT_TYPEHASH =
        keccak256("Point(address from,address user,uint16 amount,uint256 nonce,uint256 deadline)");

    bytes32 public immutable DOMAIN_SEPARATOR;

    // 당장 해당 컨트랙트를 배포한 사용자가 소유자가 됩니다.
    address immutable owner;

    // 사용자 주소에 연결된 포인트 정보
    mapping(address => Point) public users;

    // 사용자별 nonce 값
    mapping(address => uint) public nonces;

    constructor() {
        owner = msg.sender;
        // 해당 컨트랙트에 해당하는 고유 도메인 키를 생성합니다.
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes("Resin")), // 애플리케이션 이름
                keccak256(bytes("1")), // 버전
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @notice  해당 함수는 해당 컨트랙트의 소유자가 사용자의 포인트를 소각 시킬 수 있습니다.
     * @param   user    대상이 되는 사용자의 주소
     * @param   amount  소각할 포인트의 수량
     */
    function consumeFrom(address user, uint16 amount) external {
        if (msg.sender != owner) revert();

        // 사용자의 포인트 정보를 스토리지 영역에서 메모리 영역으로 복사합니다.
        Point memory u = users[user];

        // 현재 포인트 값을 가져옵니다.
        (uint16 balance, uint16 rBalance) = balanceOf(user);

        // 포인트를 사용합니다
        balance -= amount;

        // 마지막 기록을 업데이트 합니다.
        (u.balance, u.rBalance, u.lastAccess) = (balance, rBalance, uint128(block.timestamp));

        // 업데이트 된 최종 정보를 저장합니다.
        users[user] = u;
    }

    function permit(address from, address user, uint16 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        // 해당 서명 데이터가 사용되어야 하는 시간
        if (block.timestamp > deadline) revert();

        // 내가 허용한 주소가 호출한 것인지 아닌지
        if (msg.sender != from) revert();

        // 유저가 서명한 데이터 구성
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(POINT_TYPEHASH, from, user, amount, nonces[user]++, deadline))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != user) revert();

        // 포인트 차감, `consumeFrom` 함수는 앞서 external로 정의 되어 있었으므로 로직을 복사해옵니다.
        // 사용자의 포인트 정보를 스토리지 영역에서 메모리 영역으로 복사합니다.
        Point memory u = users[user];

        // 현재 포인트 값을 가져옵니다.
        (uint16 balance, uint16 rBalance) = balanceOf(user);

        // 포인트를 사용합니다
        balance -= amount;

        // 마지막 기록을 업데이트 합니다.
        (u.balance, u.rBalance, u.lastAccess) = (balance, rBalance, uint128(block.timestamp));

        // 업데이트 된 최종 정보를 저장합니다.
        users[user] = u;
    }

    /**
     * @notice  예비 포인트를 최대 포인트 220에 맞춰 충전합니다.
     */
    function recharge() external {
        // 사용자의 포인트 정보를 스토리지 영역에서 메모리 영역으로 복사합니다.
        Point memory u = users[msg.sender];

        // 현재 포인트 값을 가져옵니다.
        (uint16 balance, uint16 rBalance) = balanceOf(msg.sender);

        // 포인트가 220이면 실패
        if (balance == MAX_POINT) revert();

        // 최대 포인트를 채우기 위해 필요한 포인트 수량 계산
        uint16 req = MAX_POINT - balance;

        // 예비포인트가 필요 포인트 수량보다 많다면
        if (rBalance > req) {
            rBalance -= req;
            balance = MAX_POINT;
        } else {
            balance += rBalance;
            rBalance = 0;
        }

        // 마지막 기록을 업데이트 합니다.
        (u.balance, u.rBalance, u.lastAccess) = (balance, rBalance, uint128(block.timestamp));

        // 업데이트 된 최종 정보를 저장합니다.
        users[msg.sender] = u;
    }

    /**
     * @notice  해당 함수는 사용자의 현재 포인트와 예비 포인트를 반환합니다
     * @param   user        사용자의 주소
     * @return  balance     현재 포인트
     * @return  rBalance    현재 예비 포인트
     */
    function balanceOf(address user) public view returns (uint16 balance, uint16 rBalance) {
        // 사용자의 포인트 정보를 스토리지 영역에서 메모리 영역으로 복사합니다.
        Point memory u = users[user];

        // 해당 블록 안에서는 overflow 유무를 검사하지 않습니다
        unchecked {
            // 한 번도 시스템에서 사용된 주소가 아니라면 기본 포인트만 보여줍니다
            if (u.lastAccess == 0) return (MAX_POINT, 0);

            // 현재 시간에서 마지막 접근 시간을 빼서 지난 시간을 기록합니다
            uint128 timePassed = uint128(block.timestamp) - u.lastAccess;

            // 튜플을 이용하여 한번에 가져옵니다
            (balance, rBalance) = (u.balance, u.rBalance);

            // 필요한 포인트 수량을 계산합니다.
            uint16 reqP = MAX_POINT - balance;

            // 지난 시간을 기초 포인트로 환산합니다.
            uint16 termP = uint16(timePassed / RECOVERY_TIME);

            // 최종 포인트 수량 계산
            balance += reqP > termP ? termP : reqP;

            // 필요한 수량이 더 많은 경우
            // timePassed를 0으로
            // 기간동안의 포인트가 더 크다면, 필요 포인트만큼 곱해서 시간을 뺌
            timePassed -= reqP > termP ? timePassed : (uint128(reqP) * RECOVERY_TIME);

            if (timePassed >= RECOVERY_RESERVE_TIME) {
                rBalance += uint16(timePassed / RECOVERY_RESERVE_TIME);
                if (rBalance > MAX_RESERVE_POINT) rBalance = MAX_RESERVE_POINT;
            }
        }
    }
}
