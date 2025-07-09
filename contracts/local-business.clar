;; Local Business Contract
;; Promotes community commerce opportunities

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_BUSINESS_NOT_FOUND (err u501))
(define-constant ERR_INVALID_INPUT (err u502))
(define-constant ERR_BUSINESS_EXISTS (err u503))
(define-constant ERR_PROMOTION_NOT_FOUND (err u504))

;; Data Variables
(define-data-var next-business-id uint u1)
(define-data-var next-promotion-id uint u1)
(define-data-var business-registration-fee uint u5000)
(define-data-var promotion-fee uint u2000)

;; Data Maps
(define-map businesses
  { business-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    description: (string-ascii 300),
    category: (string-ascii 50),
    contact-info: (string-ascii 200),
    address: (string-ascii 200),
    verified: bool,
    registered-at: uint,
    status: (string-ascii 20),
    rating: uint,
    review-count: uint
  }
)

(define-map business-names
  { name: (string-ascii 100) }
  { business-id: uint }
)

(define-map promotions
  { promotion-id: uint }
  {
    business-id: uint,
    title: (string-ascii 100),
    description: (string-ascii 300),
    discount-percent: uint,
    promo-code: (string-ascii 20),
    starts-at: uint,
    expires-at: uint,
    max-uses: uint,
    current-uses: uint,
    status: (string-ascii 20)
  }
)

(define-map business-reviews
  { business-id: uint, reviewer: principal }
  {
    rating: uint,
    comment: (string-ascii 200),
    reviewed-at: uint,
    verified-purchase: bool
  }
)

(define-map promotion-usage
  { promotion-id: uint, user: principal }
  {
    used-at: uint,
    transaction-id: (string-ascii 50)
  }
)

(define-map business-analytics
  { business-id: uint }
  {
    total-views: uint,
    total-promotions: uint,
    total-revenue: uint,
    last-updated: uint
  }
)

;; Public Functions

