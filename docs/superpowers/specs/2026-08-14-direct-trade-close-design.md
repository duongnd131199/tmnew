# Direct Trade Close Design

## Approved behavior

Selecting `Đóng trạng thái` from a position action sheet on the Trade screen
immediately submits the close command. It no longer navigates to the order
ticket. The position disappears optimistically through the existing EX V2
controller, server reconciliation continues in the background, and genuine
server failures restore the position and display an error.

Other routes that intentionally open an order/close ticket remain unchanged.
The visual layout of the Trade screen and action sheet does not change.

## Verification

A widget regression test must prove that tapping `Đóng trạng thái` removes the
position without requiring GoRouter navigation. Existing close-ticket and EX V2
controller tests must continue to pass.
