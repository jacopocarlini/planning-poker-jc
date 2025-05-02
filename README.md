# Poker Planning App ♠️

## Description & Link

A real-time Planning Poker application built with Flutter and Firebase. This tool helps Agile teams estimate tasks collaboratively by allowing participants to vote simultaneously and then revealing the votes to facilitate discussion.

**Key Features:**

*   Create new planning rooms.
*   Join existing rooms using a Room ID.
*   Real-time participant list with online status.
*   Select voting cards (e.g., Fibonacci sequence).
*   See who has voted (without revealing the vote value).
*   Reveal all votes simultaneously.
*   View voting results, including:
    *   Average vote (for numeric cards).
    *   Standard Deviation (as a measure of consensus).
    *   Vote summary/distribution.
*   Reset voting for the next estimation round.

**Live Demo:**

[Access the live application here](https://poker-planning-jc.web.app)

<img width="1400" alt="image" src="https://github.com/user-attachments/assets/5baa43f9-e451-490f-9bf9-a8e861120ad0" />




---

## Technologies Used

*   **Frontend Framework:** Flutter (Web)
*   **Programming Language:** Dart
*   **Backend & Realtime Database:** Firebase
    *   **Realtime Database:** For storing room data, participants, votes, and enabling real-time synchronization.
    *   **Firebase Hosting:** For easy deployment of the Flutter web app.

---

## How to Run Locally

Follow these steps to set up and run the project on your local machine:

**Prerequisites:**

1.  **Flutter SDK:** Ensure you have Flutter installed. Follow the official [Flutter installation guide](https://docs.flutter.dev/get-started/install).
2.  **Code Editor:** VS Code with the Flutter extension, Android Studio, or IntelliJ IDEA.

**Setup Steps:**

1.  **Clone the Repository:**
    ```bash
    git clone jacopocarlini/planning-poker-jc
    cd jacopocarlini/planning-poker-jc
    ```

2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the App (Web):**
    ```bash
    flutter run -d chrome
    ```
    This will build and launch the app in your Chrome browser.

---

## Notes

Demo Purpose: This project is intended solely as a technical demonstration.

Firebase Configuration: Please be aware that the Firebase configuration details might be included in the public repository for simplified demo setup. Never expose credentials this way in a real-world application. Use secure methods like environment variables or backend configuration for production.

Free Tier Limits: The application runs on Firebase's free "Spark" plan. Heavy usage might exceed the free quotas, potentially causing the service to become temporarily or permanently unavailable.

---
