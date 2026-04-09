# Implementation Plan: Chat-Style Interaction UI

This plan transitions the Daily Question interaction from a card-based layout to a modern "Chat Thread" layout, making the exchange feel like a private conversation between partners.

## User Review Required

> [!IMPORTANT]
> The interaction will now look like a chat window. 
> - **Self-Answers**: Aligned to the right.
> - **Partner-Answers**: Aligned to the left with their profile picture.
> - **Question**: Will appear as a "System Message" at the start of the thread.

## Proposed Changes

### UI Components

#### [MODIFY] `lib/features/pairing/widgets/daily_question_interactive_sheet.dart`
- **Layout Refactor**: Change the content from a simple `Column` to a chat-like thread.
- **New Chat Bubble Widgets**:
  - `ChatBubble`: A reusable widget for messages.
  - Aligned Left/Right based on the user.
  - Integrated profile avatars (using `ProfileAvatar` from the app).
- **Interactive Review Flow**:
  - The "How did they do?" review buttons will be styled as action chips or a follow-up interaction in the thread.
- **Improved Input**:
  - Style the answer/comment inputs to match a standard chat box at the bottom of the screen.

## Verification Plan

### Manual Verification
1. **Visual Look**:
   - Verify the question looks like a starting prompt.
   - Verify my answer appears on the right.
   - Verify the partner's answer appears on the left with their avatar.
2. **Interactive Flow**:
   - Verify the "Review" buttons appear naturally after the partner's message.
   - Verify the chat thread handles long messages gracefully without overflow.
3. **Keyboard Handling**:
   - Ensure the chat input remains visible and focused when the keyboard opens.
