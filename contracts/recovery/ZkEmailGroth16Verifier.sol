// SPDX-License-Identifier: GPL-3.0
/*
    Copyright 2021 0KIMS association.

    This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

    snarkJS is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    snarkJS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with snarkJS. If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.7.0 <0.9.0;

contract Groth16Verifier {
    // Scalar field size
    uint256 constant r =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax =
        20491192805390485299153009773594534940189261866228447918068658471970481763042;
    uint256 constant alphay =
        9383485363053290200918347156157836566562967994039712273449902621266178545958;
    uint256 constant betax1 =
        4252822878758300859123897981450591353533073413197771768651442665752259397132;
    uint256 constant betax2 =
        6375614351688725206403948262868962793625744043794305715222011528459656738731;
    uint256 constant betay1 =
        21847035105528745403288232691147584728191162732299865338377159692350059136679;
    uint256 constant betay2 =
        10505242626370262277552901082094356697409835680220590971873171140371331206856;
    uint256 constant gammax1 =
        11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 =
        10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 =
        4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 =
        8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 =
        13119437632057744464014709711176858877068215974709671701277711727526774539785;
    uint256 constant deltax2 =
        2712235010848813209022045172689398190725792038347809750632648645891722737549;
    uint256 constant deltay1 =
        7572350608991807111584789102651812102974128219382685574549265083526564855822;
    uint256 constant deltay2 =
        10941110255110445889511984352696971623646213857942199227344790219436069177941;

    uint256 constant IC0x =
        19477245108953844507574563390692961131823239884053906691297203727094436630533;
    uint256 constant IC0y =
        11023961398147602215630111146951766411489371181682818096509921939168821080729;

    uint256 constant IC1x =
        14931376108607846648718937076191446210336272926923193425695866371108675262173;
    uint256 constant IC1y =
        13761321583929035584516475110760583319062432817974989694016128251168174201240;

    uint256 constant IC2x =
        12131932022879682985474072545578521963815997947480339210669605252754210396051;
    uint256 constant IC2y =
        11940919770382015695050879135937614564340897767616666983407054872916365193504;

    uint256 constant IC3x =
        5126801464894281459702029389920327529268793288907332623960589300370098265535;
    uint256 constant IC3y =
        10223690687023042899249275532160056448669574580884131882467168698301908661661;

    uint256 constant IC4x =
        17408004213562760725473927914482267398260645482487926835727085415082078379641;
    uint256 constant IC4y =
        7301470307380762836243429547019852376183197926229467899293023318486601069067;

    uint256 constant IC5x =
        11472638234468268914167344324302931201731846451064322867635965680496791226726;
    uint256 constant IC5y =
        3145853258978601979348739533091751712562482583766464299994753623320468024980;

    uint256 constant IC6x =
        15669735029729306030552133407738926579989328074672824004378472978331256544781;
    uint256 constant IC6y =
        9941566678721966019445919855438574552663020956292953886758482830992929775077;

    uint256 constant IC7x =
        5312092972277425396961954863482312724310068408218134839471830122736871852045;
    uint256 constant IC7y =
        7601957008095706560700317304770816150337302550332624873525704969148533454677;

    uint256 constant IC8x =
        9462413155098898158129465246424400699753666487750838020725222430321562010210;
    uint256 constant IC8y =
        9099635878014200626869986733009341356966582092452747064299889920778307884927;

    uint256 constant IC9x =
        4693370166986330253929769041269625055970924773806368929386285316552070502660;
    uint256 constant IC9y =
        3266540005584514712673838766521778320639424247072634490709853472123939428303;

    uint256 constant IC10x =
        15651402892503522535822574625146289383988405098022336977998824448468751412905;
    uint256 constant IC10y =
        13173401696745669045406113149155977915886569423801339873908106381641566740730;

    uint256 constant IC11x =
        8086635842074821135646658107947120376969490027758631284779412508782231143807;
    uint256 constant IC11y =
        19490749838477101236409077850825938418498205525749906036192509002569772355712;

    uint256 constant IC12x =
        100067478489073975525877384293419670002952706847542837710141693374779505934;
    uint256 constant IC12y =
        2441650921928695787034260601974749209171721185300338678476788805686179763539;

    uint256 constant IC13x =
        21175435672613234919803791340561308865953552307265163502089193332787978512275;
    uint256 constant IC13y =
        10060096910185250739192201556274871334435096017349775480283659520816525068822;

    uint256 constant IC14x =
        10470538012789791681998127448866556480842619909039311990453353321979167417928;
    uint256 constant IC14y =
        10683376942983592936084227744693573131311281146620432681341922184872624353279;

    uint256 constant IC15x =
        17662854312064038016326354324330109465202214577777932181000030861083171173413;
    uint256 constant IC15y =
        3888908623427560306684413739947383058551442408477674926833829983076013338891;

    uint256 constant IC16x =
        2309154288161007476841780781980136194786728470713476997930818819647034108160;
    uint256 constant IC16y =
        20152178651512777253399704434009738274268747111692039102961973744720984578636;

    uint256 constant IC17x =
        6198846037695025636630058991871074047325795250543090225784502223792296243266;
    uint256 constant IC17y =
        7791941921926429450809458864714028710863500064508081056525978073033904181943;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[17] calldata _pubSignals
    ) public view returns (bool) {
        assembly {
            function checkField(v) {
                if iszero(lt(v, r)) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            // G1 function to multiply a G1 value(x,y) to value in an address
            function g1_mulAccC(pR, x, y, s) {
                let success
                let mIn := mload(0x40)
                mstore(mIn, x)
                mstore(add(mIn, 32), y)
                mstore(add(mIn, 64), s)

                success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            function checkPairing(pA, pB, pC, pubSignals, pMem) -> isOk {
                let _pPairing := add(pMem, pPairing)
                let _pVk := add(pMem, pVk)

                mstore(_pVk, IC0x)
                mstore(add(_pVk, 32), IC0y)

                // Compute the linear combination vk_x

                g1_mulAccC(_pVk, IC1x, IC1y, calldataload(add(pubSignals, 0)))

                g1_mulAccC(_pVk, IC2x, IC2y, calldataload(add(pubSignals, 32)))

                g1_mulAccC(_pVk, IC3x, IC3y, calldataload(add(pubSignals, 64)))

                g1_mulAccC(_pVk, IC4x, IC4y, calldataload(add(pubSignals, 96)))

                g1_mulAccC(_pVk, IC5x, IC5y, calldataload(add(pubSignals, 128)))

                g1_mulAccC(_pVk, IC6x, IC6y, calldataload(add(pubSignals, 160)))

                g1_mulAccC(_pVk, IC7x, IC7y, calldataload(add(pubSignals, 192)))

                g1_mulAccC(_pVk, IC8x, IC8y, calldataload(add(pubSignals, 224)))

                g1_mulAccC(_pVk, IC9x, IC9y, calldataload(add(pubSignals, 256)))

                g1_mulAccC(
                    _pVk,
                    IC10x,
                    IC10y,
                    calldataload(add(pubSignals, 288))
                )

                g1_mulAccC(
                    _pVk,
                    IC11x,
                    IC11y,
                    calldataload(add(pubSignals, 320))
                )

                g1_mulAccC(
                    _pVk,
                    IC12x,
                    IC12y,
                    calldataload(add(pubSignals, 352))
                )

                g1_mulAccC(
                    _pVk,
                    IC13x,
                    IC13y,
                    calldataload(add(pubSignals, 384))
                )

                g1_mulAccC(
                    _pVk,
                    IC14x,
                    IC14y,
                    calldataload(add(pubSignals, 416))
                )

                g1_mulAccC(
                    _pVk,
                    IC15x,
                    IC15y,
                    calldataload(add(pubSignals, 448))
                )

                g1_mulAccC(
                    _pVk,
                    IC16x,
                    IC16y,
                    calldataload(add(pubSignals, 480))
                )

                g1_mulAccC(
                    _pVk,
                    IC17x,
                    IC17y,
                    calldataload(add(pubSignals, 512))
                )

                // -A
                mstore(_pPairing, calldataload(pA))
                mstore(
                    add(_pPairing, 32),
                    mod(sub(q, calldataload(add(pA, 32))), q)
                )

                // B
                mstore(add(_pPairing, 64), calldataload(pB))
                mstore(add(_pPairing, 96), calldataload(add(pB, 32)))
                mstore(add(_pPairing, 128), calldataload(add(pB, 64)))
                mstore(add(_pPairing, 160), calldataload(add(pB, 96)))

                // alpha1
                mstore(add(_pPairing, 192), alphax)
                mstore(add(_pPairing, 224), alphay)

                // beta2
                mstore(add(_pPairing, 256), betax1)
                mstore(add(_pPairing, 288), betax2)
                mstore(add(_pPairing, 320), betay1)
                mstore(add(_pPairing, 352), betay2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))

                // gamma2
                mstore(add(_pPairing, 448), gammax1)
                mstore(add(_pPairing, 480), gammax2)
                mstore(add(_pPairing, 512), gammay1)
                mstore(add(_pPairing, 544), gammay2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), deltax1)
                mstore(add(_pPairing, 672), deltax2)
                mstore(add(_pPairing, 704), deltay1)
                mstore(add(_pPairing, 736), deltay2)

                let success := staticcall(
                    sub(gas(), 2000),
                    8,
                    _pPairing,
                    768,
                    _pPairing,
                    0x20
                )

                isOk := and(success, mload(_pPairing))
            }

            let pMem := mload(0x40)
            mstore(0x40, add(pMem, pLastMem))

            // Validate that all evaluations ∈ F

            checkField(calldataload(add(_pubSignals, 0)))

            checkField(calldataload(add(_pubSignals, 32)))

            checkField(calldataload(add(_pubSignals, 64)))

            checkField(calldataload(add(_pubSignals, 96)))

            checkField(calldataload(add(_pubSignals, 128)))

            checkField(calldataload(add(_pubSignals, 160)))

            checkField(calldataload(add(_pubSignals, 192)))

            checkField(calldataload(add(_pubSignals, 224)))

            checkField(calldataload(add(_pubSignals, 256)))

            checkField(calldataload(add(_pubSignals, 288)))

            checkField(calldataload(add(_pubSignals, 320)))

            checkField(calldataload(add(_pubSignals, 352)))

            checkField(calldataload(add(_pubSignals, 384)))

            checkField(calldataload(add(_pubSignals, 416)))

            checkField(calldataload(add(_pubSignals, 448)))

            checkField(calldataload(add(_pubSignals, 480)))

            checkField(calldataload(add(_pubSignals, 512)))

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
