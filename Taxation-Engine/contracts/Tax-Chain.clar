;; Tax Management & Calculation System

;; Error constants
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-PAYMENT-AMOUNT-INVALID (err u101))
(define-constant ERR-TAX-BRACKET-MISSING (err u102))
(define-constant ERR-FUNDS-INSUFFICIENT (err u103))
(define-constant ERR-TAX-PERCENTAGE-INVALID (err u104))
(define-constant ERR-CURRENCY-CODE-INVALID (err u105))
(define-constant ERR-DEDUCTION-INVALID (err u106))
(define-constant ERR-REFUND-DISALLOWED (err u107))
(define-constant ERR-TAX-PERIOD-INVALID (err u108))
(define-constant ERR-FUNDS-TRANSFER-FAILED (err u109))

;; Contract configuration data
(define-data-var contract-admin principal tx-sender)
(define-data-var tax-exempt-threshold uint u100) ;; Minimum amount subject to taxation in base currency

;; Exchange rate management for multi-currency support (rates scaled by 1e8)
(define-map forex-exchange-rates
    { currency-symbol: (string-ascii 10) }
    { conversion-rate: uint,
      last-updated-at: uint,
      is-active: bool }
)

;; Progressive tax system definition
(define-map tax-bracket-system
    { taxpayer-classification: (string-ascii 24) }
    {
        progressive-brackets: (list 10 {
            income-limit: uint,
            rate-percentage: uint,
            bracket-name: (string-ascii 64)
        }),
        reference-currency: (string-ascii 10),
        last-modified-at: uint
    }
)

;; Available tax deductions registry
(define-map tax-deduction-registry
    { deduction-identifier: (string-ascii 10) }
    {
        deduction-title: (string-ascii 64),
        deduction-cap: uint,
        relief-percentage: uint,
        requires-verification: bool
    }
)

;; Taxpayer data and history tracking
(define-map taxpayer-records
    principal
    {
        total-taxes-paid: uint,
        total-refunds-received: uint,
        last-payment-amount: uint,
        tax-classification: (string-ascii 24),
        active-deductions: (list 20 {
            deduction-identifier: (string-ascii 10),
            claimed-amount: uint,
            is-verified: bool
        }),
        payment-records: (list 50 {
            payment-amount: uint,
            payment-date: uint,
            payment-currency: (string-ascii 10)
        })
    }
)

;; Read-only information retrieval functions
(define-read-only (fetch-taxpayer-data (taxpayer-id principal))
    (map-get? taxpayer-records taxpayer-id)
)

(define-read-only (fetch-tax-brackets (taxpayer-class (string-ascii 24)))
    (map-get? tax-bracket-system { taxpayer-classification: taxpayer-class })
)

(define-read-only (fetch-currency-data (currency-symbol (string-ascii 10)))
    (map-get? forex-exchange-rates { currency-symbol: currency-symbol })
)

(define-read-only (fetch-deduction-details (deduction-identifier (string-ascii 10)))
    (map-get? tax-deduction-registry { deduction-identifier: deduction-identifier })
)

;; Currency conversion utility
(define-read-only (calculate-currency-conversion (source-amount uint) (from-currency (string-ascii 10)) (to-currency (string-ascii 10)))
    (let (
        (source-rate-data (unwrap! (fetch-currency-data from-currency) ERR-CURRENCY-CODE-INVALID))
        (target-rate-data (unwrap! (fetch-currency-data to-currency) ERR-CURRENCY-CODE-INVALID))
    )
        (ok (/ (* source-amount (get conversion-rate target-rate-data)) (get conversion-rate source-rate-data)))
    )
)

;; Progressive tax calculation function
(define-read-only (calculate-tax-liability (taxable-income uint) (taxpayer-class (string-ascii 24)))
    (match (map-get? tax-bracket-system { taxpayer-classification: taxpayer-class })
        bracket-system-data
        (let ((computed-tax-amount u0))
            (ok (fold process-tax-bracket 
                (get progressive-brackets bracket-system-data)
                { assessable-income: taxable-income, computed-tax: u0 })))
        ERR-TAX-BRACKET-MISSING
    )
)

