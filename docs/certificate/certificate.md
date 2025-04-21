# OpenEdu Certificate Implement Documentation

## Overview

Contracts: [SponsorNFT.sol](../../src/SponsorNFT.sol)

There is three ways to mint a certificate:

1. Admin mint to learner:
Simple call `mint` function with learner address.

2. Learner mint:
- Learner want to mint
- Admin sign signature for approve that mint
- Learner call `mintWithPermit` function with learner address.

3. Creator sponsor gas:
- Creator create sponsor address by API
- Admin store sponsor address (privateKey) with CourseId 
- Creator deposit to sponsor address
- Learner want to mint
- Owner approve with EIP712
- Owner use sponsor address for sign transaction

## Token URI

- OpenSea Metadata Standards: https://docs.opensea.io/docs/metadata-standards
- ERC721 Documentation: https://github.com/ethereum/ercs/blob/master/ERCS/erc-721.md

Example Token URI:
`[tokenId].json`
```json
{
    "name": "OpenEdu Certificate: Introduction to Blockchain",
    "description": "This certificate verifies successful completion of Introduction to Blockchain by Tuong Thai",
    "image": "[image url]",
    "external_url": "[course url]",
    "attributes": [
        {
            "trait_type": "Course Name",
            "value": "Introduction to Blockchain"
        },
        {
            "trait_type": "Student Name",
            "value": "Tuong Thai"
        },
        {
            "trait_type": "Student Address",
            "value": "0x123..."
        },
        {
            "trait_type": "Issuer",
            "value": "OpenEdu Academy"
        },
        {
            "trait_type": "Issue Date",
            "value": 1745196000,
            "display_type": "date"
        },
        {
            "trait_type": "Expiration Date",
            "value": 1902960000,
            "display_type": "date"
        },
        {
            "trait_type": "Course Duration",
            "value": "12 weeks"
        },
        {
            "trait_type": "Grade",
            "value": "A"
        },
        {
            "trait_type": "Score",
            "value": 95,
            "display_type": "number"
        },
        {
            "trait_type": "Skills",
            "value": "Solidity, Smart Contracts, DeFi"
        },
        {
            "trait_type": "Certificate ID",
            "value": "OEC-2025-[tokenId]"
        }
    ],
    "additional_data": {
        "achievements": [
            "Completed all assignments",
            "Top performer",
            "..."
        ],
        "instructor": {
            "name": "Dr. Satoshi",
            "profile": "https://vbiacademy.edu.vn/en/instructors/satoshi"
        }
    }
}
```

Token URI Must be a API with return an Json file. Example: https://api.openedu.net/certificate/[tokenId]

## Admin Sample Sign For Approve

```typescript
const crypto = require('crypto');

function generateNonce() {
  return '0x' + crypto.randomBytes(32).toString('hex');
}

...

const name = "OpenEdu Certificate";
const version = "1.0.0";
const chainId = (await this.provider.getNetwork()).chainId;
const verifyingContract = contracts.sponsorNft;

const domain = {
  name,
  version,
  chainId,
  verifyingContract
};

const types = {
  Approve: [
    { name: 'account', type: 'address' },
    { name: 'tokenId', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' }
  ]
};

const value = {
  account: alice.address,
  tokenId: tokenId,
  nonce: generateNonce(),
  deadline: 1745196000
};

const signature = await alice.signTypedData(domain, types, value);

const { r, s, v } = ethers.Signature.from(signature);

...
```