;; Register a new business
(define-public (register-business
  (name (string-ascii 100))
  (description (string-ascii 300))
  (category (string-ascii 50))
  (contact-info (string-ascii 200))
  (address (string-ascii 200)))
  (let
    (
      (business-id (var-get next-business-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (> (len name) u0) ERR_INVALID_INPUT)
    (asserts! (> (len description) u0) ERR_INVALID_INPUT)
    (asserts! (is-none (map-get? business-names { name: name })) ERR_BUSINESS_EXISTS)

    ;; Store business data
    (map-set businesses
      { business-id: business-id }
      {
        owner: tx-sender,
        name: name,
        description: description,
        category: category,
        contact-info: contact-info,
        address: address,
        verified: false,
        registered-at: current-time,
        status: "active",
        rating: u0,
        review-count: u0
      }
    )

    ;; Map business name to ID
    (map-set business-names
      { name: name }
      { business-id: business-id }
    )

    ;; Initialize analytics
    (map-set business-analytics
      { business-id: business-id }
      {
        total-views: u0,
        total-promotions: u0,
        total-revenue: u0,
        last-updated: current-time
      }
    )

    (var-set next-business-id (+ business-id u1))

    (ok business-id)
  )
)

;; Create a promotion
(define-public (create-promotion
  (business-id uint)
  (title (string-ascii 100))
  (description (string-ascii 300))
  (discount-percent uint)
  (promo-code (string-ascii 20))
  (duration-hours uint)
  (max-uses uint))
  (let
    (
      (promotion-id (var-get next-promotion-id))
      (business-data (unwrap! (map-get? businesses { business-id: business-id }) ERR_BUSINESS_NOT_FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (expires-at (+ current-time (* duration-hours u3600)))
    )
    (asserts! (is-eq tx-sender (get owner business-data)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status business-data) "active") ERR_UNAUTHORIZED)
    (asserts! (> (len title) u0) ERR_INVALID_INPUT)
    (asserts! (<= discount-percent u100) ERR_INVALID_INPUT)
    (asserts! (> max-uses u0) ERR_INVALID_INPUT)

    ;; Create promotion
    (map-set promotions
      { promotion-id: promotion-id }
      {
        business-id: business-id,
        title: title,
        description: description,
        discount-percent: discount-percent,
        promo-code: promo-code,
        starts-at: current-time,
        expires-at: expires-at,
        max-uses: max-uses,
        current-uses: u0,
        status: "active"
      }
    )

    ;; Update business analytics
    (match (map-get? business-analytics { business-id: business-id })
      analytics-data
      (map-set business-analytics
        { business-id: business-id }
        (merge analytics-data {
          total-promotions: (+ (get total-promotions analytics-data) u1),
          last-updated: current-time
        })
      )
      true
    )

    (var-set next-promotion-id (+ promotion-id u1))

    (ok promotion-id)
  )
)

;; Use a promotion
(define-public (use-promotion (promotion-id uint) (transaction-id (string-ascii 50)))
  (let
    (
      (promotion-data (unwrap! (map-get? promotions { promotion-id: promotion-id }) ERR_PROMOTION_NOT_FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (existing-usage (map-get? promotion-usage { promotion-id: promotion-id, user: tx-sender }))
    )
    (asserts! (is-eq (get status promotion-data) "active") ERR_UNAUTHORIZED)
    (asserts! (< current-time (get expires-at promotion-data)) ERR_UNAUTHORIZED)
    (asserts! (< (get current-uses promotion-data) (get max-uses promotion-data)) ERR_UNAUTHORIZED)
    (asserts! (is-none existing-usage) ERR_UNAUTHORIZED)
    (asserts! (> (len transaction-id) u0) ERR_INVALID_INPUT)

    ;; Record promotion usage
    (map-set promotion-usage
      { promotion-id: promotion-id, user: tx-sender }
      {
        used-at: current-time,
        transaction-id: transaction-id
      }
    )

    ;; Update promotion usage count
    (map-set promotions
      { promotion-id: promotion-id }
      (merge promotion-data {
        current-uses: (+ (get current-uses promotion-data) u1)
      })
    )

    (ok true)
  )
)

;; Review a business
(define-public (review-business (business-id uint) (rating uint) (comment (string-ascii 200)))
  (let
    (
      (business-data (unwrap! (map-get? businesses { business-id: business-id }) ERR_BUSINESS_NOT_FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (existing-review (map-get? business-reviews { business-id: business-id, reviewer: tx-sender }))
    )
    (asserts! (is-eq (get status business-data) "active") ERR_UNAUTHORIZED)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_INPUT)
    (asserts! (is-none existing-review) ERR_UNAUTHORIZED)

    ;; Store review
    (map-set business-reviews
      { business-id: business-id, reviewer: tx-sender }
      {
        rating: rating,
        comment: comment,
        reviewed-at: current-time,
        verified-purchase: false
      }
    )

    ;; Update business rating
    (let
      (
        (current-rating (get rating business-data))
        (review-count (get review-count business-data))
        (new-review-count (+ review-count u1))
        (new-rating (/ (+ (* current-rating review-count) rating) new-review-count))
      )
      (map-set businesses
        { business-id: business-id }
        (merge business-data {
          rating: new-rating,
          review-count: new-review-count
        })
      )
    )

    (ok true)
  )
)

;; Verify business (admin only)
(define-public (verify-business (business-id uint))
  (let
    (
      (business-data (unwrap! (map-get? businesses { business-id: business-id }) ERR_BUSINESS_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set businesses
      { business-id: business-id }
      (merge business-data { verified: true })
    )

    (ok true)
  )
)

;; Update business info
(define-public (update-business-info
  (business-id uint)
  (description (string-ascii 300))
  (contact-info (string-ascii 200))
  (address (string-ascii 200)))
  (let
    (
      (business-data (unwrap! (map-get? businesses { business-id: business-id }) ERR_BUSINESS_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner business-data)) ERR_UNAUTHORIZED)
    (asserts! (> (len description) u0) ERR_INVALID_INPUT)

    (map-set businesses
      { business-id: business-id }
      (merge business-data {
        description: description,
        contact-info: contact-info,
        address: address
      })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get business details
(define-read-only (get-business (business-id uint))
  (map-get? businesses { business-id: business-id })
)

;; Get business by name
(define-read-only (get-business-by-name (name (string-ascii 100)))
  (match (map-get? business-names { name: name })
    name-data (map-get? businesses { business-id: (get business-id name-data) })
    none
  )
)

;; Get promotion details
(define-read-only (get-promotion (promotion-id uint))
  (map-get? promotions { promotion-id: promotion-id })
)

;; Get business review
(define-read-only (get-business-review (business-id uint) (reviewer principal))
  (map-get? business-reviews { business-id: business-id, reviewer: reviewer })
)

;; Get promotion usage
(define-read-only (get-promotion-usage (promotion-id uint) (user principal))
  (map-get? promotion-usage { promotion-id: promotion-id, user: user })
)

;; Get business analytics
(define-read-only (get-business-analytics (business-id uint))
  (map-get? business-analytics { business-id: business-id })
)

;; Check if promotion is valid
(define-read-only (is-promotion-valid (promotion-id uint))
  (match (map-get? promotions { promotion-id: promotion-id })
    promotion-data
    (let
      (
        (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      )
      (and
        (is-eq (get status promotion-data) "active")
        (< current-time (get expires-at promotion-data))
        (< (get current-uses promotion-data) (get max-uses promotion-data))
      )
    )
    false
  )
)

;; Get next business ID
(define-read-only (get-next-business-id)
  (var-get next-business-id)
)

;; Get next promotion ID
(define-read-only (get-next-promotion-id)
  (var-get next-promotion-id)
)
