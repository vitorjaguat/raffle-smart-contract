### Layout of CONTRACT:

- // SPDX-License-Identifier: MIT
- pragma version
- imports
- -errors- (put them as the first items inside the contract, better for testing!)
- interfaces, libraries, contracts
  - errors
  - type declarations
  - state variables
  - events
  - modifiers
  - functions

### Layout of FUNCTIONS:

- constructor
- receive (if any)
- fallback (if any)
- external
- public
- internal
- private
- view & pure functions
