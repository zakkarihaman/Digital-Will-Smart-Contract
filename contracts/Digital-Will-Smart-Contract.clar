(define-trait sip-010-trait (
    (transfer
        (uint principal principal (optional (buff 34)))
        (response bool uint)
    )
    (get-name
        ()
        (response (string-ascii 32) uint)
    )
    (get-symbol
        ()
        (response (string-ascii 32) uint)
    )
    (get-decimals
        ()
        (response uint uint)
    )
    (get-balance
        (principal)
        (response uint uint)
    )
    (get-total-supply
        ()
        (response uint uint)
    )
    (get-token-uri
        ()
        (response (optional (string-utf8 256)) uint)
    )
))

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
(define-constant ERR_INVALID_STATUS (err u111))
(define-constant ERR_EVENT_NOT_FOUND (err u112))
(define-constant ERR_NOT_JOINT_WILL (err u113))
(define-constant ERR_ALREADY_JOINT_TESTATOR (err u114))
(define-constant ERR_INSUFFICIENT_VOTES (err u115))
(define-constant ERR_ALREADY_VOTED (err u116))
(define-constant ERR_MAX_TESTATORS_REACHED (err u117))
(define-constant ERR_DOC_EXISTS (err u118))
(define-constant ERR_DOC_NOT_FOUND (err u119))
(define-constant ERR_DOC_UNAUTHORIZED (err u120))
(define-constant ERR_TOKEN_NOT_SUPPORTED (err u121))
(define-constant ERR_TOKEN_TRANSFER_FAILED (err u122))
(define-constant ERR_INVALID_TOKEN_AMOUNT (err u123))

(define-data-var contract-nonce uint u0)
(define-data-var event-nonce uint u0)
(define-data-var action-nonce uint u0)

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

(define-map will-status
    { will-id: uint }
    {
        status: (string-ascii 20),
        days-until-expiry: uint,
        risk-level: (string-ascii 10),
        last-updated: uint,
        notification-sent: bool,
    }
)

(define-map will-events
    { event-id: uint }
    {
        will-id: uint,
        event-type: (string-ascii 30),
        timestamp: uint,
        actor: principal,
        details: (string-utf8 256),
    }
)

(define-map notification-preferences
    { user: principal }
    {
        heartbeat-reminder: bool,
        status-updates: bool,
        emergency-alerts: bool,
        reminder-frequency: uint,
    }
)

(define-map joint-wills
    { will-id: uint }
    {
        testators: (list 5 principal),
        required-votes: uint,
        is-joint: bool,
    }
)

(define-map joint-will-votes
    {
        will-id: uint,
        action: (string-ascii 20),
        voter: principal,
    }
    {
        vote-cast: bool,
        timestamp: uint,
    }
)

(define-map pending-joint-actions
    {
        will-id: uint,
        action-id: uint,
    }
    {
        action-type: (string-ascii 20),
        proposer: principal,
        votes-received: uint,
        proposed-at: uint,
        executed: bool,
    }
)

(define-map will-documents
    {
        will-id: uint,
        version: uint,
    }
    {
        hash: (buff 32),
        uri: (string-utf8 256),
        added-at: uint,
        added-by: principal,
    }
)

(define-map will-doc-latest
    { will-id: uint }
    { latest: uint }
)

(define-map will-tokens
    {
        will-id: uint,
        token-contract: principal,
    }
    {
        balance: uint,
        token-symbol: (string-ascii 12),
        is-active: bool,
    }
)

(define-map supported-tokens
    { token-contract: principal }
    {
        token-symbol: (string-ascii 12),
        decimals: uint,
        is-enabled: bool,
    }
)

