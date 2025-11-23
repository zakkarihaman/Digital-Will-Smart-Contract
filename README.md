# 📜 Digital Will Smart Contract

A comprehensive smart contract solution for creating and managing digital wills on the Stacks blockchain. This contract enables secure inheritance management with automated execution and multi-beneficiary support.

## ✨ Features

- 🏗️ **Will Creation**: Create digital wills with customizable heartbeat periods
- 👥 **Multi-Beneficiary Support**: Add multiple beneficiaries with percentage-based allocations
- 💰 **Asset Management**: Deposit STX tokens into wills for distribution
- ❤️ **Heartbeat System**: Regular check-ins to prove testator is alive
- 🚨 **Emergency Contacts**: Trusted contacts who can execute wills in emergencies
- 🔒 **Will Locking**: Lock wills to prevent modifications
- ⚡ **Automated Execution**: Automatic execution when heartbeat period expires
- 💸 **Inheritance Claims**: Beneficiaries can claim their allocated inheritance

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) installed
- [Stacks wallet](https://wallet.hiro.so/) for testing

### Installation
```bash
git clone https://github.com/zakkarihaman/Digital-Will-Smart-Contract
cd Digital-Will-Smart-Contract
clarinet check
```

## 📋 Usage

### Creating a Will
```clarity
(contract-call? .digital-will-smart-contract create-will u144 "My Digital Will")
```
- `heartbeat-period`: Blocks between required heartbeats (u144 ≈ 24 hours)
- `metadata`: Description of the will

### Adding Beneficiaries
```clarity
(contract-call? .digital-will-smart-contract add-beneficiary u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u50 "stx" "Primary beneficiary")
```
- `will-id`: ID of the will
- `beneficiary`: Principal address of beneficiary
- `allocation-percentage`: Percentage of inheritance (1-100)
- `asset-type`: Type of asset being inherited
- `conditions`: Special conditions for inheritance

### Depositing Assets
```clarity
(contract-call? .digital-will-smart-contract deposit-to-will u1 u1000000)
```
- Deposits 1 STX (1000000 micro-STX) into will ID 1

### Sending Heartbeat
```clarity
(contract-call? .digital-will-smart-contract heartbeat u1)
```
- Proves testator is alive and resets the countdown

### Emergency Contacts
```clarity
(contract-call? .digital-will-smart-contract add-emergency-contact u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```
- Adds a trusted contact who can execute the will in emergencies

### Executing a Will
```clarity
(contract-call? .digital-will-smart-contract execute-will u1)
```
- Can be called by testator, emergency contacts, or automatically after heartbeat period

### Claiming Inheritance
```clarity
(contract-call? .digital-will-smart-contract claim-inheritance u1)
```
- Beneficiaries claim their allocated inheritance after will execution

## 🔍 Read-Only Functions

### Check Will Information
```clarity
(contract-call? .digital-will-smart-contract get-will-info u1)
```

### Check Execution Readiness
```clarity
(contract-call? .digital-will-smart-contract is-will-ready-for-execution u1)
```

### Calculate Beneficiary Share
```clarity
(contract-call? .digital-will-smart-contract calculate-beneficiary-share u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### Get User's Wills
```clarity
(contract-call? .digital-will-smart-contract get-user-wills 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 🛡️ Security Features

- **Owner Authorization**: Only testators can modify their wills
- **Heartbeat Verification**: Prevents premature execution
- **Emergency Access Control**: Trusted contacts for crisis situations
- **Percentage Validation**: Ensures allocations don't exceed 100%
- **Execution Prevention**: Multiple checks before will execution

## ⚠️ Error Codes

- `u100`: Not authorized
- `u101`: Will does not exist
- `u102`: Will already exists
- `u103`: Beneficiary not found
- `u104`: Not enough time passed for execution
- `u105`: Will already executed
- `u106`: Invalid beneficiary
- `u107`: Insufficient balance
- `u108`: Transfer failed
- `u109`: Will is locked
- `u110`: Invalid percentage

## 🧪 Testing

Run the test suite:
```bash
npm install
npm test
```

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.


