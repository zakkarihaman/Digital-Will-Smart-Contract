(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_WILL_NOT_EXISTS (err u101))
(define-constant ERR_WILL_ALREADY_EXISTS (err u102))
(define-constant ERR_BENEFICIARY_NOT_FOUND (err u103))
(define-constant ERR_NOT_ENOUGH_TIME_PASSED (err u104))
(define-constant ERR_WILL_ALREADY_EXECUTED (err u105))
(define-constant ERR_INVALID_BENEFICIARY (err u106))
(define-constant ERR_INSUFFICIENT_BALANCE (err u107))
(define-constant ERR_TRANSFER_FAILED (err u108))
(define-constant ERR_WILL_LOCKED (err u109))
(define-constant ERR_INVALID_PERCENTAGE (err u110))

(define-data-var contract-nonce uint u0)

(define-map wills
    { will-id: uint }
    {
        testator: principal,
        creation-block: uint,
        last-heartbeat: uint,
        heartbeat-period: uint,
        is-executed: bool,
        is-locked: bool,
        total-value: uint,
        metadata: (string-utf8 256),
    }
)

(define-map beneficiaries
    {
        will-id: uint,
        beneficiary: principal,
    }
    {
        allocation-percentage: uint,
        asset-type: (string-ascii 32),
        conditions: (string-utf8 256),
        is-active: bool,
    }
)

(define-map emergency-contacts
    {
        will-id: uint,
        contact: principal,
    }
    {
        can-execute: bool,
        added-at: uint,
    }
)

(define-map user-wills
    { user: principal }
    { will-ids: (list 10 uint) }
)

(define-read-only (get-will-info (will-id uint))
    (map-get? wills { will-id: will-id })
)

(define-read-only (get-beneficiary-info
        (will-id uint)
        (beneficiary principal)
    )
    (map-get? beneficiaries {
        will-id: will-id,
        beneficiary: beneficiary,
    })
)

(define-read-only (get-emergency-contact
        (will-id uint)
        (contact principal)
    )
    (map-get? emergency-contacts {
        will-id: will-id,
        contact: contact,
    })
)

(define-read-only (get-user-wills (user principal))
    (default-to { will-ids: (list) } (map-get? user-wills { user: user }))
)

(define-read-only (is-will-ready-for-execution (will-id uint))
    (match (map-get? wills { will-id: will-id })
        will-data (let (
                (current-block stacks-block-height)
                (last-heartbeat (get last-heartbeat will-data))
                (heartbeat-period (get heartbeat-period will-data))
                (is-executed (get is-executed will-data))
            )
            (and
                (not is-executed)
                (>= (- current-block last-heartbeat) heartbeat-period)
            )
        )
        false
    )
)

(define-read-only (get-contract-balance)
    (stx-get-balance (as-contract tx-sender))
)

(define-read-only (calculate-beneficiary-share
        (will-id uint)
        (beneficiary principal)
    )
    (match (get-will-info will-id)
        will-data (match (get-beneficiary-info will-id beneficiary)
            beneficiary-data (let (
                    (total-value (get total-value will-data))
                    (percentage (get allocation-percentage beneficiary-data))
                )
                (some (/ (* total-value percentage) u100))
            )
            none
        )
        none
    )
)

(define-private (add-will-to-user
        (user principal)
        (will-id uint)
    )
    (let (
            (current-wills (get will-ids (get-user-wills user)))
            (updated-wills (unwrap! (as-max-len? (append current-wills will-id) u10) (err u999)))
        )
        (map-set user-wills { user: user } { will-ids: updated-wills })
        (ok true)
    )
)

(define-private (validate-percentage-sum
        (will-id uint)
        (new-percentage uint)
    )
    (let ((total-percentage u0))
        (<= (+ total-percentage new-percentage) u100)
    )
)

(define-public (create-will
        (heartbeat-period uint)
        (metadata (string-utf8 256))
    )
    (let (
            (will-id (+ (var-get contract-nonce) u1))
            (current-block stacks-block-height)
        )
        (asserts! (> heartbeat-period u0) ERR_NOT_AUTHORIZED)
        (var-set contract-nonce will-id)
        (map-set wills { will-id: will-id } {
            testator: tx-sender,
            creation-block: current-block,
            last-heartbeat: current-block,
            heartbeat-period: heartbeat-period,
            is-executed: false,
            is-locked: false,
            total-value: u0,
            metadata: metadata,
        })
        (unwrap! (add-will-to-user tx-sender will-id) (err u999))
        (ok will-id)
    )
)

(define-public (add-beneficiary
        (will-id uint)
        (beneficiary principal)
        (allocation-percentage uint)
        (asset-type (string-ascii 32))
        (conditions (string-utf8 256))
    )
    (let ((will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS)))
        (asserts! (is-eq tx-sender (get testator will-data)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-locked will-data)) ERR_WILL_LOCKED)
        (asserts! (not (is-eq beneficiary tx-sender)) ERR_INVALID_BENEFICIARY)
        (asserts!
            (and (> allocation-percentage u0) (<= allocation-percentage u100))
            ERR_INVALID_PERCENTAGE
        )
        (asserts! (is-none (get-beneficiary-info will-id beneficiary))
            ERR_BENEFICIARY_NOT_FOUND
        )
        (map-set beneficiaries {
            will-id: will-id,
            beneficiary: beneficiary,
        } {
            allocation-percentage: allocation-percentage,
            asset-type: asset-type,
            conditions: conditions,
            is-active: true,
        })
        (ok true)
    )
)

