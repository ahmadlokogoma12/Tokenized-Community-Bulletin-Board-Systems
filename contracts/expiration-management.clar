;; Expiration Management Contract
;; Removes outdated announcements automatically

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_POST_NOT_FOUND (err u301))
(define-constant ERR_INVALID_INPUT (err u302))
(define-constant ERR_ALREADY_EXPIRED (err u303))

;; Data Variables
(define-data-var default-expiry-hours uint u168) ;; 7 days default
(define-data-var cleanup-reward uint u100)
(define-data-var max-cleanup-batch uint u10)

;; Data Maps
(define-map post-expiry
  { post-id: uint }
  {
    created-at: uint,
    expires-at: uint,
    extended-count: uint,
    auto-cleanup: bool,
    renewal-fee: uint
  }
)

(define-map expiry-queue
  { expiry-time: uint, post-id: uint }
  { queued-at: uint, processed: bool }
)

(define-map cleanup-rewards
  { cleaner: principal }
  { total-cleanups: uint, total-rewards: uint, last-cleanup: uint }
)

(define-map post-extensions
  { post-id: uint, extension-id: uint }
  {
    extended-by: principal,
    extended-at: uint,
    hours-added: uint,
    fee-paid: uint
  }
)

;; Public Functions

;; Set post expiration
(define-public (set-post-expiration (post-id uint) (expiry-hours uint) (auto-cleanup bool))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (expiry-time (+ current-time (* expiry-hours u3600)))
    )
    (asserts! (> expiry-hours u0) ERR_INVALID_INPUT)

    ;; Store expiration data
    (map-set post-expiry
      { post-id: post-id }
      {
        created-at: current-time,
        expires-at: expiry-time,
        extended-count: u0,
        auto-cleanup: auto-cleanup,
        renewal-fee: u1000
      }
    )

    ;; Add to expiry queue if auto-cleanup enabled
    (if auto-cleanup
      (map-set expiry-queue
        { expiry-time: expiry-time, post-id: post-id }
        { queued-at: current-time, processed: false }
      )
      true
    )

    (ok true)
  )
)

;; Extend post expiration
(define-public (extend-post-expiration (post-id uint) (additional-hours uint))
  (let
    (
      (expiry-data (unwrap! (map-get? post-expiry { post-id: post-id }) ERR_POST_NOT_FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (new-expiry (+ (get expires-at expiry-data) (* additional-hours u3600)))
      (extension-id (get extended-count expiry-data))
    )
    (asserts! (> additional-hours u0) ERR_INVALID_INPUT)
    (asserts! (< current-time (get expires-at expiry-data)) ERR_ALREADY_EXPIRED)

    ;; Update expiration data
    (map-set post-expiry
      { post-id: post-id }
      (merge expiry-data {
        expires-at: new-expiry,
        extended-count: (+ extension-id u1)
      })
    )

    ;; Record extension
    (map-set post-extensions
      { post-id: post-id, extension-id: extension-id }
      {
        extended-by: tx-sender,
        extended-at: current-time,
        hours-added: additional-hours,
        fee-paid: (get renewal-fee expiry-data)
      }
    )

    ;; Update expiry queue if auto-cleanup enabled
    (if (get auto-cleanup expiry-data)
      (begin
        (map-delete expiry-queue { expiry-time: (get expires-at expiry-data), post-id: post-id })
        (map-set expiry-queue
          { expiry-time: new-expiry, post-id: post-id }
          { queued-at: current-time, processed: false }
        )
      )
      true
    )

    (ok true)
  )
)

;; Cleanup expired posts
(define-public (cleanup-expired-posts (post-ids (list 10 uint)))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (cleanup-count (len post-ids))
    )
    (asserts! (<= cleanup-count (var-get max-cleanup-batch)) ERR_INVALID_INPUT)

    ;; Process each post
    (fold cleanup-single-post post-ids u0)

    ;; Update cleanup rewards
    (match (map-get? cleanup-rewards { cleaner: tx-sender })
      reward-data
      (map-set cleanup-rewards
        { cleaner: tx-sender }
        {
          total-cleanups: (+ (get total-cleanups reward-data) cleanup-count),
          total-rewards: (+ (get total-rewards reward-data) (* cleanup-count (var-get cleanup-reward))),
          last-cleanup: current-time
        }
      )
      (map-set cleanup-rewards
        { cleaner: tx-sender }
        {
          total-cleanups: cleanup-count,
          total-rewards: (* cleanup-count (var-get cleanup-reward)),
          last-cleanup: current-time
        }
      )
    )

    (ok cleanup-count)
  )
)

