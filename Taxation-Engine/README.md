# Tax Management & Calculation System

A comprehensive smart contract for managing and calculating taxes on the Stacks blockchain using Clarity language.

## Overview

This smart contract provides a complete tax management system with features including:

- Progressive taxation calculation
- Multi-currency support with exchange rate conversion
- Tax deduction management
- Comprehensive reporting capabilities
- Administrative functions for system management

## Core Features

### Progressive Tax System

The contract implements a progressive tax bracket system that can be configured for different taxpayer classifications. Tax liability is calculated based on income brackets with different rates.

### Multi-Currency Support

- Handles transactions in multiple currencies
- Maintains exchange rates for different currencies
- Provides currency conversion functions

### Deduction Management

- Registry of available tax deductions
- Deduction claims by taxpayers
- Administrative verification of deduction claims
- Tracking of verified deductions

### Comprehensive Reporting

- Tax summary generation for taxpayers
- Tracking of payment history
- Calculation of net tax obligations

### Administrative Functions

- Setting and updating currency exchange rates
- Creating and managing deduction categories
- Verifying deduction claims
- Processing tax refunds

## Contract Functions

### Read-Only Functions

- `fetch-taxpayer-data`: Retrieves data for a specific taxpayer
- `fetch-tax-brackets`: Gets tax bracket information for a taxpayer classification
- `fetch-currency-data`: Retrieves exchange rate information for a currency
- `fetch-deduction-details`: Gets details about a specific deduction type
- `calculate-currency-conversion`: Converts amounts between currencies
- `calculate-tax-liability`: Computes tax liability based on income and classification
- `generate-tax-summary`: Creates a comprehensive tax report for a taxpayer
- `calculate-taxpayer-obligation`: Determines a taxpayer's current tax obligation

### Public Functions (Administrative)

- `set-currency-exchange-rate`: Updates exchange rates for currencies
- `create-deduction-category`: Creates new deduction types
- `verify-deduction-claim`: Verifies taxpayer deduction claims
- `process-tax-refund`: Issues tax refunds to taxpayers

### Public Functions (Taxpayer)

- `claim-tax-deduction`: Submits deduction claims

## Data Structures

### Taxpayer Records

Stores comprehensive taxpayer information:
- Total taxes paid
- Total refunds received
- Last payment amount
- Tax classification
- Active deductions (with verification status)
- Payment history

### Tax Bracket System

Defines progressive tax brackets for different taxpayer classifications:
- Income limits for each bracket
- Tax rate percentages
- Bracket names
- Reference currency
- Last modification timestamp

### Forex Exchange Rates

Manages currency conversion rates:
- Conversion rate (scaled by 1e8)
- Last update timestamp
- Active status

### Tax Deduction Registry

Catalogs available deductions:
- Deduction title
- Deduction cap
- Relief percentage
- Verification requirements

## Error Codes

- `ERR-UNAUTHORIZED-ACCESS` (u100): Access denied for non-administrative functions
- `ERR-PAYMENT-AMOUNT-INVALID` (u101): Invalid payment or deduction amount
- `ERR-TAX-BRACKET-MISSING` (u102): Tax bracket not found
- `ERR-FUNDS-INSUFFICIENT` (u103): Insufficient funds for operation
- `ERR-TAX-PERCENTAGE-INVALID` (u104): Invalid tax percentage
- `ERR-CURRENCY-CODE-INVALID` (u105): Invalid currency code
- `ERR-DEDUCTION-INVALID` (u106): Invalid deduction
- `ERR-REFUND-DISALLOWED` (u107): Refund not allowed
- `ERR-TAX-PERIOD-INVALID` (u108): Invalid tax period
- `ERR-FUNDS-TRANSFER-FAILED` (u109): Failed fund transfer

## Usage Examples

### Calculating Tax Liability

```clarity
;; Calculate tax for a taxpayer with 5000 income in the "individual" classification
(contract-call? .tax-system calculate-tax-liability u5000 "individual")
```

### Claiming a Deduction

```clarity
;; Claim a "mortgage" deduction of 1200
(contract-call? .tax-system claim-tax-deduction "mortgage" u1200)
```

### Currency Conversion

```clarity
;; Convert 1000 USD to STX
(contract-call? .tax-system calculate-currency-conversion u1000 "USD" "STX")
```

### Generating a Tax Report

```clarity
;; Generate tax summary for current user for tax period 2023
(contract-call? .tax-system generate-tax-summary tx-sender u2023)
```

## Security Considerations

- Administrative functions are protected by principal checks
- Deduction claims are subject to caps and verification
- Tax refunds are limited by previously paid taxes