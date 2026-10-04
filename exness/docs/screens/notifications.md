# Notifications sheet

## Reference

- The Account tab contains a bell in `exness/docs/reference-frames/43s.png`.
  The video does not open the notification list.

## Layout and states

- The bell opens a sheet that reads `GET /notifications` for the active EX V2
  account. Empty, loading, and retryable error states are distinct.
- An unread row calls `PUT /notifications/{id}/read`, then reloads the list.
  “Đánh dấu tất cả” calls `PUT /notifications/read-all`.
- Both writes include an idempotency key and correlation ID. An in-flight
  write disables repeated taps. A failed write leaves the item unread and
  displays an error.

## Assumptions

- This is an in-app list. Push notifications are not configured in this phase.