;; Helper for bracket-based tax calculation
(define-private (process-tax-bracket 
    (bracket { income-limit: uint, rate-percentage: uint, bracket-name: (string-ascii 64) })
    (calculation-data { assessable-income: uint, computed-tax: uint }))
    (let (
        (income-in-bracket (if (> (get assessable-income calculation-data) (get income-limit bracket))
            (- (get assessable-income calculation-data) (get income-limit bracket))
            u0))
        (bracket-tax-portion (/ (* income-in-bracket (get rate-percentage bracket)) u100))
    )
        { 
            assessable-income: (get assessable-income calculation-data),
            computed-tax: (+ (get computed-tax calculation-data) bracket-tax-portion)
        }
    )
)

;; Deduction approval processor
(define-private (process-deduction-approval 
    (deduction-position uint) 
    (current-position uint) 
    (deduction-record { deduction-identifier: (string-ascii 10), claimed-amount: uint, is-verified: bool })
    (target-position uint))
    (if (is-eq current-position target-position)
        ;; Mark target deduction as approved
        {
            deduction-identifier: (get deduction-identifier deduction-record),
            claimed-amount: (get claimed-amount deduction-record),
            is-verified: true
        }
        ;; Keep other deductions unchanged
        deduction-record)
)

;; Administration functions
(define-public (set-currency-exchange-rate (currency-symbol (string-ascii 10)) (updated-rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-UNAUTHORIZED-ACCESS)
        (ok (map-set forex-exchange-rates
            { currency-symbol: currency-symbol }
            { conversion-rate: updated-rate,
              last-updated-at: block-height,
              is-active: true }
        ))
    )
)

(define-public (create-deduction-category (deduction-identifier (string-ascii 10)) (deduction-title (string-ascii 64)) 
               (maximum-deductible uint) (relief-percentage uint) (requires-verification bool))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (<= relief-percentage u100) ERR-TAX-PERCENTAGE-INVALID)
        (ok (map-set tax-deduction-registry
            { deduction-identifier: deduction-identifier }
            { deduction-title: deduction-title,
              deduction-cap: maximum-deductible,
              relief-percentage: relief-percentage,
              requires-verification: requires-verification }
        ))
    )
)

;; Taxpayer-facing functions
(define-public (claim-tax-deduction (deduction-identifier (string-ascii 10)) (claimed-amount uint))
    (let (
        (deduction-details (unwrap! (fetch-deduction-details deduction-identifier) ERR-DEDUCTION-INVALID))
        (taxpayer-data (default-to 
            {
                total-taxes-paid: u0,
                total-refunds-received: u0,
                last-payment-amount: u0,
                tax-classification: "",
                active-deductions: (list ),
                payment-records: (list )
            }
            (fetch-taxpayer-data tx-sender)))
    )
        (begin
            (asserts! (<= claimed-amount (get deduction-cap deduction-details)) ERR-PAYMENT-AMOUNT-INVALID)
            (ok (map-set taxpayer-records
                tx-sender
                {
                    total-taxes-paid: (get total-taxes-paid taxpayer-data),
                    total-refunds-received: (get total-refunds-received taxpayer-data),
                    last-payment-amount: (get last-payment-amount taxpayer-data),
                    tax-classification: (get tax-classification taxpayer-data),
                    active-deductions: (unwrap-panic (as-max-len? 
                        (append (get active-deductions taxpayer-data)
                            {
                                deduction-identifier: deduction-identifier,
                                claimed-amount: claimed-amount,
                                is-verified: (not (get requires-verification deduction-details))
                            })
                        u20)),
                    payment-records: (get payment-records taxpayer-data)
                }
            ))
        )
    )
)