(define-map token-distribution-ratios
    {
        will-id: uint,
        beneficiary: principal,
        token-contract: principal,
    }
    {
        ratio-percentage: uint,
        custom-amount: uint,
        distribution-type: (string-ascii 10),
    }
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

(define-read-only (get-will-status (will-id uint))
    (map-get? will-status { will-id: will-id })
)

(define-read-only (get-will-events (event-id uint))
    (map-get? will-events { event-id: event-id })
)

(define-read-only (get-notification-preferences (user principal))
    (default-to {
        heartbeat-reminder: true,
        status-updates: true,
        emergency-alerts: true,
        reminder-frequency: u7,
    }
        (map-get? notification-preferences { user: user })
    )
)

(define-read-only (calculate-will-risk-level (will-id uint))
    (match (get-will-info will-id)
        will-data (let (
                (current-block stacks-block-height)
                (last-heartbeat (get last-heartbeat will-data))
                (heartbeat-period (get heartbeat-period will-data))
                (time-since-heartbeat (- current-block last-heartbeat))
                (percentage-elapsed (/ (* time-since-heartbeat u100) heartbeat-period))
            )
            (if (<= percentage-elapsed u50)
                "low"
                (if (<= percentage-elapsed u80)
                    "medium"
                    "high"
                )
            )
        )
        "unknown"
    )
)

(define-read-only (get-days-until-expiry (will-id uint))
    (match (get-will-info will-id)
        will-data (let (
                (current-block stacks-block-height)
                (last-heartbeat (get last-heartbeat will-data))
                (heartbeat-period (get heartbeat-period will-data))
                (blocks-remaining (- (+ last-heartbeat heartbeat-period) current-block))
            )
            (if (> blocks-remaining u0)
                (/ blocks-remaining u144)
                u0
            )
        )
        u0
    )
)

(define-read-only (get-joint-will-info (will-id uint))
    (map-get? joint-wills { will-id: will-id })
)

(define-read-only (is-joint-testator
        (will-id uint)
        (testator principal)
    )
    (match (get-joint-will-info will-id)
        joint-data (is-some (index-of (get testators joint-data) testator))
        false
    )
)

(define-read-only (get-joint-action-votes
        (will-id uint)
        (action-id uint)
    )
    (map-get? pending-joint-actions {
        will-id: will-id,
        action-id: action-id,
    })
)

(define-read-only (has-voted-on-action
        (will-id uint)
        (action (string-ascii 20))
        (voter principal)
    )
    (match (map-get? joint-will-votes {
        will-id: will-id,
        action: action,
        voter: voter,
    })
        vote-data (get vote-cast vote-data)
        false
    )
)

(define-read-only (get-will-document
        (will-id uint)
        (version uint)
    )
    (map-get? will-documents {
        will-id: will-id,
        version: version,
    })
)

(define-read-only (get-latest-document-version (will-id uint))
    (match (map-get? will-doc-latest { will-id: will-id })
        v (get latest v)
        u0
    )
)

(define-read-only (get-latest-will-document (will-id uint))
    (match (map-get? will-doc-latest { will-id: will-id })
        v (map-get? will-documents {
            will-id: will-id,
            version: (get latest v),
        })
        none
    )
)

(define-read-only (get-will-token-balance
        (will-id uint)
        (token-contract principal)
    )
    (map-get? will-tokens {
        will-id: will-id,
        token-contract: token-contract,
    })
)

(define-read-only (is-token-supported (token-contract principal))
    (match (map-get? supported-tokens { token-contract: token-contract })
        token-info (get is-enabled token-info)
        false
    )
)

(define-read-only (get-token-distribution
        (will-id uint)
        (beneficiary principal)
        (token-contract principal)
    )
    (map-get? token-distribution-ratios {
        will-id: will-id,
        beneficiary: beneficiary,
        token-contract: token-contract,
    })
)

(define-read-only (calculate-token-inheritance
        (will-id uint)
        (beneficiary principal)
        (token-contract principal)
    )
    (match (get-will-token-balance will-id token-contract)
        token-data (match (get-token-distribution will-id beneficiary token-contract)
            distribution-data (let (
                    (total-balance (get balance token-data))
                    (distribution-type (get distribution-type distribution-data))
                )
                (if (is-eq distribution-type "percentage")
                    (some (/ (* total-balance (get ratio-percentage distribution-data))
                        u100
                    ))
                    (some (get custom-amount distribution-data))
                )
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

(define-private (log-will-event
        (will-id uint)
        (event-type (string-ascii 30))
        (actor principal)
        (details (string-utf8 256))
    )
    (let ((event-id (+ (var-get event-nonce) u1)))
        (var-set event-nonce event-id)
        (map-set will-events { event-id: event-id } {
            will-id: will-id,
            event-type: event-type,
            timestamp: stacks-block-height,
            actor: actor,
            details: details,
        })
        (ok event-id)
    )
)

(define-private (update-will-status (will-id uint))
    (let (
            (days-until-expiry (get-days-until-expiry will-id))
            (risk-level (calculate-will-risk-level will-id))
            (status (if (<= days-until-expiry u3)
                "critical"
                (if (<= days-until-expiry u7)
                    "warning"
                    "active"
                )
            ))
        )
        (map-set will-status { will-id: will-id } {
            status: status,
            days-until-expiry: days-until-expiry,
            risk-level: risk-level,
            last-updated: stacks-block-height,
            notification-sent: false,
        })
        (ok true)
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
        (unwrap! (update-will-status will-id) (err u999))
        (unwrap!
            (log-will-event will-id "will-created" tx-sender
                u"Will successfully created"
            )
            (err u999)
        )
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
        (unwrap! (update-will-status will-id) (err u999))
        (unwrap!
            (log-will-event will-id "heartbeat" tx-sender
                u"Heartbeat signal received"
            )
            (err u999)
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
        (map-set will-status { will-id: will-id } {
            status: "executed",
            days-until-expiry: u0,
            risk-level: "none",
            last-updated: stacks-block-height,
            notification-sent: false,
        })
        (unwrap!
            (log-will-event will-id "will-executed" caller
                u"Will has been executed"
            )
            (err u999)
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
        (map-set will-status { will-id: will-id } {
            status: "executed",
            days-until-expiry: u0,
            risk-level: "none",
            last-updated: stacks-block-height,
            notification-sent: false,
        })
        (unwrap!
            (log-will-event will-id "emergency-executed" tx-sender
                u"Emergency execution performed"
            )
            (err u999)
        )
        (ok true)
    )
)

(define-public (set-notification-preferences
        (heartbeat-reminder bool)
        (status-updates bool)
        (emergency-alerts bool)
        (reminder-frequency uint)
    )
    (begin
        (asserts! (and (>= reminder-frequency u1) (<= reminder-frequency u30))
            ERR_INVALID_STATUS
        )
        (map-set notification-preferences { user: tx-sender } {
            heartbeat-reminder: heartbeat-reminder,
            status-updates: status-updates,
            emergency-alerts: emergency-alerts,
            reminder-frequency: reminder-frequency,
        })
        (ok true)
    )
)

(define-public (refresh-will-status (will-id uint))
    (let ((will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS)))
        (asserts! (is-eq tx-sender (get testator will-data)) ERR_NOT_AUTHORIZED)
        (unwrap! (update-will-status will-id) (err u999))
        (unwrap!
            (log-will-event will-id "status-refresh" tx-sender
                u"Status manually refreshed"
            )
            (err u999)
        )
        (ok true)
    )
)

(define-public (mark-notification-sent (will-id uint))
    (let (
            (will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS))
            (current-status (unwrap! (get-will-status will-id) ERR_INVALID_STATUS))
        )
        (asserts! (is-eq tx-sender (get testator will-data)) ERR_NOT_AUTHORIZED)
        (map-set will-status { will-id: will-id }
            (merge current-status { notification-sent: true })
        )
        (ok true)
    )
)

(define-public (create-joint-will
        (co-testators (list 4 principal))
        (heartbeat-period uint)
        (metadata (string-utf8 256))
    )
    (let (
            (will-id (+ (var-get contract-nonce) u1))
            (current-block stacks-block-height)
            (all-testators (unwrap! (as-max-len? (append co-testators tx-sender) u5)
                ERR_MAX_TESTATORS_REACHED
            ))
            (required-votes (+ (/ (len all-testators) u2) u1))
        )
        (asserts! (> heartbeat-period u0) ERR_NOT_AUTHORIZED)
        (asserts! (> (len co-testators) u0) ERR_NOT_AUTHORIZED)
        (asserts! (< (len co-testators) u5) ERR_MAX_TESTATORS_REACHED)
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
        (map-set joint-wills { will-id: will-id } {
            testators: all-testators,
            required-votes: required-votes,
            is-joint: true,
        })
        (unwrap! (update-will-status will-id) (err u999))
        (unwrap!
            (log-will-event will-id "joint-will-created" tx-sender
                u"Joint will successfully created"
            )
            (err u999)
        )
        (unwrap! (add-will-to-user tx-sender will-id) (err u999))
        (ok will-id)
    )
)

(define-public (propose-joint-action
        (will-id uint)
        (action-type (string-ascii 20))
    )
    (let (
            (will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS))
            (joint-data (unwrap! (get-joint-will-info will-id) ERR_NOT_JOINT_WILL))
            (action-id (+ (var-get action-nonce) u1))
        )
        (asserts! (is-joint-testator will-id tx-sender) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
        (var-set action-nonce action-id)
        (map-set pending-joint-actions {
            will-id: will-id,
            action-id: action-id,
        } {
            action-type: action-type,
            proposer: tx-sender,
            votes-received: u1,
            proposed-at: stacks-block-height,
            executed: false,
        })
        (map-set joint-will-votes {
            will-id: will-id,
            action: action-type,
            voter: tx-sender,
        } {
            vote-cast: true,
            timestamp: stacks-block-height,
        })
        (unwrap!
            (log-will-event will-id "action-proposed" tx-sender
                u"Joint will action proposed"
            )
            (err u999)
        )
        (ok action-id)
    )
)

(define-public (vote-on-joint-action
        (will-id uint)
        (action-id uint)
        (action-type (string-ascii 20))
    )
    (let (
            (will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS))
            (joint-data (unwrap! (get-joint-will-info will-id) ERR_NOT_JOINT_WILL))
            (action-data (unwrap! (get-joint-action-votes will-id action-id)
                ERR_EVENT_NOT_FOUND
            ))
        )
        (asserts! (is-joint-testator will-id tx-sender) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
        (asserts! (not (get executed action-data)) ERR_WILL_ALREADY_EXECUTED)
        (asserts! (not (has-voted-on-action will-id action-type tx-sender))
            ERR_ALREADY_VOTED
        )
        (map-set joint-will-votes {
            will-id: will-id,
            action: action-type,
            voter: tx-sender,
        } {
            vote-cast: true,
            timestamp: stacks-block-height,
        })
        (map-set pending-joint-actions {
            will-id: will-id,
            action-id: action-id,
        }
            (merge action-data { votes-received: (+ (get votes-received action-data) u1) })
        )
        (unwrap!
            (log-will-event will-id "vote-cast" tx-sender
                u"Vote cast on joint action"
            )
            (err u999)
        )
        (ok true)
    )
)

(define-public (execute-joint-will
        (will-id uint)
        (action-id uint)
    )
    (let (
            (will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS))
            (joint-data (unwrap! (get-joint-will-info will-id) ERR_NOT_JOINT_WILL))
            (action-data (unwrap! (get-joint-action-votes will-id action-id)
                ERR_EVENT_NOT_FOUND
            ))
            (required-votes (get required-votes joint-data))
            (votes-received (get votes-received action-data))
        )
        (asserts! (is-joint-testator will-id tx-sender) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
        (asserts! (not (get executed action-data)) ERR_WILL_ALREADY_EXECUTED)
        (asserts!
            (or
                (>= votes-received required-votes)
                (is-will-ready-for-execution will-id)
            )
            ERR_INSUFFICIENT_VOTES
        )
        (map-set wills { will-id: will-id }
            (merge will-data { is-executed: true })
        )
        (map-set pending-joint-actions {
            will-id: will-id,
            action-id: action-id,
        }
            (merge action-data { executed: true })
        )
        (map-set will-status { will-id: will-id } {
            status: "executed",
            days-until-expiry: u0,
            risk-level: "none",
            last-updated: stacks-block-height,
            notification-sent: false,
        })
        (unwrap!
            (log-will-event will-id "joint-will-executed" tx-sender
                u"Joint will executed with consensus"
            )
            (err u999)
        )
        (ok true)
    )
)

(define-public (joint-will-heartbeat (will-id uint))
    (let (
            (will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS))
            (joint-data (unwrap! (get-joint-will-info will-id) ERR_NOT_JOINT_WILL))
        )
        (asserts! (is-joint-testator will-id tx-sender) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
        (map-set wills { will-id: will-id }
            (merge will-data { last-heartbeat: stacks-block-height })
        )
        (unwrap! (update-will-status will-id) (err u999))
        (unwrap!
            (log-will-event will-id "joint-heartbeat" tx-sender
                u"Joint will heartbeat received"
            )
            (err u999)
        )
        (ok true)
    )
)

(define-public (set-will-document
        (will-id uint)
        (version uint)
        (hash (buff 32))
        (uri (string-utf8 256))
    )
    (let (
            (will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS))
            (authorized (or (is-eq tx-sender (get testator will-data)) (is-joint-testator will-id tx-sender)))
        )
        (asserts! authorized ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
        (asserts! (> version u0) ERR_INVALID_STATUS)
        (asserts!
            (is-none (map-get? will-documents {
                will-id: will-id,
                version: version,
            }))
            ERR_DOC_EXISTS
        )
        (map-set will-documents {
            will-id: will-id,
            version: version,
        } {
            hash: hash,
            uri: uri,
            added-at: stacks-block-height,
            added-by: tx-sender,
        })
        (let ((latest0 (match (map-get? will-doc-latest { will-id: will-id })
                v (get latest v)
                u0
            )))
            (if (> version latest0)
                (map-set will-doc-latest { will-id: will-id } { latest: version })
                true
            )
        )
        (unwrap!
            (log-will-event will-id "doc-set" tx-sender u"Document recorded")
            (err u999)
        )
        (ok version)
    )
)

(define-public (register-supported-token
        (token-contract principal)
        (token-symbol (string-ascii 12))
        (decimals uint)
    )
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set supported-tokens { token-contract: token-contract } {
            token-symbol: token-symbol,
            decimals: decimals,
            is-enabled: true,
        })
        (ok true)
    )
)

(define-public (deposit-token-to-will
        (will-id uint)
        (token-contract <sip-010-trait>)
        (amount uint)
        (token-symbol (string-ascii 12))
    )
    (let (
            (will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS))
            (token-principal (contract-of token-contract))
            (current-balance (default-to {
                balance: u0,
                token-symbol: token-symbol,
                is-active: true,
            }
                (get-will-token-balance will-id token-principal)
            ))
        )
        (asserts! (is-eq tx-sender (get testator will-data)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
        (asserts! (> amount u0) ERR_INVALID_TOKEN_AMOUNT)
        (asserts! (is-token-supported token-principal) ERR_TOKEN_NOT_SUPPORTED)
        (match (contract-call? token-contract transfer amount tx-sender
            (as-contract tx-sender) none
        )
            success (begin
                (map-set will-tokens {
                    will-id: will-id,
                    token-contract: token-principal,
                } {
                    balance: (+ (get balance current-balance) amount),
                    token-symbol: token-symbol,
                    is-active: true,
                })
                (unwrap!
                    (log-will-event will-id "token-deposit" tx-sender
                        u"Token deposited to will"
                    )
                    (err u999)
                )
                (ok amount)
            )
            error
            ERR_TOKEN_TRANSFER_FAILED
        )
    )
)

(define-public (set-token-distribution
        (will-id uint)
        (beneficiary principal)
        (token-contract principal)
        (ratio-percentage uint)
        (custom-amount uint)
        (distribution-type (string-ascii 10))
    )
    (let ((will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS)))
        (asserts! (is-eq tx-sender (get testator will-data)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-locked will-data)) ERR_WILL_LOCKED)
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
        (asserts! (is-token-supported token-contract) ERR_TOKEN_NOT_SUPPORTED)
        (asserts! (is-some (get-beneficiary-info will-id beneficiary))
            ERR_BENEFICIARY_NOT_FOUND
        )
        (asserts!
            (or
                (and (is-eq distribution-type "percentage") (<= ratio-percentage u100))
                (and (is-eq distribution-type "fixed") (> custom-amount u0))
            )
            ERR_INVALID_PERCENTAGE
        )
        (map-set token-distribution-ratios {
            will-id: will-id,
            beneficiary: beneficiary,
            token-contract: token-contract,
        } {
            ratio-percentage: ratio-percentage,
            custom-amount: custom-amount,
            distribution-type: distribution-type,
        })
        (ok true)
    )
)

(define-public (claim-token-inheritance
        (will-id uint)
        (token-contract <sip-010-trait>)
    )
    (let (
            (will-data (unwrap! (get-will-info will-id) ERR_WILL_NOT_EXISTS))
            (token-principal (contract-of token-contract))
            (token-balance (unwrap! (get-will-token-balance will-id token-principal)
                ERR_TOKEN_NOT_SUPPORTED
            ))
            (inheritance-amount (unwrap!
                (calculate-token-inheritance will-id tx-sender token-principal)
                ERR_BENEFICIARY_NOT_FOUND
            ))
        )
        (asserts! (get is-executed will-data) ERR_WILL_ALREADY_EXECUTED)
        (asserts! (get is-active token-balance) ERR_TOKEN_NOT_SUPPORTED)
        (asserts! (> inheritance-amount u0) ERR_INVALID_TOKEN_AMOUNT)
        (asserts! (<= inheritance-amount (get balance token-balance))
            ERR_INSUFFICIENT_BALANCE
        )
        (match (as-contract (contract-call? token-contract transfer inheritance-amount tx-sender
            tx-sender none
        ))
            success (begin
                (map-set will-tokens {
                    will-id: will-id,
                    token-contract: token-principal,
                }
                    (merge token-balance { balance: (- (get balance token-balance) inheritance-amount) })
                )
                (map-delete token-distribution-ratios {
                    will-id: will-id,
                    beneficiary: tx-sender,
                    token-contract: token-principal,
                })
                (unwrap!
                    (log-will-event will-id "token-claimed" tx-sender
                        u"Token inheritance claimed"
                    )
                    (err u999)
                )
                (ok inheritance-amount)
            )
            error
            ERR_TOKEN_TRANSFER_FAILED
        )
    )
)