;; Renew post before expiration
(define-public (renew-post (post-id uint) (renewal-hours uint))
  (let
    (
      (expiry-data (unwrap! (map-get? post-expiry { post-id: post-id }) ERR_POST_NOT_FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (time-until-expiry (- (get expires-at expiry-data) current-time))
    )
    (asserts! (> renewal-hours u0) ERR_INVALID_INPUT)
    (asserts! (< time-until-expiry u86400) ERR_INVALID_INPUT) ;; Must be within 24 hours of expiry

    ;; Extend the post
    (try! (extend-post-expiration post-id renewal-hours))

    (ok true)
  )
)

;; Toggle auto-cleanup for post
(define-public (toggle-auto-cleanup (post-id uint))
  (let
    (
      (expiry-data (unwrap! (map-get? post-expiry { post-id: post-id }) ERR_POST_NOT_FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (new-auto-cleanup (not (get auto-cleanup expiry-data)))
    )
    ;; Update auto-cleanup setting
    (map-set post-expiry
      { post-id: post-id }
      (merge expiry-data { auto-cleanup: new-auto-cleanup })
    )

    ;; Update expiry queue accordingly
    (if new-auto-cleanup
      (map-set expiry-queue
        { expiry-time: (get expires-at expiry-data), post-id: post-id }
        { queued-at: current-time, processed: false }
      )
      (map-delete expiry-queue { expiry-time: (get expires-at expiry-data), post-id: post-id })
    )

    (ok new-auto-cleanup)
  )
)

;; Helper Functions
(define-private (cleanup-single-post (post-id uint) (acc uint))
  (let
    (
      (expiry-data (map-get? post-expiry { post-id: post-id }))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (match expiry-data
      data
      (if (>= current-time (get expires-at data))
        (begin
          ;; Mark as processed in queue
          (map-set expiry-queue
            { expiry-time: (get expires-at data), post-id: post-id }
            { queued-at: (get created-at data), processed: true }
          )
          (+ acc u1)
        )
        acc
      )
      acc
    )
  )
)

;; Read-only Functions

;; Get post expiration data
(define-read-only (get-post-expiration (post-id uint))
  (map-get? post-expiry { post-id: post-id })
)

;; Check if post is expired
(define-read-only (is-post-expired (post-id uint))
  (match (map-get? post-expiry { post-id: post-id })
    expiry-data
    (let
      (
        (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      )
      (>= current-time (get expires-at expiry-data))
    )
    false
  )
)

;; Get time until expiration
(define-read-only (get-time-until-expiry (post-id uint))
  (match (map-get? post-expiry { post-id: post-id })
    expiry-data
    (let
      (
        (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
        (expiry-time (get expires-at expiry-data))
      )
      (if (> expiry-time current-time)
        (some (- expiry-time current-time))
        (some u0)
      )
    )
    none
  )
)

;; Get cleanup rewards for user
(define-read-only (get-cleanup-rewards (cleaner principal))
  (map-get? cleanup-rewards { cleaner: cleaner })
)

;; Get post extension history
(define-read-only (get-post-extension (post-id uint) (extension-id uint))
  (map-get? post-extensions { post-id: post-id, extension-id: extension-id })
)

;; Get default expiry hours
(define-read-only (get-default-expiry-hours)
  (var-get default-expiry-hours)
)