;; Administrative deduction verification
(define-public (verify-deduction-claim (taxpayer-id principal) (deduction-position uint))
    (let (
        (taxpayer-data (unwrap! (fetch-taxpayer-data taxpayer-id) ERR-TAX-BRACKET-MISSING))
        (current-deductions (get active-deductions taxpayer-data))
    )
        (begin
            (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (< deduction-position (len current-deductions)) ERR-DEDUCTION-INVALID)
            
            (ok (map-set taxpayer-records
                taxpayer-id
                {
                    total-taxes-paid: (get total-taxes-paid taxpayer-data),
                    total-refunds-received: (get total-refunds-received taxpayer-data),
                    last-payment-amount: (get last-payment-amount taxpayer-data),
                    tax-classification: (get tax-classification taxpayer-data),
                    active-deductions: (unwrap-panic (as-max-len? 
                        (map process-deduction-approval 
                            (list deduction-position)
                            (list u0)
                            current-deductions
                            (list deduction-position))
                        u20)),
                    payment-records: (get payment-records taxpayer-data)
                }
            ))
        )
    )
)

;; Tax refund processing with native STX transfer
(define-public (process-tax-refund (taxpayer-id principal) (refund-amount uint) (refund-currency (string-ascii 10)))
    (let (
        (taxpayer-data (unwrap! (fetch-taxpayer-data taxpayer-id) ERR-TAX-BRACKET-MISSING))
        (stx-equivalent-amount (unwrap! (calculate-currency-conversion refund-amount refund-currency "STX") ERR-CURRENCY-CODE-INVALID))
    )
        (begin
            (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (<= stx-equivalent-amount (get total-taxes-paid taxpayer-data)) ERR-REFUND-DISALLOWED)
            ;; Transfer STX to taxpayer
            (try! (stx-transfer? stx-equivalent-amount (var-get contract-admin) taxpayer-id))
            (ok (map-set taxpayer-records
                taxpayer-id
                {
                    total-taxes-paid: (get total-taxes-paid taxpayer-data),
                    total-refunds-received: (+ (get total-refunds-received taxpayer-data) stx-equivalent-amount),
                    last-payment-amount: (get last-payment-amount taxpayer-data),
                    tax-classification: (get tax-classification taxpayer-data),
                    active-deductions: (get active-deductions taxpayer-data),
                    payment-records: (unwrap-panic (as-max-len?
                        (append (get payment-records taxpayer-data)
                            { 
                                payment-amount: (- u0 stx-equivalent-amount),
                                payment-date: block-height,
                                payment-currency: refund-currency 
                            })
                        u50))
                }
            ))
        )
    )
)

;; Tax reporting functions
(define-read-only (generate-tax-summary (taxpayer-id principal) (tax-period uint))
    (let (
        (taxpayer-data (unwrap! (fetch-taxpayer-data taxpayer-id) ERR-TAX-BRACKET-MISSING))
    )
        (ok {
            gross-tax-paid: (get total-taxes-paid taxpayer-data),
            refunds-received: (get total-refunds-received taxpayer-data),
            net-tax-liability: (- (get total-taxes-paid taxpayer-data) (get total-refunds-received taxpayer-data)),
            qualified-deductions: (get active-deductions taxpayer-data),
            transaction-history: (get payment-records taxpayer-data)
        })
    )
)

(define-read-only (calculate-taxpayer-obligation (taxpayer-id principal))
    (let (
        (taxpayer-data (unwrap! (fetch-taxpayer-data taxpayer-id) ERR-TAX-BRACKET-MISSING))
        (verified-deduction-total (fold sum-verified-deductions
            (get active-deductions taxpayer-data)
            u0))
    )
        (ok (- (get total-taxes-paid taxpayer-data) verified-deduction-total))
    )
)

;; Helper for summing verified deductions
(define-private (sum-verified-deductions 
    (deduction-record { deduction-identifier: (string-ascii 10), claimed-amount: uint, is-verified: bool }) 
    (total-so-far uint))
    (if (get is-verified deduction-record)
        (+ total-so-far (get claimed-amount deduction-record))
        total-so-far)
)