(define-public (update-beneficiary
        (will-id uint)
        (beneficiary principal)
        (allocation-percentage uint)
        (conditions (string-utf8 256))
    )
    (let (
            (will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS))
            (beneficiary-data (unwrap! (get-beneficiary-info will-id beneficiary)
                ERR_BENEFICIARY_NOT_FOUND
            ))
        )
        (asserts! (is-eq tx-sender (get testator will-data)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-locked will-data)) ERR_WILL_LOCKED)
        (asserts!
            (and (> allocation-percentage u0) (<= allocation-percentage u100))
            ERR_INVALID_PERCENTAGE
        )
        (map-set beneficiaries {
            will-id: will-id,
            beneficiary: beneficiary,
        }
            (merge beneficiary-data {
                allocation-percentage: allocation-percentage,
                conditions: conditions,
            })
        )
        (ok true)
    )
)

(define-public (remove-beneficiary
        (will-id uint)
        (beneficiary principal)
    )
    (let ((will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS)))
        (asserts! (is-eq tx-sender (get testator will-data)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-locked will-data)) ERR_WILL_LOCKED)
        (asserts! (is-some (get-beneficiary-info will-id beneficiary))
            ERR_BENEFICIARY_NOT_FOUND
        )
        (map-delete beneficiaries {
            will-id: will-id,
            beneficiary: beneficiary,
        })
        (ok true)
    )
)

(define-public (add-emergency-contact
        (will-id uint)
        (contact principal)
    )
    (let ((will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS)))
        (asserts! (is-eq tx-sender (get testator will-data)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-locked will-data)) ERR_WILL_LOCKED)
        (asserts! (not (is-eq contact tx-sender)) ERR_INVALID_BENEFICIARY)
        (map-set emergency-contacts {
            will-id: will-id,
            contact: contact,
        } {
            can-execute: true,
            added-at: stacks-block-height,
        })
        (ok true)
    )
)

(define-public (deposit-to-will
        (will-id uint)
        (amount uint)
    )
    (let ((will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS)))
        (asserts! (is-eq tx-sender (get testator will-data)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
        (asserts! (> amount u0) ERR_INSUFFICIENT_BALANCE)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set wills { will-id: will-id }
            (merge will-data { total-value: (+ (get total-value will-data) amount) })
        )
        (ok true)
    )
)

(define-public (heartbeat (will-id uint))
    (let ((will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS)))
        (asserts! (is-eq tx-sender (get testator will-data)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
        (map-set wills { will-id: will-id }
            (merge will-data { last-heartbeat: stacks-block-height })
        )
        (ok true)
    )
)

(define-public (lock-will (will-id uint))
    (let ((will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS)))
        (asserts! (is-eq tx-sender (get testator will-data)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
        (map-set wills { will-id: will-id } (merge will-data { is-locked: true }))
        (ok true)
    )
)

(define-public (execute-will (will-id uint))
    (let (
            (will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS))
            (caller tx-sender)
            (testator (get testator will-data))
        )
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
        (asserts!
            (or
                (is-eq caller testator)
                (is-some (get-emergency-contact will-id caller))
                (is-will-ready-for-execution will-id)
            )
            ERR_NOT_AUTHORIZED
        )
        (asserts! (is-will-ready-for-execution will-id)
            ERR_NOT_ENOUGH_TIME_PASSED
        )
        (map-set wills { will-id: will-id }
            (merge will-data { is-executed: true })
        )
        (ok true)
    )
)

(define-public (claim-inheritance (will-id uint))
    (let (
            (will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS))
            (beneficiary-data (unwrap! (get-beneficiary-info will-id tx-sender)
                ERR_BENEFICIARY_NOT_FOUND
            ))
            (inheritance-amount (unwrap! (calculate-beneficiary-share will-id tx-sender)
                ERR_BENEFICIARY_NOT_FOUND
            ))
        )
        (asserts! (get is-executed will-data) ERR_WILL_ALREADY_EXECUTED)
        (asserts! (get is-active beneficiary-data) ERR_BENEFICIARY_NOT_FOUND)
        (asserts! (> inheritance-amount u0) ERR_INSUFFICIENT_BALANCE)
        (try! (as-contract (stx-transfer? inheritance-amount tx-sender tx-sender)))
        (map-set beneficiaries {
            will-id: will-id,
            beneficiary: tx-sender,
        }
            (merge beneficiary-data { is-active: false })
        )
        (ok inheritance-amount)
    )
)

(define-public (emergency-execute (will-id uint))
    (let (
            (will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS))
            (emergency-contact (unwrap! (get-emergency-contact will-id tx-sender) ERR_NOT_AUTHORIZED))
        )
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
        (asserts! (get can-execute emergency-contact) ERR_NOT_AUTHORIZED)
        (map-set wills { will-id: will-id }
            (merge will-data { is-executed: true })
        )
        (ok true)
    )
)
